//
//  MockTodoRepositoryTests.swift
//  IntentTodo
//

import Domain
import Foundation
import Testing
@testable import Repository

@Suite("MockTodoRepository Tests")
@MainActor
struct MockTodoRepositoryTests {
    // MARK: - Create Tests

    @Test("Create adds todo to repository")
    func createTodo() throws {
        let repository = MockTodoRepository()
        let todo = TodoItem(title: "Test todo")

        try repository.create(todo)

        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched != nil)
        #expect(fetched?.title == "Test todo")
    }

    // MARK: - Read Tests

    @Test("FetchAll returns all todos")
    func fetchAllTodos() throws {
        let todo1 = TodoItem(title: "Todo 1")
        let todo2 = TodoItem(title: "Todo 2")
        let repository = MockTodoRepository(initialTodos: [todo1, todo2])

        let todos = try repository.fetchAll()

        #expect(todos.count == 2)
    }

    @Test("Fetch by ID returns correct todo")
    func fetchById() throws {
        let todo = TodoItem(title: "Target todo")
        let repository = MockTodoRepository(initialTodos: [todo])

        let fetched = try repository.fetch(by: todo.id)

        #expect(fetched?.id == todo.id)
        #expect(fetched?.title == "Target todo")
    }

    @Test("Fetch by ID returns nil for non-existent todo")
    func fetchByIdNotFound() throws {
        let repository = MockTodoRepository()

        let fetched = try repository.fetch(by: UUID())

        #expect(fetched == nil)
    }

    @Test("Fetch with predicate returns matching todos")
    func fetchWithPredicate() throws {
        let todo1 = TodoItem(title: "Todo 1", isCompleted: true)
        let todo2 = TodoItem(title: "Todo 2", isCompleted: false)
        let todo3 = TodoItem(title: "Todo 3", isCompleted: false)
        let repository = MockTodoRepository(initialTodos: [todo1, todo2, todo3])

        let incomplete = try repository.fetch { !$0.isCompleted }

        #expect(incomplete.count == 2)
    }

    // MARK: - Update Tests

    @Test("Update modifies existing todo")
    func updateTodo() throws {
        let todo = TodoItem(title: "Original")
        let repository = MockTodoRepository(initialTodos: [todo])

        todo.title = "Updated"
        try repository.update(todo)

        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.title == "Updated")
    }

    @Test("Update throws for non-existent todo")
    func updateNotFound() throws {
        let repository = MockTodoRepository()
        let todo = TodoItem(title: "New todo")

        #expect(throws: RepositoryError.self) {
            try repository.update(todo)
        }
    }

    // MARK: - Delete Tests

    @Test("Delete removes todo from repository")
    func deleteTodo() throws {
        let todo = TodoItem(title: "To delete")
        let repository = MockTodoRepository(initialTodos: [todo])

        try repository.delete(todo)

        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched == nil)
    }

    @Test("Delete by ID removes todo from repository")
    func deleteById() throws {
        let todo = TodoItem(title: "To delete")
        let repository = MockTodoRepository(initialTodos: [todo])

        try repository.delete(by: todo.id)

        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched == nil)
    }

    @Test("Delete throws for non-existent todo")
    func deleteNotFound() throws {
        let repository = MockTodoRepository()

        #expect(throws: RepositoryError.self) {
            try repository.delete(by: UUID())
        }
    }

    // MARK: - Convenience Methods Tests

    @Test("FetchIncomplete returns only incomplete todos")
    func fetchIncomplete() throws {
        let todo1 = TodoItem(title: "Complete", isCompleted: true)
        let todo2 = TodoItem(title: "Incomplete", isCompleted: false)
        let repository = MockTodoRepository(initialTodos: [todo1, todo2])

        let incomplete = try repository.fetchIncomplete()

        #expect(incomplete.count == 1)
        #expect(incomplete.first?.title == "Incomplete")
    }

    @Test("FetchFavorites returns only favorite todos")
    func fetchFavorites() throws {
        let todo1 = TodoItem(title: "Favorite", isFavorite: true)
        let todo2 = TodoItem(title: "Not favorite", isFavorite: false)
        let repository = MockTodoRepository(initialTodos: [todo1, todo2])

        let favorites = try repository.fetchFavorites()

        #expect(favorites.count == 1)
        #expect(favorites.first?.title == "Favorite")
    }
}
