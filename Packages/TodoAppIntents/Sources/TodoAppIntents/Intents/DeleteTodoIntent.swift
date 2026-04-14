//
//  DeleteTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Domain
import Repository
import SwiftData

/// Deletes a todo item.
public struct DeleteTodoIntent: AppIntent {
    public static var title: LocalizedStringResource { "Delete Todo" }

    public static var description: IntentDescription {
        IntentDescription(
            "Deletes a todo item",
            categoryName: "Todos",
            searchKeywords: ["delete", "remove", "trash"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to delete")
    public var todo: TodoAppEntity

    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        try TodoActions.delete(todoId: todo.id, using: repository)
        WidgetReloader.reloadAllWidgets()
        return .result()
    }
}
