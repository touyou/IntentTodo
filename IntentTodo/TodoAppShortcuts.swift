//
//  TodoAppShortcuts.swift
//  IntentTodo
//
//  Registers user-facing intents as App Shortcuts so they appear in Siri,
//  Shortcuts, and Spotlight. Intents marked `isDiscoverable = false` are not registered.
//
//  Phrases embed a parameter where they can ("Complete \(\.$todo) in ..."), with the values
//  coming from `TodoEntityQuery.suggestedEntities()`. Each shortcut also keeps one
//  parameter-free phrase so Siri can ask which todo was meant.
//
//  Parameterised phrases do not work until `updateAppShortcutParameters()` has run at least
//  once; that call is wired to app launch and to `TodoService.dataDidChange()`.
//
//  IMPORTANT: `AppShortcutsProvider` must live in the app target, NOT in an SPM
//  package. When declared inside a Swift Package, the shortcuts are extracted
//  into that package's `.appintents` metadata but are dropped during the app
//  target's metadata aggregation (`autoShortcuts: 0` in the shipped
//  `IntentTodo.app/Metadata.appintents`), so Siri / Shortcuts / Spotlight never
//  see them. Intents/entities/queries DO aggregate from packages; only
//  `AppShortcutsProvider` does not. See docs/insights/03-app-intents-core.md.
//

import AppIntents
import TodoAppIntents

struct TodoAppShortcuts: AppShortcutsProvider {
    /// Background colour of the tiles in the Shortcuts app.
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
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

        // One shortcut rather than several, to stay well inside the ten-shortcut limit: the
        // filter is an `AppEnum`, so its values can be embedded in the phrases.
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my \(\.$filter) todos in \(.applicationName)",
                "Show \(\.$filter) todos in \(.applicationName)",
                "Show my todos in \(.applicationName)",
                "List todos in \(.applicationName)",
                "What are my todos in \(.applicationName)",
                "Open \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Show Todos"),
            systemImageName: "list.bullet"
        )

        // Toggle completion
        AppShortcut(
            intent: ToggleTodoCompletionIntent(),
            phrases: [
                "Complete \(\.$todo) in \(.applicationName)",
                "Mark \(\.$todo) as done in \(.applicationName)",
                "Toggle \(\.$todo) in \(.applicationName)",
                "Toggle todo completion in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Toggle Completion"),
            systemImageName: "checkmark.circle"
        )

        // Toggle favorite
        AppShortcut(
            intent: ToggleFavoriteIntent(),
            phrases: [
                "Star \(\.$todo) in \(.applicationName)",
                "Favorite \(\.$todo) in \(.applicationName)",
                "Toggle favorite in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Toggle Favorite"),
            systemImageName: "star.circle"
        )

        // Delete
        AppShortcut(
            intent: DeleteTodoIntent(),
            phrases: [
                "Delete \(\.$todo) in \(.applicationName)",
                "Remove \(\.$todo) in \(.applicationName)",
                "Delete todo in \(.applicationName)"
            ],
            shortTitle: LocalizedStringResource("Delete Todo"),
            systemImageName: "trash"
        )

        // Snooze
        AppShortcut(
            intent: SnoozeTodoIntent(),
            phrases: [
                "Snooze \(\.$todo) in \(.applicationName)",
                "Delay \(\.$todo) in \(.applicationName)",
                "Snooze todo in \(.applicationName)"
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
