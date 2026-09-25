//
//  TodoListViewModel.swift
//  IntentTodo
//

import Foundation
import TodoAppIntents

/// View model for the todo list view.
///
/// This view model manages **UI state only** (filter, sort, search).
/// Business logic (CRUD operations) is handled by App Intents.
///
/// ## Responsibilities
/// - Filter state management
/// - Sort order management
/// - Search text management
/// - Filtering and sorting logic (UI-specific, not used by Siri/Shortcuts)
@MainActor
@Observable
public final class TodoListViewModel {
    // MARK: - Defaults

    /// The filter a list opens with.
    ///
    /// Incomplete rather than `.all`: a completed todo has no action left on it, so a list
    /// that keeps every one of them forever ends up mostly history. `.all` and `.completed`
    /// stay in the options menu, and a todo that was just ticked off lingers for
    /// ``completionGracePeriod`` so the tap still has somewhere to land.
    public static let defaultFilter: TodoFilter = .incomplete

    /// How long a just-completed todo stays on screen while the list is hiding completed
    /// todos.
    ///
    /// Filling the checkbox and striking the title through is the only feedback the tap
    /// gives, so the row must not leave on the same frame — long enough to read, short
    /// enough that "completed todos are put away" stays true.
    public static let completionGracePeriod: TimeInterval = 3

    // MARK: - UI State

    /// Current filter for the todo list.
    public var filter: TodoFilter = TodoListViewModel.defaultFilter

    /// Current sort order for the todo list.
    public var sortOrder: TodoSortOrder = .createdAtDescending

    /// Search text for filtering todos.
    public var searchText = ""

    /// Which list the todos have to belong to.
    public var listFilter: TodoListFilter = .all

    /// Which tag the todos have to carry, or `nil` for any.
    ///
    /// Held as the tag's stored spelling, which is what `TodoOrganizeSnapshot` keys by.
    public var tagFilter: String?

    /// Whether a list or tag filter is narrowing the list.
    ///
    /// Read by the empty state, which otherwise reports "All Done!" for a list that merely
    /// has nothing in it.
    public var isNarrowedByListOrTag: Bool {
        listFilter != .all || tagFilter != nil
    }

