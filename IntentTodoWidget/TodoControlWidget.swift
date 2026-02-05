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
/// Uses `StaticControlConfiguration` with `OpenAddTodoIntent` for reliable app launch.
/// This uses a simple, parameterless intent which works more reliably with Control Center.
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        // Use StaticControlConfiguration - no ConfigurationIntent needed
        StaticControlConfiguration(kind: Self.kind) {
            // Use local intent defined in Widget Extension for reliable app opening
            ControlWidgetButton(action: LocalOpenAddTodoIntent()) {
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
/// Uses `StaticControlConfiguration` with `OpenTodoListIntent` for reliable app launch.
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        // Use StaticControlConfiguration - fetches count directly
        StaticControlConfiguration(kind: Self.kind) {
            // Use local intent defined in Widget Extension for reliable app opening
            ControlWidgetButton(action: LocalOpenTodoListIntent()) {
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

// MARK: - Widget Extension Local Intents

/// Intent for opening the app to add a todo.
/// Defined in Widget Extension for reliable Control Center behavior.
struct LocalOpenAddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Add Todo"

    /// Runs in foreground to open the app.
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Set flag for the main app to show add todo screen
        let sharedDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) ?? .standard
        sharedDefaults.set(true, forKey: "IntentAppState.shouldShowAddTodo")
        return .result()
    }
}

/// Intent for opening the app to todo list.
/// Defined in Widget Extension for reliable Control Center behavior.
struct LocalOpenTodoListIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Todo List"

    /// Runs in foreground to open the app.
    static var supportedModes: IntentModes { .foreground }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Just open the app - no special state needed
        return .result()
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
