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
    @State private var newTodoTitle = ""

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
        ContentUnavailableView {
            Label(emptyViewTitle, systemImage: emptyViewIcon)
        } description: {
            Text(emptyViewDescription)
        } actions: {
            if viewModel.filter == .all && viewModel.searchText.isEmpty {
                Button("Add Todo") {
                    showingAddTodo = true
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyViewTitle: String {
        if !viewModel.searchText.isEmpty {
            return "No Results"
        }
        switch viewModel.filter {
        case .all:
            return "No Todos"
        case .incomplete:
            return "All Done!"
        case .completed:
            return "No Completed Todos"
        case .favorites:
            return "No Favorites"
        }
    }

    private var emptyViewIcon: String {
        if !viewModel.searchText.isEmpty {
            return "magnifyingglass"
        }
        switch viewModel.filter {
        case .all:
            return "checklist"
        case .incomplete:
            return "checkmark.circle"
        case .completed:
            return "circle"
        case .favorites:
            return "star"
        }
    }

    private var emptyViewDescription: String {
        if !viewModel.searchText.isEmpty {
            return "No todos match your search."
        }
        switch viewModel.filter {
        case .all:
            return "Tap + to add your first todo."
        case .incomplete:
            return "You've completed all your todos!"
        case .completed:
            return "Complete some todos to see them here."
        case .favorites:
            return "Star a todo to add it to favorites."
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
