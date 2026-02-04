//
//  LiveActivityIntents.swift
//  IntentTodoLiveActivity
//
//  Intents for Live Activity actions.
//

import ActivityKit
import AppIntents
import Domain
import Repository
import SwiftData
import WidgetKit

// MARK: - Model Container

/// Uses SharedModelContainer for data sharing with the main app.
/// Requires App Group to be configured in Xcode.
let liveActivityModelContainer: ModelContainer = {
    // swiftlint:disable:next force_try
    return try! SharedModelContainer.createContainer()
}()

// MARK: - Complete Todo Intent

/// Intent to complete a todo from Live Activity.
struct CompleteTodoFromActivityIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Complete Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    init() {
        self.todoId = ""
    }

    init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoId) else {
            return .result()
        }

        let repository = SwiftDataTodoRepository(modelContext: liveActivityModelContainer.mainContext)
        if let todo = try await repository.fetch(by: uuid) {
            todo.isCompleted = true
            try await repository.update(todo)

            // Reload widgets to reflect the change
            WidgetCenter.shared.reloadAllTimelines()

            // End the Live Activity
            await endLiveActivity(for: todoId)
        }

        return .result()
    }

    @MainActor
    private func endLiveActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            if activity.attributes.todoId == todoId {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}

// MARK: - Snooze Todo Intent

/// Intent to snooze a todo deadline from Live Activity.
struct SnoozeTodoIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Snooze Todo"

    @Parameter(title: "Todo ID")
    var todoId: String

    init() {
        self.todoId = ""
    }

    init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoId) else {
            return .result()
        }

        let repository = SwiftDataTodoRepository(modelContext: liveActivityModelContainer.mainContext)
        if let todo = try await repository.fetch(by: uuid),
           let currentDueDate = todo.dueDate {
            // Snooze by 30 minutes
            let newDueDate = currentDueDate.addingTimeInterval(30 * 60)
            todo.dueDate = newDueDate
            try await repository.update(todo)

            // Reload widgets to reflect the change
            WidgetCenter.shared.reloadAllTimelines()

            // Update the Live Activity
            await updateLiveActivity(for: todoId, newDueDate: newDueDate)
        }

        return .result()
    }

    @MainActor
    private func updateLiveActivity(for todoId: String, newDueDate: Date) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            if activity.attributes.todoId == todoId {
                let contentState = TodoDeadlineActivityAttributes.ContentState(
                    title: activity.content.state.title,
                    dueDate: newDueDate,
                    isCompleted: false
                )
                await activity.update(using: contentState)
            }
        }
    }
}