    /// Whether the list is showing anything other than its default view.
    ///
    /// Compared against ``defaultFilter``, not `.all`: the filter the list opens with is
    /// not a choice the person made, and marking it as active would leave the options
    /// button looking filled on every launch.
    public var isNarrowed: Bool {
        filter != Self.defaultFilter || isNarrowedByListOrTag || !searchText.isEmpty
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Filtering & Sorting

    /// Filters and sorts todos based on current UI state.
    ///
    /// This logic is UI-specific and not exposed to Siri/Shortcuts.
    /// - Parameters:
    ///   - todos: The source todos to filter and sort.
    ///   - focusFilter: applied before the person's own filter, since a system constraint
    ///     must not be wideable from the UI. Defaults to `.inactive`.
    ///   - organize: list and tag memberships, for the tag filter and for matching a
    ///     search term against tags. Tags are not carried on `TodoAppEntity` (they are a
    ///     `@DeferredProperty`, because reading the model's array can trap), so the
    ///     membership has to come from a snapshot that was *fetched*. `nil` drops the tag
    ///     filter rather than silently filtering everything out.
    ///   - now: the clock the post-completion grace period is measured against. Passed in
    ///     so the list can re-evaluate a grace period that has run out, and so tests do
    ///     not depend on the wall clock.
    /// - Returns: Filtered and sorted todos.
    public func filteredTodos(
        from todos: [TodoAppEntity],
        focusFilter: TodoFocusFilter = .inactive,
        organize: TodoOrganizeSnapshot? = nil,
        now: Date = Date()
    ) -> [TodoAppEntity] {
        var result = focusFilter.apply(to: todos)

        // Apply filter
        switch filter {
        case .all:
            break
        case .incomplete:
            result = result.filter { !$0.isCompleted || isWithinCompletionGrace($0, now: now) }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        switch listFilter {
        case .all:
            break
        case .uncategorized:
            result = result.filter { $0.category == nil }
        case .list(let id):
            result = result.filter { $0.category?.id == id }
        }

        if let tagFilter, let organize {
            let tagged = organize.todoIDs(withTag: tagFilter)
            result = result.filter { tagged.contains($0.id) }
        }

        // Apply search
        // `localizedStandardContains(_:)`, as in the entity queries: `lowercased()` plus
        // `contains` is locale-independent and treats kana forms and diacritics as
        // different characters.
        if !searchText.isEmpty {
            // A term is matched against everything a person can see on a todo, not just the
            // title: typing a list or tag name and getting nothing back reads as "search is
            // broken" rather than "search only looks at titles".
            let taggedMatches = organize.map { taggedIDs(matching: searchText, in: $0) } ?? []
            result = result.filter { todo in
                todo.title.localizedStandardContains(searchText)
                    || todo.todoDescription?.localizedStandardContains(searchText) == true
                    || todo.category?.name.localizedStandardContains(searchText) == true
                    || taggedMatches.contains(todo.id)
            }
        }

        // Apply sort
        return sortTodos(result, by: sortOrder)
    }

    // MARK: - Completion Grace Period

    /// When the earliest grace period still in effect runs out, or `nil` when no todo is
    /// inside one.
    ///
    /// Nothing in the store changes at that moment, so the row would sit there until the
    /// next edit; the list schedules a wake-up on this instead.
    ///
    /// - Parameter todos: the todos currently on screen, which already include the ones
    ///   the grace period is keeping there.
    public func nextCompletionGraceExpiry(
        in todos: [TodoAppEntity],
        now: Date = Date()
    ) -> Date? {
        guard filter == .incomplete else { return nil }
        return todos
            .filter { $0.isCompleted && isWithinCompletionGrace($0, now: now) }
            .compactMap { $0.completionDate?.addingTimeInterval(Self.completionGracePeriod) }
            .min()
    }

    /// Whether `todo` was completed recently enough for the incomplete filter to keep
    /// showing it.
    ///
    /// A completed todo with no completion date counts as long done: every path that
    /// writes `isCompleted` stamps the date alongside it, so a missing one means the row
    /// predates that or came back from a restored snapshot.
    private func isWithinCompletionGrace(_ todo: TodoAppEntity, now: Date) -> Bool {
        guard let completionDate = todo.completionDate else { return false }
        return now.timeIntervalSince(completionDate) < Self.completionGracePeriod
    }

    // MARK: - Manual Order

    /// Splices a drag that happened in a *narrowed* list back into the full manual order.
    ///
    /// The person can only drag what they can see, so the todos a filter is hiding keep
    /// the slots they already hold: only the visible positions are rewritten, in the order
    /// the drag produced. Handing the visible ids straight to
    /// `TodoService.reorderTodos(orderedIDs:)` would instead number them 0..n across the
    /// whole store and collide with every hidden todo's index.
    ///
    /// - Parameters:
    ///   - orderedVisibleIDs: the dragged list's ids, in their new order.
    ///   - todos: every todo in the store.
    /// - Returns: every id, in the order to persist.
    public func manualOrder(
        applying orderedVisibleIDs: [String],
        to todos: [TodoAppEntity]
    ) -> [String] {
        let visible = Set(orderedVisibleIDs)
        var dragged = orderedVisibleIDs.makeIterator()
        return sortTodos(todos, by: .manual).map { todo in
            guard visible.contains(todo.id), let next = dragged.next() else { return todo.id }
            return next
        }
    }

    /// Ids of the todos whose tags match `term`.
    private func taggedIDs(matching term: String, in organize: TodoOrganizeSnapshot) -> Set<String> {
        organize.todoIDsByTag.reduce(into: Set<String>()) { result, entry in
            guard entry.key.localizedStandardContains(term) else { return }
            result.formUnion(entry.value)
        }
    }

    // MARK: - Statistics

    /// Number of incomplete todos.
    public func incompleteCount(from todos: [TodoAppEntity]) -> Int {
        todos.filter { !$0.isCompleted }.count
    }

    /// Number of favorite todos.
    public func favoriteCount(from todos: [TodoAppEntity]) -> Int {
        todos.filter { $0.isFavorite }.count
    }

    // MARK: - Private Helpers

    private func sortTodos(_ todos: [TodoAppEntity], by order: TodoSortOrder) -> [TodoAppEntity] {
        switch order {
        case .createdAtDescending:
            return todos.sorted { $0.createdAt > $1.createdAt }
        case .createdAtAscending:
            return todos.sorted { $0.createdAt < $1.createdAt }
        case .titleAscending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedAscending }
        case .titleDescending:
            return todos.sorted { $0.title.localizedCompare($1.title) == .orderedDescending }
        case .dueDateAscending:
            return todos.sorted { compareDueDates($0.dueDateValue, $1.dueDateValue, ascending: true) }
        case .dueDateDescending:
            return todos.sorted { compareDueDates($0.dueDateValue, $1.dueDateValue, ascending: false) }
        case .manual:
            // Drag-to-reorder order, persisted on the model as `sortIndex`.
            // Ties (e.g. brand-new todos still at 0) fall back to newest-first.
            return todos.sorted {
                $0.sortIndex != $1.sortIndex
                    ? $0.sortIndex < $1.sortIndex
                    : $0.createdAt > $1.createdAt
            }
        }
    }

    /// Todos without a due date sort **last** in both directions: the intent is "dated
    /// first", not "compare dates", so the nil position does not follow `ascending`.
    private func compareDueDates(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return false
        case (nil, _):
            return false
        case (_, nil):
            return true
        case let (date1?, date2?):
            return ascending ? date1 < date2 : date1 > date2
        }
    }
}

