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
/// - **Navigation**: `NavigationViewModel` manages navigation state
public struct TodoListView: View {
    // MARK: - Properties

    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @State private var navigationViewModel = NavigationViewModel()

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
        NavigationStack(path: $navigationViewModel.path) {
            Group {
                if filteredTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle("Todos")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .todoDetail(let todo):
                    TodoDetailView(todo: todo)
                }
            }
            .toolbar {
                toolbarContent
            }
            .searchable(text: $viewModel.searchText, prompt: "Search todos")
            .sheet(isPresented: $navigationViewModel.showingAddTodo) {
                addTodoSheet
            }
        }
        #if os(iOS)
        .monitorLiveActivities(for: todoItems)
        #endif
        .onAppear {
            // Check if an Intent requested to show add todo
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #if os(iOS)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Also check when app becomes active (from background)
            if IntentAppState.shared.consumeShowAddTodoRequest() {
                navigationViewModel.showAddTodo()
            }
        }
        #endif
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
                    navigationViewModel.showAddTodo()
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
                Button {
                    navigationViewModel.showDetail(for: todo)
                } label: {
                    TodoRowView(todo: todo)
                }
                .buttonStyle(.plain)
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
                navigationViewModel.showAddTodo()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("addTodoButton")
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
            .accessibilityIdentifier("filterSortMenu")
            .accessibilityLabel("Filter and sort")
        }
    }

    private var addTodoSheet: some View {
        NavigationStack {
            AddTodoView()
        }
        .presentationDetents([.medium])
        .onChange(of: todoItems.count) { oldCount, newCount in
            // Close sheet when a new todo is added
            if newCount > oldCount {
                navigationViewModel.dismissAddTodo()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TodoListView()
}
