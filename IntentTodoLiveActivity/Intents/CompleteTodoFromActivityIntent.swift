//
//  CompleteTodoFromActivityIntent.swift
//  IntentTodoLiveActivity
//
//  Intent to complete a todo from Live Activity.
//

import ActivityKit
import AppIntents
import Domain
import Repository
import SwiftData
import WidgetKit

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
