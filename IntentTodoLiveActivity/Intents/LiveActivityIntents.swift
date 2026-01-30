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

// MARK: - Model Container

/// Shared model container for Live Activity intents.
let liveActivityModelContainer: ModelContainer = {
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: schema, configurations: [config])
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
            todo.dueDate = currentDueDate.addingTimeInterval(30 * 60)
            try await repository.update(todo)

            // Update the Live Activity
            await updateLiveActivity(for: todoId, newDueDate: todo.dueDate!)
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
