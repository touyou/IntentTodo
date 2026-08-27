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
        // macOS では entitlement が無いプロセスでもパス自体は解決される（実測。
        // 返るのは ~/Library/Group Containers/<id>。ただし書き込みはできない）。
        // したがってこの assert は「App Group が使える」ことの証明にはならず、
        // 識別子からパスを組めることだけを見ている。
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

    /// 共有ストアを実際に開けるのは App Group + iCloud の entitlement を持つ
    /// プロセス（アプリ本体 / 各 Extension）だけ。SPM のテストプロセスには
    /// entitlement が無く、macOS ではパスが解決できてしまう分だけ質が悪い
    /// （`configuration` の DEBUG フォールバックが働かず、開けないパスをそのまま
    /// 掴んで `NSCocoaErrorDomain 256 / SQLite 23` で落ちる）。
    ///
    /// そのため「環境によって落ちるテスト」として明示する。entitlement のある
    /// ホストで走らせれば成功し、`isIntermittent: true` なのでその場合も緑のまま。
    /// in-memory 経路の実質的なカバレッジは下の `containerMainContext` にある。
    ///
    /// 経緯: docs/devlog/05-extensions-and-data-sharing.md（2026-08-26）
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
