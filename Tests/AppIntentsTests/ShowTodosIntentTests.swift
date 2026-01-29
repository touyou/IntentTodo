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

    // MARK: - ShowTodosIntent Tests

    @Test("ShowTodosIntent returns all todos")
    func showAllTodos() async throws {
        _ = try await createTodo(title: "Todo 1")
        _ = try await createTodo(title: "Todo 2", isCompleted: true)
        _ = try await createTodo(title: "Todo 3", isFavorite: true)

        let intent = ShowTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 3)
    }

    @Test("ShowTodosIntent returns empty when no todos")
    func showAllTodosEmpty() async throws {
        let intent = ShowTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }

    // MARK: - ShowIncompleteTodosIntent Tests

    @Test("ShowIncompleteTodosIntent returns only incomplete todos")
    func showIncompleteTodos() async throws {
        _ = try await createTodo(title: "Incomplete 1")
        _ = try await createTodo(title: "Completed", isCompleted: true)
        _ = try await createTodo(title: "Incomplete 2")

        let intent = ShowIncompleteTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 2)
        #expect(entities.allSatisfy { !$0.isCompleted })
    }

    @Test("ShowIncompleteTodosIntent returns empty when all completed")
    func showIncompleteTodosAllCompleted() async throws {
        _ = try await createTodo(title: "Completed 1", isCompleted: true)
        _ = try await createTodo(title: "Completed 2", isCompleted: true)

        let intent = ShowIncompleteTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }

    // MARK: - ShowFavoriteTodosIntent Tests

    @Test("ShowFavoriteTodosIntent returns only favorite todos")
    func showFavoriteTodos() async throws {
        _ = try await createTodo(title: "Regular")
        _ = try await createTodo(title: "Favorite 1", isFavorite: true)
        _ = try await createTodo(title: "Favorite 2", isFavorite: true)

        let intent = ShowFavoriteTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.count == 2)
        #expect(entities.allSatisfy { $0.isFavorite })
    }

    @Test("ShowFavoriteTodosIntent returns empty when no favorites")
    func showFavoriteTodosNone() async throws {
        _ = try await createTodo(title: "Regular 1")
        _ = try await createTodo(title: "Regular 2")

        let intent = ShowFavoriteTodosIntent()
        let result = try await intent.perform()

        let entities = try #require(result.value)
        #expect(entities.isEmpty)
    }
}
