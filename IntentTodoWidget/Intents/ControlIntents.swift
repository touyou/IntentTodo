//
//  ControlIntents.swift
//  IntentTodoWidget
//
//  Background-mode intents for Control Center widgets.
//  All Control Widget intents use .background mode with notification feedback
//  because opening the app from Control Widgets is unreliable on iOS 26.
//  See docs/INSIGHTS.md Section 18 for details.
//

import AppIntents
import Domain
import SwiftData
import TodoAppIntents
import UserNotifications
import WidgetKit

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

// MARK: - QuickAddTodoNotifyIntent

/// Intent for the Quick Add control button.
/// Sends a notification prompting the user to open the app and add a todo.
struct QuickAddTodoNotifyIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Todo"

    static var supportedModes: IntentModes { .background }

    @MainActor
    func perform() async throws -> some IntentResult {
        ControlNotificationHelper.sendQuickAddNotification()
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
