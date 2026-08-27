//
//  SwiftDataTodoRepositoryTests.swift
//  IntentTodo
//
//  `MockTodoRepository` と `SwiftDataTodoRepository` は同じプロトコルの**別実装**で、
//  後者は `#Predicate` マクロ + `SortDescriptor` + `fetchLimit` に依存する。Mock が
//  緑でも本番だけ壊れる形（optional `Date` 絡みの `#Predicate` は過去にリグレッションを
//  出している）を捕まえるため、in-memory ストアで本番実装そのものを走らせる。
//

import Domain
import Foundation
import SwiftData
import Testing
@testable import Repository

@Suite("SwiftDataTodoRepository")
@MainActor
struct SwiftDataTodoRepositoryTests {
    /// ディスクに触らない実ストア。テストごとに新しいコンテナを作るので状態は漏れない。
    ///
    /// **`container.mainContext` ではなく `ModelContext(container)` を渡す**。前者は
    /// コンテナを retain しないので、ヘルパがコンテナをローカルに閉じ込めた時点で解放され、
    /// 次の `insert` / `save` で SwiftData が `EXC_BREAKPOINT` で落ちる。落ち方が
    /// アサーション失敗ではなくプロセスクラッシュなので、`Restarting after unexpected exit`
    /// が延々と並ぶだけで、どのテストのどの行かは crash report を読むまで分からない。
    private func makeRepository() throws -> SwiftDataTodoRepository {
        let container = try SharedModelContainer.createInMemoryContainer()
        return SwiftDataTodoRepository(modelContext: ModelContext(container))
    }

    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(offset)
    }

    // MARK: - fetchMostUrgentIncomplete

    /// Control Center の `ToggleUrgentTodoIntent` が握っている経路。ここが黙って nil を
    /// 返し続けると「期限が近いタスクなし」と表示されたまま期限を過ぎる。
    @Test("fetchMostUrgentIncomplete returns the earliest due incomplete todo")
    func mostUrgentPicksEarliestDue() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "later", dueDate: date(3600)))
        try repository.create(TodoItem(title: "soonest", dueDate: date(60)))
        try repository.create(TodoItem(title: "middle", dueDate: date(600)))

        #expect(try repository.fetchMostUrgentIncomplete()?.title == "soonest")
    }

    /// `#Predicate { ... && $0.dueDate != nil }` の optional 判定。期限なしの todo が
    /// 混ざっていても、期限つきの最短が選ばれる。
    @Test("fetchMostUrgentIncomplete ignores todos without a due date")
    func mostUrgentIgnoresNilDueDate() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "no due date"))
        try repository.create(TodoItem(title: "has due date", dueDate: date(1800)))

        #expect(try repository.fetchMostUrgentIncomplete()?.title == "has due date")
    }

    /// `#Predicate { !$0.isCompleted ... }` の側。完了済みは期限が最短でも選ばれない。
    @Test("fetchMostUrgentIncomplete skips completed todos")
    func mostUrgentSkipsCompleted() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "done", isCompleted: true, dueDate: date(60)))
        try repository.create(TodoItem(title: "pending", dueDate: date(600)))

        #expect(try repository.fetchMostUrgentIncomplete()?.title == "pending")
    }

    @Test("fetchMostUrgentIncomplete returns nil when nothing qualifies")
    func mostUrgentReturnsNilWhenEmpty() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "no due date"))
        try repository.create(TodoItem(title: "done", isCompleted: true, dueDate: date(60)))

        #expect(try repository.fetchMostUrgentIncomplete() == nil)
    }

    // MARK: - CRUD round-trip

    @Test("create then fetch by id round-trips")
    func createAndFetchByID() throws {
        let repository = try makeRepository()
        let todo = TodoItem(title: "buy milk", dueDate: date(120))
        try repository.create(todo)

        let fetched = try repository.fetch(by: todo.id)
        #expect(fetched?.title == "buy milk")
        #expect(fetched?.dueDate == date(120))
    }

    @Test("fetch by unknown id returns nil")
    func fetchUnknownID() throws {
        let repository = try makeRepository()
        #expect(try repository.fetch(by: UUID()) == nil)
    }

    @Test("delete by id removes the todo")
    func deleteByID() throws {
        let repository = try makeRepository()
        let todo = TodoItem(title: "temporary")
        try repository.create(todo)

        try repository.delete(by: todo.id)
        #expect(try repository.fetch(by: todo.id) == nil)
    }

    @Test("delete by unknown id throws notFound")
    func deleteUnknownIDThrows() throws {
        let repository = try makeRepository()
        #expect(throws: RepositoryError.self) {
            try repository.delete(by: UUID())
        }
    }

    // MARK: - Filtered fetches

    @Test("fetchIncomplete and fetchCompleted partition the store")
    func filteredFetchesPartition() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "done", isCompleted: true))
        try repository.create(TodoItem(title: "pending"))

        #expect(try repository.fetchIncomplete().map(\.title) == ["pending"])
        #expect(try repository.fetchCompleted().map(\.title) == ["done"])
    }

    @Test("fetchFavorites returns only favorites")
    func favoritesOnly() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "starred", isFavorite: true))
        try repository.create(TodoItem(title: "plain"))

        #expect(try repository.fetchFavorites().map(\.title) == ["starred"])
    }

    /// `fetchCount` は本体を materialize せずに数えるため `fetchIncomplete().count` とは
    /// 別コードパス。ズレると Control / Widget の件数表示だけが静かに狂う。
    @Test("incompleteCount matches fetchIncomplete's count")
    func incompleteCountMatchesFetch() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "done", isCompleted: true))
        try repository.create(TodoItem(title: "pending 1"))
        try repository.create(TodoItem(title: "pending 2"))

        #expect(try repository.incompleteCount() == 2)
        #expect(try repository.incompleteCount() == repository.fetchIncomplete().count)
    }

    // MARK: - fetchCategory

    @Test("fetchCategory resolves a stored category by id")
    func fetchCategoryByID() throws {
        let container = try SharedModelContainer.createInMemoryContainer()
        let context = ModelContext(container)
        let repository = SwiftDataTodoRepository(modelContext: context)
        let category = Domain.Category(name: "Work")
        context.insert(category)
        try context.save()

        #expect(try repository.fetchCategory(by: category.id)?.name == "Work")
        #expect(try repository.fetchCategory(by: UUID()) == nil)
    }
}
