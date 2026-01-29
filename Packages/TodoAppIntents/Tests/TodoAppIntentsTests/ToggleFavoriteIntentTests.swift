//
//  ToggleFavoriteIntentTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("ToggleFavoriteIntent Tests")
@MainActor
struct ToggleFavoriteIntentTests {
    // MARK: - Setup

    private func setupRepository(with todo: TodoItem) -> MockTodoRepository {
        let repository = MockTodoRepository(initialTodos: [todo])
        IntentDependencies.shared.testRepository = repository
        return repository
    }

    // MARK: - Success Cases

    @Test("ToggleFavoriteIntent marks non-favorite todo as favorite")
    func markAsFavorite() async throws {
        let todo = TodoItem(title: "Test todo", isFavorite: false)
        let repository = setupRepository(with: todo)
        let entity = TodoAppEntity(from: todo)

        let intent = ToggleFavoriteIntent(todo: entity)
        let result = try await intent.perform()

        #expect(result.value?.isFavorite == true)

        // Verify persisted
        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.isFavorite == true)
    }

    @Test("ToggleFavoriteIntent removes favorite status")
    func removeFromFavorites() async throws {
        let todo = TodoItem(title: "Test todo", isFavorite: true)
        let repository = setupRepository(with: todo)
        let entity = TodoAppEntity(from: todo)

        let intent = ToggleFavoriteIntent(todo: entity)
        let result = try await intent.perform()

        #expect(result.value?.isFavorite == false)

        // Verify persisted
        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.isFavorite == false)
    }

    // MARK: - Error Cases

    @Test("ToggleFavoriteIntent throws error for non-existent todo")
    func errorForNonExistentTodo() async throws {
        IntentDependencies.shared.testRepository = MockTodoRepository()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "Non-existent")

        let intent = ToggleFavoriteIntent(todo: entity)

        await #expect(throws: IntentError.self) {
            _ = try await intent.perform()
        }
    }
}
