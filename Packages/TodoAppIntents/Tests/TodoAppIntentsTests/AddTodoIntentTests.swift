//
//  AddTodoIntentTests.swift
//  IntentTodo
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("AddTodoIntent Tests")
@MainActor
struct AddTodoIntentTests {
    // MARK: - Setup

    init() {
        // Setup mock repository for each test
        IntentDependencies.shared.testRepository = MockTodoRepository()
    }

    // MARK: - Success Cases

    @Test("AddTodoIntent creates todo with valid title")
    func createWithValidTitle() async throws {
        let intent = AddTodoIntent(todoTitle: "Buy groceries")

        let result = try await intent.perform()

        // Verify the returned entity
        let entity = result.value
        #expect(entity != nil)
        #expect(entity?.title == "Buy groceries")
        #expect(entity?.isCompleted == false)
        #expect(entity?.isFavorite == false)
    }

    @Test("AddTodoIntent creates todo with all properties")
    func createWithAllProperties() async throws {
        let dueDate = Date()
        let intent = AddTodoIntent(
            title: "Complete project",
            todoDescription: "Finish the IntentTodo app",
            dueDate: dueDate,
            isFavorite: true
        )

        let result = try await intent.perform()

        let entity = result.value
        #expect(entity?.title == "Complete project")
        #expect(entity?.isFavorite == true)
        #expect(entity?.dueDate == dueDate)
    }

    @Test("AddTodoIntent trims whitespace from title")
    func trimsWhitespace() async throws {
        let intent = AddTodoIntent(todoTitle: "  Buy groceries  ")

        let result = try await intent.perform()

        #expect(result.value?.title == "Buy groceries")
    }

    @Test("AddTodoIntent persists todo to repository")
    func persistsToRepository() async throws {
        let repository = MockTodoRepository()
        IntentDependencies.shared.testRepository = repository

        let intent = AddTodoIntent(todoTitle: "Test todo")
        _ = try await intent.perform()

        let todos = try repository.fetchAll()
        #expect(todos.count == 1)
        #expect(todos.first?.title == "Test todo")
    }

    // MARK: - Error Cases

    @Test("AddTodoIntent throws error for empty title")
    func errorForEmptyTitle() async throws {
        let intent = AddTodoIntent(todoTitle: "")

        await #expect(throws: IntentError.self) {
            _ = try await intent.perform()
        }
    }

    @Test("AddTodoIntent throws error for whitespace-only title")
    func errorForWhitespaceTitle() async throws {
        let intent = AddTodoIntent(todoTitle: "   ")

        await #expect(throws: IntentError.self) {
            _ = try await intent.perform()
        }
    }
}
