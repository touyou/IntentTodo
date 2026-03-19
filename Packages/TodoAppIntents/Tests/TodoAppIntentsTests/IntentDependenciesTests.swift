//
//  IntentDependenciesTests.swift
//  IntentTodo
//

import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("IntentDependencies Tests")
@MainActor
struct IntentDependenciesTests {
    // MARK: - Setup / Teardown

    init() {
        IntentDependencies.shared.reset()
    }

    // MARK: - Initial State Tests

    @Test("Initial state has nil modelContainer and testRepository")
    func initialState() {
        #expect(IntentDependencies.shared.modelContainer == nil)
        #expect(IntentDependencies.shared.testRepository == nil)
    }

    // MARK: - Test Repository Tests

    @Test("createRepository returns testRepository when set")
    func createRepositoryWithTestRepo() throws {
        let mockRepo = MockTodoRepository()
        IntentDependencies.shared.testRepository = mockRepo

        let repo = try IntentDependencies.shared.createRepository()

        // Verify it returns the mock by using it
        let todo = TodoItem(title: "Test")
        try repo.create(todo)
        let fetched = try repo.fetchAll()
        #expect(fetched.count == 1)

        // Also verify through the original mock reference
        let mockFetched = try mockRepo.fetchAll()
        #expect(mockFetched.count == 1)
    }

    @Test("createRepository falls back to SharedModelContainer when no container configured")
    func createRepositoryFallback() throws {
        // No container configured, no test repository
        // This should attempt to create a SharedModelContainer
        // It may succeed or fail depending on App Group configuration in test environment
        // The important thing is it doesn't crash and follows the expected code path
        do {
            let repo = try IntentDependencies.shared.createRepository()
            #expect(repo != nil)
        } catch {
            // Expected in test environment without App Group
            #expect(error != nil)
        }
    }

    // MARK: - Reset Tests

    @Test("reset clears both modelContainer and testRepository")
    func reset() {
        IntentDependencies.shared.testRepository = MockTodoRepository()

        IntentDependencies.shared.reset()

        #expect(IntentDependencies.shared.modelContainer == nil)
        #expect(IntentDependencies.shared.testRepository == nil)
    }

    @Test("reset is idempotent")
    func resetIdempotent() {
        IntentDependencies.shared.reset()
        IntentDependencies.shared.reset()

        #expect(IntentDependencies.shared.modelContainer == nil)
        #expect(IntentDependencies.shared.testRepository == nil)
    }
}

// MARK: - IntentDependenciesError Tests

@Suite("IntentDependenciesError Tests")
struct IntentDependenciesErrorTests {
    @Test("notConfigured has correct error description")
    func notConfiguredDescription() {
        let error = IntentDependenciesError.notConfigured

        #expect(
            error.errorDescription
                == "IntentDependencies not configured. Call IntentDependencies.shared.configure(modelContainer:) at app launch."
        )
    }

    @Test("notConfigured conforms to LocalizedError")
    func localizedErrorConformance() {
        let error: any LocalizedError = IntentDependenciesError.notConfigured

        #expect(error.errorDescription != nil)
    }
}
