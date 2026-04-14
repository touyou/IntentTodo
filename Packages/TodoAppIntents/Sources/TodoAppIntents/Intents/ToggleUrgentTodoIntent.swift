//
//  ToggleUrgentTodoIntent.swift
//  TodoAppIntents
//
//  Auto-selects the most urgent (earliest-due) incomplete todo and toggles it.
//  Designed for Control Center (no parameter picking available there).
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
        let context = modelContainer.mainContext
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

        WidgetReloader.reloadAllWidgets()
        ControlNotificationHelper.sendToggledNotification(
            todoTitle: todoTitle,
            isCompleted: isNowCompleted
        )
        return .result()
    }
}
