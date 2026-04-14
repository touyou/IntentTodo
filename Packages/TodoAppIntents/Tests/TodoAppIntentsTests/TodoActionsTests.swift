//
//  TodoActionsTests.swift
//  TodoAppIntents
//
//  Tests for the shared Todo business logic core. Intent perform() 経由のテストは
//  @Dependency を AppDependencyManager から解決する必要があり SPM テストでは
//  再現が難しいため、ロジック本体は TodoActions の関数単位でカバーする。
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("TodoActions")
@MainActor
struct TodoActionsTests {
    private func makeRepository(seed: [TodoItem] = []) -> MockTodoRepository {
        MockTodoRepository(initialTodos: seed)
    }

    // MARK: - create

    @Test("create persists a new todo with trimmed title")
    func createPersistsTrimmed() throws {
        let repo = makeRepository()
        let entity = try TodoActions.create(
            title: "  Buy groceries  ",
            todoDescription: "store list",
            dueDate: nil,
            isFavorite: false,
            using: repo
        )
        #expect(entity.title == "Buy groceries")
        #expect(try repo.fetchAll().count == 1)
    }

    @Test("create rejects empty or whitespace-only title")
    func createRejectsEmpty() {
        let repo = makeRepository()
        #expect(throws: IntentError.self) {
            _ = try TodoActions.create(title: "", todoDescription: nil, dueDate: nil, isFavorite: false, using: repo)
        }
        #expect(throws: IntentError.self) {
            _ = try TodoActions.create(title: "   ", todoDescription: nil, dueDate: nil, isFavorite: false, using: repo)
        }
    }

    // MARK: - toggleCompletion

    @Test("toggleCompletion flips and persists")
    func toggleCompletionFlips() throws {
        let item = TodoItem(title: "task")
        let repo = makeRepository(seed: [item])
        let result = try TodoActions.toggleCompletion(todoId: item.id.uuidString, using: repo)
        #expect(result.isNowCompleted == true)
        #expect(try repo.fetch(by: item.id)?.isCompleted == true)
    }

    @Test("toggleCompletion throws for unknown id")
    func toggleCompletionNotFound() {
        let repo = makeRepository()
        #expect(throws: IntentError.self) {
            _ = try TodoActions.toggleCompletion(todoId: UUID().uuidString, using: repo)
        }
    }

    // MARK: - toggleFavorite

    @Test("toggleFavorite flips and persists")
    func toggleFavoriteFlips() throws {
        let item = TodoItem(title: "task")
        let repo = makeRepository(seed: [item])
        let entity = try TodoActions.toggleFavorite(todoId: item.id.uuidString, using: repo)
        #expect(entity.isFavorite == true)
    }

    // MARK: - delete

    @Test("delete removes the todo")
    func deleteRemoves() throws {
        let item = TodoItem(title: "task")
        let repo = makeRepository(seed: [item])
        try TodoActions.delete(todoId: item.id.uuidString, using: repo)
        #expect(try repo.fetchAll().isEmpty)
    }

    @Test("delete throws for invalid id string")
    func deleteInvalidId() {
        let repo = makeRepository()
        #expect(throws: IntentError.self) {
            try TodoActions.delete(todoId: "not-a-uuid", using: repo)
        }
    }

    // MARK: - snooze

    @Test("snooze adds the interval to dueDate")
    func snoozeAddsInterval() throws {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let item = TodoItem(title: "task", dueDate: baseDate)
        let repo = makeRepository(seed: [item])
        let result = try TodoActions.snooze(todoId: item.id.uuidString, by: 60, using: repo)
        #expect(result.newDueDate == baseDate.addingTimeInterval(60))
    }

    @Test("snooze throws when todo has no dueDate")
    func snoozeNoDueDate() {
        let item = TodoItem(title: "task")
        let repo = makeRepository(seed: [item])
        #expect(throws: IntentError.self) {
            _ = try TodoActions.snooze(todoId: item.id.uuidString, using: repo)
        }
    }
}
