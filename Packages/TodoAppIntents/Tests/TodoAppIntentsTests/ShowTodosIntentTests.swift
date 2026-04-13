//
//  ShowTodosIntentTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("ShowTodosIntent Tests")
@MainActor
struct ShowTodosIntentTests {
    // MARK: - Setup

    init() {
        IntentDependencies.shared.testRepository = MockTodoRepository()
    }

    // MARK: - Helper

    private func createTodo(
        title: String,
        isCompleted: Bool = false,
        isFavorite: Bool = false
    ) async throws -> TodoItem {
        let repository = try IntentDependencies.shared.createRepository()
        let todo = TodoItem(title: title, isCompleted: isCompleted, isFavorite: isFavorite)
        try repository.create(todo)
        return todo
    }

    // MARK: - filter: .all (default)

    @Test("filter .all returns all todos")
    func showAllTodos() async throws {
        _ = try await createTodo(title: "Todo 1")
        _ = try await createTodo(title: "Todo 2", isCompleted: true)
        _ = try await createTodo(title: "Todo 3", isFavorite: true)

        let intent = ShowTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 3)
    }

    @Test("filter .all returns empty when no todos")
    func showAllTodosEmpty() async throws {
        let intent = ShowTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }

    // MARK: - filter: .incomplete

    @Test("filter .incomplete returns only incomplete todos")
    func showIncompleteTodos() async throws {
        _ = try await createTodo(title: "Incomplete 1")
        _ = try await createTodo(title: "Completed", isCompleted: true)
        _ = try await createTodo(title: "Incomplete 2")

        let intent = ShowTodosIntent(filter: .incomplete)
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 2)
        #expect(entities.allSatisfy { !$0.isCompleted })
    }

    @Test("filter .incomplete returns empty when all completed")
    func showIncompleteTodosAllCompleted() async throws {
        _ = try await createTodo(title: "Completed 1", isCompleted: true)
        _ = try await createTodo(title: "Completed 2", isCompleted: true)

        let intent = ShowTodosIntent(filter: .incomplete)
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }

    // MARK: - filter: .favorites

    @Test("filter .favorites returns only favorite todos")
    func showFavoriteTodos() async throws {
        _ = try await createTodo(title: "Regular")
        _ = try await createTodo(title: "Favorite 1", isFavorite: true)
        _ = try await createTodo(title: "Favorite 2", isFavorite: true)

        let intent = ShowTodosIntent(filter: .favorites)
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 2)
        #expect(entities.allSatisfy { $0.isFavorite })
    }

    @Test("filter .favorites returns empty when no favorites")
    func showFavoriteTodosNone() async throws {
        _ = try await createTodo(title: "Regular 1")
        _ = try await createTodo(title: "Regular 2")

        let intent = ShowTodosIntent(filter: .favorites)
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }
}
