//
//  DeleteTodoIntent.swift
//  IntentTodo
//

import AppIntents

/// Deletes a todo item.
///
/// `UndoableIntent`: 消す前にスナップショットを取り、`undoManager` に「同じ id で
/// 戻す」ハンドラを積む。詳細: `TodoUndoRegistrar` / `TodoItemSnapshot`
public struct DeleteTodoIntent: UndoableIntent {
    public static var title: LocalizedStringResource { "Delete Todo" }

    public static var description: IntentDescription {
        IntentDescription(
            "Deletes a todo item",
            categoryName: "Todos",
            searchKeywords: ["delete", "remove", "trash"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$todo)")
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
        // Destructive action — ask Siri / Shortcuts to confirm first. The call
        // throws (cancelling the intent) if the person declines.
        try await requestConfirmation(
            dialog: IntentDialog("Delete “\(todo.title)”?")
        )

        // 削除前に取る。消したあとの `TodoItem` からは何も読めない。
        let snapshot = try todoService.snapshot(todoId: todo.id)
        try todoService.delete(todoId: todo.id)
        TodoUndoRegistrar.registerRestore(
            [snapshot],
            undoManager: undoManager,
            service: todoService
        )

        // The todo no longer exists — remove any donations that reference it so the
        // system stops suggesting actions it can't perform (IntentDonationManager).
        _ = try? await IntentDonationManager.shared.deleteDonations(
            matching: .entityIdentifiers([EntityIdentifier(for: todo)])
        )

        return .result()
    }
}
