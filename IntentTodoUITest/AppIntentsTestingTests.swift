//
//  AppIntentsTestingTests.swift
//  IntentTodoUITest
//
//  Phase 6 (#295): exercises the App Intents execution path with the
//  AppIntentsTesting framework (WWDC 2026). These run out-of-process against the
//  live app — the same path Siri / Shortcuts use — so they live in the UI testing
//  bundle (App Intents Testing requires a UI test target, not a unit test target).
//
//  Tests are self-cleaning: each creates a uniquely-titled todo and deletes it so
//  the app's SwiftData store is left as it was found.
//

import AppIntents
import AppIntentsTesting
import XCTest

final class AppIntentsTestingTests: XCTestCase {
    /// Must match the app target's PRODUCT_BUNDLE_IDENTIFIER.
    private static let appBundleID = "dev.touyou.IntentTodo"

    private var app: XCUIApplication!
    private var definitions: IntentDefinitions!

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        // Discovers all intents / entities / enums / queries the app registers.
        definitions = IntentDefinitions(bundleIdentifier: Self.appBundleID)
    }

    override func tearDown() {
        app = nil
        definitions = nil
    }

    private func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(UUID().uuidString)"
    }

    // MARK: - Intent execution (makeIntent / run)

    /// Runs AddTodoIntent through the real App Intents infrastructure, verifies the
    /// created entity surfaces via an entity query, then deletes it.
    func testAddTodoIntentRunsAndPersists() async throws {
        let title = uniqueTitle("AITest Add")

        // Build the intent by type name, passing parameters by their @Parameter label.
        let addIntent = definitions.intents["AddTodoIntent"].makeIntent(title: title)
        try await addIntent.run()

        // The new todo should now be discoverable by an EntityStringQuery match.
        let matches = try await definitions.entities["TodoAppEntity"]
            .entities(matching: title)
        XCTAssertFalse(matches.isEmpty, "Added todo should be found by entity query")

        try await deleteTodos(matching: title)
    }

    // MARK: - Entity query

    /// Verifies `TodoEntityQuery.entities(matching:)` is reachable via AppIntentsTesting.
    func testEntityQueryMatchesCreatedTodo() async throws {
        let title = uniqueTitle("AITest Query")
        try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()

        let matches = try await definitions.entities["TodoAppEntity"]
            .entities(matching: title)
        XCTAssertEqual(matches.count, 1, "Exactly one todo should match the unique title")

        // Type-erased dynamic property access on the matched entity.
        let matchedTitle: String = try matches[0].title
        XCTAssertEqual(matchedTitle, title)

        try await deleteTodos(matching: title)
    }

    // MARK: - Multi-intent chain (Add → Show)

    /// Add a todo, then run ShowTodosIntent and confirm the chain executes.
    func testAddThenShowChain() async throws {
        let title = uniqueTitle("AITest Chain")
        try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()

        // ShowTodosIntent returns [TodoAppEntity]; running it should not throw.
        try await definitions.intents["ShowTodosIntent"].makeIntent().run()

        try await deleteTodos(matching: title)
    }

    // MARK: - Helpers

    /// Deletes every todo whose title matches, leaving the store clean.
    private func deleteTodos(matching title: String) async throws {
        let matches = try await definitions.entities["TodoAppEntity"]
            .entities(matching: title)
        for match in matches {
            try await definitions.intents["DeleteTodoIntent"]
                .makeIntent(todo: match)
                .run()
        }
    }
}
