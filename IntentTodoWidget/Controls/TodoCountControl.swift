//
//  TodoCountControl.swift
//  IntentTodoWidget
//
//  Control Center widget showing incomplete todo count.
//

import Domain
import SwiftData
import SwiftUI
import WidgetKit

/// Control widget showing incomplete todo count.
/// Tapping sends a notification with the current count summary.
/// Uses .background intent because opening the app directly from
/// Control Widgets is unreliable on iOS 26.
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ShowTodoCountIntent()) {
                Label {
                    Text("\(fetchIncompleteCount())")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap for summary.")
    }

    @MainActor
    private func fetchIncompleteCount() -> Int {
        let context = sharedWidgetModelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}
