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
        // ViewModel が `@Query` 更新時に entities をキャッシュしているので、
        // body 評価のたびに発生していた `todoItems.map { TodoAppEntity(from: $0) }`
        // は不要。filter/sort のみここで適用する (filter/sort は item 数に対して軽量)。
        viewModel.filteredTodos(from: viewModel.entities)
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        // iOS/iPadOS/macOS 共通で NavigationSplitView。
        // - iPad/macOS: sidebar + detail の二分割表示
        // - iPhone (compact width): 自動で push 風に collapse されるので 1 view で両対応
        // - visionOS は別ファイル (VisionOSTodoView) で別実装
        NavigationSplitView {
            Group {
                if filteredTodos.isEmpty {
                    TodoListEmptyView(
                        filter: viewModel.filter,
                        searchText: viewModel.searchText
                    )
                } else {
                    TodoListSidebar(
                        todos: filteredTodos,
                        selection: $navigationModel.selectedTodo
                    )
                }
            }
            .navigationTitle("Todos")
            .toolbar {
                TodoListToolbar(viewModel: $viewModel)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search todos")
            // sidebar 既定幅は TodoRowView には狭いため ideal を広めに固定 (iPad/macOS)。
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 480)
        } detail: {
            if let selected = navigationModel.selectedTodo {
                TodoDetailView(todo: selected)
            } else {
                ContentUnavailableView(
                    "Select a Todo",
                    systemImage: "checklist",
                    description: Text("Pick a todo from the sidebar to view details.")
                )
            }
        }
        .sheet(isPresented: $navigationModel.showingAddTodo) {
            AddTodoSheet()
        }
        // `@Query` 更新時に ViewModel の entity キャッシュを更新する。
        // initial: true で最初のレンダリングにも反映される。
        .onChange(of: todoItems, initial: true) {
            viewModel.update(from: todoItems)
        }
        #if os(iOS)
        .monitorLiveActivities(for: todoItems)
        #endif
    }
}

// MARK: - Sidebar

private struct TodoListSidebar: View {
    let todos: [TodoAppEntity]
    @Binding var selection: TodoAppEntity?

    var body: some View {
        // SwiftData @Query の delta 検出により List の行挿入/削除は標準で animate
        // されるため、明示的な `.animation(value: todos.map(\.id))` は外す。旧実装は
        // body 評価のたびに `[String]` 配列を再アロケートしていたため、件数が増える
        // ほどスクロールがカクついていた。
        List(selection: $selection) {
            ForEach(todos, id: \.id) { todo in
                TodoRowView(todo: todo)
                    .tag(todo)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        DeleteButton(todo: todo)
                    }
            }
        }
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
                FilterPicker(selection: $viewModel.filter)
                Divider()
                Menu("Sort") {
                    SortPicker(selection: $viewModel.sortOrder)
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

/// Sheet container for `AddTodoView`. Dismissal is driven by `AddTodoIntent.perform()`
/// which calls `navigationModel.dismissAddTodo()` on success — no need to observe
/// `@Query` count drift here.
private struct AddTodoSheet: View {
    var body: some View {
        #if os(macOS)
        // macOS では NavigationStack + navigationTitle がタイトル上に大きな余白を
        // 取って窮屈に見えるため、NavigationStack を外して AddTodoView 単体を表示。
        // ツールバー (Cancel / Add ボタン) は AddTodoView 側の .toolbar が
        // ウィンドウバーに自動配置される。
        AddTodoView()
            .frame(minWidth: 520, minHeight: 420)
        #else
        NavigationStack {
            AddTodoView()
        }
        .presentationDetents([.medium])
        #endif
    }
}

// MARK: - Preview

#Preview {
    TodoListView()
        .environment(NavigationModel())
}
