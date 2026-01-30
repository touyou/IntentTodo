//
//  LockScreenLiveActivityView.swift
//  IntentTodoLiveActivity
//
//  Lock screen view for Live Activity.
//

import ActivityKit
import AppIntents
import Domain
import SwiftUI
import WidgetKit

// MARK: - Lock Screen View

/// Lock screen view showing the approaching deadline todo.
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
