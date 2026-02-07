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
///
/// Uses `StaticControlConfiguration` with `LocalOpenTodoListIntent` for reliable app launch.
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LocalOpenTodoListIntent()) {
                Label {
                    Text("\(fetchIncompleteCount())")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap to open list.")
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
