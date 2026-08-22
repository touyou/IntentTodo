//
//  TodoServiceUndoTests.swift
//  TodoAppIntents
//
//  削除の取り消し（`UndoableIntent`）を支える snapshot / restore。
//  「同じ id で戻る」ことが要点で、id が変わると Spotlight index / donation /
//  ウィジェットが握っている参照がまとめて迷子になる。
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("TodoService undo support")
@MainActor
struct TodoServiceUndoTests {
    private func makeService(seed: [TodoItem] = []) -> (TodoService, MockTodoRepository) {
        let repo = MockTodoRepository(initialTodos: seed)
        return (TodoService(repository: repo), repo)
    }

    @Test("restore brings a deleted todo back under the same id")
    func restoreKeepsIdentity() throws {
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        let item = TodoItem(
            title: "task",
            todoDescription: "details",
            isFavorite: true,
            dueDate: due,
            estimatedDuration: 900,
            assigneeName: "Ada"
        )
        item.sortIndex = 3
        let (service, repo) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        #expect(try repo.fetchAll().isEmpty)

        let restored = try service.restore(snapshot)

        // 同じ id で戻ること自体が要点（Spotlight / donation / widget の参照が生きる）。
        #expect(restored.id == item.id.uuidString)
        #expect(restored.title == "task")
        #expect(restored.todoDescription == "details")
        #expect(restored.isFavorite)
        #expect(restored.dueDate == due)
        #expect(restored.assigneeName == "Ada")
        #expect(restored.sortIndex == 3)
        #expect(try repo.fetchAll().count == 1)
    }

    @Test("restore reattaches the category when it still exists")
    func restoreReattachesCategory() throws {
        let category = Domain.Category(name: "Work")
        let item = TodoItem(title: "task")
        item.category = category
        let (service, repo) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        let restored = try service.restore(snapshot)

        #expect(restored.category?.id == category.id.uuidString)
        #expect(try repo.fetchAll().count == 1)
    }

    @Test("restore drops the category when it is gone, rather than failing")
    func restoreWithoutCategory() throws {
        let category = Domain.Category(name: "Work")
        let item = TodoItem(title: "task")
        item.category = category
        let (service, _) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        // カテゴリごと消えた状況を作る（別デバイスでの削除が CloudKit で届いた等）。
        let (emptyService, _) = makeService()
        let restored = try emptyService.restore(snapshot)

        #expect(restored.id == item.id.uuidString)
        #expect(restored.category == nil)
    }

    @Test("restore brings sub-tasks back with their own ids")
    func restoreKeepsSubTasks() throws {
        let subTask = SubTask(title: "step 1", isCompleted: true, orderIndex: 0)
        let item = TodoItem(title: "task")
        item.subTasks = [subTask]
        subTask.parentTodo = item
        let (service, repo) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        try service.restore(snapshot)

        let restored = try #require(try repo.fetch(by: item.id))
        #expect(restored.subTasks?.count == 1)
        #expect(restored.subTasks?.first?.id == subTask.id)
        #expect(restored.subTasks?.first?.isCompleted == true)
    }

    @Test("restore is idempotent when the todo is already back")
    func restoreIsIdempotent() throws {
        let item = TodoItem(title: "task")
        let (service, repo) = makeService(seed: [item])

        let snapshot = try service.snapshot(todoId: item.id.uuidString)
        try service.delete(todoId: item.id.uuidString)
        try service.restore(snapshot)
        try service.restore(snapshot)

        #expect(try repo.fetchAll().count == 1)
    }

    @Test("snapshot throws for an unknown id")
    func snapshotNotFound() {
        let (service, _) = makeService()
        #expect(throws: IntentError.self) {
            _ = try service.snapshot(todoId: UUID().uuidString)
        }
    }
}
