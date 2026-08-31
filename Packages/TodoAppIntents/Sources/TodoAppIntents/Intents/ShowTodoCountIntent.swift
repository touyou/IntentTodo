//
//  ShowTodoCountIntent.swift
//  TodoAppIntents
//
//  Reports the current incomplete todo count to Siri / Shortcuts / Spotlight,
//  showing the breakdown (overdue / completed / total) via dialog + snippet.
//
//  Not called from Control Center, which presents neither dialogs nor snippets.
//

import AppIntents

public struct ShowTodoCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Todo Count"
    public static let description = IntentDescription("Shows how many todos are still incomplete")
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetIntent {
        // Swallowing a fetch failure with `try? ?? 0` would report "all done" — a lie.
        // Let it throw so the caller sees an error.
        let count = try todoService.incompleteCount()
        return .result(
            value: count,
            dialog: dialog(for: count),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }

    /// `full` is the self-contained sentence for voice-only contexts; `supporting` is the
    /// short line added when the snippet is also visible. [Apple: wwdc2026-343]
    private func dialog(for count: Int) -> IntentDialog {
        guard count > 0 else {
            return IntentDialog(full: "You've completed every todo.", supporting: "All done.")
        }
        // The noun is localized, not inflected in Swift: fragments built with `+` or `?:`
        // never reach the String Catalog.
        let noun = String(localized: count == 1 ? "todo" : "todos")
        return IntentDialog(
            full: "You have \(count) incomplete \(noun).",
            supporting: "\(count) incomplete \(noun)."
        )
    }
}