// MARK: - Supporting Types

/// Which list the todo list is narrowed to.
///
/// A separate axis from ``TodoFilter``, which is about state (completed, favourite): the two
/// combine, so "incomplete todos in Work" is expressible.
public enum TodoListFilter: Hashable, Sendable {
    case all
    /// Todos with no list at all — what `CategoryAppEntity.uncategorized` stands for.
    case uncategorized
    /// A stored list, by `CategoryAppEntity.id`.
    case list(id: String)
}

/// Filter options for the todo list.
public enum TodoFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case incomplete
    case completed
    case favorites

    public var id: String { rawValue }

    /// A `String` here would make `Label` and `Text` pick their verbatim initialisers,
    /// leaving the literals out of the String Catalog.
    public var displayName: LocalizedStringResource {
        switch self {
        case .all: return .copy("All")
        case .incomplete: return .copy("Incomplete")
        case .completed: return .copy("Completed")
        case .favorites: return .copy("Favorites")
        }
    }

    public var systemImage: String {
        switch self {
        case .all: return "list.bullet"
        case .incomplete: return "circle"
        case .completed: return "checkmark.circle"
        case .favorites: return "star"
        }
    }

    /// Bridges the intent-facing filter (`TodoFilterType`, which Siri / Shortcuts
    /// and `LaunchAppIntent` speak) to this UI-only filter. The two enums are kept
    /// separate because this one also carries presentation details (display name,
    /// symbol) that don't belong in the intents layer.
    public init(_ filterType: TodoFilterType) {
        switch filterType {
        case .all: self = .all
        case .incomplete: self = .incomplete
        case .completed: self = .completed
        case .favorites: self = .favorites
        }
    }
}

/// Sort options for the todo list.
public enum TodoSortOrder: String, CaseIterable, Identifiable, Sendable {
    case createdAtDescending
    case createdAtAscending
    case titleAscending
    case titleDescending
    case dueDateAscending
    case dueDateDescending
    /// User's drag-to-reorder order (persisted as `TodoItem.sortIndex`). Enables
    /// the reorderable list (WWDC 2026, iOS/macOS/visionOS 27+).
    case manual

    public var id: String { rawValue }

    /// Typed as in `TodoFilter.displayName`, for the same reason.
    public var displayName: LocalizedStringResource {
        switch self {
        case .createdAtDescending: return .copy("Newest First")
        case .createdAtAscending: return .copy("Oldest First")
        case .titleAscending: return .copy("Title A-Z")
        case .titleDescending: return .copy("Title Z-A")
        case .dueDateAscending: return .copy("Due Date (Earliest)")
        case .dueDateDescending: return .copy("Due Date (Latest)")
        case .manual: return .copy("Manual")
        }
    }
}
