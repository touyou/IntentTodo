//
//  ToggleUrgentTodoIntent.swift
//  TodoAppIntents
//
//  Toggles completion of the most urgent (earliest-due) incomplete todo.
//  Semantically different from ToggleTodoCompletionIntent (which takes a specific todo):
//  this one auto-selects the target, making it suitable for Control Center buttons
//  that don't have room for parameter pickers.
//

import AppIntents
import Domain
import Repository
import SwiftData

public struct ToggleUrgentTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Urgent Todo"
    public static let description = IntentDescription("Toggles completion of the most urgent todo")
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
            sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 1

        guard let todo = try? context.fetch(descriptor).first else {
            return .result()
        }

        let todoTitle = todo.title
        todo.isCompleted.toggle()
        let isNowCompleted = todo.isCompleted
        try context.save()

        ControlNotificationHelper.sendToggledNotification(
            todoTitle: todoTitle,
            isCompleted: isNowCompleted
        )
        return .result()
    }
}
