//
//  ControlIntents.swift
//  IntentTodoWidget
//
//  Background-mode intents for Control Center widgets.
//  ToggleUrgentTodoIntent and ShowTodoCountIntent use .background mode with notification
//  feedback because they do not need to open the app.
//  QuickAddTodoControl uses OpenAddTodoIntent (.foreground(.immediate)) from TodoAppIntents.
//

import AppIntents
import Domain
import os.log
import SwiftData
import TodoAppIntents
import UserNotifications
import WidgetKit

private let logger = Logger(subsystem: "com.touyou.IntentTodo.Widget", category: "ControlIntents")

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
            logger.info("No urgent todo found to toggle")
            return .result()
        }

        let todoTitle = todo.title
        todo.isCompleted.toggle()
        let isNowCompleted = todo.isCompleted
        do {
            try context.save()
            logger.info("Toggled urgent todo '\(todoTitle)' to \(isNowCompleted ? "completed" : "incomplete")")
        } catch {
            logger.error("Failed to save toggled todo: \(error.localizedDescription)")
        }

        WidgetCenter.shared.reloadAllTimelines()

        if isNowCompleted {
            ControlNotificationHelper.sendCompletedNotification(todoTitle: todoTitle)
        } else {
            ControlNotificationHelper.sendUncompletedNotification(todoTitle: todoTitle)
        }

        return .result()
    }
}

// MARK: - ShowTodoCountIntent

/// Intent for the Todo Count control button.
/// Fetches the current incomplete count and sends a summary notification.
struct ShowTodoCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Todo Count"

    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult {
        let context = sharedWidgetModelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0

        ControlNotificationHelper.sendTodoCountNotification(count: count)
        return .result()
    }
}
