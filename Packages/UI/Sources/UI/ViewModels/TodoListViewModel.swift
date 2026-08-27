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
    ///   - focusFilter: 集中モードの絞り込み。ユーザーが選んだフィルタより前に効く
    ///     （システム側の制約なので、UI のフィルタで広げ直せてはいけない）。
    ///     既定は `.inactive` で、Focus を使っていない環境では従来どおり素通し。
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
        // 突き合わせは `localizedStandardContains(_:)`（`TodoEntityQuery` と同じ）。
        // `lowercased().contains()` はロケール非依存で、かな/カナやダイアクリティカル
        // マークを別物として扱ってしまう。
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
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: true) }
        case .dueDateDescending:
            return todos.sorted { compareDueDates($0.dueDate, $1.dueDate, ascending: false) }
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

    /// 期限なしは昇順・降順のどちらでも**末尾**に置く。
    ///
    /// 「日付の大小」ではなく「日付があるものを先に見せる」という並びなので、
    /// nil の位置は `ascending` で反転させない（反転させると降順のときだけ
    /// 期限なしが先頭に来る）。
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

    /// メニュー表示用の文言。`String` で返すと `Label` / `Text` が verbatim 初期化子を
    /// 選び、リテラルが String Catalog に抽出されない。
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

    /// メニュー表示用の文言。型の理由は `TodoFilter.displayName` と同じ。
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
