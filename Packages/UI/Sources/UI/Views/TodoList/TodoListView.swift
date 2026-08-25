//
//  TodoListView.swift
//  IntentTodo
//

import AppIntents
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
    /// 集中モードの絞り込み。`TodoFocusFilterIntent` が書き込むと body が再評価される。
    @State private var focusFilterStore = TodoFocusFilterStore.shared
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed Properties

    private var filteredTodos: [TodoAppEntity] {
        // SwiftData の `@Query` が返す `[TodoItem]` は class ベースの `PersistentModel`
        // を要素に持つため、要素の中身変更 (title / isCompleted トグル) では `onChange`
        // ベースのキャッシュ更新が発火しない。安全側に倒し、body 評価ごとに entity 化する。
        // 1,000 件規模での map コストが問題になるなら、`TodoItem` のフィールドだけを
        // 抜き出した軽量 projection (例: SwiftData の `#Predicate` で fetch する struct)
        // を別途検討する。
        viewModel.filteredTodos(
            from: todoItems.map { TodoAppEntity(from: $0) },
            focusFilter: focusFilterStore.effectiveFilter
        )
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
                        selection: $navigationModel.selectedTodo,
                        // Drag-to-reorder is only meaningful when the list is showing
                        // the user's manual order (WWDC 2026 reorderable containers,
                        // 27+; gated inside the sidebar).
                        isReorderable: viewModel.sortOrder == .manual,
                        onReorder: persistReorder
                    )
                }
            }
            .navigationTitle("Todos")
            // 一覧が空になる原因が Focus のときも見えている必要があるので、List の中
            // ではなく List の外（上端）に出す。
            .safeAreaInset(edge: .top, spacing: 0) {
                FocusFilterBanner(store: focusFilterStore)
            }
            .toolbar {
                TodoListToolbar(viewModel: $viewModel)
            }
            .searchable(text: $viewModel.searchText, prompt: "Search todos")
            // sidebar 既定幅は TodoRowView には狭いため ideal を広めに固定 (iPad/macOS)。
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 480)
            #if os(iOS)
            // WWDC 2026: shrink the nav bar as the person scrolls the list down.
            // `.onScrollDown` is iOS-only, so it's gated; older OSes keep the bar.
            .modifier(NavigationBarMinimizeOnScroll())
            #endif
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
        // Apply a search term pushed by ShowTodoSearchResultsIntent (.system.searchInApp).
        .onChange(of: navigationModel.pendingSearchText) { _, newValue in
            applyPendingSearch(newValue)
        }
        .onAppear { applyPendingSearch(navigationModel.pendingSearchText) }
        // Apply a filter pushed by LaunchAppIntent (Todo Count control, Siri "show
        // my favorite todos", …) so the app lands on the list the caller asked for.
        .onChange(of: navigationModel.pendingFilter) { _, newValue in
            applyPendingFilter(newValue)
        }
        .onAppear { applyPendingFilter(navigationModel.pendingFilter) }
        #if os(iOS)
        .monitorLiveActivities(for: todoItems)
        #endif
    }

    /// Copies an intent-supplied search term into the search field, then clears
    /// the pending value so it isn't re-applied.
    private func applyPendingSearch(_ term: String?) {
        guard let term else { return }
        viewModel.searchText = term
        navigationModel.pendingSearchText = nil
    }

    /// Copies an intent-supplied filter into the list's filter state, then clears
    /// the pending value so it isn't re-applied.
    private func applyPendingFilter(_ filterType: TodoFilterType?) {
        guard let filterType else { return }
        viewModel.filter = TodoFilter(filterType)
        navigationModel.pendingFilter = nil
    }

    /// Persists a drag-to-reorder result. The reorder gesture can't be a
    /// `Button(intent:)`, so it calls the same `TodoService` the canonical
    /// `ReorderTodosIntent` runs — no logic is duplicated. `modelContext.container`
    /// is the app's shared container, so the write lands in the `@Query`'s context.
    private func persistReorder(_ orderedIDs: [String]) {
        let service = TodoService.swiftDataBacked(container: modelContext.container)
        try? service.reorderTodos(orderedIDs: orderedIDs)
    }
}

// MARK: - Sidebar

private struct TodoListSidebar: View {
    let todos: [TodoAppEntity]
    @Binding var selection: TodoAppEntity?
    let isReorderable: Bool
    /// Receives the new, fully-ordered list of todo ids after a drag.
    let onReorder: ([String]) -> Void

    var body: some View {
        // SwiftData @Query の delta 検出により List の行挿入/削除は標準で animate
        // されるため、明示的な `.animation(value: todos.map(\.id))` は外す。旧実装は
        // body 評価のたびに `[String]` 配列を再アロケートしていたため、件数が増える
        // ほどスクロールがカクついていた。
        List(selection: $selection) {
            SiriTipRow()

            // `.reorderable()` (WWDC 2026) turns any container into a drag-to-reorder
            // one. It's 27+ only, so gate it; on older OSes (or non-manual sort) the
            // rows render exactly as before.
            if #available(iOS 27, macOS 27, visionOS 27, *), isReorderable {
                ForEach(todos, id: \.id) { row($0) }
                    .reorderable()
            } else {
                ForEach(todos, id: \.id) { row($0) }
            }
        }
        // Collection onscreen (WWDC 2026 #343): advertise every visible row's
        // entity so Siri / Apple Intelligence can resolve references like "the
        // third one" while the list is on screen. The selection-type variant
        // keeps overhead low for large lists by mapping ids lazily.
        .appEntityIdentifier(forSelectionType: TodoAppEntity.self) { todo in
            EntityIdentifier(for: TodoAppEntity.self, identifier: todo.id)
        }
        .modifier(ReorderContainer(enabled: isReorderable, todos: todos, onReorder: onReorder))
    }

    @ViewBuilder
    private func row(_ todo: TodoAppEntity) -> some View {
        TodoRowView(todo: todo)
            .tag(todo)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                DeleteButton(todo: todo)
            }
    }
}

