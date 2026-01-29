//
//  DomainTests.swift
//  IntentTodo
//

import Testing
@testable import Domain

@Suite("Domain Tests")
struct DomainTests {
    @Test("Domain module is accessible")
    func domainModuleAccessible() {
        #expect(Domain.version == "1.0.0")
    }
}
