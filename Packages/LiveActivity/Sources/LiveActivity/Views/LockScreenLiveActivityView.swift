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

    /// ボタンに載せる entity。Activity が持っているのは id と title だけだが、
    /// システムが `perform()` 前に `TodoEntityQuery.entities(for:)` で id から
    /// 再解決するため、ここでは id が正しければ足りる。
    private var todoEntity: TodoAppEntity {
        TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark.fill")
                    .foregroundStyle(.orange)
                    .font(.title3)

                Text(.copy("Due Soon"))
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                TimeRemainingView(dueDate: context.state.dueDate, style: .full)
            }

            Text(context.state.title)
                .font(.title3.bold())
                .lineLimit(2)

            HStack(spacing: 16) {
                Button(intent: ToggleTodoCompletionIntent(todo: todoEntity)) {
                    Label(.copy("Mark Complete"), systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)

                Button(intent: QuickSnoozeTodoIntent(todo: todoEntity)) {
                    Label(.copy("Snooze 30m"), systemImage: "clock.arrow.circlepath")
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
