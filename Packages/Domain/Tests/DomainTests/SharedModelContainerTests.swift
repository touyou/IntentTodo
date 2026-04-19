//
//  SharedModelContainerTests.swift
//  IntentTodo
//
//  Tests for SharedModelContainer to ensure proper App Group data sharing.
//

import Foundation
import SwiftData
import Testing
@testable import Domain

@Suite("SharedModelContainer Tests")
struct SharedModelContainerTests {
    // MARK: - App Group Identifier Tests

    @Test("App Group identifier follows expected format")
    func appGroupIdentifierFormat() {
        let identifier = SharedModelContainer.appGroupIdentifier
        #expect(identifier.hasPrefix("group."))
    }

    // MARK: - Container URL Tests

    @Test("Container URL is available for App Group")
    func containerURLAvailable() {
        // Note: In unit tests, App Group may not be available
        // This test documents the expected behavior
        let url = SharedModelContainer.sharedContainerURL

        // URL should be non-nil when App Group is properly configured
        // In test environment, it may fall back to default location
        #expect(url != nil)
    }

    @Test("Container URL is consistent across calls")
    func containerURLConsistent() {
        let url1 = SharedModelContainer.sharedContainerURL
        let url2 = SharedModelContainer.sharedContainerURL

        #expect(url1 == url2)
    }

    // MARK: - Schema Tests

    @Test("Schema includes all required models")
    func schemaIncludesAllModels() {
        let schema = SharedModelContainer.schema

        // Verify the schema contains the expected entity names
        let entityNames = schema.entities.map { $0.name }

        #expect(entityNames.contains("TodoItem"))
        #expect(entityNames.contains("SubTask"))
        #expect(entityNames.contains("Category"))
    }

    // MARK: - Configuration Tests

    @Test("Configuration is non-in-memory in DEBUG fallback as well")
    func configurationIsNotInMemoryOnly() {
        // In DEBUG (SPM test) builds the configuration falls back to a non-shared
        // on-disk store; in production it would be the App Group store. Either
        // way it is never in-memory.
        let config = SharedModelContainer.configuration
        #expect(config.isStoredInMemoryOnly == false)
    }

    // MARK: - Container Tests

    @Test("Container can be created successfully")
    func containerCreation() throws {
        // This may use in-memory or temp storage in test environment
        let container = try SharedModelContainer.createContainer()

        // Verify container was created (non-optional, so this is just documentation)
        _ = container
    }

    @Test("Container provides functional main context")
    @MainActor
    func containerMainContext() throws {
        let container = try SharedModelContainer.createInMemoryContainer()
        let context = container.mainContext

        // Should be able to create and save a TodoItem
        let todo = TodoItem(title: "Test Todo")
        context.insert(todo)
        try context.save()

        // Should be able to fetch the item
        let descriptor = FetchDescriptor<TodoItem>()
        let todos = try context.fetch(descriptor)

        #expect(todos.count >= 1)
        #expect(todos.contains { $0.title == "Test Todo" })
    }
}
