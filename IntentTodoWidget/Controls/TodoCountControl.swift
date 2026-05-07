//
//  TodoCountControl.swift
//  IntentTodoWidget
//
//  Control Center widget showing incomplete todo count.
//

#if !os(visionOS)
import Domain
import os.log
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoCountControl")

/// Control widget showing incomplete todo count.
/// Tapping sends a notification with the current count summary.
struct TodoCountControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: ShowTodoCountIntent()) {
                Label {
                    Text("\(count)")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap for summary.")
    }
}

extension TodoCountControl {
    /// Value provider is the Apple-recommended way to feed data into a Control Widget.
    /// body 内で直接 fetch するより、システムが適切なタイミングで `currentValue()` を
    /// 呼ぶのでバックグラウンド挙動や更新が WidgetKit 側で最適化される。
    struct Provider: ControlValueProvider {
        var previewValue: Int { 3 }

        func currentValue() async throws -> Int {
            try await MainActor.run {
                let context = sharedWidgetModelContainer.mainContext
                let descriptor = FetchDescriptor<TodoItem>(
                    predicate: #Predicate { !$0.isCompleted }
                )
                do {
                    return try context.fetchCount(descriptor)
                } catch {
                    // fetch 失敗を `?? 0` で吸収すると Control が "0" を表示し、
                    // ユーザーは「全部完了」と誤認してしまうため throw に変える。
                    // WidgetKit が前回値 / placeholder を維持し、`?? 0` の嘘表示を回避。
                    logger.error("TodoCountControl fetchCount failed: \(String(reflecting: error))")
                    throw error
                }
            }
        }
    }
}
#endif
