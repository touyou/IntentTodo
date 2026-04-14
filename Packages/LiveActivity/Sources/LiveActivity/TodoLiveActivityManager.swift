//
//  TodoLiveActivityManager.swift
//  LiveActivity
//
//  ActivityKit ラッパー。Live Activity の start / update / end を集約。
//  ActivityKit は iOS 限定のため全体を #if os(iOS) でガード。
//

#if os(iOS)
import ActivityKit
import Domain
import Foundation

/// Manager for starting and updating Live Activities.
@MainActor
public final class TodoLiveActivityManager {
    public static let shared = TodoLiveActivityManager()

    private init() {}

    /// Starts a Live Activity for a todo that's due soon. No-op if an activity for the same todo already exists.
    /// - Parameters:
    ///   - todoId: The todo's unique identifier.
    ///   - title: The todo's title.
    ///   - dueDate: The todo's due date.
    public func startActivity(todoId: String, title: String, dueDate: Date) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let existingActivity = Activity<TodoDeadlineActivityAttributes>.activities.first {
            $0.attributes.todoId == todoId
        }
        if existingActivity != nil { return }

        let attributes = TodoDeadlineActivityAttributes(todoId: todoId)
        let contentState = TodoDeadlineActivityAttributes.ContentState(
            title: title,
            dueDate: dueDate
        )
        let staleDate = dueDate.addingTimeInterval(15 * 60)

        _ = try Activity.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: staleDate),
            pushType: nil
        )
    }

    /// Ends all activities whose ContentState reports completion.
    public func updateActivities() async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
            where activity.content.state.isCompleted {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    /// Ends a specific activity.
    public func endActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
            where activity.attributes.todoId == todoId {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    /// Ends all activities.
    public func endAllActivities() async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}
#endif
