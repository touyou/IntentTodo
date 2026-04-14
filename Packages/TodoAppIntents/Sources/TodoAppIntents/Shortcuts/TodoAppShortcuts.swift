//
//  TodoAppShortcuts.swift
//  TodoAppIntents
//
//  Registers Primary intents as App Shortcuts so they appear in Siri, Shortcuts,
//  and Spotlight. FromExtension variants are intentionally NOT registered.
//

import AppIntents

public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        // Create
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo in \(.applicationName)",
                "Create a new todo in \(.applicationName)",
                "New todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Add Todo"),
            systemImageName: "plus.circle"
        )

        // Query: all / incomplete / favorites
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my todos in \(.applicationName)",
                "List todos in \(.applicationName)",
                "What are my todos in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Show Todos"),
            systemImageName: "list.bullet"
        )

        AppShortcut(
            intent: ShowTodosIntent(filter: .incomplete),
            phrases: [
                "Show incomplete todos in \(.applicationName)",
                "What do I need to do in \(.applicationName)",
                "Show unfinished tasks in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Incomplete Todos"),
            systemImageName: "circle"
        )

        AppShortcut(
            intent: ShowTodosIntent(filter: .favorites),
            phrases: [
                "Show favorite todos in \(.applicationName)",
                "Show starred todos in \(.applicationName)",
                "Important todos in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Favorite Todos"),
            systemImageName: "star"
        )

        // Toggle completion (Primary; user picks a todo)
        AppShortcut(
            intent: ToggleTodoCompletionIntent(),
            phrases: [
                "Toggle todo completion in \(.applicationName)",
                "Mark todo in \(.applicationName)",
                "Complete todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Toggle Completion"),
            systemImageName: "checkmark.circle"
        )

        // Toggle favorite
        AppShortcut(
            intent: ToggleFavoriteIntent(),
            phrases: [
                "Toggle favorite in \(.applicationName)",
                "Star todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Toggle Favorite"),
            systemImageName: "star.circle"
        )

        // Delete
        AppShortcut(
            intent: DeleteTodoIntent(),
            phrases: [
                "Delete todo in \(.applicationName)",
                "Remove todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Delete Todo"),
            systemImageName: "trash"
        )

        // Snooze
        AppShortcut(
            intent: SnoozeTodoIntent(),
            phrases: [
                "Snooze todo in \(.applicationName)",
                "Delay todo deadline in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Snooze Todo"),
            systemImageName: "clock.arrow.circlepath"
        )

        // Toggle urgent todo (no parameter — auto-selects)
        AppShortcut(
            intent: ToggleUrgentTodoIntent(),
            phrases: [
                "Toggle urgent todo in \(.applicationName)",
                "Complete my most urgent todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Toggle Urgent Todo"),
            systemImageName: "clock.badge.exclamationmark"
        )

        // Todo count summary
        AppShortcut(
            intent: ShowTodoCountIntent(),
            phrases: [
                "Show todo count in \(.applicationName)",
                "How many todos do I have in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Show Todo Count"),
            systemImageName: "number.circle"
        )

        // Note: `LaunchAppIntent` is used by widgets / control widgets for navigation.
        // Not registered as an App Shortcut because Apple limits AppShortcuts to 10
        // and "Open X" phrases are already covered by `ShowTodosIntent`.
    }
}
