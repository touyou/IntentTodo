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
import os.log
import SwiftUI

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "LiveActivityMonitor")

struct LiveActivityMonitorModifier: ViewModifier {
    let todos: [TodoItem]

    /// reconcile が反応すべき変化を絞った signature。dueDate を持たない todo は
    /// Live Activity の対象外なので無視し、対象 todo の `id` / `isCompleted` /
    /// `dueDate` のみを観測する。これにより dueDate 無 todo の追加・編集では
    /// `.task` が再起動されなくなる (旧実装は全 todo の id 配列を毎更新で
    /// 再アロケートしており、件数増で観測コストが線形に増えていた)。
    private var monitorSignature: [String] {
        todos.compactMap { todo in
            guard let dueDate = todo.dueDate else { return nil }
            return "\(todo.id.uuidString)|\(todo.isCompleted)|\(dueDate.timeIntervalSinceReferenceDate)"
        }
    }

    func body(content: Content) -> some View {
        // .task(id:) は id 変化のたびに自動でキャンセル＆再起動するので、
        // onChange + unstructured Task の組み合わせより安全でシリアル実行が保証される。
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
                // Activity 上限到達 (8 件) / throttling / Encodable 失敗等。
                // ユーザー操作で解消可能なので silently 飲まずログを残す。
                // 同一 todoId に対しては次の reconcile (todos 変化時) で再試行される。
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
