//
//  ToggleFavoriteIntent.swift
//  IntentTodo
//

import AppIntents
import Repository
import SwiftData

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
    var modelContainer: ModelContainer

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))

        guard let uuid = UUID(uuidString: todo.id),
              let todoItem = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }

        todoItem.isFavorite.toggle()
        try repository.update(todoItem)
        WidgetReloader.reloadAllWidgets()

        return .result(value: TodoAppEntity(from: todoItem))
    }
}
