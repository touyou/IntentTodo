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
        createdAt: Date = Date()
    ) -> TodoAppEntity {
        TodoAppEntity(
            id: id,
            title: title,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDate,
            createdAt: createdAt
        )
    }

    // MARK: - Initial State Tests

    @Test("Initial state has empty todos and default values")
    func initialState() {
        let viewModel = TodoListViewModel()

        #expect(viewModel.todos.isEmpty)
        #expect(!viewModel.isLoading)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.filter == .all)
        #expect(viewModel.sortOrder == .createdAtDescending)
        #expect(viewModel.searchText.isEmpty)
    }

    // MARK: - Todo Management Tests

    @Test("addTodo adds entity to todos array")
    func addTodo() {
        let viewModel = TodoListViewModel()
        let todo = makeTodo(title: "New Todo")

        viewModel.addTodo(todo)

        #expect(viewModel.todos.count == 1)
        #expect(viewModel.todos.first?.title == "New Todo")
    }

    @Test("updateTodo updates existing entity")
    func updateTodo() {
        let viewModel = TodoListViewModel()
        let id = UUID().uuidString
        let original = makeTodo(id: id, title: "Original", isCompleted: false)
        viewModel.addTodo(original)

        let updated = TodoAppEntity(
            id: id,
            title: "Updated",
            isCompleted: true,
            isFavorite: false
        )
        viewModel.updateTodo(updated)

        #expect(viewModel.todos.count == 1)
        #expect(viewModel.todos.first?.title == "Updated")
        #expect(viewModel.todos.first?.isCompleted == true)
    }

    @Test("updateTodo does nothing for non-existent entity")
    func updateNonExistentTodo() {
        let viewModel = TodoListViewModel()
        let todo = makeTodo(title: "Existing")
        viewModel.addTodo(todo)

        let nonExistent = makeTodo(id: "non-existent", title: "Non-existent")
        viewModel.updateTodo(nonExistent)

        #expect(viewModel.todos.count == 1)
        #expect(viewModel.todos.first?.title == "Existing")
    }

    @Test("removeTodo removes entity from todos array")
    func removeTodo() {
        let viewModel = TodoListViewModel()
        let todo = makeTodo(title: "To Remove")
        viewModel.addTodo(todo)
        #expect(viewModel.todos.count == 1)

        viewModel.removeTodo(todo)

        #expect(viewModel.todos.isEmpty)
    }

    @Test("removeTodo does nothing for non-existent entity")
    func removeNonExistentTodo() {
        let viewModel = TodoListViewModel()
        let todo = makeTodo(title: "Existing")
        viewModel.addTodo(todo)

        let nonExistent = makeTodo(id: "non-existent", title: "Non-existent")
        viewModel.removeTodo(nonExistent)

        #expect(viewModel.todos.count == 1)
    }

    // MARK: - Filter Tests

    @Test("Filter all shows all todos")
    func filterAll() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(isCompleted: false))
        viewModel.addTodo(makeTodo(isCompleted: true))
        viewModel.addTodo(makeTodo(isFavorite: true))

        viewModel.filter = .all

        #expect(viewModel.filteredTodos.count == 3)
    }

    @Test("Filter incomplete shows only incomplete todos")
    func filterIncomplete() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Incomplete", isCompleted: false))
        viewModel.addTodo(makeTodo(title: "Completed", isCompleted: true))

        viewModel.filter = .incomplete

        #expect(viewModel.filteredTodos.count == 1)
        #expect(viewModel.filteredTodos.first?.title == "Incomplete")
    }

    @Test("Filter completed shows only completed todos")
    func filterCompleted() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Incomplete", isCompleted: false))
        viewModel.addTodo(makeTodo(title: "Completed", isCompleted: true))

        viewModel.filter = .completed

        #expect(viewModel.filteredTodos.count == 1)
        #expect(viewModel.filteredTodos.first?.title == "Completed")
    }

    @Test("Filter favorites shows only favorite todos")
    func filterFavorites() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Regular", isFavorite: false))
        viewModel.addTodo(makeTodo(title: "Favorite", isFavorite: true))

        viewModel.filter = .favorites

        #expect(viewModel.filteredTodos.count == 1)
        #expect(viewModel.filteredTodos.first?.title == "Favorite")
    }

    // MARK: - Search Tests

    @Test("Search filters todos by title")
    func searchByTitle() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Buy groceries"))
        viewModel.addTodo(makeTodo(title: "Call mom"))
        viewModel.addTodo(makeTodo(title: "Buy milk"))

        viewModel.searchText = "Buy"

        #expect(viewModel.filteredTodos.count == 2)
    }

    @Test("Search is case insensitive")
    func searchCaseInsensitive() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Buy GROCERIES"))
        viewModel.addTodo(makeTodo(title: "Call mom"))

        viewModel.searchText = "groceries"

        #expect(viewModel.filteredTodos.count == 1)
        #expect(viewModel.filteredTodos.first?.title == "Buy GROCERIES")
    }

    @Test("Search combined with filter")
    func searchWithFilter() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Buy groceries", isCompleted: false))
        viewModel.addTodo(makeTodo(title: "Buy milk", isCompleted: true))
        viewModel.addTodo(makeTodo(title: "Call mom", isCompleted: false))

        viewModel.searchText = "Buy"
        viewModel.filter = .incomplete

        #expect(viewModel.filteredTodos.count == 1)
        #expect(viewModel.filteredTodos.first?.title == "Buy groceries")
    }

    @Test("Empty search shows all todos for current filter")
    func emptySearch() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Todo 1"))
        viewModel.addTodo(makeTodo(title: "Todo 2"))

        viewModel.searchText = ""

        #expect(viewModel.filteredTodos.count == 2)
    }

    // MARK: - Sort Tests

    @Test("Sort by created date descending")
    func sortCreatedAtDescending() {
        let viewModel = TodoListViewModel()
        let date1 = Date().addingTimeInterval(-3600)
        let date2 = Date().addingTimeInterval(-1800)
        let date3 = Date()

        viewModel.addTodo(makeTodo(title: "Old", createdAt: date1))
        viewModel.addTodo(makeTodo(title: "Newest", createdAt: date3))
        viewModel.addTodo(makeTodo(title: "Middle", createdAt: date2))

        viewModel.sortOrder = .createdAtDescending

        #expect(viewModel.filteredTodos[0].title == "Newest")
        #expect(viewModel.filteredTodos[1].title == "Middle")
        #expect(viewModel.filteredTodos[2].title == "Old")
    }

    @Test("Sort by created date ascending")
    func sortCreatedAtAscending() {
        let viewModel = TodoListViewModel()
        let date1 = Date().addingTimeInterval(-3600)
        let date2 = Date().addingTimeInterval(-1800)
        let date3 = Date()

        viewModel.addTodo(makeTodo(title: "Old", createdAt: date1))
        viewModel.addTodo(makeTodo(title: "Newest", createdAt: date3))
        viewModel.addTodo(makeTodo(title: "Middle", createdAt: date2))

        viewModel.sortOrder = .createdAtAscending

        #expect(viewModel.filteredTodos[0].title == "Old")
        #expect(viewModel.filteredTodos[1].title == "Middle")
        #expect(viewModel.filteredTodos[2].title == "Newest")
    }

    @Test("Sort by title ascending")
    func sortTitleAscending() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Zebra"))
        viewModel.addTodo(makeTodo(title: "Apple"))
        viewModel.addTodo(makeTodo(title: "Mango"))

        viewModel.sortOrder = .titleAscending

        #expect(viewModel.filteredTodos[0].title == "Apple")
        #expect(viewModel.filteredTodos[1].title == "Mango")
        #expect(viewModel.filteredTodos[2].title == "Zebra")
    }

    @Test("Sort by title descending")
    func sortTitleDescending() {
        let viewModel = TodoListViewModel()
        viewModel.addTodo(makeTodo(title: "Zebra"))
        viewModel.addTodo(makeTodo(title: "Apple"))
        viewModel.addTodo(makeTodo(title: "Mango"))

        viewModel.sortOrder = .titleDescending

        #expect(viewModel.filteredTodos[0].title == "Zebra")
        #expect(viewModel.filteredTodos[1].title == "Mango")
        #expect(viewModel.filteredTodos[2].title == "Apple")
    }

    @Test("Sort by due date with nil dates at end")
    func sortDueDateAscending() {
        let viewModel = TodoListViewModel()
        let tomorrow = Date().addingTimeInterval(86400)
        let nextWeek = Date().addingTimeInterval(604800)

        viewModel.addTodo(makeTodo(title: "No date", dueDate: nil))
        viewModel.addTodo(makeTodo(title: "Next week", dueDate: nextWeek))
        viewModel.addTodo(makeTodo(title: "Tomorrow", dueDate: tomorrow))

        viewModel.sortOrder = .dueDateAscending

        #expect(viewModel.filteredTodos[0].title == "Tomorrow")
        #expect(viewModel.filteredTodos[1].title == "Next week")
        #expect(viewModel.filteredTodos[2].title == "No date")
    }

    // MARK: - Error Handling Tests

    @Test("clearError sets errorMessage to nil")
    func clearError() {
        let viewModel = TodoListViewModel()
        viewModel.errorMessage = "Some error"

        viewModel.clearError()

        #expect(viewModel.errorMessage == nil)
    }
}
