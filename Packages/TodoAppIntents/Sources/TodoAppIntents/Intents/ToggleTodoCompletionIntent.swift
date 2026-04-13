//
//  ToggleTodoCompletionIntent.swift
//  IntentTodo
//

import AppIntents
import Repository
import SwiftData

/// Toggles the completion status of a todo item.
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
        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))

        guard let uuid = UUID(uuidString: todo.id),
              let todoItem = try repository.fetch(by: uuid) else {
            throw IntentError.notFound("Todo not found")
        }

        todoItem.isCompleted.toggle()
        try repository.update(todoItem)
        WidgetReloader.reloadAllWidgets()

        return .result(value: TodoAppEntity(from: todoItem))
    }
}
