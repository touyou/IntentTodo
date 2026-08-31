//
//  TodoAttributeWritePathTests.swift
//  TodoAppIntents
//
//  Covers *writing* the schema-derived attributes. Three things, none of which is simply
//  "does it save":
//
//  - normalisation (trimming, empties, duplicates) agrees with the `Set<String>` the entity
//    boundary exposes
//  - replace / clear / leave alone stay distinguishable through `FieldUpdate`
//  - the read side can rebuild `Calendar.RecurrenceRule` and `locationTrigger` from what was
//    written
//
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
        // Duplicate detection ignores case and diacritics, so "WORK" is the same tag: two
        // entries that search cannot tell apart should not both exist.
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

    // MARK: - update: location

    @Test("update が場所名を書き換え、前の座標を残さない")
    func updateReplacesLocationAndDropsStaleCoordinate() throws {
        let item = TodoItem(title: "task")
        item.locationName = "Office"
        item.locationLatitude = 35.681
        item.locationLongitude = 139.767
        let (service, repo) = makeService(seed: [item])

        _ = try service.update(todoId: item.id.uuidString, locationName: .set(" City Hall "))

        let updated = try stored(in: repo)
        #expect(updated.locationName == "City Hall")
        // The coordinate described "Office", so keeping it would point the trigger at the
        // wrong place.
        #expect(updated.locationLatitude == nil)
        #expect(updated.locationLongitude == nil)
    }

    @Test("update の .set(nil) / 空文字が場所を外す")
    func updateClearsLocation() throws {
        let item = TodoItem(title: "task")
        item.locationName = "Office"
        item.locationLatitude = 35.681
        item.locationLongitude = 139.767
        item.locationTriggerEvent = "arrive"
        let (service, repo) = makeService(seed: [item])

        _ = try service.update(todoId: item.id.uuidString, locationName: .set("   "))

        let updated = try stored(in: repo)
        #expect(updated.locationName == nil)
        #expect(updated.locationLatitude == nil)
        #expect(updated.locationLongitude == nil)
        // The event survives on its own: it becomes inert, and a place added later revives
        // it, matching how create treats an event with no place.
        #expect(updated.locationTriggerEvent == "arrive")
        #expect(TodoAppEntity(from: updated).locationTrigger == nil)
    }

    @Test("update の場所名が同じなら座標は保たれる")
    func updateKeepsCoordinateForSameLocationName() throws {
        let item = TodoItem(title: "task")
        item.locationName = "Office"
        item.locationLatitude = 35.681
        item.locationLongitude = 139.767
        let (service, repo) = makeService(seed: [item])

        // The app's edit form always sends every field, so re-saving an untouched location
        // must not throw the coordinate away.
        _ = try service.update(todoId: item.id.uuidString, locationName: .set("Office"))

        let updated = try stored(in: repo)
        #expect(updated.locationLatitude == 35.681)
        #expect(updated.locationLongitude == 139.767)
    }

    // MARK: - Rebuilding on Read

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
        // Still stored, so a location can be added later, but no trigger can be built yet.
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

    // MARK: - Normalisation Helpers

    @Test("normalized(tags:) は与えられた順序を保つ")
    func normalizationPreservesOrder() {
        #expect(TodoAttributes.normalized(tags: ["z", "a", "z", "m"]) == ["z", "a", "m"])
    }
}
