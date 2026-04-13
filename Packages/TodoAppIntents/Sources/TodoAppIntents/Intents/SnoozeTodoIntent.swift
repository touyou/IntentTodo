//
//  SnoozeTodoIntent.swift
//  TodoAppIntents
//
//  Extends the due date of a todo by 30 minutes. Also updates any active
//  Live Activity showing the todo on iOS.
//

#if os(iOS)
import ActivityKit
#endif
import AppIntents
import Domain
import Repository
import SwiftData

public struct SnoozeTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Snooze Todo"
    public static let description = IntentDescription("Extends the due date by 30 minutes")
    public static let supportedModes: IntentModes = [.background]

    public static var parameterSummary: some ParameterSummary {
        Summary("Snooze \(\.$todo) by 30 minutes")
    }

    @Parameter(title: "Todo", description: "The todo to snooze")
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
              let todoItem = try repository.fetch(by: uuid),
              let currentDueDate = todoItem.dueDate else {
            throw IntentError.notFound("Todo or due date not found")
        }

        let newDueDate = currentDueDate.addingTimeInterval(30 * 60)
        todoItem.dueDate = newDueDate
        try repository.update(todoItem)
        WidgetReloader.reloadAllWidgets()

        #if os(iOS)
        await updateMatchingLiveActivity(for: todo.id, newDueDate: newDueDate, title: todoItem.title)
        #endif

        return .result(value: TodoAppEntity(from: todoItem))
    }

    #if os(iOS)
    @MainActor
    private func updateMatchingLiveActivity(for todoId: String, newDueDate: Date, title: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
        where activity.attributes.todoId == todoId {
            let contentState = TodoDeadlineActivityAttributes.ContentState(
                title: title,
                dueDate: newDueDate,
                isCompleted: false
            )
            await activity.update(using: contentState)
        }
    }
    #endif
}

#if os(iOS)
extension SnoozeTodoIntent: LiveActivityIntent {}
#endif
