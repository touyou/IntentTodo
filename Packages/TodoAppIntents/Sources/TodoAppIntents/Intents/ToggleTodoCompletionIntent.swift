//
//  ToggleTodoCompletionIntent.swift
//  TodoAppIntents
//
//  Primary variant: runs in the main app process via @Dependency.
//  For widget / Live Activity contexts, use ToggleTodoCompletionFromExtensionIntent.
//

import AppIntents
import Domain
import Repository
import SwiftData

public struct ToggleTodoCompletionIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as completed or incomplete",
            categoryName: "Todos",
            searchKeywords: ["complete", "done", "finish", "toggle", "check"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Toggle completion of \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to toggle")
    public var todo: TodoAppEntity

    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        let result = try TodoActions.toggleCompletion(todoId: todo.id, using: repository)
        WidgetReloader.reloadAllWidgets()
        return .result(value: result.entity)
    }
}
