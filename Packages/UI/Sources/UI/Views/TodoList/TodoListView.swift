//
//  TodoListView.swift
//  IntentTodo
//

import Domain
#if os(iOS)
import LiveActivity
#endif
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

    private var filteredTodos: [TodoAppEntity] {
        viewModel.filteredTodos(from: todoItems.map { TodoAppEntity(from: $0) })
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        NavigationStack(path: $navigationModel.path) {
            Group {
                if filteredTodos.isEmpty {
                    TodoListEmptyView(
                        filter: viewModel.filter,
                        searchText: viewModel.searchText
                    )
                } else {
                    TodoListContent(todos: filteredTodos)
                }
            }
            #if os(macOS)
            // macOS native はデフォルトだとコンテンツが端まで詰まって窮屈に見えるので、
            // List/Empty 双方に共通の横余白を入れる。
            .padding(.horizontal, 24)
            #endif
            .navigationTitle("Todos")
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .todoDetail(let todo):
                    TodoDetailView(todo: todo)
                }
            }
            .toolbar {
                TodoListToolbar(viewModel: $viewModel)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search todos")
            .sheet(isPresented: $navigationModel.showingAddTodo) {
                AddTodoSheet(todoCount: todoItems.count)
            }
        }
        #if os(iOS)
        .monitorLiveActivities(for: todoItems)
        #endif
    }
}

// MARK: - Empty View

private struct TodoListEmptyView: View {
    let filter: TodoFilter
    let searchText: String
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        let content = emptyContent
        ContentUnavailableView {
            Label(content.title, systemImage: content.icon)
        } description: {
            Text(content.description)
        } actions: {
            if filter == .all && searchText.isEmpty {
                Button("Add Todo") { navigationModel.showAddTodo() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyContent: (title: String, icon: String, description: String) {
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
}

// MARK: - List Content

private struct TodoListContent: View {
    let todos: [TodoAppEntity]
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        List {
            ForEach(todos, id: \.id) { todo in
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
        .animation(.default, value: todos.map(\.id))
    }
}

// MARK: - Toolbar

private struct TodoListToolbar: ToolbarContent {
    @Binding var viewModel: TodoListViewModel
    @Environment(NavigationModel.self) private var navigationModel

    /// `.topBarTrailing` は macOS で利用不可のため分岐。
    private var filterSortPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    var body: some ToolbarContent {
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
                            Text(order.displayName).tag(order)
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
}

// MARK: - Add Todo Sheet

private struct AddTodoSheet: View {
    let todoCount: Int
    @Environment(NavigationModel.self) private var navigationModel
    @State private var baselineCount: Int?

    var body: some View {
        NavigationStack {
            AddTodoView()
        }
        .presentationDetents([.medium])
        #if os(macOS)
        // macOS の sheet はデフォルトだと小さすぎて Form が窮屈になるため最小サイズを指定。
        .frame(minWidth: 480, minHeight: 360)
        #endif
        .task { baselineCount = todoCount }
        .onChange(of: todoCount) { _, newValue in
            // シート開いた時点より件数が増えていれば Intent が成功したと判定しシートを閉じる。
            if let baseline = baselineCount, newValue > baseline {
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
