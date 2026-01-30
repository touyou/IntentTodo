//
//  TodoLiveActivity.swift
//  IntentTodoLiveActivity
//
//  Live Activity for showing todos with approaching deadlines.
//  Displays tasks that are due within 1 hour.
//

import ActivityKit
import AppIntents
import Domain
import SwiftUI
import WidgetKit

// Note: TodoDeadlineActivityAttributes is defined in Domain package
// to allow the main app to start Live Activities.

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
