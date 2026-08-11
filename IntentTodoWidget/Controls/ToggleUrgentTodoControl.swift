//
//  ToggleUrgentTodoControl.swift
//  IntentTodoWidget
//
//  Control Center widget for toggling the most urgent todo.
//

#if !os(visionOS)
import Domain
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "ToggleUrgentTodoControl")

/// Control widget for toggling the most urgent todo.
///
/// Displays the most urgent (earliest due date) incomplete todo.
/// Tap to toggle its completion status.
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetButton(action: ToggleUrgentTodoIntent()) {
                Label {
                    Text(snapshot.title ?? "No urgent todo")
                } icon: {
                    Image(systemName: snapshot.isCompleted
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
                // Control Center は dialog を出さないため通知でも結果を返しているが、
                // このモディファイアで Control 自体にも即時の状態文字列を表示できる
                // (wwdc2024-10157 16:08「controlWidgetStatus で瞬間的なステータスを表示」)。
                .controlWidgetStatus(snapshot.isCompleted ? "Completed" : "Due soon")
            }
        }
        .displayName("Urgent Todo")
        .description("Toggle completion of the most urgent todo.")
    }
}

extension ToggleUrgentTodoControl {
    /// Snapshot fed to the control body. body 内で直接 fetch するより、
    /// ControlValueProvider 経由で値を渡した方が WidgetKit と整合する。
    struct Snapshot: Sendable {
        let title: String?
        let isCompleted: Bool

        static let empty = Snapshot(title: nil, isCompleted: false)
    }

    struct Provider: ControlValueProvider {
        var previewValue: Snapshot {
            Snapshot(title: "Finish report", isCompleted: false)
        }

        func currentValue() async throws -> Snapshot {
            try await MainActor.run {
                let context = sharedWidgetModelContainer.mainContext
                var descriptor = FetchDescriptor<TodoItem>(
                    predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
                    sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
                )
                descriptor.fetchLimit = 1
                do {
                    let todo = try context.fetch(descriptor).first
                    return todo.map { Snapshot(title: $0.title, isCompleted: $0.isCompleted) } ?? .empty
                } catch {
                    // fetch 失敗を `try?` で `.empty` (= "No urgent todo") に潰すと、
                    // ユーザーが「期限近い Todo はない」と誤認して期限超過するリスクがある。
                    // throw して WidgetKit に前回値 / placeholder の維持を委ねる。
                    logger.error("ToggleUrgentTodoControl fetch failed: \(String(reflecting: error))")
                    throw error
                }
            }
        }
    }
}
#endif
