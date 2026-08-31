//
//  WatchTodoDetailView.swift
//  WatchUI
//

import AppIntents
import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Detail view for a todo item on watchOS.
///
/// Takes a `TodoAppEntity`, which is what both the list's `NavigationLink` and
/// `OpenTodoIntent` push, so navigation from the UI and from Siri share one entry point.
public struct WatchTodoDetailView: View {
    private let todo: TodoAppEntity

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    public var body: some View {
        // An unparseable id goes straight to the missing state, without querying.
        if let targetId = UUID(uuidString: todo.id) {
            WatchTodoDetailQueryView(targetId: targetId)
        } else {
            ContentUnavailableView(
                .copy("Todo Not Found"),
                systemImage: "questionmark.circle"
            )
        }
    }
}

private struct WatchTodoDetailQueryView: View {
    @Query private var todoItems: [TodoItem]
    @Environment(\.dismiss) private var dismiss

    private var todo: TodoItem? { todoItems.first }
    private var entity: TodoAppEntity? { todo.map { TodoAppEntity(from: $0) } }

    init(targetId: UUID) {
        _todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
    }

    var body: some View {
        Group {
            if let todo, let entity {
                detailContent(todo: todo, entity: entity)
            } else {
                ContentUnavailableView(
                    .copy("Todo Not Found"),
                    systemImage: "questionmark.circle"
                )
            }
        }
        .onChange(of: todo) { _, newValue in
            if newValue == nil {
                dismiss()
            }
        }
    }

    private func detailContent(todo: TodoItem, entity: TodoAppEntity) -> some View {
        List {
            Section { WatchTodoDetailHeaderSection(todo: todo, entity: entity) }

            if let dueDate = todo.dueDate {
                Section(.copy("Due Date")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(dueDate.formatted(date: .complete, time: .omitted))
                        Text(dueDate.formatted(date: .omitted, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let description = todo.todoDescription, !description.isEmpty {
                Section(.copy("Description")) {
                    Text(description)
                        .font(.caption)
                }
            }

            Section { WatchTodoDetailActionsSection(todo: todo, entity: entity) }
        }
        .navigationTitle(.copy("Details"))
        // Tells Siri which todo is open, so "complete this" resolves. iOS puts the
        // identifier on a `.userActivity` to get a Handoff title as well; the watch has
        // nothing to hand off to, so it uses the modifier that needs no `NSUserActivityTypes`
        // declaration.
        .appEntityIdentifier(EntityIdentifier(for: entity))
    }
}

// MARK: - Header

private struct WatchTodoDetailHeaderSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    var body: some View {
        HStack {
            Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(todo.title)
                .font(.headline)
        }
    }
}

// MARK: - Actions

private struct WatchTodoDetailActionsSection: View {
    let todo: TodoItem
    let entity: TodoAppEntity

    @State private var isConfirmingDelete = false

    var body: some View {
        Group {
            Button(intent: ToggleFavoriteIntent(todo: entity)) {
                Label(
                    todo.isFavorite ? .copy("Remove Favorite") : .copy("Add Favorite"),
                    systemImage: todo.isFavorite ? "star.slash" : "star"
                )
            }

            // Confirmed here: `requestConfirmation` has no surface to present on when the
            // caller is an in-app button.
            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(.copy("Delete"), systemImage: "trash")
            }
        }
        .confirmationDialog(
            .copy("Delete “\(entity.title)”?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
                Text(.copy("Delete"))
            }
        }
    }
}
