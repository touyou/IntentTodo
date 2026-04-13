//
//  TodoAppShortcuts.swift
//  TodoAppIntents
//
//  Provides App Shortcuts for the Todo app.
//

import AppIntents

/// Provides App Shortcuts for the Todo app.
///
/// App Shortcuts allow users to quickly access app features via Siri,
/// the Shortcuts app, and Spotlight.
public struct TodoAppShortcuts: AppShortcutsProvider {
    // MARK: - App Shortcuts

    /// The shortcuts available for this app.
    public static var appShortcuts: [AppShortcut] {
        // Add a new todo
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new todo in \(.applicationName)",
                "New todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Todo", comment: "Add todo shortcut title"),
            systemImageName: "plus.circle"
        )

        // Show all todos
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my todos in \(.applicationName)",
                "List todos in \(.applicationName)",
                "What are my todos in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Show Todos", comment: "Show todos shortcut title"),
            systemImageName: "list.bullet"
        )

        // Show incomplete todos
        AppShortcut(
            intent: ShowTodosIntent(filter: .incomplete),
            phrases: [
                "Show incomplete todos in \(.applicationName)",
                "What do I need to do in \(.applicationName)",
                "Show unfinished tasks in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(
                "Incomplete Todos",
                comment: "Incomplete todos shortcut title"
            ),
            systemImageName: "circle"
        )

        // Show favorite todos
        AppShortcut(
            intent: ShowTodosIntent(filter: .favorites),
            phrases: [
                "Show favorite todos in \(.applicationName)",
                "Show starred todos in \(.applicationName)",
                "Important todos in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource(
                "Favorite Todos",
                comment: "Favorite todos shortcut title"
            ),
            systemImageName: "star"
        )
    }
}
