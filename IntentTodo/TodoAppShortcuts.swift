//
//  TodoAppShortcuts.swift
//  IntentTodo
//
//  Registers user-facing intents as App Shortcuts so they appear in Siri,
//  Shortcuts, and Spotlight. `isDiscoverable = false` の内部用 Intent
//  (QuickSnoozeTodoIntent / SetTodoCompletionIntent 等) は登録しない。
//
//  フレーズには可能な限り Intent のパラメータを埋め込む（"Complete \(\.$todo) in ..."）。
//  候補はシステムが `TodoEntityQuery.suggestedEntities()` から取る。パラメータ無しの
//  フレーズも各 shortcut に 1 つ残す（指定なしで呼ばれたとき Siri が聞き返せるように）。
//
//  パラメータ付きフレーズは `updateAppShortcutParameters()` が一度も呼ばれていないと
//  機能しない。呼び出しは `IntentTodoApp` の起動時と `TodoService.dataDidChange()` に
//  紐づけてある。詳細: docs/insights/03-app-intents-core.md
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

        // Query: 1 shortcut に統合（AppShortcuts は 10 件上限）。フィルタは
        // `TodoFilterType`（AppEnum）で値が事前に確定しているのでフレーズに埋め込める。
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
