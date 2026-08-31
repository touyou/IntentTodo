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
    /// Focus filtering. `TodoFocusFilterIntent` writes it, which re-evaluates the body.
    @State private var focusFilterStore = TodoFocusFilterStore.shared
    /// Feedback that could not be delivered because a channel is disabled in Settings.
    @State private var missedFeedback = MissedFeedbackModel()
    /// Decides when to teach an App Shortcut phrase.
    @State private var siriTip = SiriTipModel()
    @State private var showingSettings = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed Properties

    private var filteredTodos: [TodoAppEntity] {
        // Mapped on every body evaluation rather than cached: `@Query` returns reference
        // types, so changing a field in place would not fire an `onChange`-based cache.
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
        // One `NavigationSplitView` covers iPhone, iPad and Mac: at compact width it
        // collapses into push navigation on its own. visionOS has its own view.
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
            .navigationTitle(.copy("Todos"))
            // Outside the list, not in it: the banners have to stay visible when the list
            // is empty — which is exactly when a Focus filter is the explanation.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    FocusFilterBanner(store: focusFilterStore)
                    // The writer can be an extension process, so there is nothing to
                    // subscribe to: re-read on appear and on foregrounding.
                    MissedFeedbackBanner(model: missedFeedback)
                    SiriTipBanner(model: siriTip)
                }
            }
            .onAppear { missedFeedback.refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else {
                    // Leaving the foreground hides the tip without counting as dismissal.
                    siriTip.hide()
                    return
                }
                missedFeedback.refresh()
            }
            // Adding a todo from the app's own sheet is the moment a phrase would have
            // saved work — and the counter does not move for Siri, Shortcuts or widget
            // additions, so people already using phrases never see the tip.
            //
            // Not even counted on macOS, where `SiriTipView` is unavailable: otherwise the
            // two-time budget would be spent on a platform that can never show it.
            #if !os(macOS)
            .onChange(of: navigationModel.inAppAddCount) { _, _ in
                siriTip.recordInAppAdd()
            }
            #endif
            .toolbar {
                TodoListToolbar(viewModel: $viewModel, showingSettings: $showingSettings)
            }
            .searchable(text: $viewModel.searchText, prompt: .copy("Search todos"))
            // The default sidebar width is too narrow for a todo row.
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
                    .copy("Select a Todo"),
                    systemImage: "checklist",
                    description: Text(.copy("Pick a todo from the sidebar to view details."))
                )
            }
        }
        .sheet(isPresented: $navigationModel.showingAddTodo) {
            AddTodoSheet()
        }
        #if os(iOS)
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
        #endif
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
        // No explicit `.animation(value:)`: `@Query` delta detection already animates row
        // insertion and removal, and building an id array per body evaluation cost more
        // than it bought.
        List(selection: $selection) {
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
    /// Copy for one `ContentUnavailableView`.
    ///
    /// Typed as `LocalizedStringResource`: with `String`, `Label` and `Text` pick their
    /// verbatim initialisers and the literals never reach the String Catalog.
    private struct EmptyContent {
        let title: LocalizedStringResource
        let icon: String
        let description: LocalizedStringResource
    }

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
                Button(.copy("Add Todo")) { navigationModel.showAddTodo() }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var emptyContent: EmptyContent {
        if !searchText.isEmpty {
            return EmptyContent(
                title: .copy("No Results"),
                icon: "magnifyingglass",
                description: .copy("No todos match your search.")
            )
        }
        switch filter {
        case .all:
            return EmptyContent(
                title: .copy("No Todos"),
                icon: "checklist",
                description: .copy("Tap + to add your first todo.")
            )
        case .incomplete:
            return EmptyContent(
                title: .copy("All Done!"),
                icon: "checkmark.circle",
                description: .copy("You've completed all your todos!")
            )
        case .completed:
            return EmptyContent(
                title: .copy("No Completed Todos"),
                icon: "circle",
                description: .copy("Complete some todos to see them here.")
            )
        case .favorites:
            return EmptyContent(
                title: .copy("No Favorites"),
                icon: "star",
                description: .copy("Star a todo to add it to favorites.")
            )
        }
    }
}

// MARK: - Toolbar

private struct TodoListToolbar: ToolbarContent {
    @Binding var viewModel: TodoListViewModel
    @Binding var showingSettings: Bool
    @Environment(NavigationModel.self) private var navigationModel

    /// `.topBarTrailing` does not exist on macOS.
    private var filterSortPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    var body: some ToolbarContent {
        #if os(iOS)
        // Entry point for the integration settings. `SettingsView` is not built on macOS
        // (no `ShortcutsLink` there), so the button is iOS-only as well.
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityIdentifier("settingsButton")
            .accessibilityLabel(.copy("Settings"))
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            Button {
                navigationModel.showAddTodo()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityIdentifier("addTodoButton")
            .accessibilityLabel(.copy("Add todo"))
        }

        ToolbarItem(placement: filterSortPlacement) {
            Menu {
                FilterPicker(selection: $viewModel.filter)
                Divider()
                Menu(.copy("Sort")) {
                    SortPicker(selection: $viewModel.sortOrder)
                }
            } label: {
                Label(.copy("Filter"), systemImage: "line.3.horizontal.decrease.circle")
                    .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("filterSortMenu")
            .accessibilityLabel(.copy("Filter and sort"))
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
        // No `NavigationStack` on macOS: with a navigation title it reserves a band of
        // space above the form. The view's own toolbar lands in the window bar anyway.
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
