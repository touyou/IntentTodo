//
//  TodoLiveActivityManager.swift
//  LiveActivity
//
//  ActivityKit wrapper for starting, updating and ending Live Activities. ActivityKit is
//  iOS-only, so the whole file is guarded.
//

#if os(iOS)
import ActivityKit
import Domain
import Foundation
import os.log
import TodoAppIntents

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoLiveActivityManager")

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
        // Returns rather than throws when Live Activities are disabled: reconciliation walks
        // every todo, so an error here would flood the log. It is still recorded, because
        // otherwise there is no way to find out why nothing appears on the lock screen.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning(
                "startActivity skipped for todoId=\(todoId, privacy: .public): Live Activities are disabled in Settings"
            )
            MissedFeedback.record(.liveActivity)
            return
        }
        // Re-enabled, so drop the record instead of leaving the banner up.
        MissedFeedback.clear(.liveActivity)

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
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends a specific activity.
    public func endActivity(for todoId: String) async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities
            where activity.attributes.todoId == todoId {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Ends all activities.
    public func endAllActivities() async {
        for activity in Activity<TodoDeadlineActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
#endif
