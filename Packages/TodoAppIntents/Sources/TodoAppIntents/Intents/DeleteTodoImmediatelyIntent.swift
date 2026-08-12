//
//  DeleteTodoImmediatelyIntent.swift
//  TodoAppIntents
//
//  `DeleteTodoIntent` と分かれている理由は entity 解決の回避ではなく **対話の有無**。
//  `DeleteTodoIntent` は `requestConfirmation` で確認を取るが、アプリ内の
//  `Button(intent:)` には確認を提示する面が無く、
//  `LNPerformActionErrorCodeUnsupportedValueType` で失敗して**何も起きない**。
//  UI 側は SwiftUI の `.confirmationDialog` / スワイプ操作自体を確認手段とし、
//  実際の削除はこちらの確認なし版で行う。
//  経緯: docs/devlog/06-control-widget-ios26.md（2026-08-12 の削除ボタン不動作）
//

import AppIntents

/// Deletes a todo without asking for confirmation.
///
/// 呼出元（UI）が既に確認を取っている前提。Siri / Shortcuts から
/// ユーザーが直接選ぶ用途には確認付きの `DeleteTodoIntent` を使う。
public struct DeleteTodoImmediatelyIntent: AppIntent {
    public static var title: LocalizedStringResource { "Delete Todo Immediately" }
    public static let description = IntentDescription("Deletes a todo without asking for confirmation.")

    /// 確認なしの破壊的操作なので、ユーザーが選べる候補としては出さない。
    public static let isDiscoverable = false
    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$todo) without confirming")
    }

    @Parameter(title: "Todo", description: "The todo to delete")
    public var todo: TodoAppEntity

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.delete(todoId: todo.id)

        // The todo no longer exists — remove any donations that reference it so the
        // system stops suggesting actions it can't perform (IntentDonationManager).
        _ = try? await IntentDonationManager.shared.deleteDonations(
            matching: .entityIdentifiers([EntityIdentifier(for: todo)])
        )

        return .result()
    }
}
