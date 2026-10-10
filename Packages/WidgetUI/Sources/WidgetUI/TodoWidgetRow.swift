//
//  TodoWidgetRow.swift
//  WidgetUI
//
//  Row component for displaying a todo item in widgets.
//

import Domain
import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item in widgets.
///
/// The checkbox completes the todo in place with `Toggle(isOn:intent:)`; the rest of the row
/// only opens the todo, so it is a `Link` — Apple: "If you want to offer an interaction that
/// opens the app, use `Link`". The two sit side by side because a control nested inside a link
/// does not get its taps reliably.
///
/// A toggle rather than a button because the intent runs in the app process and the reload
/// that follows takes a moment: the system flips a toggle's `isOn` on tap, so the circle
/// answers at once instead of looking like the tap was dropped. The link destination is the same URL the entity's
/// `URLRepresentableEntity` produces, so Siri and the widget point at the same place.
struct TodoWidgetRow: View {
    let todo: TodoAppEntity
    let compact: Bool

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: todo.isCompleted, intent: ToggleTodoCompletionIntent(todo: todo)) {
                EmptyView()
            }
            .toggleStyle(CheckboxToggleStyle(compact: compact))
            .accessibilityLabel(todo.isCompleted ? .copy("Mark as incomplete") : .copy("Mark as complete"))

            Link(destination: TodoDeepLink.todo(id: todo.id).url) {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Text(todo.title)
                .font(compact ? .caption : .subheadline)
                .lineLimit(1)
                .strikethrough(todo.isCompleted)
                .foregroundStyle(todo.isCompleted ? .secondary : .primary)

            Spacer()

            if let dueDate = todo.dueDateValue, !compact {
                DueDateBadge(date: dueDate, isCompleted: todo.isCompleted)
            }
        }
    }
}

/// Draws the row's circle from the toggle's own `isOn`, which the system flips on tap ahead
/// of the timeline reload.
private struct CheckboxToggleStyle: ToggleStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(configuration.isOn ? .green : .secondary)
            .font(compact ? .caption : .body)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// Badge component for displaying due date with appropriate styling.
///
/// Widgets need "due today" as its own state, which `DueDateStatus` does not model.
struct DueDateBadge: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        DueDateStatus.evaluate(date: date, isCompleted: isCompleted) == .overdue
    }

    private var isDueToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Text(formattedDate)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        if isOverdue { return .red }
        if isDueToday { return .orange }
        return .secondary
    }

    private var formattedDate: String {
        if isDueToday {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
