//
//  TodoControlWidget.swift
//  IntentTodoWidget
//
//  Control Center widget for quick todo access.
//  Supports iOS 18+ Control Center integration.
//

import AppIntents
import SwiftData
import SwiftUI
import WidgetKit
import Domain
import TodoAppIntents

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
@available(iOS 18.0, *)
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Add Todo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        return .result(opensIntent: OpenAddTodoIntent())
    }
}

/// Intent to open app with add todo sheet.
struct OpenAddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Add Todo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // The app will handle showing the add todo sheet
        return .result()
    }
}

// MARK: - Todo Count Control Widget

/// Control widget showing incomplete todo count.
@available(iOS 18.0, *)
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTodoListIntent()) {
                Label {
                    Text("Todos")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("View your incomplete todos.")
    }
}

// MARK: - Toggle Todo Control Widget

/// Control widget for toggling the most urgent todo.
@available(iOS 18.0, *)
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ToggleUrgentTodoIntent.self
        ) { configuration in
            ControlWidgetToggle(isOn: configuration.isCompleted, action: configuration) {
                Label(configuration.todoTitle ?? "No urgent todo", systemImage: "clock.badge.exclamationmark")
            }
        }
        .displayName("Urgent Todo")
        .description("Complete your most urgent todo.")
    }
}

/// Intent for toggling the most urgent (nearest deadline) todo.
@available(iOS 18.0, *)
struct ToggleUrgentTodoIntent: SetValueIntent, ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Toggle Urgent Todo"

    @Parameter(title: "Completed")
    var value: Bool

    @Parameter(title: "Todo Title")
    var todoTitle: String?

    @Parameter(title: "Todo ID")
    var todoId: String?

    @Parameter(title: "Is Completed")
    var isCompleted: Bool

    init() {
        self.value = false
        self.todoTitle = nil
        self.todoId = nil
        self.isCompleted = false
    }

    init(value: Bool, todoTitle: String?, todoId: String?, isCompleted: Bool) {
        self.value = value
        self.todoTitle = todoTitle
        self.todoId = todoId
        self.isCompleted = isCompleted
    }

    func perform() async throws -> some IntentResult {
        guard let todoId, let uuid = UUID(uuidString: todoId) else {
            return .result()
        }

        let repository = await IntentDependencies.shared.repository
        if let todo = try await repository.fetch(by: uuid) {
            todo.isCompleted = value
            try await repository.update(todo)
        }

        return .result()
    }
}

// MARK: - Action Button Support

/// Intent for Action Button integration.
/// Allows quick todo creation with physical button press.
struct ActionButtonAddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Todo"
    static var description = IntentDescription("Create a new todo with Action Button.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        // Opens app to add todo screen
        return .result()
    }
}

// MARK: - Shortcuts Provider

/// Provides app shortcuts for Shortcuts app and Siri.
struct TodoAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new task in \(.applicationName)",
                "New todo in \(.applicationName)"
            ],
            shortTitle: "Add Todo",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my todos in \(.applicationName)",
                "Show my tasks in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: "Show Todos",
            systemImageName: "checklist"
        )

        AppShortcut(
            intent: ShowIncompleteTodosIntent(),
            phrases: [
                "Show incomplete todos in \(.applicationName)",
                "What tasks are left in \(.applicationName)",
                "Show remaining tasks in \(.applicationName)"
            ],
            shortTitle: "Incomplete Todos",
            systemImageName: "circle"
        )

        AppShortcut(
            intent: ShowFavoriteTodosIntent(),
            phrases: [
                "Show favorite todos in \(.applicationName)",
                "Show starred tasks in \(.applicationName)",
                "Important todos in \(.applicationName)"
            ],
            shortTitle: "Favorite Todos",
            systemImageName: "star"
        )
    }
}

// MARK: - Control Widget Bundle

@available(iOS 18.0, *)
extension IntentTodoWidgetBundle {
    var controls: some ControlWidget {
        QuickAddTodoControl()
        TodoCountControl()
        ToggleUrgentTodoControl()
    }
}
