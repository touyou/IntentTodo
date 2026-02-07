//
//  SnoozeTodoIntent.swift
//  IntentTodoLiveActivity
//
//  Intent to snooze a todo deadline from Live Activity.
//

import ActivityKit
import AppIntents
import Domain
import Repository
import SwiftData
import WidgetKit

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
