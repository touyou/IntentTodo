//
//  TodoListViewModelTests.swift
//  IntentTodo
//

import Foundation
import Testing
import TodoAppIntents
@testable import UI

@MainActor
@Suite("TodoListViewModel Tests")
struct TodoListViewModelTests {
    // MARK: - Helpers

    private func makeTodo(
        id: String = UUID().uuidString,
        title: String = "Test Todo",
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortIndex: Int = 0
    ) -> TodoAppEntity {
        TodoAppEntity(
            id: id,
            title: title,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDate,
            createdAt: createdAt,
            sortIndex: sortIndex
        )
    }

    // MARK: - Initial State Tests

    @Test("Initial state has default values")
    func initialState() {
        let viewModel = TodoListViewModel()

        #expect(viewModel.filter == .all)
        #expect(viewModel.sortOrder == .createdAtDescending)
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Filter Tests

    @Test("Filter all shows all todos")
    func filterAll() {
        let viewModel = TodoListViewModel()
        viewModel.filter = .all

        let todos = [
            makeTodo(isCompleted: false),
            makeTodo(isCompleted: true),
            makeTodo(isFavorite: true),
        ]

        #expect(viewModel.filteredTodos(from: todos).count == 3)
    }

    @Test("Filter incomplete shows only incomplete todos")
    func filterIncomplete() {
        let viewModel = TodoListViewModel()
        viewModel.filter = .incomplete

        let todos = [
            makeTodo(title: "Incomplete", isCompleted: false),
            makeTodo(title: "Completed", isCompleted: true),
        ]

        let filtered = viewModel.filteredTodos(from: todos)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Incomplete")
    }

    @Test("Filter completed shows only completed todos")
    func filterCompleted() {
        let viewModel = TodoListViewModel()
        viewModel.filter = .completed

        let todos = [
            makeTodo(title: "Incomplete", isCompleted: false),
            makeTodo(title: "Completed", isCompleted: true),
        ]

        let filtered = viewModel.filteredTodos(from: todos)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Completed")
    }

    @Test("Filter favorites shows only favorite todos")
    func filterFavorites() {
        let viewModel = TodoListViewModel()
        viewModel.filter = .favorites

        let todos = [
            makeTodo(title: "Regular", isFavorite: false),
            makeTodo(title: "Favorite", isFavorite: true),
        ]

        let filtered = viewModel.filteredTodos(from: todos)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Favorite")
    }

    // MARK: - Search Tests

    @Test("Search filters todos by title")
    func searchByTitle() {
        let viewModel = TodoListViewModel()
        viewModel.searchText = "Buy"

        let todos = [
            makeTodo(title: "Buy groceries"),
            makeTodo(title: "Call mom"),
            makeTodo(title: "Buy milk"),
        ]

        #expect(viewModel.filteredTodos(from: todos).count == 2)
    }

    @Test("Search is case insensitive")
    func searchCaseInsensitive() {
        let viewModel = TodoListViewModel()
        viewModel.searchText = "groceries"

        let todos = [
            makeTodo(title: "Buy GROCERIES"),
            makeTodo(title: "Call mom"),
        ]

        let filtered = viewModel.filteredTodos(from: todos)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Buy GROCERIES")
    }

    @Test("Search combined with filter")
    func searchWithFilter() {
        let viewModel = TodoListViewModel()
        viewModel.searchText = "Buy"
        viewModel.filter = .incomplete

        let todos = [
            makeTodo(title: "Buy groceries", isCompleted: false),
            makeTodo(title: "Buy milk", isCompleted: true),
            makeTodo(title: "Call mom", isCompleted: false),
        ]

        let filtered = viewModel.filteredTodos(from: todos)
        #expect(filtered.count == 1)
        #expect(filtered.first?.title == "Buy groceries")
    }

    @Test("Empty search shows all todos for current filter")
    func emptySearch() {
        let viewModel = TodoListViewModel()
        viewModel.searchText = ""

        let todos = [
            makeTodo(title: "Todo 1"),
            makeTodo(title: "Todo 2"),
        ]

        #expect(viewModel.filteredTodos(from: todos).count == 2)
    }

    // MARK: - Sort Tests

    @Test("Sort by created date descending")
    func sortCreatedAtDescending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .createdAtDescending

        let date1 = Date().addingTimeInterval(-3600)
        let date2 = Date().addingTimeInterval(-1800)
        let date3 = Date()

        let todos = [
            makeTodo(title: "Old", createdAt: date1),
            makeTodo(title: "Newest", createdAt: date3),
            makeTodo(title: "Middle", createdAt: date2),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Newest")
        #expect(sorted[1].title == "Middle")
        #expect(sorted[2].title == "Old")
    }

    @Test("Sort by created date ascending")
    func sortCreatedAtAscending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .createdAtAscending

        let date1 = Date().addingTimeInterval(-3600)
        let date2 = Date().addingTimeInterval(-1800)
        let date3 = Date()

        let todos = [
            makeTodo(title: "Old", createdAt: date1),
            makeTodo(title: "Newest", createdAt: date3),
            makeTodo(title: "Middle", createdAt: date2),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Old")
        #expect(sorted[1].title == "Middle")
        #expect(sorted[2].title == "Newest")
    }

    @Test("Sort by title ascending")
    func sortTitleAscending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .titleAscending

        let todos = [
            makeTodo(title: "Zebra"),
            makeTodo(title: "Apple"),
            makeTodo(title: "Mango"),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Apple")
        #expect(sorted[1].title == "Mango")
        #expect(sorted[2].title == "Zebra")
    }

    @Test("Sort by title descending")
    func sortTitleDescending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .titleDescending

        let todos = [
            makeTodo(title: "Zebra"),
            makeTodo(title: "Apple"),
            makeTodo(title: "Mango"),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Zebra")
        #expect(sorted[1].title == "Mango")
        #expect(sorted[2].title == "Apple")
    }

    @Test("Sort by due date ascending with nil dates at end")
    func sortDueDateAscending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .dueDateAscending

        let tomorrow = Date().addingTimeInterval(86400)
        let nextWeek = Date().addingTimeInterval(604800)

        let todos = [
            makeTodo(title: "No date", dueDate: nil),
            makeTodo(title: "Next week", dueDate: nextWeek),
            makeTodo(title: "Tomorrow", dueDate: tomorrow),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Tomorrow")
        #expect(sorted[1].title == "Next week")
        #expect(sorted[2].title == "No date")
    }

    @Test("Sort by due date descending with nil dates at end")
    func sortDueDateDescending() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .dueDateDescending

        let tomorrow = Date().addingTimeInterval(86400)
        let nextWeek = Date().addingTimeInterval(604800)

        let todos = [
            makeTodo(title: "No date", dueDate: nil),
            makeTodo(title: "Next week", dueDate: nextWeek),
            makeTodo(title: "Tomorrow", dueDate: tomorrow),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted[0].title == "Next week")
        #expect(sorted[1].title == "Tomorrow")
        #expect(sorted[2].title == "No date")
    }

