//
//  ToggleTodoCompletionIntentTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("ToggleTodoCompletionIntent Tests")
@MainActor
struct ToggleTodoCompletionIntentTests {
    // MARK: - Setup

    private func setupRepository(with todo: TodoItem) -> MockTodoRepository {
        let repository = MockTodoRepository(initialTodos: [todo])
        IntentDependencies.shared.testRepository = repository
        return repository
    }

    // MARK: - Success Cases

    @Test("ToggleTodoCompletionIntent marks incomplete todo as complete")
    func markAsComplete() async throws {
        let todo = TodoItem(title: "Test todo", isCompleted: false)
        let repository = setupRepository(with: todo)
        let entity = TodoAppEntity(from: todo)

        let intent = ToggleTodoCompletionIntent(todo: entity)
        let result = try await intent.perform()

        #expect(result.value?.isCompleted == true)

        // Verify persisted
        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.isCompleted == true)
    }

    @Test("ToggleTodoCompletionIntent marks complete todo as incomplete")
    func markAsIncomplete() async throws {
        let todo = TodoItem(title: "Test todo", isCompleted: true)
        let repository = setupRepository(with: todo)
        let entity = TodoAppEntity(from: todo)

        let intent = ToggleTodoCompletionIntent(todo: entity)
        let result = try await intent.perform()

        #expect(result.value?.isCompleted == false)

        // Verify persisted
        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.isCompleted == false)
    }

    // MARK: - Error Cases

    @Test("ToggleTodoCompletionIntent throws error for non-existent todo")
    func errorForNonExistentTodo() async throws {
        IntentDependencies.shared.testRepository = MockTodoRepository()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "Non-existent")

        let intent = ToggleTodoCompletionIntent(todo: entity)

        await #expect(throws: IntentError.self) {
            _ = try await intent.perform()
        }
    }
}
