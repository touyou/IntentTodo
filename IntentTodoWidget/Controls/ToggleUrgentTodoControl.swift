//
//  ToggleUrgentTodoControl.swift
//  IntentTodoWidget
//
//  Control Center widget for toggling the most urgent todo.
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

/// Control widget for toggling the most urgent todo.
///
/// Displays the most urgent (earliest due date) incomplete todo.
/// Tap to toggle its completion status.
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ToggleUrgentTodoIntent()) {
                Label {
                    Text(fetchUrgentTodoTitle() ?? "No urgent todo")
                } icon: {
                    Image(systemName: isUrgentTodoCompleted()
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
            }
        }
        .displayName("Urgent Todo")
        .description("Toggle completion of the most urgent todo.")
    }

    @MainActor
    private func fetchUrgentTodoTitle() -> String? {
        fetchUrgentTodo()?.title
    }

    @MainActor
    private func isUrgentTodoCompleted() -> Bool {
        fetchUrgentTodo()?.isCompleted ?? false
    }

    @MainActor
    private func fetchUrgentTodo() -> TodoItem? {
        let context = sharedWidgetModelContainer.mainContext
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
            sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
