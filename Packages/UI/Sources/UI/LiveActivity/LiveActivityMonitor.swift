//
//  LiveActivityMonitor.swift
//  UI
//
//  Monitors todos and automatically starts/ends Live Activities
//  for todos that are due within 1 hour.
//

#if os(iOS)
import ActivityKit
import Domain
import SwiftUI

/// A view modifier that monitors todos and manages Live Activities.
@available(iOS 16.1, *)
struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    func body(content: Content) -> some View {
        content
            .task {
                await checkAndStartActivities()
            }
            .onChange(of: todos.map(\.id)) { _, _ in
                Task {
                    await checkAndStartActivities()
                }
            }
    }

    @MainActor
    private func checkAndStartActivities() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)

        // Find todos due within 1 hour that are not completed
        let urgentTodos = todos.filter { todo in
            guard let dueDate = todo.dueDate,
                  !todo.isCompleted else { return false }
            return dueDate > now && dueDate <= oneHourFromNow
        }

        // Get existing activity IDs
        let existingActivityTodoIds = Set(
            Activity<TodoDeadlineActivityAttributes>.activities.map { $0.attributes.todoId }
        )

        // Start activities for new urgent todos
        for todo in urgentTodos {
            let todoIdString = todo.id.uuidString
            if !existingActivityTodoIds.contains(todoIdString) {
                guard let dueDate = todo.dueDate else { continue }
                await startActivity(todoId: todoIdString, title: todo.title, dueDate: dueDate)
            }
        }

        // End activities for completed todos or those past 15 minutes after due
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            let todoId = activity.attributes.todoId
            if let todo = todos.first(where: { $0.id.uuidString == todoId }) {
                if todo.isCompleted {
                    await activity.end(dismissalPolicy: .immediate)
                } else if let dueDate = todo.dueDate {
                    let fifteenMinutesAfterDue = dueDate.addingTimeInterval(15 * 60)
                    if now > fifteenMinutesAfterDue {
                        await activity.end(dismissalPolicy: .immediate)
                    }
                }
            }
        }
    }

    private func startActivity(todoId: String, title: String, dueDate: Date) async {
        // Check if activity already exists
        let existingActivity = Activity<TodoDeadlineActivityAttributes>.activities.first {
            $0.attributes.todoId == todoId
        }
        if existingActivity != nil { return }

        let attributes = TodoDeadlineActivityAttributes(todoId: todoId)
        let contentState = TodoDeadlineActivityAttributes.ContentState(
            title: title,
            dueDate: dueDate
        )

        // Set stale date to 15 minutes after due
        let staleDate = dueDate.addingTimeInterval(15 * 60)

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: staleDate),
                pushType: nil
            )
        } catch {
            // Activity creation failed, ignore
        }
    }
}

// MARK: - View Extension

@available(iOS 16.1, *)
public extension View {
    /// Monitors todos and automatically manages Live Activities for urgent items.
    ///
    /// - Parameter todos: The list of todos to monitor.
    /// - Returns: A view with Live Activity monitoring enabled.
    func monitorLiveActivities(for todos: [TodoItem]) -> some View {
        modifier(LiveActivityMonitorModifier(todos: todos))
    }
}
#endif
