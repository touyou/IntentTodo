//
//  TodoControlWidget.swift
//  IntentTodoWidget
//
//  Control Center widget for quick todo access.
//  Supports iOS 26+ Control Center integration with OpenIntent.
//

import AppIntents
import Domain
import Repository
import SwiftData
import SwiftUI
import TodoAppIntents
import UserNotifications
import WidgetKit

// MARK: - Quick Add Control Widget

/// Control widget for quickly adding a new todo.
///
/// Uses `StaticControlConfiguration` with `LaunchAppIntent` (OpenIntent) for proper app launch.
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        // Use StaticControlConfiguration - no ConfigurationIntent needed
        StaticControlConfiguration(kind: Self.kind) {
            // Use LaunchAppIntent with .addTodo target to open add screen
            ControlWidgetButton(action: LaunchAppIntent(target: .addTodo)) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}

// MARK: - Todo Count Control Widget

/// Control widget showing incomplete todo count.
///
/// Uses `StaticControlConfiguration` with `LaunchAppIntent` (OpenIntent) for proper app launch.
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        // Use StaticControlConfiguration - fetches count directly
        StaticControlConfiguration(kind: Self.kind) {
            // Use LaunchAppIntent with .todoList target to open the list
            ControlWidgetButton(action: LaunchAppIntent(target: .todoList)) {
                Label {
                    Text("\(fetchIncompleteCount())")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("Shows incomplete todo count. Tap to open list.")
    }

    @MainActor
    private func fetchIncompleteCount() -> Int {
        let context = sharedWidgetModelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }
}

// MARK: - Toggle Urgent Todo Control Widget

/// Control widget for toggling the most urgent todo.
///
/// Displays the most urgent (earliest due date) incomplete todo.
/// Tap to toggle its completion status.
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        // Use StaticControlConfiguration
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ToggleUrgentTodoIntent()) {
                Label {
                    Text(fetchUrgentTodoTitle() ?? "No urgent todo")
                } icon: {
                    Image(systemName: isUrgentTodoCompleted()
                        ? "checkmark.circle.fill"
                        : "clock.badge.exclamationmark")
                }
            }
        }
        .displayName("Urgent Todo")
        .description("Toggle completion of the most urgent todo.")
    }

    @MainActor
    private func fetchUrgentTodoTitle() -> String? {
        fetchUrgentTodo()?.title
    }

    @MainActor
    private func isUrgentTodoCompleted() -> Bool {
        fetchUrgentTodo()?.isCompleted ?? false
    }

    @MainActor
    private func fetchUrgentTodo() -> TodoItem? {
        let context = sharedWidgetModelContainer.mainContext
        var descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted && $0.dueDate != nil },
            sortBy: [SortDescriptor(\TodoItem.dueDate, order: .forward)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

// MARK: - Toggle Urgent Todo Intent

/// Intent for toggling the most urgent todo.
/// Defined here because it uses SwiftData which requires Widget Extension context.
struct ToggleUrgentTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Urgent Todo"

    /// Runs in background without opening the app.
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

        // Reload widgets to reflect the change
        WidgetCenter.shared.reloadAllTimelines()

        // Send notification with feedback
        if isNowCompleted {
            ControlNotificationHelper.sendCompletedNotification(todoTitle: todoTitle)
        } else {
            ControlNotificationHelper.sendUncompletedNotification(todoTitle: todoTitle)
        }

        return .result()
    }
}
