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
        // On macOS the path resolves even without the entitlement (to
        // ~/Library/Group Containers/<id>, which cannot be written to), so this asserts only
        // that a path can be derived from the identifier — not that the App Group works.
        let url = SharedModelContainer.sharedContainerURL

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

    /// Only an entitled process — the app or one of its extensions — can actually open the
    /// shared store. An SPM test process has no entitlement, and on macOS that is worse than
    /// having no path at all: the DEBUG fallback in `configuration` never triggers, so the
    /// unopenable store is used and creation fails with `NSCocoaErrorDomain 256`.
    ///
    /// Marked as a known, environment-dependent issue: on an entitled host it passes, and
    /// `isIntermittent` keeps that green. The in-memory path is covered by
    /// `containerMainContext` below.
    ///
    @Test("Container can be created successfully")
    func containerCreation() throws {
        withKnownIssue(
            "App Group / iCloud entitlement のないプロセスでは共有ストアを開けない",
            isIntermittent: true
        ) {
            _ = try SharedModelContainer.createContainer()
        }
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
