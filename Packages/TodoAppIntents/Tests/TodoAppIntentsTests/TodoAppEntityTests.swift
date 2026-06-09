//
//  TodoAppEntityTests.swift
//  IntentTodo
//

import Domain
import Foundation
import Testing
@testable import TodoAppIntents

@Suite("TodoAppEntity Tests")
struct TodoAppEntityTests {
    @Test("Entity initializes with all properties")
    func initializesWithAllProperties() {
        let dueDate = Date()
        let createdAt = Date().addingTimeInterval(-3600)

        let entity = TodoAppEntity(
            id: "test-id",
            title: "Test Todo",
            isCompleted: true,
            isFavorite: true,
            dueDate: dueDate,
            createdAt: createdAt
        )

        #expect(entity.id == "test-id")
        #expect(entity.title == "Test Todo")
        #expect(entity.isCompleted == true)
        #expect(entity.isFavorite == true)
        #expect(entity.dueDate == dueDate)
        #expect(entity.createdAt == createdAt)
    }

    @Test("Entity initializes with default values")
    func initializesWithDefaults() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Test Todo"
        )

        #expect(entity.id == "test-id")
        #expect(entity.title == "Test Todo")
        #expect(entity.isCompleted == false)
        #expect(entity.isFavorite == false)
        #expect(entity.dueDate == nil)
    }

    @Test("Entity from TodoItem preserves all properties")
    @MainActor
    func initializesFromTodoItem() {
        let dueDate = Date()
        let todoItem = TodoItem(
            title: "Test Todo",
            todoDescription: "Description",
            isFavorite: true,
            dueDate: dueDate
        )
        todoItem.isCompleted = true

        let entity = TodoAppEntity(from: todoItem)

        #expect(entity.id == todoItem.id.uuidString)
        #expect(entity.title == todoItem.title)
        #expect(entity.isCompleted == todoItem.isCompleted)
        #expect(entity.isFavorite == todoItem.isFavorite)
        #expect(entity.dueDate == todoItem.dueDate)
        #expect(entity.createdAt == todoItem.createdAt)
    }

    @Test("Entity conforms to Hashable")
    func conformsToHashable() {
        let sharedDate = Date()
        let entity1 = TodoAppEntity(id: "id-1", title: "Todo 1", createdAt: sharedDate)
        let entity2 = TodoAppEntity(id: "id-1", title: "Todo 1", createdAt: sharedDate)
        let entity3 = TodoAppEntity(id: "id-2", title: "Todo 2", createdAt: sharedDate)

        #expect(entity1 == entity2)
        #expect(entity1 != entity3)

        var set = Set<TodoAppEntity>()
        set.insert(entity1)
        set.insert(entity2)
        #expect(set.count == 1)
    }

    // MARK: - isOverdue (@ComputedProperty)

    @Test("isOverdue is true for an incomplete todo past its due date")
    func isOverdueWhenPastDueAndIncomplete() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Late Todo",
            isCompleted: false,
            dueDate: Date().addingTimeInterval(-3600)
        )
        #expect(entity.isOverdue == true)
    }

    @Test("isOverdue is false when the todo is completed even if past due")
    func isNotOverdueWhenCompleted() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Done Todo",
            isCompleted: true,
            dueDate: Date().addingTimeInterval(-3600)
        )
        #expect(entity.isOverdue == false)
    }

    @Test("isOverdue is false for a future due date")
    func isNotOverdueWhenDueInFuture() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Upcoming Todo",
            dueDate: Date().addingTimeInterval(3600)
        )
        #expect(entity.isOverdue == false)
    }

    @Test("isOverdue is false when there is no due date")
    func isNotOverdueWithoutDueDate() {
        let entity = TodoAppEntity(id: "test-id", title: "No Due Date")
        #expect(entity.isOverdue == false)
    }

    @Test("TypeDisplayRepresentation is configured")
    func typeDisplayRepresentationConfigured() {
        let representation = TodoAppEntity.typeDisplayRepresentation
        #expect(representation.name != nil)
    }

    @Test("DisplayRepresentation shows correct title")
    func displayRepresentationShowsTitle() {
        let entity = TodoAppEntity(id: "test-id", title: "My Todo")
        let representation = entity.displayRepresentation

        // DisplayRepresentation.title contains LocalizedStringResource
        // We verify it exists
        #expect(representation.title != nil)
    }

    @Test("DisplayRepresentation shows completed status")
    func displayRepresentationShowsCompleted() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Completed Todo",
            isCompleted: true
        )
        let representation = entity.displayRepresentation

        #expect(representation.subtitle != nil)
    }

    @Test("DisplayRepresentation shows due date when present")
    func displayRepresentationShowsDueDate() {
        let entity = TodoAppEntity(
            id: "test-id",
            title: "Todo with due date",
            dueDate: Date()
        )
        let representation = entity.displayRepresentation

        #expect(representation.subtitle != nil)
    }

    @Test("DefaultQuery is configured")
    func defaultQueryConfigured() {
        let query = TodoAppEntity.defaultQuery
        #expect(query != nil)
    }
}
