//
//  DeleteTodoIntentTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("DeleteTodoIntent Tests")
@MainActor
struct DeleteTodoIntentTests {
    // MARK: - Setup

    private func setupRepository(with todo: TodoItem) -> MockTodoRepository {
        let repository = MockTodoRepository(initialTodos: [todo])
        IntentDependencies.shared.testRepository = repository
        return repository
    }

    // MARK: - Success Cases

    @Test("DeleteTodoIntent removes todo from repository")
    func deleteTodo() async throws {
        let todo = TodoItem(title: "Test todo")
        let repository = setupRepository(with: todo)
        let entity = TodoAppEntity(from: todo)

        let intent = DeleteTodoIntent(todo: entity)
        _ = try await intent.perform()

        // Verify deleted
        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched == nil)
    }

    @Test("DeleteTodoIntent does not affect other todos")
    func doesNotAffectOtherTodos() async throws {
        let todo1 = TodoItem(title: "Todo 1")
        let todo2 = TodoItem(title: "Todo 2")
        let repository = MockTodoRepository(initialTodos: [todo1, todo2])
        IntentDependencies.shared.testRepository = repository

        let entity = TodoAppEntity(from: todo1)
        let intent = DeleteTodoIntent(todo: entity)
        _ = try await intent.perform()

        // Verify only todo1 is deleted
        let todos = try repository.fetchAll()
        #expect(todos.count == 1)
        #expect(todos.first?.id == todo2.id)
    }

    // MARK: - Error Cases

    @Test("DeleteTodoIntent throws error for non-existent todo")
    func errorForNonExistentTodo() async throws {
        IntentDependencies.shared.testRepository = MockTodoRepository()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "Non-existent")

        let intent = DeleteTodoIntent(todo: entity)

        await #expect(throws: Error.self) {
            _ = try await intent.perform()
        }
    }
}
