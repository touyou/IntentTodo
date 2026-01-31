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
    @Test("Repository protocol and mock are accessible")
    @MainActor
    func repositoryModuleAccessible() {
        let repository = MockTodoRepository()
        #expect(repository != nil)
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
