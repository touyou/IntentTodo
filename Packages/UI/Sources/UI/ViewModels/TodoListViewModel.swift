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
    // MARK: - UI State

    /// Current filter for the todo list.
    public var filter: TodoFilter = .all

    /// Current sort order for the todo list.
    public var sortOrder: TodoSortOrder = .createdAtDescending

    /// Search text for filtering todos.
    public var searchText = ""

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
    /// - Returns: Filtered and sorted todos.
    public func filteredTodos(
        from todos: [TodoAppEntity],
        focusFilter: TodoFocusFilter = .inactive
    ) -> [TodoAppEntity] {
        var result = focusFilter.apply(to: todos)

        // Apply filter
        switch filter {
        case .all:
            break
        case .incomplete:
            result = result.filter { !$0.isCompleted }
        case .completed:
            result = result.filter { $0.isCompleted }
        case .favorites:
            result = result.filter { $0.isFavorite }
        }

        // Apply search
        // `localizedStandardContains(_:)`, as in the entity queries: `lowercased()` plus
        // `contains` is locale-independent and treats kana forms and diacritics as
        // different characters.
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedStandardContains(searchText) }
        }

        // Apply sort
        return sortTodos(result, by: sortOrder)
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
