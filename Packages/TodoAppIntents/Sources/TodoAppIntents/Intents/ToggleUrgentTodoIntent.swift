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

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetIntent {
        let result = try todoService.toggleMostUrgentTodo()
        // 片付けた直後は「残りどれだけか」が次に知りたい情報なので、個別 todo ではなく
        // サマリ snippet を返す。対象が無かった場合も同じ型で返せる。
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
