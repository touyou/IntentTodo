//
//  TodoListView.swift
//  IntentTodo
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// The main todo list view.
///
/// This view displays all todos with filtering, sorting, and search capabilities.
/// All actions are performed via App Intents, and data updates are handled
/// automatically by SwiftData's @Query.
public struct TodoListView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]

    @State private var filter: TodoFilter = .all
    @State private var sortOrder: TodoSortOrder = .createdAtDescending
    @State private var searchText = ""
    @State private var showingAddTodo = false

    // MARK: - Computed Properties

    private var filteredTodos: [TodoAppEntity] {
        var result = todoItems

        // Apply filter
        switch filter {
        case .all:
            break
        case .incomplete:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.title.lowercased().contains(query) }
        }

        // Apply sort
        result = sortTodos(result, by: sortOrder)

        // Convert to entities
        return result.map { TodoAppEntity(from: $0) }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if filteredTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                toolbarContent
            }
            .searchable(text: $searchText, prompt: "Search todos")
            .sheet(isPresented: $showingAddTodo) {
                addTodoSheet
            }
        }
    }

    // MARK: - Subviews

    private var emptyView: some View {
        let content = emptyViewContent
        return ContentUnavailableView {
            Label(content.title, systemImage: content.icon)
        } description: {
            Text(content.description)
        } actions: {
            if filter == .all && searchText.isEmpty {
                Button("Add Todo") {
                    showingAddTodo = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyViewContent: (title: String, icon: String, description: String) {
        if !searchText.isEmpty {
            return ("No Results", "magnifyingglass", "No todos match your search.")
        }
        switch filter {
        case .all:
            return ("No Todos", "checklist", "Tap + to add your first todo.")
        case .incomplete:
            return ("All Done!", "checkmark.circle", "You've completed all your todos!")
        case .completed:
            return ("No Completed Todos", "circle", "Complete some todos to see them here.")
        case .favorites:
            return ("No Favorites", "star", "Star a todo to add it to favorites.")
        }
    }

    private var todoList: some View {
        List {
            ForEach(filteredTodos, id: \.id) { todo in
                TodoRowView(todo: todo)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        DeleteButton(todo: todo)
                    }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: filteredTodos.map(\.id))
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAddTodo = true
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add todo")
        }

        ToolbarItem(placement: .secondaryAction) {
            Menu {
                Picker("Filter", selection: $filter) {
                    ForEach(TodoFilter.allCases) { filterOption in
                        Label(filterOption.displayName, systemImage: filterOption.systemImage)
                            .tag(filterOption)
                    }
                }

                Divider()

                Menu("Sort") {
                    Picker("Sort", selection: $sortOrder) {
                        ForEach(TodoSortOrder.allCases) { order in
                            Text(order.displayName)
                                .tag(order)
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter and sort")
        }
    }

    private var addTodoSheet: some View {
        NavigationStack {
            AddTodoView {
                showingAddTodo = false
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Private Helpers

    private func sortTodos(_ todos: [TodoItem], by order: TodoSortOrder) -> [TodoItem] {
        switch order {
        case .createdAtDescending:
            return todos.sorted { $0.createdAt > $1.createdAt }
        case .createdAtAscending:
            return todos.sorted { $0.createdAt < $1.createdAt }
        case .titleAscending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .dueDateAscending:
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: true) }
        case .dueDateDescending:
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: false) }
        }
    }

    private func compareDueDates(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case (nil, _):
            return !ascending
        case (_, nil):
            return ascending
        case let (date1?, date2?):
            return ascending ? date1 < date2 : date1 > date2
        }
    }
}

// MARK: - Supporting Types

/// Filter options for the todo list.
public enum TodoFilter: String, CaseIterable, Identifiable {
    case all
    case incomplete
    case completed
    case favorites

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: return "All"
        case .incomplete: return "Incomplete"
        case .completed: return "Completed"
        case .favorites: return "Favorites"
        }
    }

    public var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .incomplete: return "circle"
        case .completed: return "checkmark.circle"
        case .favorites: return "star"
        }
    }
}

/// Sort options for the todo list.
public enum TodoSortOrder: String, CaseIterable, Identifiable {
    case createdAtDescending
    case createdAtAscending
    case titleAscending
    case titleDescending
    case dueDateAscending
    case dueDateDescending

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .createdAtDescending: return "Newest First"
        case .createdAtAscending: return "Oldest First"
        case .titleAscending: return "Title A-Z"
        case .titleDescending: return "Title Z-A"
        case .dueDateAscending: return "Due Date (Earliest)"
        case .dueDateDescending: return "Due Date (Latest)"
        }
    }
}

// MARK: - Preview

#Preview {
    TodoListView()
}
