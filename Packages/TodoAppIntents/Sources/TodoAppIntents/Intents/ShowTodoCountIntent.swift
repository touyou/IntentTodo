//
//  ShowTodoCountIntent.swift
//  TodoAppIntents
//
//  Reports the current incomplete todo count to Siri / Shortcuts / Spotlight,
//  showing the breakdown (overdue / completed / total) via dialog + snippet.
//
//  Control からは呼ばない (Control は dialog も snippet も提示しない)。
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
        // fetch 失敗を `try? ?? 0` で握りつぶすと「全部完了!」と嘘の結果を返すため、
        // そのまま throw して Siri / Shortcuts 側にエラーとして伝える。
        let count = try todoService.incompleteCount()
        return .result(
            value: count,
            dialog: dialog(for: count),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }

    /// WWDC 2026 (#343): `full` は音声のみの文脈で単体完結するメッセージ、
    /// `supporting` は snippet が視覚表示される文脈で添える短い一言。
    private func dialog(for count: Int) -> IntentDialog {
        guard count > 0 else {
            return IntentDialog(full: "You've completed every todo.", supporting: "All done.")
        }
        let noun = count == 1 ? "todo" : "todos"
        return IntentDialog(
            full: "You have \(count) incomplete \(noun).",
            supporting: "\(count) incomplete \(noun)."
        )
    }
}
