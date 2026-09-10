//
//  RepositoryTests.swift
//  IntentTodo
//

import Domain
import Foundation
import Testing
@testable import Repository

@Suite("Repository Tests")
struct RepositoryTests {
    @Test("A fresh mock satisfies the protocol and starts empty")
    @MainActor
    func freshMockStartsEmpty() throws {
        // Typed as the protocol so conformance is enforced at compile time; the assertion
        // covers the part that can actually regress — `MockTodoRepository()` seeding rows
        // would make every test that builds on it start from a dirty store.
        let repository: any TodoRepositoryProtocol = MockTodoRepository()

        #expect(try repository.fetchAll().isEmpty)
        #expect(try repository.incompleteCount() == 0)
    }

    @Test("RepositoryError cases are defined")
    func repositoryErrorCases() {
        let testId = UUID()
        let notFoundError = RepositoryError.notFound(id: testId)
        let persistenceError = RepositoryError.persistenceError(underlying: NSError(domain: "test", code: 1))
        let cancelledError = RepositoryError.cancelled

        // Verify notFound case
        if case .notFound(let id) = notFoundError {
            #expect(id == testId)
        } else {
            Issue.record("Expected notFound case")
        }

        // Verify persistenceError case
        if case .persistenceError(let underlying) = persistenceError {
            #expect((underlying as NSError).domain == "test")
        } else {
            Issue.record("Expected persistenceError case")
        }

        // Verify cancelled case
        if case .cancelled = cancelledError {
            // OK
        } else {
            Issue.record("Expected cancelled case")
        }

        // Verify LocalizedError conformance
        #expect(notFoundError.errorDescription != nil)
        #expect(persistenceError.errorDescription != nil)
        #expect(cancelledError.errorDescription != nil)
    }
}
