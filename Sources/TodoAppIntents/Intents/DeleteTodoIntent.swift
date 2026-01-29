//
//  DeleteTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that deletes a todo item.
///
/// This intent can be triggered via:
/// - Siri: "Delete 'Buy groceries' from IntentTodo"
/// - Shortcuts: Delete Todo action
/// - UI: `Button(intent: DeleteTodoIntent(todo: entity))`
public struct DeleteTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        "Delete Todo"
    }

    public static var description: IntentDescription {
        IntentDescription(
            "Deletes a todo item",
            categoryName: "Todos",
            searchKeywords: ["delete", "remove", "trash"]
        )
    }

    public static var openAppWhenRun: Bool { false }

    // MARK: - Parameters

    @Parameter(title: "Todo", description: "The todo to delete")
    public var todo: TodoAppEntity

    // MARK: - Initialization

    public init() {}

    /// Creates an intent to delete the specified todo.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        let repository = try IntentDependencies.shared.createRepository()

        guard let uuid = UUID(uuidString: todo.id) else {
            throw IntentError.validation("Invalid todo ID")
        }

        // Delete the todo
        try repository.delete(by: uuid)

        return .result()
    }
}
