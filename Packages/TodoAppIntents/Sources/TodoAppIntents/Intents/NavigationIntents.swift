//
//  NavigationIntents.swift
//  TodoAppIntents
//
//  Navigation intents for opening the app to specific screens.
//  Designed for Control Center widgets and Shortcuts.
//

import AppIntents
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "NavigationIntents")

// MARK: - Simple Open Add Todo Intent

/// Simple intent for opening the app to add a todo.
///
/// This is a parameterless intent specifically designed for Control Center widgets.
/// Unlike `LaunchAppIntent` which has a target parameter, this intent has no parameters
/// and always opens to the add todo screen.
public struct OpenAddTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Add Todo", comment: "Intent title for opening add todo screen")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Opens the app to add a new todo",
                comment: "Intent description for opening add todo screen"
            ),
            categoryName: "Navigation",
            searchKeywords: ["open", "add", "new", "todo", "create"]
        )
    }

    /// Runs in foreground mode to open the app.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("OpenAddTodoIntent.perform() called")

        // Set flag for the main app to show add todo screen
        IntentAppState.shared.requestShowAddTodo()
        logger.info("IntentAppState.shouldShowAddTodo set to true")

        return .result()
    }
}

// MARK: - Simple Open Todo List Intent

/// Simple intent for opening the app to the todo list.
public struct OpenTodoListIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Todo List", comment: "Intent title for opening todo list")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Opens the app to view todos",
                comment: "Intent description for opening todo list"
            ),
            categoryName: "Navigation",
            searchKeywords: ["open", "list", "todos", "view"]
        )
    }

    /// Runs in foreground mode to open the app.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("OpenTodoListIntent.perform() called")
        // No special state to set - just open the app to the default list
        return .result()
    }
}
