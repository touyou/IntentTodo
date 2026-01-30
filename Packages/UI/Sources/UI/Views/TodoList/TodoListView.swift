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
/// - **Data**: SwiftData's `@Query` provides automatic updates
/// - **Actions**: `Button(intent:)` executes App Intents directly
/// - **UI State**: `TodoListViewModel` manages filter, sort, and search
public struct TodoListView: View {
    // MARK: - Properties

    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @State private var showingAddTodo = false

    // MARK: - Computed Properties

    private var allTodos: [TodoAppEntity] {
        todoItems.map { TodoAppEntity(from: $0) }
    }

    private var filteredTodos: [TodoAppEntity] {
        viewModel.filteredTodos(from: allTodos)
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
            .searchable(text: $viewModel.searchText, prompt: "Search todos")
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
            if viewModel.filter == .all && viewModel.searchText.isEmpty {
                Button("Add Todo") {
                    showingAddTodo = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyViewContent: (title: String, icon: String, description: String) {
        if !viewModel.searchText.isEmpty {
            return ("No Results", "magnifyingglass", "No todos match your search.")
        }
        switch viewModel.filter {
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
                Picker("Filter", selection: $viewModel.filter) {
                    ForEach(TodoFilter.allCases) { filterOption in
                        Label(filterOption.displayName, systemImage: filterOption.systemImage)
                            .tag(filterOption)
                    }
                }

                Divider()

                Menu("Sort") {
                    Picker("Sort", selection: $viewModel.sortOrder) {
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
}

// MARK: - Preview

#Preview {
    TodoListView()
}
