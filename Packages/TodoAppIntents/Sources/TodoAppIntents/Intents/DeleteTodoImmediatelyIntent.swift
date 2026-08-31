//
//  DeleteTodoImmediatelyIntent.swift
//  TodoAppIntents
//
//

import AppIntents

/// Deletes a todo without asking for confirmation.
///
/// Exists because a confirming intent cannot run from the app's own UI: there is no
/// surface to answer `requestConfirmation` on, so the run fails with
/// `LNPerformActionErrorCodeUnsupportedValueType` and *nothing happens*. The UI confirms
/// with `.confirmationDialog` (or treats the swipe itself as the confirmation) and then
/// calls this. Siri and Shortcuts use `DeleteTodoIntent` instead.
public struct DeleteTodoImmediatelyIntent: UndoableIntent {
    public static var title: LocalizedStringResource { "Delete Todo Immediately" }
    public static let description = IntentDescription("Deletes a todo without asking for confirmation.")

    /// Destructive with no confirmation, so it is never offered as a user-pickable action.
    public static let isDiscoverable = false
    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

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
        // No confirmation makes undo the only safety net, so snapshot before deleting.
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
