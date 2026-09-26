//
//  ShowTodosSnippetIntent.swift
//  TodoAppIntents
//
//  Interactive snippet for `ShowTodosIntent`, so the list reads the same in Siri,
//  Shortcuts and Spotlight instead of each surface rendering the returned value its own way.
//

import AppIntents
import Repository
import SwiftUI

/// An interactive snippet listing the todos a `ShowTodosIntent` run matched.
public struct ShowTodosSnippetIntent: SnippetIntent {
    public static let title: LocalizedStringResource = "Todo List Snippet"

    /// Not a user-facing action — only presented via `snippetIntent:` from `ShowTodosIntent`.
    public static let isDiscoverable = false

    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        .result(view: ShowTodosSnippetView(filter: filter, todos: Self.currentTodos(matching: filter)))
    }

    /// Reads the store afresh: the system re-performs a snippet intent after each contained
    /// `Button(intent:)`, and a completed row has to update in place.
    @MainActor
    private static func currentTodos(matching filter: TodoFilterType) -> [TodoAppEntity]? {
        guard let container = TodoEntityStore.container,
              let items = try? TodoService.items(
                  matching: filter,
                  in: SwiftDataTodoRepository(modelContext: container.mainContext)
              )
        else {
            return nil
        }
        return items.map { TodoAppEntity(from: $0) }
    }
}

// MARK: - Snippet View

/// SwiftUI layout for ``ShowTodosSnippetIntent``.
struct ShowTodosSnippetView: View {
    let filter: TodoFilterType
    let todos: [TodoAppEntity]?

    /// A snippet is a glance, not the list screen; the rest is one tap away in the app.
    static let rowLimit = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let todos {
                if todos.isEmpty {
                    Label("Nothing here", systemImage: "checkmark.circle")
                        .font(.headline)
                } else {
                    ForEach(todos.prefix(Self.rowLimit), id: \.id) { todo in
                        row(for: todo)
                    }
                    if todos.count > Self.rowLimit {
                        Text("\(todos.count - Self.rowLimit) more")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Label("Couldn't read your todos", systemImage: "exclamationmark.triangle")
            }

            Button(intent: LaunchAppIntent(target: ShowTodosIntent.screenTarget(for: filter))) {
                Label("Open in App", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }

    private func row(for todo: TodoAppEntity) -> some View {
        HStack(spacing: 10) {
            Button(intent: ToggleTodoCompletionIntent(todo: todo)) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todo.isCompleted ? Text("Mark Incomplete") : Text("Mark Complete"))

            Text(todo.title)
                .lineLimit(1)
                .strikethrough(todo.isCompleted)

            Spacer(minLength: 0)

            if todo.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
            }
        }
    }
}