    @Test("Manual sort orders by sortIndex ascending (drag-to-reorder)")
    func sortManualBySortIndex() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .manual

        let todos = [
            makeTodo(title: "Third", sortIndex: 2),
            makeTodo(title: "First", sortIndex: 0),
            makeTodo(title: "Second", sortIndex: 1),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted.map(\.title) == ["First", "Second", "Third"])
    }

    @Test("Manual sort breaks sortIndex ties by newest first")
    func sortManualTieBreaksByCreatedAt() {
        let viewModel = TodoListViewModel()
        viewModel.sortOrder = .manual

        let older = Date().addingTimeInterval(-1000)
        let newer = Date()

        // Both brand-new todos share the default sortIndex 0.
        let todos = [
            makeTodo(title: "Older", createdAt: older, sortIndex: 0),
            makeTodo(title: "Newer", createdAt: newer, sortIndex: 0),
        ]

        let sorted = viewModel.filteredTodos(from: todos)
        #expect(sorted.map(\.title) == ["Newer", "Older"])
    }

    // MARK: - Statistics Tests

    @Test("incompleteCount returns count of incomplete todos")
    func incompleteCount() {
        let viewModel = TodoListViewModel()

        let todos = [
            makeTodo(isCompleted: false),
            makeTodo(isCompleted: true),
            makeTodo(isCompleted: false),
        ]

        #expect(viewModel.incompleteCount(from: todos) == 2)
    }

    @Test("incompleteCount returns 0 when all completed")
    func incompleteCountAllCompleted() {
        let viewModel = TodoListViewModel()

        let todos = [
            makeTodo(isCompleted: true),
            makeTodo(isCompleted: true),
        ]

        #expect(viewModel.incompleteCount(from: todos) == 0)
    }

    @Test("favoriteCount returns count of favorite todos")
    func favoriteCount() {
        let viewModel = TodoListViewModel()

        let todos = [
            makeTodo(isFavorite: true),
            makeTodo(isFavorite: false),
            makeTodo(isFavorite: true),
        ]

        #expect(viewModel.favoriteCount(from: todos) == 2)
    }

    @Test("favoriteCount returns 0 when no favorites")
    func favoriteCountNone() {
        let viewModel = TodoListViewModel()

        let todos = [
            makeTodo(isFavorite: false),
            makeTodo(isFavorite: false),
        ]

        #expect(viewModel.favoriteCount(from: todos) == 0)
    }

    @Test("Empty todos returns empty filtered result")
    func emptyTodos() {
        let viewModel = TodoListViewModel()

        #expect(viewModel.filteredTodos(from: []).isEmpty)
        #expect(viewModel.incompleteCount(from: []) == 0)
        #expect(viewModel.favoriteCount(from: []) == 0)
    }
}

