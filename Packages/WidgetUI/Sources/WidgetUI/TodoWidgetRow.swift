//
//  TodoWidgetRow.swift
//  WidgetUI
//
//  Row component for displaying a todo item in widgets.
//

import SwiftUI
import TodoAppIntents

/// Row component for displaying a todo item in widgets.
public struct TodoWidgetRow: View {
    let todo: TodoAppEntity
    let compact: Bool

    public init(todo: TodoAppEntity, compact: Bool) {
        self.todo = todo
        self.compact = compact
    }

    public var body: some View {
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

            if let dueDate = todo.dueDate, !compact {
                DueDateBadge(date: dueDate, isCompleted: todo.isCompleted)
            }
        }
    }
}

/// Badge component for displaying due date with appropriate styling.
struct DueDateBadge: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    private var isDueToday: Bool {
        Calendar.current.isDateInToday(date)
    }

    var body: some View {
        Text(formattedDate)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        if isOverdue { return .red }
        if isDueToday { return .orange }
        return .secondary
    }

    private var foregroundColor: Color {
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
