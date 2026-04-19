//
//  ToggleFavoriteIntent.swift
//  IntentTodo
//

import AppIntents

/// Toggles the favorite status of a todo item.
public struct ToggleFavoriteIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Favorite" }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as favorite or removes from favorites",
            categoryName: "Todos",
            searchKeywords: ["favorite", "star", "important", "priority"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle favorite of \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to toggle favorite status")
    public var todo: TodoAppEntity

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let entity = try todoService.toggleFavorite(todoId: todo.id)
        return .result(value: entity)
    }
}
