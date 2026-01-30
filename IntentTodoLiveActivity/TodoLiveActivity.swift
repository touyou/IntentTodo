//
//  TodoLiveActivity.swift
//  IntentTodoLiveActivity
//
//  Live Activity for showing todos with approaching deadlines.
//  Displays tasks that are due within 1 hour.
//

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Live Activity Attributes

/// Attributes for the todo deadline Live Activity.
public struct TodoDeadlineActivityAttributes: ActivityAttributes {
    /// Dynamic content that updates during the activity.
    public struct ContentState: Codable, Hashable {
        /// The todo's title.
        public var title: String
        /// The due date/time.
        public var dueDate: Date
        /// Whether the todo is completed.
        public var isCompleted: Bool

        public init(title: String, dueDate: Date, isCompleted: Bool = false) {
            self.title = title
            self.dueDate = dueDate
            self.isCompleted = isCompleted
        }
    }

    /// The todo's unique identifier.
    public var todoId: String

    public init(todoId: String) {
        self.todoId = todoId
    }
}

// MARK: - Live Activity Widget

struct TodoDeadlineLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TodoDeadlineActivityAttributes.self) { context in
            // Lock screen / banner view
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(.orange.opacity(0.2))
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded region
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "clock.badge.exclamationmark.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    TimeRemainingView(dueDate: context.state.dueDate, style: .compact)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 16) {
                        Button(intent: CompleteTodoFromActivityIntent(todoId: context.attributes.todoId)) {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)

                        Button(intent: SnoozeTodoIntent(todoId: context.attributes.todoId)) {
                            Label("Snooze", systemImage: "clock.arrow.circlepath")
                        }
                        .buttonStyle(.bordered)
                    }
                    .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                TimeRemainingView(dueDate: context.state.dueDate, style: .minimal)
            } minimal: {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Lock Screen View

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TodoDeadlineActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                Text("Due Soon")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                TimeRemainingView(dueDate: context.state.dueDate, style: .full)
            }

            Text(context.state.title)
                .font(.title3.bold())
                .lineLimit(2)

            HStack(spacing: 16) {
                Button(intent: CompleteTodoFromActivityIntent(todoId: context.attributes.todoId)) {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(intent: SnoozeTodoIntent(todoId: context.attributes.todoId)) {
                    Label("Snooze 30m", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .font(.subheadline)
        }
        .padding()
    }
}

// MARK: - Time Remaining View

struct TimeRemainingView: View {
    let dueDate: Date
    let style: Style

    enum Style {
        case minimal
        case compact
        case full
    }

    private var timeRemaining: TimeInterval {
        dueDate.timeIntervalSinceNow
    }

    private var isOverdue: Bool {
        timeRemaining <= 0
    }

    var body: some View {
        switch style {
        case .minimal:
            Text(timerInterval: Date()...dueDate, countsDown: true)
                .monospacedDigit()
                .font(.caption2)
                .foregroundStyle(isOverdue ? .red : .orange)

        case .compact:
            VStack(alignment: .trailing) {
                Text(timerInterval: Date()...dueDate, countsDown: true)
                    .monospacedDigit()
                    .font(.caption.bold())
                Text(isOverdue ? "overdue" : "remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(isOverdue ? .red : .primary)

        case .full:
            HStack(spacing: 4) {
                Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "timer")
                    .foregroundStyle(isOverdue ? .red : .orange)
                Text(timerInterval: Date()...dueDate, countsDown: true)
                    .monospacedDigit()
                    .font(.subheadline.bold())
            }
            .foregroundStyle(isOverdue ? .red : .primary)
        }
    }
}

// MARK: - Live Activity Intents

import AppIntents
import TodoAppIntents

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

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoId) else {
            return .result()
        }

        let repository = await IntentDependencies.shared.repository
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

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: todoId) else {
            return .result()
        }

        let repository = await IntentDependencies.shared.repository
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

// MARK: - Widget Bundle Extension

extension IntentTodoWidgetBundle {
    var liveActivity: some Widget {
        TodoDeadlineLiveActivity()
    }
}

// MARK: - Previews

#Preview("Notification", as: .content, using: TodoDeadlineActivityAttributes(todoId: "preview")) {
    TodoDeadlineLiveActivity()
} contentStates: {
    TodoDeadlineActivityAttributes.ContentState(
        title: "Submit project proposal",
        dueDate: Date().addingTimeInterval(45 * 60)
    )
    TodoDeadlineActivityAttributes.ContentState(
        title: "Call client about meeting",
        dueDate: Date().addingTimeInterval(-5 * 60)
    )
}
