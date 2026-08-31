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
/// Tapping opens the app's incomplete list.
///
/// The count is already on the control face, so tapping drills in rather than reporting it
/// again — a control shows neither dialogs nor snippets anyway.
struct TodoCountControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: LaunchAppIntent.incompleteTodos()) {
                Label {
                    Text("\(count)")
                } icon: {
                    Image(systemName: "checklist")
                }
                .controlWidgetActionHint("Show Incomplete Todos")
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap to open the list.")
    }
}

extension TodoCountControl {
    /// Value provider is the Apple-recommended way to feed data into a Control Widget.
    /// The system decides when to call `currentValue()`, which is what lets WidgetKit
    /// schedule the work; fetching inside `body` bypasses that.
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
                    // Absorbing the failure with `?? 0` would display "0", i.e. "all
                    // done". Throwing keeps WidgetKit on the previous value instead.
                    logger.error("TodoCountControl fetchCount failed: \(String(reflecting: error))")
                    throw error
                }
            }
        }
    }
}
#endif
