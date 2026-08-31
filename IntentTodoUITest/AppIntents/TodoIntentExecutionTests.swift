//
//  TodoIntentExecutionTests.swift
//  IntentTodoUITest
//
//  Runs intents through the real stack, the one Siri and Shortcuts use.
//

import AppIntents
import AppIntentsTesting
import XCTest

final class TodoIntentExecutionTests: AppIntentsTestCase {
    // MARK: - Creation

    /// Runs `AddTodoIntent` and checks the new entity is visible to the query.
    func testAddTodoIntentRunsAndPersists() async throws {
        let title = uniqueTitle("AITest Add")

        // Intents are looked up by type name; parameters use their `@Parameter` labels.
        try await intent("AddTodoIntent").makeIntent(title: title).run()

        let matches = try await todoEntity.entities(matching: title)
        XCTAssertFalse(matches.isEmpty, "Added todo should be found by entity query")

        try await deleteTodos(matching: title)
    }

    // MARK: - Completion Toggle

    /// One intent for Siri, the app UI, widgets and Live Activities, so the round trip is
    /// worth covering directly.
    func testToggleCompletionRoundTrip() async throws {
        let title = uniqueTitle("AITest Toggle")
        let entity = try await addTodo(title: title)
        XCTAssertFalse(try entity.isCompleted as Bool, "New todo starts incomplete")

        let toggled = try await intent("ToggleTodoCompletionIntent").makeIntent(todo: entity).run()
        XCTAssertTrue(try toggled.value.isCompleted as Bool, "First toggle completes the todo")

        let toggledBack = try await intent("ToggleTodoCompletionIntent").makeIntent(todo: entity).run()
        XCTAssertFalse(try toggledBack.value.isCompleted as Bool, "Second toggle un-completes it")

        try await deleteTodos(matching: title)
    }

    func testToggleFavoriteRoundTrip() async throws {
        let title = uniqueTitle("AITest Favorite")
        let entity = try await addTodo(title: title)
        XCTAssertFalse(try entity.isFavorite as Bool)

        let favorited = try await intent("ToggleFavoriteIntent").makeIntent(todo: entity).run()
        XCTAssertTrue(try favorited.value.isFavorite as Bool)

        let unfavorited = try await intent("ToggleFavoriteIntent").makeIntent(todo: entity).run()
        XCTAssertFalse(try unfavorited.value.isFavorite as Bool)

        try await deleteTodos(matching: title)
    }

    // MARK: - Snooze

    /// The fixed-interval variant used by Live Activity buttons.
    /// The interactive `SnoozeTodoIntent` waits on `requestChoice` and cannot be run from
    /// AppIntentsTesting at all.
    func testQuickSnoozePushesDueDateByThirtyMinutes() async throws {
        let title = uniqueTitle("AITest Snooze")
        let dueDate = Date().addingTimeInterval(60 * 60)

        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, dueDate: dueDate)
            .run()
        let entity: AnyAppEntity = try created.value

        let snoozed = try await intent("QuickSnoozeTodoIntent").makeIntent(todo: entity).run()

