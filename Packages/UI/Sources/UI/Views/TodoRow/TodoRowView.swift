//
//  TodoRowView.swift
//  IntentTodo
//

import Foundation
import SwiftUI
import TodoAppIntents

/// A row view displaying a single todo item.
///
/// This view uses App Intent buttons for all interactions.
/// Data updates are handled automatically by SwiftData's @Query in the parent view.
public struct TodoRowView: View {
    // MARK: - Properties

    private let todo: TodoAppEntity

    /// What this row matched, while a search is running. `.none` the rest of the time.
    private let searchMatch: TodoSearchMatch

    // MARK: - Initialization

    /// Creates a row view for the given todo.
    /// - Parameters:
    ///   - todo: The todo entity to display.
    ///   - searchMatch: why the row is in the results. Defaults to "no search", which is
    ///     what every caller outside the searchable list wants.
    init(todo: TodoAppEntity, searchMatch: TodoSearchMatch) {
        self.todo = todo
        self.searchMatch = searchMatch
    }

    /// Creates a row view for the given todo.
    /// - Parameter todo: The todo entity to display.
    public init(todo: TodoAppEntity) {
        self.init(todo: todo, searchMatch: .none)
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            TodoCheckbox(todo: todo)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // The matching words are emphasised in place, so a title hit needs no
                // caption to explain it.
                Text(AttributedString.highlighting(searchMatch.term, in: todo.title))
                    .font(.body)
                    // A title is whatever the person pasted in, so an unbounded row lets
                    // one of them fill the screen and push the rest of the list out of
                    // reach. Three lines is enough to tell two long titles apart; the
                    // whole of it is on the detail screen the row taps through to.
                    .lineLimit(3)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)

                TodoSearchReason(match: searchMatch, listName: todo.category?.name)

                if let dueDate = todo.dueDateValue {
                    DueDateLabel(date: dueDate, isCompleted: todo.isCompleted)
                }
            }

            Spacer()

            // Favorite button
            FavoriteButton(todo: todo)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private

    /// Built by localizing each part and joining with `.list`, not by concatenation: both
    /// the separator and the ordering are locale-dependent, and a `+=` chain produces a
    /// sentence no translator can reach.
    private var accessibilityLabel: String {
        var parts: [String] = [todo.title]
        if todo.isCompleted {
            parts.append(String(localized: .copy("completed")))
        }
        if todo.isFavorite {
            parts.append(String(localized: .copy("favorite")))
        }
        if let dueDate = todo.dueDateValue {
            let formatted = dueDate.formatted(date: .abbreviated, time: .omitted)
            parts.append(String(localized: .copy("due \(formatted)")))
        }
        return parts.formatted(.list(type: .and, width: .narrow))
    }
}

// MARK: - Due Date Label

private struct DueDateLabel: View {
    let date: Date
    let isCompleted: Bool

    private var isOverdue: Bool {
        !isCompleted && date < Date()
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "calendar")
                .font(.caption2)
            Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
        }
        .foregroundStyle(isOverdue ? .red : .secondary)
    }
}

// MARK: - Preview

#Preview("Normal") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Buy groceries",
                isCompleted: false,
                isFavorite: false
            )
        )
    }
}

#Preview("Completed & Favorite") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Completed task",
                isCompleted: true,
                isFavorite: true
            )
        )
    }
}

#Preview("With Due Date") {
    List {
        TodoRowView(
            todo: TodoAppEntity(
                id: UUID().uuidString,
                title: "Task with due date",
                isCompleted: false,
                isFavorite: false,
                dueDate: Date().addingTimeInterval(86400)
            )
        )
    }
}
