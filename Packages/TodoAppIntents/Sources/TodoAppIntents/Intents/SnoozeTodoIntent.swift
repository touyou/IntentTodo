//
//  SnoozeTodoIntent.swift
//  TodoAppIntents
//
//  Primary variant: runs in the main app process via @Dependency.
//  For Live Activity context, use SnoozeTodoFromExtensionIntent.
//

import AppIntents

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
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.snooze(todoId: todo.id)
        return .result(value: result.entity)
    }
}