        // The exposed `dueDate` is a `DateComponents?` projection with minute precision, so
        // the expectation is truncated to match.
        let snoozedComponents: DateComponents = try snoozed.value.dueDate
        let expectedComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate.addingTimeInterval(30 * 60)
        )
        XCTAssertEqual(
            snoozedComponents,
            expectedComponents,
            "Quick snooze should push the due date back by exactly 30 minutes"
        )

        try await deleteTodos(matching: title)
    }

    // MARK: - Partial Updates

    /// `UpdateTodoIntent` tells new value, explicit clear and leave alone apart via
    /// `valueState`. An omitted parameter is `.unset`, i.e. leave alone.
    func testUpdateLeavesOmittedParametersUntouched() async throws {
        let title = uniqueTitle("AITest Update Keep")
        let dueDate = Date().addingTimeInterval(3600)
        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, todoDescription: "keep me", dueDate: dueDate)
            .run()
        let entity: AnyAppEntity = try created.value

        // Only the title is passed, so the other fields must survive.
        let newTitle = uniqueTitle("AITest Update Keep New")
        let updated = try await intent("UpdateTodoIntent")
            .makeIntent(todo: entity, title: newTitle)
            .run()

        XCTAssertEqual(try updated.value.title as String, newTitle)
        XCTAssertEqual(
            try updated.value.todoDescription as String,
            "keep me",
            "Omitted parameter (.unset) must not clear the existing value"
        )

        try await deleteTodos(matching: newTitle)
    }

    /// An explicit nil is `.set(nil)`, i.e. clear.
    /// Collapsing that into `.unset` would quietly make the description unclearable from
    /// Shortcuts, and nothing else would catch it.
    func testUpdateClearsExplicitlyNilledParameter() async throws {
        let title = uniqueTitle("AITest Update Clear")
        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, todoDescription: "clear me")
            .run()
        let entity: AnyAppEntity = try created.value
        XCTAssertEqual(try created.value.todoDescription as String, "clear me")

        // `makeIntent(todoDescription: nil)` means "argument not passed", i.e. `.unset`.
        // An explicit null needs a *typed* nil, which works because `Optional` itself
        // conforms to `IntentValueExpressing`.
        let explicitNull: any IntentValueExpressing = String?.none
        let cleared = try await intent("UpdateTodoIntent")
            .makeIntent(todo: entity, todoDescription: explicitNull)
            .run()

        let remaining: String? = try? cleared.value.todoDescription
        XCTAssertNil(remaining, "Explicit nil (.set(nil)) must clear the value")

        try await deleteTodos(matching: title)
    }

    // MARK: - Bulk Operations

    /// `CompleteTodosIntent` combines `LongRunningIntent`, `CancellableIntent`,
    /// `EntityCollection` and a pinned execution target, so this checks it runs to
    /// completion as configured.
    func testBulkCompleteMarksAllTargets() async throws {
        let prefix = uniqueTitle("AITest Bulk")
        let first = try await addTodo(title: "\(prefix) 1")
        let second = try await addTodo(title: "\(prefix) 2")

        try await intent("CompleteTodosIntent").makeIntent(todos: [first, second]).run()

        for entity in [first, second] {
            let resolved = try await todoEntity.entities(identifiers: [identifier(of: entity)])
            XCTAssertEqual(resolved.count, 1)
            XCTAssertTrue(
                try resolved[0].isCompleted as Bool,
                "Bulk complete should mark every entity in the collection"
            )
        }

        try await deleteTodos(matching: prefix)
    }

    /// Bulk delete through the system `DeleteIntent` protocol.
    func testBulkDeleteRemovesAllTargets() async throws {
        let prefix = uniqueTitle("AITest BulkDelete")
        let first = try await addTodo(title: "\(prefix) 1")
        let second = try await addTodo(title: "\(prefix) 2")

        try await intent("DeleteTodosIntent").makeIntent(entities: [first, second]).run()

        let remaining = try await todoEntity.entities(matching: prefix)
        XCTAssertTrue(remaining.isEmpty, "Bulk delete should remove every entity passed in")
    }

    // MARK: - Summary

    /// The transient entity `GetTodoSummaryIntent` returns. Shortcuts conditionals depend on
    /// these counts, so the property names are part of the contract.
    func testTodoSummaryReflectsNewTodo() async throws {
        let before = try await intent("GetTodoSummaryIntent").makeIntent().run()
        let pendingBefore: Int = try before.value.pendingCount

        let title = uniqueTitle("AITest Summary")
        try await addTodo(title: title)

        let after = try await intent("GetTodoSummaryIntent").makeIntent().run()
        let pendingAfter: Int = try after.value.pendingCount

        XCTAssertEqual(pendingAfter, pendingBefore + 1, "Adding a todo increments the pending count")

        try await deleteTodos(matching: title)
    }

    // MARK: - Chaining

    /// Feeds one intent's result into the next, as a shortcut would.
    func testAddThenShowChain() async throws {
        let title = uniqueTitle("AITest Chain")
        try await addTodo(title: title)

        try await intent("ShowTodosIntent").makeIntent().run()

        try await deleteTodos(matching: title)
    }
}
