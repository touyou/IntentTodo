//
//  ToggleTodoControl.swift
//  IntentTodoWidget
//
//  Control Center toggle for a todo the person configures.
//
//  The todo is fixed by configuration because a toggle's `isOn` must survive
//  reloads. An action whose target moves (e.g. "the most urgent todo") can't be a
//  toggle — see docs/insights/06-control-widget-ios26.md.
//

#if !os(visionOS)
import Domain
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "ToggleTodoControl")

/// Control widget that completes / reopens a configured todo.
struct ToggleTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.ToggleTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetToggle(
                snapshot.title,
                isOn: snapshot.isCompleted,
                action: SetTodoCompletionIntent(todoId: snapshot.todoId ?? "")
            ) { isOn in
                Label(
                    isOn ? "Completed" : "To Do",
                    systemImage: isOn ? "checkmark.circle.fill" : "circle"
                )
                // 動詞始まりの hint。クロージャの isOn は「その状態へ遷移させる操作」を指す
                // (wwdc2024-10157 15:43)。
                .controlWidgetActionHint(isOn ? "Complete Todo" : "Reopen Todo")
            }
            .tint(.accentColor)
        }
        // 対象 todo が決まっていないと機能しないコントロールなので、追加時に設定を促す。
        .promptsForUserConfiguration()
        .displayName("Complete Todo")
        .description("Complete or reopen a todo you choose.")
    }
}

extension ToggleTodoControl {
    /// Snapshot fed to the control body.
    struct Snapshot: Sendable {
        let todoId: String?
        let title: String
        let isCompleted: Bool

        static let unconfigured = Snapshot(
            todoId: nil,
            title: String(localized: "Choose a Todo"),
            isCompleted: false
        )
    }

    /// Resolves the configured todo's *current* state. The configuration only
    /// carries the entity snapshot from when it was picked, so completion status
    /// and title are re-read from the store on every reload.
    struct Provider: AppIntentControlValueProvider {
        func previewValue(configuration: SelectTodoConfigurationIntent) -> Snapshot {
            guard let todo = configuration.todo else { return .unconfigured }
            // previewValue はコントロールギャラリー用。公式ガイダンス通り off 状態で返す。
            return Snapshot(todoId: todo.id, title: todo.title, isCompleted: false)
        }

        func currentValue(configuration: SelectTodoConfigurationIntent) async throws -> Snapshot {
            guard let todo = configuration.todo, let uuid = UUID(uuidString: todo.id) else {
                return .unconfigured
            }
            return try await MainActor.run {
                let context = sharedWidgetModelContainer.mainContext
                var descriptor = FetchDescriptor<TodoItem>(
                    predicate: #Predicate { $0.id == uuid }
                )
                descriptor.fetchLimit = 1
                do {
                    guard let item = try context.fetch(descriptor).first else {
                        // 設定後に削除された todo。設定し直しを促す表示に戻す。
                        logger.notice("configured todo no longer exists id=\(todo.id, privacy: .public)")
                        return .unconfigured
                    }
                    return Snapshot(todoId: todo.id, title: item.title, isCompleted: item.isCompleted)
                } catch {
                    // fetch 失敗を握り潰すと未完了なのに "Completed" を出す等の嘘表示になる。
                    // throw して WidgetKit に前回値 / placeholder の維持を委ねる。
                    logger.error("ToggleTodoControl fetch failed: \(String(reflecting: error))")
                    throw error
                }
            }
        }
    }
}
#endif
