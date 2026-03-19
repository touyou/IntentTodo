//
//  DomainTests.swift
//  IntentTodo
//

import Testing
@testable import Domain

@Suite("Domain Tests")
struct DomainTests {
    @Test("Domain models are accessible")
    func domainModelsAccessible() {
        // Verify core domain models can be instantiated
        let todo = TodoItem(title: "Test")
        #expect(todo.title == "Test")

        let subTask = SubTask(title: "Sub")
        #expect(subTask.title == "Sub")

        let category = Category(name: "Work")
        #expect(category.name == "Work")
    }
}
