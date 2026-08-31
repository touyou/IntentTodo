//
//  TodoEntityQueryTests.swift
//  IntentTodoUITest
//
//  The entity queries. Breakage here reads as "the Shortcuts list is empty", "the button
//  does nothing" or "it is not in search" — none of which other tests catch.
//

import AppIntents
import AppIntentsTesting
import XCTest

final class TodoEntityQueryTests: AppIntentsTestCase {
    // MARK: - EntityStringQuery

    /// The string-matching path Shortcuts uses.
    func testEntityQueryMatchesCreatedTodo() async throws {
        let title = uniqueTitle("AITest Query")
        try await addTodo(title: title)

        let matches = try await todoEntity.entities(matching: title)
        XCTAssertEqual(matches.count, 1, "Exactly one todo should match the unique title")
        XCTAssertEqual(try matches[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    // MARK: - Resolution by id

    /// `entities(for:)` is what the system calls before `perform()` when a Live Activity or
    /// widget button is pressed, so breaking it presents as an unresponsive button.
    func testEntityResolutionByIdentifier() async throws {
        let title = uniqueTitle("AITest Resolve")
        let entity = try await addTodo(title: title)

        let resolved = try await todoEntity.entities(identifiers: [identifier(of: entity)])

        XCTAssertEqual(resolved.count, 1, "Entity should resolve from its identifier alone")
        XCTAssertEqual(try resolved[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    /// An unknown id yields an empty array rather than throwing, so a stale button pointing
    /// at a deleted todo cannot crash anything.
    func testEntityResolutionOfUnknownIdentifierReturnsEmpty() async throws {
        let resolved = try await todoEntity.entities(identifiers: [UUID().uuidString])
        XCTAssertTrue(resolved.isEmpty)
    }

    // MARK: - Enumerable / suggested

    /// `allEntities()` versus `suggestedEntities()`, which is incomplete todos only.
    func testAllEntitiesIncludesSuggestedIncompleteTodo() async throws {
        let title = uniqueTitle("AITest Enumerate")
        try await addTodo(title: title)

        let all = try await todoEntity.allEntities()
        XCTAssertTrue(
            try all.contains { try $0.title as String == title },
            "allEntities() should include the newly created todo"
        )

        // Newly added, so it is incomplete and appears in the suggestions too.
        let suggested = try await todoEntity.suggestedEntities()
        XCTAssertTrue(
            try suggested.contains { try $0.title as String == title },
            "suggestedEntities() should include an incomplete todo"
        )

        try await deleteTodos(matching: title)
    }

    /// Completing a todo removes it from the suggestions.
    func testSuggestedEntitiesExcludesCompletedTodo() async throws {
        let title = uniqueTitle("AITest Suggest")
        let entity = try await addTodo(title: title)

        try await intent("ToggleTodoCompletionIntent").makeIntent(todo: entity).run()

        let suggested = try await todoEntity.suggestedEntities()
        XCTAssertFalse(
            try suggested.contains { try $0.title as String == title },
            "A completed todo should drop out of the suggestions"
        )

        try await deleteTodos(matching: title)
    }

    // MARK: - Spotlight

    /// Proves the Spotlight indexing actually happens: an intent can return the right value
    /// while the entity quietly disappears from Siri and search, and nothing else notices.
    func testNewTodoIsIndexedInSpotlight() async throws {
        let title = uniqueTitle("AITest Spotlight")

        let before = try await todoEntity.spotlightQuery(title)
        XCTAssertTrue(before.isEmpty, "Todo should not be in Spotlight before it exists")

        try await addTodo(title: title)

        // Indexing is asynchronous, so this polls before deciding.
        let indexed = try await pollUntil(timeout: 10) {
            try await self.todoEntity.spotlightQuery(title)
        } until: { !$0.isEmpty }

        XCTAssertEqual(indexed.count, 1, "Exactly one Spotlight result for the unique title")
        XCTAssertEqual(try indexed[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    /// Deleting removes it from Spotlight too; a stale index means opening a search result
    /// finds nothing.
    func testDeletedTodoIsRemovedFromSpotlight() async throws {
        let title = uniqueTitle("AITest Deindex")
        try await addTodo(title: title)

        _ = try await pollUntil(timeout: 10) {
            try await self.todoEntity.spotlightQuery(title)
        } until: { !$0.isEmpty }

        try await deleteTodos(matching: title)

        let after = try await pollUntil(timeout: 10) {
            try await self.todoEntity.spotlightQuery(title)
        } until: { $0.isEmpty }
        XCTAssertTrue(after.isEmpty, "Deleting a todo should also remove its Spotlight entry")
    }

    // MARK: - Cross-Type Search

    /// `SearchEverythingIntent` returns a `@UnionValue`; changing its members breaks how
    /// Shortcuts consumes the result.
    func testSearchEverythingFindsTodoByTitle() async throws {
        let title = uniqueTitle("AITest Union")
        try await addTodo(title: title)

        let result = try await intent("SearchEverythingIntent").makeIntent(query: title).run()
        let found: [AnyAppEntity] = try result.value
        XCTAssertTrue(
            try found.contains { (try? $0.title as String) == title },
            "Cross-entity search should surface the todo"
        )

        try await deleteTodos(matching: title)
    }
}
