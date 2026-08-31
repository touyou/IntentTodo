//
//  GetTodoSummaryIntent.swift
//  TodoAppIntents
//
//

import AppIntents
import Foundation

/// Returns a snapshot of the current todo list statistics.
///
/// Returns a `TodoListSummaryEntity` (`TransientAppEntity`) so Shortcuts users
/// can branch on individual counts without querying individual todos.
///
/// Example Shortcuts use:
/// - "If Get Todo Summary → Overdue Todos > 0 → Send notification"
/// - "If Get Todo Summary → Pending Todos = 0 → Play celebration sound"
public struct GetTodoSummaryIntent: AppIntent {
    public static var title: LocalizedStringResource { "Get Todo Summary" }
    public static let description = IntentDescription("Gets a summary of your todo list, including pending, completed, overdue, and favorite counts.")
    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Get todo summary")
    }

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoListSummaryEntity> & ProvidesDialog & ShowsSnippetIntent {
        let summary = try todoService.summarize()
        return .result(
            value: summary,
            dialog: IntentDialog(
                // Inflection belongs in `^[](inflect:)`. Stitching "s" / "is" / "are" on
                // with a ternary leaves those fragments out of the String Catalog, so
                // English words survive into translated output.
                full: "You have ^[\(summary.pendingCount) pending todo](inflect: true), including ^[\(summary.overdueCount) overdue](inflect: true).",
                supporting: "\(summary.pendingCount) pending, \(summary.overdueCount) overdue."
            ),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }
}
