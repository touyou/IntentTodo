//
//  TodoServiceTests.swift
//  TodoAppIntents
//
//  Tests for the shared Todo business logic core. Intent perform() 経由のテストは
//  @Dependency を AppDependencyManager から解決する必要があり SPM テストでは
//  再現が難しいため、ロジック本体は TodoService のメソッド単位でカバーする。
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("TodoService")
@MainActor
struct TodoServiceTests {
    private func makeService(seed: [TodoItem] = []) -> (TodoService, MockTodoRepository) {
        let repo = MockTodoRepository(initialTodos: seed)
        return (TodoService(repository: repo), repo)
    }

    // MARK: - create

    @Test("create persists a new todo with trimmed title")
    func createPersistsTrimmed() throws {
        let (service, repo) = makeService()
        let entity = try service.create(
            title: "  Buy groceries  ",
            todoDescription: "store list",
            dueDate: nil,
            isFavorite: false
        )
        #expect(entity.title == "Buy groceries")
        #expect(try repo.fetchAll().count == 1)
    }

    @Test("create rejects empty or whitespace-only title")
    func createRejectsEmpty() {
        let (service, _) = makeService()
        #expect(throws: IntentError.self) {
            _ = try service.create(title: "", todoDescription: nil, dueDate: nil, isFavorite: false)
        }
        #expect(throws: IntentError.self) {
            _ = try service.create(title: "   ", todoDescription: nil, dueDate: nil, isFavorite: false)
        }
    }

    // MARK: - toggleCompletion

    @Test("toggleCompletion flips and persists")
    func toggleCompletionFlips() throws {
        let item = TodoItem(title: "task")
        let (service, repo) = makeService(seed: [item])
        let result = try service.toggleCompletion(todoId: item.id.uuidString)
        #expect(result.isNowCompleted == true)
        #expect(try repo.fetch(by: item.id)?.isCompleted == true)
    }

    @Test("toggleCompletion bumps modifiedAt forward")
    func toggleCompletionBumpsModifiedAt() throws {
        let item = TodoItem(title: "task")
        let originalModifiedAt = item.modifiedAt
        Thread.sleep(forTimeInterval: 0.05)
        let (service, _) = makeService(seed: [item])
        _ = try service.toggleCompletion(todoId: item.id.uuidString)
        #expect(item.modifiedAt > originalModifiedAt)
    }

    @Test("toggleCompletion throws for unknown id")
    func toggleCompletionNotFound() {
        let (service, _) = makeService()
        #expect(throws: IntentError.self) {
            _ = try service.toggleCompletion(todoId: UUID().uuidString)
        }
    }

    @Test("toggleCompletion throws for invalid id string")
    func toggleCompletionInvalidId() {
        let (service, _) = makeService()
        #expect(throws: IntentError.self) {
            _ = try service.toggleCompletion(todoId: "not-a-uuid")
        }
    }

    // MARK: - toggleFavorite

    @Test("toggleFavorite flips and persists")
    func toggleFavoriteFlips() throws {
        let item = TodoItem(title: "task")
        let (service, _) = makeService(seed: [item])
        let entity = try service.toggleFavorite(todoId: item.id.uuidString)
        #expect(entity.isFavorite == true)
    }

    // MARK: - delete

    @Test("delete removes the todo")
    func deleteRemoves() throws {
        let item = TodoItem(title: "task")
        let (service, repo) = makeService(seed: [item])
        try service.delete(todoId: item.id.uuidString)
        #expect(try repo.fetchAll().isEmpty)
    }

    @Test("delete throws for invalid id string")
    func deleteInvalidId() {
        let (service, _) = makeService()
        #expect(throws: IntentError.self) {
            try service.delete(todoId: "not-a-uuid")
        }
    }

    // MARK: - snooze

    @Test("snooze adds the interval to dueDate")
    func snoozeAddsInterval() throws {
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let item = TodoItem(title: "task", dueDate: baseDate)
        let (service, _) = makeService(seed: [item])
        let result = try service.snooze(todoId: item.id.uuidString, by: 60)
        #expect(result.newDueDate == baseDate.addingTimeInterval(60))
    }

    @Test("snooze throws when todo has no dueDate")
    func snoozeNoDueDate() {
        let item = TodoItem(title: "task")
        let (service, _) = makeService(seed: [item])
        #expect(throws: IntentError.self) {
            _ = try service.snooze(todoId: item.id.uuidString)
        }
    }

    // MARK: - toggleMostUrgentTodo

    @Test("toggleMostUrgentTodo picks earliest due and flips")
    func toggleMostUrgentPicksEarliest() throws {
        let now = Date()
        let laterItem = TodoItem(title: "later", dueDate: now.addingTimeInterval(7200))
        let earlyItem = TodoItem(title: "early", dueDate: now.addingTimeInterval(60))
        let (service, repo) = makeService(seed: [laterItem, earlyItem])

        let result = try service.toggleMostUrgentTodo()
        #expect(result?.title == "early")
        #expect(result?.isNowCompleted == true)
        #expect(try repo.fetch(by: earlyItem.id)?.isCompleted == true)
        #expect(try repo.fetch(by: laterItem.id)?.isCompleted == false)
    }

    @Test("toggleMostUrgentTodo returns nil when no due incomplete todo")
    func toggleMostUrgentEmpty() throws {
        let noDueItem = TodoItem(title: "no due")
        let (service, _) = makeService(seed: [noDueItem])
        let result = try service.toggleMostUrgentTodo()
        #expect(result == nil)
    }

    // MARK: - listTodos / incompleteCount

    @Test("listTodos filters by incomplete")
    func listTodosIncomplete() throws {
        let open = TodoItem(title: "open")
        let done = TodoItem(title: "done")
        done.isCompleted = true
        let (service, _) = makeService(seed: [open, done])
        let entities = try service.listTodos(filter: .incomplete)
        #expect(entities.count == 1)
        #expect(entities.first?.title == "open")
    }

    @Test("listTodos filters by completed")
    func listTodosCompleted() throws {
        let open = TodoItem(title: "open")
        let done = TodoItem(title: "done")
        done.isCompleted = true
        let (service, _) = makeService(seed: [open, done])
        let entities = try service.listTodos(filter: .completed)
        #expect(entities.count == 1)
        #expect(entities.first?.title == "done")
    }

    @Test("incompleteCount reflects repository state")
    func incompleteCountMatches() throws {
        let open1 = TodoItem(title: "o1")
        let open2 = TodoItem(title: "o2")
        let done = TodoItem(title: "done")
        done.isCompleted = true
        let (service, _) = makeService(seed: [open1, open2, done])
        #expect(try service.incompleteCount() == 2)
    }
}
