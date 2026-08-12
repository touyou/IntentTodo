//
//  GetTodoSummaryIntent.swift
//  TodoAppIntents
//
//  `TodoListSummaryEntity`（TransientAppEntity）を返す Intent。
//  Shortcuts で「未完了が N 件以上なら通知」などの条件分岐に使える。
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
                full: "You have \(summary.pendingCount) pending todo\(summary.pendingCount == 1 ? "" : "s"), \(summary.overdueCount) of which \(summary.overdueCount == 1 ? "is" : "are") overdue.",
                supporting: "\(summary.pendingCount) pending, \(summary.overdueCount) overdue."
            ),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }
}
