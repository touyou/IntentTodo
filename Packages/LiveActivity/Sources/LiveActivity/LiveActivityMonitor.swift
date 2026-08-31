//
//  LiveActivityMonitor.swift
//  LiveActivity
//
//  SwiftUI view modifier that starts and ends Live Activities for todos due within the hour.
//  The start / end calls themselves live in `TodoLiveActivityManager`.
//

#if os(iOS)
import ActivityKit
import Domain
import os.log
import SwiftUI

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "LiveActivityMonitor")

struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    /// Narrows what reconciliation reacts to: todos without a due date can never have an
    /// activity, so adding or editing one does not restart the task.
    private var monitorSignature: [String] {
        todos.compactMap { todo in
            guard let dueDate = todo.dueDate else { return nil }
            return "\(todo.id.uuidString)|\(todo.isCompleted)|\(dueDate.timeIntervalSinceReferenceDate)"
        }
    }

    func body(content: Content) -> some View {
        // `.task(id:)` cancels and restarts on every change, which keeps the work serial —
        // unlike `onChange` plus an unstructured `Task`.
        content.task(id: monitorSignature) {
            await checkAndReconcileActivities()
        }
    }

    @MainActor
    private func checkAndReconcileActivities() async {
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)

        let urgentTodos = todos.filter { todo in
            guard let dueDate = todo.dueDate,
                  !todo.isCompleted else { return false }
            return dueDate > now && dueDate <= oneHourFromNow
        }

        for todo in urgentTodos {
            guard let dueDate = todo.dueDate else { continue }
            do {
                try await TodoLiveActivityManager.shared.startActivity(
                    todoId: todo.id.uuidString,
                    title: todo.title,
                    dueDate: dueDate
                )
            } catch {
                // Activity limit reached, throttling, encoding failure. All recoverable, and
                // the next reconciliation retries, so this logs rather than throwing.
                logger.error(
                    "startActivity failed for todoId=\(todo.id.uuidString, privacy: .public): \(String(reflecting: error))"
                )
            }
        }

        // End activities for completed todos or those past 15 minutes after due.
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            let todoId = activity.attributes.todoId
            guard let todo = todos.first(where: { $0.id.uuidString == todoId }) else { continue }
            if todo.isCompleted {
                await TodoLiveActivityManager.shared.endActivity(for: todoId)
            } else if let dueDate = todo.dueDate {
                let fifteenMinutesAfterDue = dueDate.addingTimeInterval(15 * 60)
                if now > fifteenMinutesAfterDue {
                    await TodoLiveActivityManager.shared.endActivity(for: todoId)
                }
            }
        }
    }
}

public extension View {
    /// Monitors todos and automatically manages Live Activities for items due within 1 hour.
    ///
    /// - Parameter todos: The list of todos to monitor.
    /// - Returns: A view with Live Activity monitoring enabled.
    func monitorLiveActivities(for todos: [TodoItem]) -> some View {
        modifier(LiveActivityMonitorModifier(todos: todos))
    }
}
#endif
