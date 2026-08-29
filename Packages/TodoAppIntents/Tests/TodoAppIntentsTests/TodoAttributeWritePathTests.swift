//
//  TodoAttributeWritePathTests.swift
//  TodoAppIntents
//
//  `.reminders.reminder` 由来の属性（tags / urls / recurrence / locationTriggerEvent）を
//  **書ける**ことのテスト。#83 では entity 側の露出だけを入れたので、値が変わる経路が
//  1 つも無かった。ここで押さえるのは「保存されるか」ではなく次の 3 つ:
//
//  - 正規化（trim / 空要素 / 重複）が entity 境界の型（`Set<String>`）と食い違わないこと
//  - 置き換え / クリア / 放置の三状態が `FieldUpdate` を通って区別されること
//  - 読み取り側の組み立て（`Calendar.RecurrenceRule` / `locationTrigger`）が
//    書いた値から成立すること
//
//  経緯: docs/devlog/2026-08-29-attribute-write-paths.md
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("reminders 属性の書き込み経路")
@MainActor
struct TodoAttributeWritePathTests {
    private func makeService(seed: [TodoItem] = []) -> (TodoService, MockTodoRepository) {
        let repo = MockTodoRepository(initialTodos: seed)
        return (TodoService(repository: repo), repo)
    }

    private func stored(in repo: MockTodoRepository) throws -> TodoItem {
        guard let item = try repo.fetchAll().first else {
            throw IntentError.notFound("no todo stored")
        }
        return item
    }

    // MARK: - create

    @Test("create が 4 属性すべてを保存する")
    func createPersistsSchemaAttributes() throws {
        let (service, repo) = makeService()
        _ = try service.create(
            title: "renew passport",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            locationName: "City Hall",
            locationLatitude: 35.0,
            locationLongitude: 139.0,
            tags: ["errand", "admin"],
            urls: [URL(string: "https://example.com/passport")!],
            recurrenceFrequency: .yearly,
            recurrenceInterval: 10,
            locationTriggerEvent: .arrive
        )

        let item = try stored(in: repo)
        #expect(item.tags == ["errand", "admin"])
        #expect(item.urls == [URL(string: "https://example.com/passport")!])
        #expect(item.recurrenceFrequency == "yearly")
        #expect(item.recurrenceInterval == 10)
        #expect(item.locationTriggerEvent == "arrive")
    }

    @Test("create のタグは trim / 空要素除去 / 重複排除される")
    func createNormalizesTags() throws {
        let (service, repo) = makeService()
        // 重複判定は大文字小文字 / ダイアクリティカルマークを無視するので "WORK" は同じタグ
        // （検索の `localizedStandardContains` が区別しないものを 2 件持たない）。
        _ = try service.create(
            title: "task",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            tags: ["  Work ", "", "   ", "WORK", "home"]
        )
        #expect(try stored(in: repo).tags == ["Work", "home"])
    }

    @Test("create のリンクは重複排除される")
    func createDeduplicatesURLs() throws {
        let (service, repo) = makeService()
        let link = URL(string: "https://example.com")!
        _ = try service.create(
            title: "task",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            urls: [link, link]
        )
        #expect(try stored(in: repo).urls == [link])
    }

    @Test("create の recurrenceInterval は 1 を下回らない")
    func createFloorsRecurrenceInterval() throws {
        let (service, repo) = makeService()
        _ = try service.create(
            title: "task",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            recurrenceFrequency: .weekly,
            recurrenceInterval: 0
        )
        #expect(try stored(in: repo).recurrenceInterval == TodoRecurrenceFrequency.minimumInterval)
    }

    // MARK: - update

    @Test("update の .set が値を置き換える")
    func updateReplacesValues() throws {
        let item = TodoItem(title: "task")
        item.tags = ["old"]
        item.urls = [URL(string: "https://old.example.com")!]
        let (service, repo) = makeService(seed: [item])

        _ = try service.update(
            todoId: item.id.uuidString,
            tags: .set(["new", "new"]),
            urls: .set([URL(string: "https://new.example.com")!]),
            recurrenceFrequency: .set(.monthly),
            recurrenceInterval: .set(3),
            locationTriggerEvent: .set(.depart)
        )

        let updated = try stored(in: repo)
        #expect(updated.tags == ["new"])
        #expect(updated.urls == [URL(string: "https://new.example.com")!])
        #expect(updated.recurrenceFrequency == "monthly")
        #expect(updated.recurrenceInterval == 3)
        #expect(updated.locationTriggerEvent == "depart")
    }

