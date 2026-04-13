//
//  ToggleTodoCompletionIntent.swift
//  IntentTodo
//

#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Domain
import Repository
import SwiftData

/// Toggles the completion status of a todo item.
///
/// Conforms to `LiveActivityIntent` on iOS so the same intent can be triggered
/// from Dynamic Island / lock screen buttons. When a todo becomes completed,
/// any active Live Activity for that todo is ended automatically.
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

        // If the todo is now completed, end any matching Live Activity.
        #if os(iOS)
        if todoItem.isCompleted {
            await endMatchingLiveActivity(for: todo.id)
        }
        #endif

        return .result(value: TodoAppEntity(from: todoItem))
    }

    #if os(iOS)
    @MainActor
    private func endMatchingLiveActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
        where activity.attributes.todoId == todoId {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
    #endif
}

#if os(iOS)
extension ToggleTodoCompletionIntent: LiveActivityIntent {}
#endif
