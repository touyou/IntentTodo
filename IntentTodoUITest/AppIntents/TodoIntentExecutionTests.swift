//
//  TodoIntentExecutionTests.swift
//  IntentTodoUITest
//
//  Intent を実経路（Siri / Shortcuts と同じスタック）で走らせる。
//

import AppIntents
import AppIntentsTesting
import XCTest

final class TodoIntentExecutionTests: AppIntentsTestCase {
    // MARK: - 作成

    /// `AddTodoIntent` を実経路で走らせ、作られた entity が query から見えることまで確認する。
    func testAddTodoIntentRunsAndPersists() async throws {
        let title = uniqueTitle("AITest Add")

        // Intent は型名で作り、パラメータは @Parameter のラベルで渡す。
        try await intent("AddTodoIntent").makeIntent(title: title).run()

        let matches = try await todoEntity.entities(matching: title)
        XCTAssertFalse(matches.isEmpty, "Added todo should be found by entity query")

        try await deleteTodos(matching: title)
    }

    // MARK: - 完了トグル

    /// `ToggleTodoCompletionIntent` は Siri / UI / Widget / Live Activity 共通の経路。
    /// FromExtension 分離を撤去した際にここへ副作用を寄せたので、往復を押さえておく。
    /// 経緯: docs/devlog/03-app-intents-core.md（2026-08-12 の撤去）
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

    // MARK: - スヌーズ

    /// `QuickSnoozeTodoIntent`（Live Activity ボタン用の固定 30 分）。
    /// 対話版の `SnoozeTodoIntent` は `requestChoice` で応答待ちになり
    /// AppIntentsTesting からは走らせられないため、ここでは扱わない。
    func testQuickSnoozePushesDueDateByThirtyMinutes() async throws {
        let title = uniqueTitle("AITest Snooze")
        let dueDate = Date().addingTimeInterval(60 * 60)

        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, dueDate: dueDate)
            .run()
        let entity: AnyAppEntity = try created.value

        let snoozed = try await intent("QuickSnoozeTodoIntent").makeIntent(todo: entity).run()

        let newDueDate: Date = try snoozed.value.dueDate
        XCTAssertEqual(
            newDueDate.timeIntervalSince(dueDate),
            30 * 60,
            accuracy: 1,
            "Quick snooze should push the due date back by exactly 30 minutes"
        )

        try await deleteTodos(matching: title)
    }

    // MARK: - 部分更新（IntentParameter.valueState）

    /// `UpdateTodoIntent` は「新値 / 明示クリア / 据え置き」を `valueState` で区別する。
    /// **パラメータを省略した場合**は `.unset` = 据え置き。
    func testUpdateLeavesOmittedParametersUntouched() async throws {
        let title = uniqueTitle("AITest Update Keep")
        let dueDate = Date().addingTimeInterval(3600)
        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, todoDescription: "keep me", dueDate: dueDate)
            .run()
        let entity: AnyAppEntity = try created.value

        // title だけ渡す → description / dueDate は据え置きになるはず。
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

    /// **明示的に nil を渡した場合**は `.set(nil)` = クリア。
    /// ここが `.unset` と同じ扱いに退化すると「Shortcuts で説明を消せない」という
    /// 静かな不具合になる（他のテストでは捕まらない）。
    func testUpdateClearsExplicitlyNilledParameter() async throws {
        let title = uniqueTitle("AITest Update Clear")
        let created = try await intent("AddTodoIntent")
            .makeIntent(title: title, todoDescription: "clear me")
            .run()
        let entity: AnyAppEntity = try created.value
        XCTAssertEqual(try created.value.todoDescription as String, "clear me")

        // `makeIntent(todoDescription: nil)` は「引数を渡さなかった」= `.unset` になる。
        // 明示的な null を表現するには、`Optional` 自身が `IntentValueExpressing` に
        // 適合していることを使って **型付きの nil** を渡す。
        let explicitNull: any IntentValueExpressing = String?.none
        let cleared = try await intent("UpdateTodoIntent")
            .makeIntent(todo: entity, todoDescription: explicitNull)
            .run()

        let remaining: String? = try? cleared.value.todoDescription
        XCTAssertNil(remaining, "Explicit nil (.set(nil)) must clear the value")

        try await deleteTodos(matching: title)
    }

    // MARK: - バルク処理

    /// `CompleteTodosIntent` は `LongRunningIntent` + `CancellableIntent` +
    /// `EntityCollection` + `allowedExecutionTargets = [.main]` を一度に使う。
    /// 実行プロセス指定を含めて実際に完走することを押さえる。
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

    /// `DeleteTodosIntent`（`DeleteIntent`）でまとめて消える。
    func testBulkDeleteRemovesAllTargets() async throws {
        let prefix = uniqueTitle("AITest BulkDelete")
        let first = try await addTodo(title: "\(prefix) 1")
        let second = try await addTodo(title: "\(prefix) 2")

        try await intent("DeleteTodosIntent").makeIntent(entities: [first, second]).run()

        let remaining = try await todoEntity.entities(matching: prefix)
        XCTAssertTrue(remaining.isEmpty, "Bulk delete should remove every entity passed in")
    }

    // MARK: - 集計（TransientAppEntity）

    /// `GetTodoSummaryIntent` が返す `TodoListSummaryEntity`（`TransientAppEntity`）。
    /// Shortcuts の条件分岐がこの各カウントに依存するので、プロパティ名込みで押さえる。
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

    // MARK: - 複数 Intent の連鎖

    /// Shortcuts でユーザーが組むのと同じように、Intent の結果を次の Intent へ渡す。
    func testAddThenShowChain() async throws {
        let title = uniqueTitle("AITest Chain")
        try await addTodo(title: title)

        try await intent("ShowTodosIntent").makeIntent().run()

        try await deleteTodos(matching: title)
    }
}
