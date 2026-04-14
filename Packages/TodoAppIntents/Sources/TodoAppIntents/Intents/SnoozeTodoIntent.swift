//
//  SnoozeTodoIntent.swift
//  TodoAppIntents
//
//  Primary variant: runs in the main app process via @Dependency.
//  For Live Activity context, use SnoozeTodoFromExtensionIntent.
//

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
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
        let result = try TodoActions.snooze(todoId: todo.id, using: repository)
        WidgetReloader.reloadAllWidgets()
        return .result(value: result.entity)
    }
}
