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
        // すでに動いているなら `launch()`（= terminate + 再起動）ではなく `activate()`。
        // テストごとに起動し直すとシミュレータが
        // "did not return a process handle nor launch error" で散発的に落ちる。
        if app.state == .runningForeground || app.state == .runningBackground {
            app.activate()
        } else {
            app.launch()
        }
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

    // MARK: - Entity resolution by identifier

    /// `TodoEntityQuery.entities(for:)` は Live Activity / Widget のボタンが押されたときに
    /// システムが `perform()` 前に呼ぶ経路。ここが壊れると「ボタンが無反応」という
    /// 切り分けにくい症状になるので、id からの再解決を直接押さえておく。
    /// 経緯: docs/devlog/03-app-intents-core.md（2026-08-12 の A-3）
    func testEntityResolutionByIdentifier() async throws {
        let title = uniqueTitle("AITest Resolve")
        let created = try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()
        // id は `@Property` ではないので dynamic member lookup（`entity.id`）では取れない
        // （`NSNull` へのキャスト失敗になる）。`AnyAppEntity.identifier` から読む。
        let entity: AnyAppEntity = try created.value
        let createdId = entity.identifier.instanceIdentifier

        let resolved = try await definitions.entities["TodoAppEntity"]
            .entities(identifiers: [createdId])

        XCTAssertEqual(resolved.count, 1, "Entity should resolve from its identifier alone")
        XCTAssertEqual(try resolved[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    /// 存在しない id は空配列（throw ではない）。削除済み todo を指す古いボタンを
    /// 押したときに落ちないことの担保。
    func testEntityResolutionOfUnknownIdentifierReturnsEmpty() async throws {
        let resolved = try await definitions.entities["TodoAppEntity"]
            .entities(identifiers: [UUID().uuidString])
        XCTAssertTrue(resolved.isEmpty)
    }

    // MARK: - Enumerable / suggested entities

    /// `EnumerableEntityQuery.allEntities()` と `suggestedEntities()`（未完了のみ）。
    func testAllEntitiesIncludesSuggestedIncompleteTodo() async throws {
        let title = uniqueTitle("AITest Enumerate")
        try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()

        let all = try await definitions.entities["TodoAppEntity"].allEntities()
        XCTAssertTrue(
            try all.contains { try $0.title as String == title },
            "allEntities() should include the newly created todo"
        )

        // 追加直後は未完了なので suggestedEntities() にも出る。
        let suggested = try await definitions.entities["TodoAppEntity"].suggestedEntities()
        XCTAssertTrue(
            try suggested.contains { try $0.title as String == title },
            "suggestedEntities() should include an incomplete todo"
        )

        try await deleteTodos(matching: title)
    }

    // MARK: - Spotlight indexing

    /// `IndexedEntity` + `@Property(indexingKey:)` の実効性を押さえる。
    /// Intent の戻り値が正しくても Spotlight への index を落とすと Siri / 検索から
    /// 消えるだけで、他のテストには一切引っかからない。
    func testNewTodoIsIndexedInSpotlight() async throws {
        let title = uniqueTitle("AITest Spotlight")

        let before = try await definitions.entities["TodoAppEntity"].spotlightQuery(title)
        XCTAssertTrue(before.isEmpty, "Todo should not be in Spotlight before it exists")

        try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()

        // index は Intent 完了とは非同期。数回リトライしてから判定する。
        let indexed = try await pollUntil(timeout: 10) {
            try await self.definitions.entities["TodoAppEntity"].spotlightQuery(title)
        } until: { !$0.isEmpty }

        XCTAssertEqual(indexed.count, 1, "Exactly one Spotlight result for the unique title")
        XCTAssertEqual(try indexed[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    // MARK: - Live Activity ボタンが呼ぶ Intent

    /// `ToggleTodoCompletionIntent` は Siri / UI / Widget / Live Activity 共通の経路。
    /// FromExtension 分離を撤去した際にここへ副作用を寄せたので、往復を押さえておく。
    /// 経緯: docs/devlog/03-app-intents-core.md（2026-08-12 の撤去）
    func testToggleCompletionRoundTrip() async throws {
        let title = uniqueTitle("AITest Toggle")
        let created = try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()
        let entity: AnyAppEntity = try created.value
        XCTAssertFalse(try entity.isCompleted as Bool, "New todo starts incomplete")

        let toggled = try await definitions.intents["ToggleTodoCompletionIntent"]
            .makeIntent(todo: entity)
            .run()
        XCTAssertTrue(try toggled.value.isCompleted as Bool, "First toggle completes the todo")

        let toggledBack = try await definitions.intents["ToggleTodoCompletionIntent"]
            .makeIntent(todo: entity)
            .run()
        XCTAssertFalse(try toggledBack.value.isCompleted as Bool, "Second toggle un-completes it")

        try await deleteTodos(matching: title)
    }

    /// `QuickSnoozeTodoIntent`（Live Activity ボタン用の固定 30 分）。
    /// 対話版の `SnoozeTodoIntent` は `requestChoice` で止まるためここでは扱わない。
    func testQuickSnoozePushesDueDateByThirtyMinutes() async throws {
        let title = uniqueTitle("AITest Snooze")
        let dueDate = Date().addingTimeInterval(60 * 60)

        let created = try await definitions.intents["AddTodoIntent"]
            .makeIntent(title: title, dueDate: dueDate)
            .run()
        let entity: AnyAppEntity = try created.value

        let snoozed = try await definitions.intents["QuickSnoozeTodoIntent"]
            .makeIntent(todo: entity)
            .run()

        let newDueDate: Date = try snoozed.value.dueDate
        XCTAssertEqual(
            newDueDate.timeIntervalSince(dueDate),
            30 * 60,
            accuracy: 1,
            "Quick snooze should push the due date back by exactly 30 minutes"
        )

        try await deleteTodos(matching: title)
    }

    // MARK: - TransientAppEntity

    /// `GetTodoSummaryIntent` が返す `TodoListSummaryEntity`（`TransientAppEntity`）。
    /// Shortcuts の条件分岐がこの各カウントに依存するので、プロパティ名込みで押さえる。
    func testTodoSummaryReflectsNewTodo() async throws {
        let before = try await definitions.intents["GetTodoSummaryIntent"].makeIntent().run()
        let pendingBefore: Int = try before.value.pendingCount

        let title = uniqueTitle("AITest Summary")
        try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()

        let after = try await definitions.intents["GetTodoSummaryIntent"].makeIntent().run()
        let pendingAfter: Int = try after.value.pendingCount

        XCTAssertEqual(pendingAfter, pendingBefore + 1, "Adding a todo increments the pending count")

        try await deleteTodos(matching: title)
    }

    // MARK: - Helpers

    /// 非同期に反映される結果（Spotlight index 等）を待つ。
    private func pollUntil<T>(
        timeout: TimeInterval,
        interval: TimeInterval = 0.5,
        _ produce: () async throws -> T,
        until isSatisfied: (T) -> Bool
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = try await produce()
        while !isSatisfied(latest), Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            latest = try await produce()
        }
        return latest
    }

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
