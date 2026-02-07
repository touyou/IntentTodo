//
//  ControlIntents.swift
//  IntentTodoWidget
//
//  App Intents for Control Center widgets.
//  Defined in Widget Extension for reliable Control Center behavior.
//

import AppIntents
import Domain
import SwiftData
import UserNotifications
import WidgetKit

// MARK: - LocalOpenAddTodoIntent

/// Intent for opening the app to add a todo.
struct LocalOpenAddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Add Todo"

    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        let sharedDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        sharedDefaults.set(true, forKey: "IntentAppState.shouldShowAddTodo")
        return .result()
    }
}

// MARK: - LocalOpenTodoListIntent

/// Intent for opening the app to todo list.
struct LocalOpenTodoListIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Todo List"

    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        return .result()
    }
}

// MARK: - ToggleUrgentTodoIntent

/// Intent for toggling the most urgent todo.
/// Uses SwiftData which requires Widget Extension context.
struct ToggleUrgentTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Urgent Todo"

    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = sharedWidgetModelContainer.mainContext
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
        try? context.save()

        WidgetCenter.shared.reloadAllTimelines()

        if isNowCompleted {
            ControlNotificationHelper.sendCompletedNotification(todoTitle: todoTitle)
        } else {
            ControlNotificationHelper.sendUncompletedNotification(todoTitle: todoTitle)
        }

        return .result()
    }
}
