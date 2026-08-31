//
//  DeleteTodoIntent.swift
//  IntentTodo
//

import AppIntents

/// Deletes a todo item.
///
/// Undo restores the todo under the *same* id, so Spotlight entries, donations and widget
/// references stay valid. See `TodoUndoRegistrar`.
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

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
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

        // Taken before the delete: nothing can be read off a deleted `TodoItem`.
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
