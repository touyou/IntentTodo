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
        // 設定でライブアクティビティが無効なときは throw せず抜ける（呼出側の
        // reconcile は毎回全 todo を回すので、error にすると同じログで溢れる）。
        // ただし無言で消えるとユーザーは「期限が近い todo が出てこない」理由に
        // 到達できないので、ログと `MissedFeedback` の記録は残す。アプリの一覧が
        // 設定誘導のバナーを出す。
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            logger.warning(
                "startActivity skipped for todoId=\(todoId, privacy: .public): Live Activities are disabled in Settings"
            )
            MissedFeedback.record(.liveActivity)
            return
        }
        // 有効に戻っていれば古い記録は消す（バナーを出し続けない）。
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
