//
//  ToggleUrgentTodoIntent.swift
//  TodoAppIntents
//
//  Auto-selects the most urgent (earliest-due) incomplete todo and toggles it.
//
//  Siri / Shortcuts only — surfaces where dialog and snippets both render.
//

import AppIntents

public struct ToggleUrgentTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Urgent Todo"
    public static let description = IntentDescription("Toggles completion of the most urgent todo")
    public static let supportedModes: IntentModes = [.background]

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let result = try todoService.toggleMostUrgentTodo()
        // "How much is left" is the useful answer right after clearing one, so this
        // returns the summary snippet rather than the individual todo. The same shape also
        // covers the case where there was nothing to toggle.
        return .result(
            dialog: dialog(for: result),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }

    private func dialog(for result: UrgentTodoToggleResult?) -> IntentDialog {
        guard let result else {
            return IntentDialog(
                full: "You have no todos with a due date left to do.",
                supporting: "Nothing due."
            )
        }
        if result.isNowCompleted {
            return IntentDialog(
                full: "Completed \(result.title).",
                supporting: "Completed \(result.title)."
            )
        }
        return IntentDialog(
            full: "Reopened \(result.title).",
            supporting: "Reopened \(result.title)."
        )
    }
}
