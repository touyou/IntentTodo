//
//  LaunchAppIntent.swift
//  TodoAppIntents
//
//  Unified OpenIntent for launching the app to specific screens.
//  Used by Widgets, Control Center, Action Button, and Shortcuts.
//

import AppIntents
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "LaunchAppIntent")

// MARK: - App Screen Enum

/// Enum representing app screens that can be opened via OpenIntent.
public enum AppScreenTarget: String, AppEnum {
    case addTodo
    case todoList
    case incompleteTodos
    case favoriteTodos

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("App Screen", comment: "App screen type name")
        )
    }

    public static var caseDisplayRepresentations: [AppScreenTarget: DisplayRepresentation] {
        [
            .addTodo: DisplayRepresentation(
                title: LocalizedStringResource("Add Todo", comment: "Add todo screen"),
                image: .init(systemName: "plus.circle")
            ),
            .todoList: DisplayRepresentation(
                title: LocalizedStringResource("Todo List", comment: "Todo list screen"),
                image: .init(systemName: "list.bullet")
            ),
            .incompleteTodos: DisplayRepresentation(
                title: LocalizedStringResource("Incomplete Todos", comment: "Incomplete todos screen"),
                image: .init(systemName: "circle")
            ),
            .favoriteTodos: DisplayRepresentation(
                title: LocalizedStringResource("Favorite Todos", comment: "Favorite todos screen"),
                image: .init(systemName: "star")
            )
        ]
    }
}

// MARK: - Launch App Intent (Unified OpenIntent)

/// Unified intent to open app to a specific screen.
///
/// This intent is used by:
/// - Widgets: Quick add button, todo list
/// - Control Center: Quick add control, todo count
/// - Action Button: Physical button press on iPhone 15 Pro+
/// - Shortcuts: Open to specific screen
///
/// Conforms to:
/// - `OpenIntent`: For proper Control Center and Widget integration
///
/// Uses `supportedModes: .foreground(.dynamic)` to ensure the intent runs in
/// the main app process with dynamic foreground behavior (iOS 26+).
///
/// The `target` parameter specifies which screen to open.
public struct LaunchAppIntent: OpenIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Todo App", comment: "Intent title for opening the app")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Opens the Todo app to a specific screen",
                comment: "Intent description for opening the app"
            ),
            categoryName: "Todos",
            searchKeywords: ["open", "launch", "app", "todo"]
        )
    }

    /// Forces execution in foreground with dynamic behavior.
    /// This is the iOS 26+ replacement for ForegroundContinuableIntent.
    public static var supportedModes: IntentModes { .foreground(.dynamic) }

    // MARK: - OpenIntent Target

    /// The target screen to open.
    @Parameter(title: "Target")
    public var target: AppScreenTarget

    // MARK: - Initialization

    public init() {
        self.target = .todoList
    }

    public init(target: AppScreenTarget) {
        self.target = target
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("LaunchAppIntent.perform() called with target: \(target.rawValue)")

        switch target {
        case .addTodo:
            IntentAppState.shared.requestShowAddTodo()
            logger.info("IntentAppState.shouldShowAddTodo set to true")
        case .todoList, .incompleteTodos, .favoriteTodos:
            // The app will handle showing the appropriate view based on the target
            // For now, we just log the target
            logger.info("Opening app to target: \(target.rawValue)")
        }

        return .result()
    }
}

// MARK: - Convenience Factory Methods

/// Extension to provide convenience factory methods for common targets.
public extension LaunchAppIntent {
    /// Creates an intent to open the Add Todo screen.
    static func addTodo() -> LaunchAppIntent {
        LaunchAppIntent(target: .addTodo)
    }

    /// Creates an intent to open the Todo List screen.
    static func todoList() -> LaunchAppIntent {
        LaunchAppIntent(target: .todoList)
    }

    /// Creates an intent to open the Incomplete Todos screen.
    static func incompleteTodos() -> LaunchAppIntent {
        LaunchAppIntent(target: .incompleteTodos)
    }

    /// Creates an intent to open the Favorite Todos screen.
    static func favoriteTodos() -> LaunchAppIntent {
        LaunchAppIntent(target: .favoriteTodos)
    }
}
