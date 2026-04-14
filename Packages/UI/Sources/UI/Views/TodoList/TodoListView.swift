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
/// - **Data**: `@Query` for automatic SwiftData updates
/// - **Actions**: `Button(intent:)` executes App Intents directly
/// - **Navigation**: `NavigationModel` from environment — written by Intents via @Dependency
public struct TodoListView: View {
    // MARK: - Properties

    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todoItems: [TodoItem]
    @State private var viewModel = TodoListViewModel()
    @Environment(NavigationModel.self) private var navigationModel

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
        @Bindable var navigationModel = navigationModel
        NavigationStack(path: $navigationModel.path) {
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
            .sheet(isPresented: $navigationModel.showingAddTodo) {
                addTodoSheet
            }
        }
        #if os(iOS)
        .monitorLiveActivities(for: todoItems)
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
                    navigationModel.showAddTodo()
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
                    navigationModel.showDetail(for: todo)
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

    /// Filter/Sort メニューのツールバー配置先。`.topBarTrailing` は macOS で利用不可のため分岐。
    private var filterSortPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                navigationModel.showAddTodo()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("addTodoButton")
            .accessibilityLabel("Add todo")
        }

        ToolbarItem(placement: filterSortPlacement) {
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
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .labelStyle(.iconOnly)
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
            if newCount > oldCount {
                navigationModel.dismissAddTodo()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TodoListView()
        .environment(NavigationModel())
}
