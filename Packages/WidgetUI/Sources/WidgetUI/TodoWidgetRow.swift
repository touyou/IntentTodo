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
/// Tapping a row only opens the todo, so it is a `Link`, not a `Button(intent:)` — Apple:
/// "If you want to offer an interaction that opens the app, use `Link`". The destination is
/// the same URL the entity's `URLRepresentableEntity` produces, so Siri and the widget point
/// at the same place.
struct TodoWidgetRow: View {
    let todo: TodoAppEntity
    let compact: Bool

    var body: some View {
        Link(destination: TodoDeepLink.todo(id: todo.id).url) {
            rowContent
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(todo.isCompleted ? .green : .secondary)
                .font(compact ? .caption : .body)

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
