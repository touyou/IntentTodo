//
//  ToggleFavoriteIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that toggles the favorite status of a todo item.
///
/// This intent can be triggered via:
/// - Siri: "Star 'Buy groceries' in IntentTodo"
/// - Shortcuts: Toggle Favorite action
/// - UI: `Button(intent: ToggleFavoriteIntent(todo: entity))`
public struct ToggleFavoriteIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        "Toggle Favorite"
    }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as favorite or removes from favorites",
            categoryName: "Todos",
            searchKeywords: ["favorite", "star", "important", "priority"]
        )
    }

    public static var openAppWhenRun: Bool { false }

    // MARK: - Parameters

    @Parameter(title: "Todo", description: "The todo to toggle favorite status")
    public var todo: TodoAppEntity

    // MARK: - Initialization

    public init() {}

    /// Creates an intent to toggle the favorite status of the specified todo.
    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let repository = try IntentDependencies.shared.createRepository()

        guard let uuid = UUID(uuidString: todo.id),
              let todoItem = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }

        // Toggle favorite status
        todoItem.isFavorite.toggle()

        // Save changes
        try repository.update(todoItem)

        // Return updated entity
        let entity = TodoAppEntity(from: todoItem)
        return .result(value: entity)
    }
}
