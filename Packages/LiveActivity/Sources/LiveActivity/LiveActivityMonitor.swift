//
//  LiveActivityMonitor.swift
//  LiveActivity
//
//  Todo の配列を監視し、期限1時間以内のものに対して Live Activity を自動で start/end する
//  SwiftUI ViewModifier。start / end 自体は TodoLiveActivityManager に委譲する。
//

#if os(iOS)
import ActivityKit
import Domain
import SwiftUI

struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    func body(content: Content) -> some View {
        // .task(id:) は id 変化のたびに自動でキャンセル＆再起動するので、
        // onChange + unstructured Task の組み合わせより安全でシリアル実行が保証される。
        content.task(id: todos.map(\.id)) {
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
            try? await TodoLiveActivityManager.shared.startActivity(
                todoId: todo.id.uuidString,
                title: todo.title,
                dueDate: dueDate
            )
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
