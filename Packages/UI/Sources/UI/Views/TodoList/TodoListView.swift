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
    /// Only for the list and tag filters: the names and colours the menu offers, and the
    /// change signal that keeps ``organize`` fresh.
    @Query(sort: \Domain.Category.name) private var categories: [Domain.Category]
    @State private var viewModel = TodoListViewModel()
    /// List and tag memberships, for the two filters the menu adds. Fetched rather than read
    /// off `todoItems` — see `OrganizeSnapshotReader`.
    @State private var organize: TodoOrganizeSnapshot?
    /// Focus filtering. `TodoFocusFilterIntent` writes it, which re-evaluates the body.
    @State private var focusFilterStore = TodoFocusFilterStore.shared
    /// Feedback that could not be delivered because a channel is disabled in Settings.
    @State private var missedFeedback = MissedFeedbackModel()
    @State private var showingSettings = false
    /// The clock the post-completion grace period is measured against.
    ///
    /// Re-stamped when the oldest grace period runs out, which is what takes the row off
    /// the list: completing a todo is a store change and redraws on its own, but the row
    /// *leaving* three seconds later is not. Reading a stale value only ever keeps a row
    /// a frame longer, and scheduling on a past deadline corrects it immediately.
    @State private var graceNow = Date()
    /// Owned here rather than left to the system so the sidebar button and the View menu
    /// drive the same state.
    ///
    /// `.all` on iOS rather than `.automatic`: at the widths an iPad in portrait and a
    /// folding iPhone report, the system resolves `.automatic` to `.detailOnly`, which
    /// hides the list column — and with it every toolbar item the list owns.
    #if os(iOS)
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    #else
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    #endif
    #if os(macOS)
    /// The todo the list is about to delete, and the dialog's source of truth.
    ///
    /// Written by the Delete key, the row's context menu and the Todo menu; all three
    /// confirm here and then run the non-confirming intent.
    @State private var todoPendingDeletion: TodoAppEntity?
    @FocusState private var isSearchFieldFocused: Bool
    #endif
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NavigationModel.self) private var navigationModel
    @Environment(\.modelContext) private var modelContext

    // MARK: - Computed Properties

    #if os(iOS)
    /// Whether the create action is a prominent button over the detail column.
    ///
    /// Two columns means a list column whose bar is too narrow to hold another item and
    /// which the person can close outright. The detail column is on screen either way,
    /// and a button of its own reads as the primary action rather than as one more icon
    /// beside Edit.
    private var addsTodoFromDetail: Bool {
        horizontalSizeClass == .regular
    }
    #endif

    private var filteredTodos: [TodoAppEntity] {
        // Mapped on every body evaluation rather than cached: `@Query` returns reference
        // types, so changing a field in place would not fire an `onChange`-based cache.
        viewModel.filteredTodos(
            from: todoItems.map { TodoAppEntity(from: $0) },
            focusFilter: focusFilterStore.effectiveFilter,
            organize: organize,
            now: graceNow
        )
    }

    /// The title for the list currently being browsed.
    ///
    /// A `Text` rather than a `LocalizedStringResource`: a list's name is the person's own
    /// words and must stay verbatim, while the two fixed cases are UI copy.
    private var listTitle: Text {
        switch viewModel.listFilter {
        case .all:
            return Text(.copy("Todos"))
        case .uncategorized:
            return Text(.copy("Uncategorized"))
        case .list(let id):
            // Falls back to the generic title until the snapshot has loaded, rather than
            // flashing an empty navigation bar.
            guard let name = organize?.lists.first(where: { $0.id == id })?.name else {
                return Text(.copy("Todos"))
            }
            return Text(name)
        }
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        // Evaluated once and passed down: the list, the empty state and the grace-period
        // wake-up all need the same answer, and each read re-runs the whole filter.
        let visibleTodos = filteredTodos
        let graceExpiry = viewModel.nextCompletionGraceExpiry(in: visibleTodos, now: graceNow)
        // One `NavigationSplitView` covers iPhone, iPad and Mac: at compact width it
        // collapses into push navigation on its own. visionOS has its own view.
        return NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if visibleTodos.isEmpty {
                    TodoListEmptyView(
                        filter: viewModel.filter,
                        searchText: viewModel.searchText,
                        isNarrowed: viewModel.isNarrowedByListOrTag,
                        isStoreEmpty: todoItems.isEmpty
                    )
                } else {
                    TodoListSidebar(
                        todos: visibleTodos,
                        selection: $navigationModel.selectedTodo,
                        // Drag-to-reorder is only meaningful when the list is showing
                        // the user's manual order (WWDC 2026 reorderable containers,
                        // 27+; gated inside the sidebar).
                        isReorderable: viewModel.sortOrder == .manual,
                        searchTerm: viewModel.searchText,
                        organize: organize,
                        onReorder: persistReorder,
                        onRequestDeletion: requestDeletion
                    )
                }
            }
            // The list being browsed, not a fixed "Todos": the list filter is the one bit of
            // narrowing that changes *what* you are looking at rather than how much of it,
            // so it belongs in the title the way Reminders puts the list name there.
            .navigationTitle(listTitle)
            // Outside the list, not in it: the banners have to stay visible when the list
            // is empty — which is exactly when a Focus filter is the explanation.
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    FocusFilterBanner(store: focusFilterStore)
                    // The writer can be an extension process, so there is nothing to
                    // subscribe to: re-read on appear and on foregrounding.
                    MissedFeedbackBanner(model: missedFeedback)
                }
            }
            .onAppear { missedFeedback.refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                missedFeedback.refresh()
            }
            // Takes a just-completed row off the list once its grace period is up. The id
            // is `nil` whenever no row is waiting, so an idle list schedules nothing.
            .task(id: graceExpiry) {
                guard let graceExpiry else { return }
                let remaining = graceExpiry.timeIntervalSinceNow
                if remaining > 0 {
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                }
                // Not a bare `Date()`: the sleep is measured on the continuous clock while
                // this is the wall clock, so an adjustment during the wait can leave the
                // new stamp short of the deadline. The row would then still be inside its
                // grace period, `graceExpiry` would be unchanged, and the task would not
                // run again — leaving the row until the next store change.
                graceNow = max(Date(), graceExpiry)
            }
            // Keeps the list and tag filters in step with the store. The read is a fetch, so
            // the `@Query` results are only the change signal.
            .task(id: TodoStoreDigest.make(todos: todoItems, categories: categories)) {
                let service = TodoService.swiftDataBacked(container: modelContext.container)
                organize = (try? service.organizeSnapshot()) ?? .empty
            }
            #if os(macOS)
            // The system's own toggle sits at the *trailing* edge of the sidebar's
            // toolbar section, so it jumps across the window every time the sidebar
            // collapses. `TodoListToolbar` puts ours next to the window controls, where
            // it stays in both states.
            .toolbar(removing: .sidebarToggle)
            #endif
            .toolbar {
                TodoListToolbar(
                    viewModel: $viewModel,
                    showingSettings: $showingSettings,
                    columnVisibility: $columnVisibility,
                    organize: organize,
                    includesAddTodo: {
                        #if os(iOS)
                        !addsTodoFromDetail
                        #else
                        true
                        #endif
                    }()
                )
            }
            .searchable(text: $viewModel.searchText, prompt: .copy("Search todos"))
            #if os(macOS)
            // Lets the Find command put the caret in the toolbar's search field.
            .searchFocused($isSearchFieldFocused)
            #endif
            // The default sidebar width is too narrow for a todo row.
            .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 480)
            #if os(iOS)
            // WWDC 2026: shrink the nav bar as the person scrolls the list down.
            // `.onScrollDown` is iOS-only, so it's gated; older OSes keep the bar.
            .modifier(NavigationBarMinimizeOnScroll())
            #endif
        } detail: {
            Group {
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
            #if os(iOS)
            // Over the detail column, which stays on screen when the list column is
            // closed — the one state where nothing the list owns is reachable.
            .safeAreaInset(edge: .bottom) {
                if addsTodoFromDetail {
                    ProminentAddTodoButton()
                }
            }
            #endif
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
        #if os(macOS)
        // Confirmed here, not by the intent: `requestConfirmation` has no surface to
        // present on when the caller is the app itself, so the confirming intent would
        // fail silently. The non-confirming one runs from the dialog's button.
        .confirmationDialog(
            Text(.copy("Delete “\(todoPendingDeletion?.title ?? "")”?")),
            item: $todoPendingDeletion,
            titleVisibility: .visible
        ) { todo in
            Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: todo)) {
                Text(.copy("Delete"))
            }
        }
        // Published scene-wide so the menu bar commands act on the current selection
        // however focus moves between the sidebar, the detail pane and the search field.
        .focusedSceneValue(\.selectedTodo, navigationModel.selectedTodo)
        .focusedSceneValue(\.todoDeletionRequest, $todoPendingDeletion)
        .focusedSceneValue(
            \.todoSearchFieldFocus,
            Binding { isSearchFieldFocused } set: { isSearchFieldFocused = $0 }
        )
        #endif
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
    ///
    /// The drag only ever reports the rows that were on screen, so it is spliced back into
    /// the order of the whole store first: `reorderTodos(orderedIDs:)` numbers what it is
    /// given from zero, which would collide with every todo a filter was hiding.
    private func persistReorder(_ orderedIDs: [String]) {
        let service = TodoService.swiftDataBacked(container: modelContext.container)
        let all = todoItems.map { TodoAppEntity(from: $0) }
        try? service.reorderTodos(
            orderedIDs: viewModel.manualOrder(applying: orderedIDs, to: all)
        )
    }

    /// Puts a todo in front of the delete confirmation.
    ///
    /// Only the Mac has list-level delete affordances (the Delete key, the row's
    /// context menu and the Todo menu); elsewhere the swipe action deletes directly.
    private func requestDeletion(of todo: TodoAppEntity) {
        #if os(macOS)
        todoPendingDeletion = todo
        #endif
    }
}

