//
//  TodoEntityQueryTests.swift
//  IntentTodoUITest
//
//  Entity query 群。ここが壊れると「Shortcuts の一覧が空」「ボタンが無反応」
//  「検索に出ない」といった、他のテストでは捕まらない症状になる。
//

import AppIntents
import AppIntentsTesting
import XCTest

final class TodoEntityQueryTests: AppIntentsTestCase {
    // MARK: - EntityStringQuery

    /// `TodoEntityQuery.entities(matching:)`。Shortcuts の文字列マッチ経路。
    func testEntityQueryMatchesCreatedTodo() async throws {
        let title = uniqueTitle("AITest Query")
        try await addTodo(title: title)

        let matches = try await todoEntity.entities(matching: title)
        XCTAssertEqual(matches.count, 1, "Exactly one todo should match the unique title")
        XCTAssertEqual(try matches[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    // MARK: - id からの解決

    /// `TodoEntityQuery.entities(for:)` は Live Activity / Widget のボタンが押されたときに
    /// システムが `perform()` 前に呼ぶ経路。ここが壊れると「ボタンが無反応」という
    /// 切り分けにくい症状になるので、id からの再解決を直接押さえておく。
    /// 経緯: docs/devlog/03-app-intents-core.md（2026-08-12 の A-3）
    func testEntityResolutionByIdentifier() async throws {
        let title = uniqueTitle("AITest Resolve")
        let entity = try await addTodo(title: title)

        let resolved = try await todoEntity.entities(identifiers: [identifier(of: entity)])

        XCTAssertEqual(resolved.count, 1, "Entity should resolve from its identifier alone")
        XCTAssertEqual(try resolved[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    /// 存在しない id は空配列（throw ではない）。削除済み todo を指す古いボタンを
    /// 押したときに落ちないことの担保。
    func testEntityResolutionOfUnknownIdentifierReturnsEmpty() async throws {
        let resolved = try await todoEntity.entities(identifiers: [UUID().uuidString])
        XCTAssertTrue(resolved.isEmpty)
    }

    // MARK: - Enumerable / suggested

    /// `EnumerableEntityQuery.allEntities()` と `suggestedEntities()`（未完了のみ）。
    func testAllEntitiesIncludesSuggestedIncompleteTodo() async throws {
        let title = uniqueTitle("AITest Enumerate")
        try await addTodo(title: title)

        let all = try await todoEntity.allEntities()
        XCTAssertTrue(
            try all.contains { try $0.title as String == title },
            "allEntities() should include the newly created todo"
        )

        // 追加直後は未完了なので suggestedEntities() にも出る。
        let suggested = try await todoEntity.suggestedEntities()
        XCTAssertTrue(
            try suggested.contains { try $0.title as String == title },
            "suggestedEntities() should include an incomplete todo"
        )

        try await deleteTodos(matching: title)
    }

    /// 完了済みの todo は候補から外れる（`suggestedEntities()` は未完了のみ）。
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

    /// `IndexedEntity` + `@Property(indexingKey:)` の実効性を押さえる。
    /// Intent の戻り値が正しくても Spotlight への index を落とすと Siri / 検索から
    /// 消えるだけで、他のテストには一切引っかからない。
    func testNewTodoIsIndexedInSpotlight() async throws {
        let title = uniqueTitle("AITest Spotlight")

        let before = try await todoEntity.spotlightQuery(title)
        XCTAssertTrue(before.isEmpty, "Todo should not be in Spotlight before it exists")

        try await addTodo(title: title)

        // index は Intent 完了とは非同期。数回リトライしてから判定する。
        let indexed = try await pollUntil(timeout: 10) {
            try await self.todoEntity.spotlightQuery(title)
        } until: { !$0.isEmpty }

        XCTAssertEqual(indexed.count, 1, "Exactly one Spotlight result for the unique title")
        XCTAssertEqual(try indexed[0].title as String, title)

        try await deleteTodos(matching: title)
    }

    /// 削除したら Spotlight からも消える。index の張りっぱなしは
    /// 「検索から開こうとすると何も無い」という体験になる。
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

    // MARK: - 横断検索（@UnionValue）

    /// `SearchEverythingIntent` は `TodoOrCategory`（`@UnionValue`）を返す。
    /// union のメンバー構成が変わると Shortcuts 側の受け取りが壊れる。
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
