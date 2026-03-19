//
//  TodoLiveActivityManager.swift
//  IntentTodoLiveActivity
//
//  Manager for starting and controlling Live Activities.
//

import ActivityKit
import Domain
import Foundation

// MARK: - Live Activity Manager

/// Manager for starting and updating Live Activities.
@MainActor
public final class TodoLiveActivityManager {
    public static let shared = TodoLiveActivityManager()

    private init() {}

    /// Starts a Live Activity for a todo that's due soon.
    /// - Parameters:
    ///   - todoId: The todo's unique identifier.
    ///   - title: The todo's title.
    ///   - dueDate: The todo's due date.
    public func startActivity(todoId: String, title: String, dueDate: Date) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Check if activity already exists
        let existingActivity = Activity<TodoDeadlineActivityAttributes>.activities.first {
            $0.attributes.todoId == todoId
        }
        if existingActivity != nil { return }

        let attributes = TodoDeadlineActivityAttributes(todoId: todoId)
        let contentState = TodoDeadlineActivityAttributes.ContentState(
            title: title,
            dueDate: dueDate
        )

        // Calculate when to dismiss (at due date or after some time)
        let dismissalDate = dueDate.addingTimeInterval(15 * 60) // 15 min after due

        _ = try Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: dismissalDate),
            pushType: nil
        )
    }

    /// Updates all activities for deadline changes.
    public func updateActivities() async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            if activity.content.state.isCompleted {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    /// Ends a specific activity.
    public func endActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            if activity.attributes.todoId == todoId {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }

    /// Ends all activities.
    public func endAllActivities() async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