    @Test("update の .unchanged は既存値に触らない")
    func updateLeavesUnchangedFieldsAlone() throws {
        let item = TodoItem(title: "task")
        item.tags = ["keep"]
        item.recurrenceFrequency = "daily"
        item.locationTriggerEvent = "arrive"
        let (service, repo) = makeService(seed: [item])

        _ = try service.update(todoId: item.id.uuidString, title: .set("renamed"))

        let updated = try stored(in: repo)
        #expect(updated.title == "renamed")
        #expect(updated.tags == ["keep"])
        #expect(updated.recurrenceFrequency == "daily")
        #expect(updated.locationTriggerEvent == "arrive")
    }

    @Test("update の .set(nil) / 空配列がフィールドをクリアする")
    func updateClearsFields() throws {
        let item = TodoItem(title: "task")
        item.tags = ["gone"]
        item.urls = [URL(string: "https://example.com")!]
        item.recurrenceFrequency = "daily"
        item.locationTriggerEvent = "arrive"
        let (service, repo) = makeService(seed: [item])

        _ = try service.update(
            todoId: item.id.uuidString,
            tags: .set([]),
            urls: .set([]),
            recurrenceFrequency: .set(nil),
            locationTriggerEvent: .set(nil)
        )

        let updated = try stored(in: repo)
        #expect(updated.tags.isEmpty)
        #expect(updated.urls.isEmpty)
        #expect(updated.recurrenceFrequency == nil)
        #expect(updated.locationTriggerEvent == nil)
    }

    // MARK: - 読み取り側の組み立て

    @Test("書いた頻度と間隔から Calendar.RecurrenceRule が組み直される")
    func writtenRecurrenceRebuildsRule() throws {
        let (service, repo) = makeService()
        _ = try service.create(
            title: "rent",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            recurrenceFrequency: .monthly,
            recurrenceInterval: 2
        )
        let entity = TodoAppEntity(from: try stored(in: repo))
        #expect(entity.recurrence?.frequency == .monthly)
        #expect(entity.recurrence?.interval == 2)
    }

    @Test("locationTriggerEvent だけでは trigger にならない（場所が要る）")
    func triggerNeedsBothHalves() throws {
        let (service, repo) = makeService()
        _ = try service.create(
            title: "task",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            locationTriggerEvent: .arrive
        )
        let item = try stored(in: repo)
        // 保存自体はされる（場所を後から足せる）が、entity 側は組み立てられない。
        #expect(item.locationTriggerEvent == "arrive")
        #expect(TodoAppEntity(from: item).locationTrigger == nil)
    }

    @Test("場所と event が揃うと trigger が組み立てられる")
    func triggerBuildsWithPlaceAndEvent() throws {
        let (service, repo) = makeService()
        _ = try service.create(
            title: "task",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            locationName: "Office",
            locationLatitude: 35.681,
            locationLongitude: 139.767,
            locationTriggerEvent: .depart
        )
        let trigger = TodoAppEntity(from: try stored(in: repo)).locationTrigger
        #expect(trigger?.event == .depart)
    }

    // MARK: - undo

    @Test("snapshot / restore が 4 属性を往復する")
    func snapshotRoundTripsSchemaAttributes() throws {
        let item = TodoItem(title: "task")
        item.tags = ["a", "b"]
        item.urls = [URL(string: "https://example.com")!]
        item.recurrenceFrequency = "weekly"
        item.recurrenceInterval = 4
        item.locationTriggerEvent = "depart"
        let (service, repo) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        _ = try service.restore(snapshot)

        let restored = try stored(in: repo)
        #expect(restored.tags == ["a", "b"])
        #expect(restored.urls == [URL(string: "https://example.com")!])
        #expect(restored.recurrenceFrequency == "weekly")
        #expect(restored.recurrenceInterval == 4)
        #expect(restored.locationTriggerEvent == "depart")
    }

    // MARK: - 正規化ヘルパー単体

    @Test("normalized(tags:) は与えられた順序を保つ")
    func normalizationPreservesOrder() {
        #expect(TodoAttributes.normalized(tags: ["z", "a", "z", "m"]) == ["z", "a", "m"])
    }
}
