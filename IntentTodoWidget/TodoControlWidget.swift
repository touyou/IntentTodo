//
//  TodoControlWidget.swift
//  IntentTodoWidget
//
//  Control Center widget for quick todo access.
//  Supports iOS 18+ Control Center integration.
//

import AppIntents
import Domain
import Repository
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

// MARK: - Model Container for Control Widget

private let controlWidgetModelContainer: ModelContainer = {
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: schema, configurations: [config])
}()

// MARK: - Quick Add Control Widget

/// Control widget for quickly adding a new todo.
@available(iOS 18.0, *)
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: QuickAddTodoControlIntent.self
        ) { _ in
            ControlWidgetButton(action: QuickAddTodoControlIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}

/// Intent for quick add control.
///
/// Note: ControlConfigurationIntent must be defined in the extension target,
/// not in a package, due to platform-specific requirements.
@available(iOS 18.0, *)
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Add Todo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        // Uses OpenAddTodoIntent from TodoAppIntents package
        return .result(opensIntent: OpenAddTodoIntent())
    }
}

// MARK: - Todo Count Control Widget

/// Control widget showing incomplete todo count.
@available(iOS 18.0, *)
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: TodoCountControlIntent.self
        ) { configuration in
            ControlWidgetButton(action: OpenTodoListIntent()) {
                Label {
                    Text("\(configuration.incompleteCount)")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap to open list.")
    }
}

/// Intent for todo count control configuration.
@available(iOS 18.0, *)
struct TodoCountControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Todo Count"

    @MainActor
    var incompleteCount: Int {
        let context = controlWidgetModelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

// MARK: - Toggle Urgent Todo Control Widget

/// Control widget for toggling the most urgent todo.
///
/// Displays the most urgent (earliest due date) incomplete todo.
/// Tap to toggle its completion status.
@available(iOS 18.0, *)
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ToggleUrgentTodoControlIntent.self
        ) { configuration in
            ControlWidgetButton(action: ToggleUrgentTodoControlIntent()) {
                Label {
                    Text(configuration.todoTitle ?? "No urgent todo")
                } icon: {
                    Image(systemName: configuration.isCompleted
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
            }
        }
        .displayName("Urgent Todo")
        .description("Toggle completion of the most urgent todo.")
    }
}

/// Intent for toggling the most urgent todo.
@available(iOS 18.0, *)
struct ToggleUrgentTodoControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Toggle Urgent Todo"

    /// The title of the most urgent todo.
    @MainActor
    var todoTitle: String? {
        guard let todo = fetchUrgentTodo() else { return nil }
        return todo.title
    }

    /// Whether the most urgent todo is completed.
    @MainActor
    var isCompleted: Bool {
        guard let todo = fetchUrgentTodo() else { return false }
        return todo.isCompleted
    }

    /// The ID of the most urgent todo (for configuration).
    @MainActor
    var todoId: String? {
        guard let todo = fetchUrgentTodo() else { return nil }
        return todo.id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let todo = fetchUrgentTodo() else {
            return .result()
        }

        let context = controlWidgetModelContainer.mainContext
        todo.isCompleted.toggle()
        try? context.save()

        return .result()
    }

    @MainActor
    private func fetchUrgentTodo() -> TodoItem? {
        let context = controlWidgetModelContainer.mainContext
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
            sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