// MARK: - Sidebar

private struct TodoListSidebar: View {
    let todos: [TodoAppEntity]
    @Binding var selection: TodoAppEntity?
    let isReorderable: Bool
    /// The live search term, so each row can say what it matched on.
    let searchTerm: String
    /// Supplies the tag memberships a match reason is derived from.
    let organize: TodoOrganizeSnapshot?
    /// Receives the new, fully-ordered list of todo ids after a drag.
    let onReorder: ([String]) -> Void
    /// Asks the list to confirm deleting a todo. Called from the Mac's Delete key and
    /// row context menu.
    let onRequestDeletion: (TodoAppEntity) -> Void

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
        #if os(macOS)
        // ⌫ / ⌦ on the focused list. Routed through the responder chain rather than a
        // plain-key `keyboardShortcut`, which would swallow backspace in the search
        // field as well.
        .onDeleteCommand {
            guard let selection else { return }
            onRequestDeletion(selection)
        }
        #endif
    }

    /// Whether the row offers its actions as a menu.
    ///
    /// Always on the Mac, where the menu is a right-click and cannot be confused with
    /// anything else. On iOS a long press is how the reorderable list is dragged, so the
    /// menu stands down while manual order is the one in effect — otherwise the same
    /// gesture would mean two things.
    private var showsRowMenu: Bool {
        #if os(macOS)
        true
        #else
        !isReorderable
        #endif
    }

    @ViewBuilder
    private func row(_ todo: TodoAppEntity) -> some View {
        TodoRowView(
            todo: todo,
            searchMatch: TodoSearchMatch.make(for: todo, term: searchTerm, organize: organize)
        )
            .tag(todo)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                DeleteButton(todo: todo)
            }
            .modifier(RowMenu(isEnabled: showsRowMenu) { rowMenu(todo) })
    }

    /// The row's own actions. Same intents the checkbox, the star and the swipe run.
    @ViewBuilder
    private func rowMenu(_ todo: TodoAppEntity) -> some View {
        Button(intent: ToggleTodoCompletionIntent(todo: todo)) {
            Text(todo.isCompleted ? .copy("Mark as Not Completed") : .copy("Mark as Completed"))
        }
        Button(intent: ToggleFavoriteIntent(todo: todo)) {
            Text(todo.isFavorite ? .copy("Remove from Favorites") : .copy("Add to Favorites"))
        }
        Divider()
        #if os(macOS)
        // Confirmed by the list, which owns the dialog: `requestConfirmation` has no
        // surface to present on when the caller is the app itself.
        Button(role: .destructive) {
            onRequestDeletion(todo)
        } label: {
            Text(.copy("Delete"))
        }
        #else
        // Matches the swipe action, where revealing Delete and pressing it is already the
        // confirmation, so the non-confirming intent is the right one.
        Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: todo)) {
            Text(.copy("Delete"))
        }
        #endif
    }
}

