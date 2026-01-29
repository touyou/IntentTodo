//
//  TodoListView.swift
//  IntentTodo
//

import SwiftUI
import TodoAppIntents

/// The main todo list view.
///
/// This view displays all todos with filtering, sorting, and search capabilities.
/// All actions are performed via App Intents.
public struct TodoListView: View {
    // MARK: - Properties

    @State private var viewModel = TodoListViewModel()
    @State private var showingAddTodo = false

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.todos.isEmpty {
                    loadingView
                } else if viewModel.filteredTodos.isEmpty {
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
            .refreshable {
                await viewModel.loadTodos()
            }
            .alert("Error", isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") {
                    viewModel.clearError()
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showingAddTodo) {
                addTodoSheet
            }
        }
        .task {
            await viewModel.loadTodos()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        ProgressView("Loading...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

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
            ForEach(viewModel.filteredTodos, id: \.id) { todo in
                TodoRowView(
                    todo: todo,
                    onUpdate: { updatedTodo in
                        viewModel.updateTodo(updatedTodo)
                    },
                    onDelete: {
                        viewModel.removeTodo(todo)
                    }
                )
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    DeleteButton(todo: todo) {
                        viewModel.removeTodo(todo)
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.default, value: viewModel.filteredTodos.map(\.id))
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
                    ForEach(TodoFilter.allCases) { filter in
                        Label(filter.displayName, systemImage: filter.systemImage)
                            .tag(filter)
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
            AddTodoView { entity in
                viewModel.addTodo(entity)
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
