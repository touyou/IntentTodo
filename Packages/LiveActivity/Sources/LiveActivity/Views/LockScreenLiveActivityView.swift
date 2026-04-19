//
//  LockScreenLiveActivityView.swift
//  LiveActivity
//
//  Lock screen view for Live Activity.
//

#if os(iOS)
import ActivityKit
import AppIntents
import Domain
import SwiftUI
import TodoAppIntents
import WidgetKit

/// Lock screen view showing the approaching deadline todo.
public struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<TodoDeadlineActivityAttributes>

    public init(context: ActivityViewContext<TodoDeadlineActivityAttributes>) {
        self.context = context
    }

    public var body: some View {
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
                Button(intent: ToggleTodoCompletionFromExtensionIntent(todoId: context.attributes.todoId)) {
                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(intent: SnoozeTodoFromExtensionIntent(todoId: context.attributes.todoId)) {
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
#endif
