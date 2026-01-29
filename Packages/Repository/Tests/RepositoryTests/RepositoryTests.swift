//
//  RepositoryTests.swift
//  IntentTodo
//

import Testing
@testable import Repository

@Suite("Repository Tests")
struct RepositoryTests {
    @Test("Repository module is accessible")
    func repositoryModuleAccessible() {
        #expect(Repository.version == "1.0.0")
    }
}