/// Attaches the row's context menu, or leaves the long press alone.
///
/// A `contextMenu` with empty content still opens an empty menu, so the choice has to be
/// whether the modifier is applied at all.
private struct RowMenu<Menu: View>: ViewModifier {
    let isEnabled: Bool
    @ViewBuilder let menu: () -> Menu

    func body(content: Content) -> some View {
        if isEnabled {
            content.contextMenu { menu() }
        } else {
            content
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
    /// Whether a list or tag filter is also narrowing the list. Without it, "All Done!"
    /// would claim every todo is finished when in fact one list is simply empty.
    let isNarrowed: Bool
    /// Whether there are no todos at all. Read before the filter, which since it defaults
    /// to incomplete would otherwise greet a brand-new install with "All Done!".
    let isStoreEmpty: Bool
    @Environment(NavigationModel.self) private var navigationModel

    /// Whether nothing but an empty store explains the empty list, which is the one case
    /// worth offering the create action in.
    private var isFirstRun: Bool {
        isStoreEmpty && searchText.isEmpty && !isNarrowed
    }

    var body: some View {
        let content = emptyContent
        ContentUnavailableView {
            Label(content.title, systemImage: content.icon)
        } description: {
            Text(content.description)
        } actions: {
            if isFirstRun {
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
        if isNarrowed {
            return EmptyContent(
                title: .copy("Nothing Here"),
                icon: "line.3.horizontal.decrease.circle",
                description: .copy("No todos match the list or tag you picked.")
            )
        }
        if isFirstRun {
            return EmptyContent(
                title: .copy("No Todos"),
                icon: "checklist",
                description: .copy("Tap + to add your first todo.")
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
    @Binding var columnVisibility: NavigationSplitViewVisibility
    /// Supplies the list and tag choices. `nil` before the first read, which hides those
    /// submenus rather than showing empty ones.
    let organize: TodoOrganizeSnapshot?
    /// `false` when the detail column is showing the create action instead.
    let includesAddTodo: Bool
    @Environment(NavigationModel.self) private var navigationModel

    /// `.topBarTrailing` does not exist on macOS.
    private var optionsPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarTrailing
        #endif
    }

    /// The lists button sits at the leading edge, where "go up a level" is read.
    private var listsPlacement: ToolbarItemPlacement {
        #if os(macOS)
        .automatic
        #else
        .topBarLeading
        #endif
    }

    var body: some ToolbarContent {
        #if os(macOS)
        // First item of the sidebar's toolbar section, so it sits right after the
        // window controls — the one spot that stays put when the sidebar collapses and
        // the section reflows to the window's leading edge. (`.navigation` would land
        // it ahead of the title in the *detail* section, which does move.)
        ToolbarItem(placement: .automatic) {
            Button {
                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
            } label: {
                Image(systemName: "sidebar.leading")
            }
            .help(.copy("Show or hide the sidebar"))
            .accessibilityIdentifier("sidebarToggleButton")
            .accessibilityLabel(.copy("Show or hide the sidebar"))
        }
        #endif

        // Browsing by list is its own screen, not another row in the menu: picking a
        // list changes *what* you are looking at, and the title changes with it. Editing the
        // lists themselves stays in Settings.
        ToolbarItem(placement: listsPlacement) {
            NavigationLink {
                TodoListsBrowseView(selection: $viewModel.listFilter)
            } label: {
                Label(.copy("Lists"), systemImage: "folder")
                    .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("browseListsButton")
        }

        // At regular width the detail column carries a prominent button instead — see
        // `TodoListView.addsTodoFromDetail`.
        if includesAddTodo {
            ToolbarItem(placement: .primaryAction) {
                AddTodoButton()
            }
        }

        // One menu for everything that is not creating a todo or changing lists. Four
        // separate controls did not fit the list column's bar: the system moved them
        // into its own overflow menu and squeezed out the title.
        ToolbarItem(placement: optionsPlacement) {
            Menu {
                FilterPicker(selection: $viewModel.filter)
                if let organize, !organize.tags.isEmpty {
                    Menu(.copy("Tag")) {
                        TagFilterPicker(selection: $viewModel.tagFilter, tags: organize.tags)
                    }
                }
                Divider()
                Menu(.copy("Sort")) {
                    SortPicker(selection: $viewModel.sortOrder)
                }
                #if os(iOS)
                Divider()
                // `SettingsView` is not built on macOS (no `ShortcutsLink` there), so
                // this row is iOS-only; the Mac has it in the app menu.
                Button {
                    showingSettings = true
                } label: {
                    Label(.copy("Settings"), systemImage: "gearshape")
                }
                .accessibilityIdentifier("settingsButton")
                #endif
            } label: {
                // Filled while something is narrowing the list, so an accidental filter is
                // visible from the toolbar rather than only from inside the menu.
                Label(
                    .copy("More"),
                    systemImage: viewModel.isNarrowed
                        ? "ellipsis.circle.fill"
                        : "ellipsis.circle"
                )
                .labelStyle(.iconOnly)
            }
            .accessibilityIdentifier("filterSortMenu")
        }
    }

}

#if os(iOS)
/// The create action as a prominent button in the detail column's trailing bottom
/// corner, the way Reminders presents "New Reminder". Used where the list column's bar
/// has no room for another item and the column itself can be closed.
private struct ProminentAddTodoButton: View {
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        Button {
            navigationModel.showAddTodo()
        } label: {
            // Icon only: the button floats over the detail content, and `+` needs no
            // gloss next to a list of todos. The label is still there for VoiceOver.
            Label(.copy("Add Todo"), systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.circle)
        .controlSize(.extraLarge)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
        .accessibilityIdentifier("addTodoButton")
    }
}
#endif

/// The create action as a bar button, for widths where the bar has room for it.
private struct AddTodoButton: View {
    @Environment(NavigationModel.self) private var navigationModel

    var body: some View {
        Button {
            navigationModel.showAddTodo()
        } label: {
            // `Label`, not a bare `Image`: an item the overflow menu cannot title is
            // dropped from it, so an icon-only button vanishes outright once the bar
            // runs short rather than moving into the menu.
            Label(.copy("Add todo"), systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .accessibilityIdentifier("addTodoButton")
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
        // Opens at half height and grows to full height when dragged up — the form
        // scrolls only after it reaches `.large`.
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
}

// MARK: - Preview

#Preview {
    TodoListView()
        .environment(NavigationModel())
}