// MARK: - TodoFilter Tests

@Suite("TodoFilter Tests")
struct TodoFilterTests {
    @Test("All cases are iterable")
    func allCases() {
        #expect(TodoFilter.allCases.count == 4)
    }

    // `displayName` は `LocalizedStringResource`（パッケージ同梱の String Catalog 参照）。
    // 解決後の文字列で比較する。en では key がそのまま返る。
    @Test("Each filter has a display name")
    func displayNames() {
        #expect(String(localized: TodoFilter.all.displayName) == "All")
        #expect(String(localized: TodoFilter.incomplete.displayName) == "Incomplete")
        #expect(String(localized: TodoFilter.completed.displayName) == "Completed")
        #expect(String(localized: TodoFilter.favorites.displayName) == "Favorites")
    }

    @Test("Each filter has a system image")
    func systemImages() {
        #expect(TodoFilter.all.systemImage == "list.bullet")
        #expect(TodoFilter.incomplete.systemImage == "circle")
        #expect(TodoFilter.completed.systemImage == "checkmark.circle")
        #expect(TodoFilter.favorites.systemImage == "star")
    }

    @Test("Each filter has unique id based on rawValue")
    func identifiable() {
        let ids = TodoFilter.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}

// MARK: - TodoSortOrder Tests

@Suite("TodoSortOrder Tests")
struct TodoSortOrderTests {
    @Test("All cases are iterable")
    func allCases() {
        #expect(TodoSortOrder.allCases.count == 7)
    }

    @Test("Each sort order has a display name")
    func displayNames() {
        #expect(String(localized: TodoSortOrder.createdAtDescending.displayName) == "Newest First")
        #expect(String(localized: TodoSortOrder.createdAtAscending.displayName) == "Oldest First")
        #expect(String(localized: TodoSortOrder.titleAscending.displayName) == "Title A-Z")
        #expect(String(localized: TodoSortOrder.titleDescending.displayName) == "Title Z-A")
        #expect(String(localized: TodoSortOrder.dueDateAscending.displayName) == "Due Date (Earliest)")
        #expect(String(localized: TodoSortOrder.dueDateDescending.displayName) == "Due Date (Latest)")
        #expect(String(localized: TodoSortOrder.manual.displayName) == "Manual")
    }

    @Test("Each sort order has unique id based on rawValue")
    func identifiable() {
        let ids = TodoSortOrder.allCases.map(\.id)
        let uniqueIds = Set(ids)
        #expect(ids.count == uniqueIds.count)
    }
}