// MARK: - Focus Filter Banner

/// 集中モードで一覧が絞られていることを示し、その場で解除できるようにする。
///
/// 標準アプリ（カレンダー）が Focus filter 適用中に「Focus で絞り込み中」の表示と
/// 解除手段を並べて出しているのと同じ扱い（wwdc2022-10121 2:04）。表示だけ出して
/// 解除手段が無いと、絞られていることに気づいたユーザーが設定アプリまで行くしかない。
private struct FocusFilterBanner: View {
    let store: TodoFocusFilterStore

    var body: some View {
        if store.filter.isActive {
            HStack(spacing: 8) {
                Image(systemName: "moon.fill")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(store.isSuspended ? "Focus filter paused" : "Filtered by Focus")
                        .font(.footnote)
                    FocusFilterConditions(filter: store.filter)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(store.isSuspended ? "Apply" : "Show All") {
                    store.isSuspended.toggle()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Liquid Glass 時代のクロームは自前で塗らずシステムマテリアルに任せる。
            .background(.bar)
            .accessibilityElement(children: .combine)
        }
    }
}

/// 効いている条件の内訳。文言を `String` に連結せず `Text` を並べることで、
/// このファイルの他の文言と同じくローカライズ対象のまま扱える
/// （カテゴリ名だけはユーザーデータなので `verbatim`）。
private struct FocusFilterConditions: View {
    let filter: TodoFocusFilter

    var body: some View {
        HStack(spacing: 6) {
            if let categoryName = filter.categoryName {
                Text(verbatim: categoryName)
            }
            if filter.showsUrgentOnly {
                Text("Urgent only")
            }
            if filter.hidesCompleted {
                Text("Hiding completed")
            }
        }
    }
}

// MARK: - Siri Tip

/// App Shortcut の存在をアプリ内で知らせる 1 行。
///
/// App Shortcut は Spotlight / Siri / Shortcuts からは自動で見つかるが、**ユーザーが
/// 「言えること」を知らない**限り使われない。HIG (App Shortcuts / Best practices) の
/// "Make App Shortcuts discoverable in your app" に対応する標準コンポーネントが
/// `SiriTipView` で、渡した Intent に対応するフレーズをそのまま表示してくれる
/// (フレーズを View 側にハードコードしないので、`TodoAppShortcuts` を直せば追従する)。
///
/// 一度閉じたら出さない。`isVisible` に `@AppStorage` を渡しているので、
/// `SiriTipView` の閉じるボタンがそのまま永続化される。
///
/// **macOS では出さない**: `SiriTipView` / `SiriTipViewStyle` は SDK で
/// `@available(macOS, unavailable)`。Mac では Shortcuts アプリ側の一覧が導線になる。
/// 詳細: docs/insights/03-app-intents-core.md
private struct SiriTipRow: View {
    @AppStorage("siriTip.addTodo.isVisible") private var isVisible = true

    var body: some View {
        #if os(macOS)
        EmptyView()
        #else
        if isVisible {
            SiriTipView(intent: AddTodoIntent(), isVisible: $isVisible)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
        }
        #endif
    }
}

// MARK: - Reorder wiring (WWDC 2026 reorderable containers)

/// Attaches `.reorderContainer(for:itemID:)` to the list when manual reordering is
/// active and the OS supports it. Kept as a `ViewModifier` so the `#available`
/// gate lives in one place and the list body stays readable.
private struct ReorderContainer: ViewModifier {
    let enabled: Bool
    let todos: [TodoAppEntity]
    let onReorder: ([String]) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27, macOS 27, visionOS 27, *), enabled {
            content.reorderContainer(for: TodoAppEntity.self, itemID: \.id) { difference in
                onReorder(difference.newOrder(from: todos))
            }
        } else {
            content
        }
    }
}

@available(iOS 27, macOS 27, visionOS 27, *)
private extension ReorderDifference
where ItemID == String, CollectionID == ReorderableSingleCollectionIdentifier {
    /// Applies this single-collection reorder to `current` and returns the new,
    /// fully-ordered list of ids. The moved ids keep their relative order.
    func newOrder(from current: [TodoAppEntity]) -> [String] {
        let moving = Set(sources)
        var ids = current.map(\.id)
        let moved = ids.filter { moving.contains($0) }
        ids.removeAll { moving.contains($0) }
        switch destination.position {
        case .before(let anchor):
            let index = ids.firstIndex(of: anchor) ?? ids.endIndex
            ids.insert(contentsOf: moved, at: index)
        case .end:
            ids.append(contentsOf: moved)
        }
        return ids
    }
}

// MARK: - Toolbar minimize (WWDC 2026)

#if os(iOS)
/// Minimizes the navigation bar as the person scrolls down. `.onScrollDown` is
/// iOS-only and 27+, so this gates it and no-ops on older OSes.
private struct NavigationBarMinimizeOnScroll: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27, *) {
            content.toolbarMinimizationBehavior(.onScrollDown, for: .navigationBar)
        } else {
            content
        }
    }
}
#endif

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
