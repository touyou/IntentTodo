//
//  ToggleTodoCompletionIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that toggles the completion status of a todo item.
///
/// This intent can be triggered via:
/// - Siri: "Mark 'Buy groceries' as done in IntentTodo"
/// - Shortcuts: Toggle Todo Completion action
/// - UI: `Button(intent: ToggleTodoCompletionIntent(todo: entity))`
public struct ToggleTodoCompletionIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        "Toggle Todo Completion"
    }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks a todo as completed or incomplete",
            categoryName: "Todos",
            searchKeywords: ["complete", "done", "finish", "toggle", "check"]
        )
    }

    /// Runs in background without opening the app.
    public static var supportedModes: IntentModes { .background }

    // MARK: - Parameters

    @Parameter(title: "Todo", description: "The todo to toggle")
    public var todo: TodoAppEntity

    // MARK: - Initialization

    public init() {}

    /// Creates an intent to toggle the specified todo.
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

        // Toggle completion status
        todoItem.isCompleted.toggle()

        // Save changes
        try repository.update(todoItem)

        // Reload widgets to reflect the change
        WidgetReloader.reloadAllWidgets()

        // Return updated entity
        let entity = TodoAppEntity(from: todoItem)
        return .result(value: entity)
    }
}
