//
//  SwiftDataTodoRepositoryTests.swift
//  IntentTodo
//
//  Runs the real implementation against an in-memory store. `MockTodoRepository` satisfies
//  the same protocol without touching `#Predicate`, `SortDescriptor` or `fetchLimit`, so it
//  stays green for failures that only the SwiftData implementation has — `#Predicate` with
//  optional `Date` comparisons has regressed before.
//

import Domain
import Foundation
import SwiftData
import Testing
@testable import Repository

@Suite("SwiftDataTodoRepository")
@MainActor
struct SwiftDataTodoRepositoryTests {
    /// A real store that never touches disk, rebuilt per test so no state leaks.
    ///
    /// **`ModelContext(container)`, not `container.mainContext`.** The latter does not retain
    /// the container, so it is released as soon as this helper returns and the next
    /// `insert` / `save` traps. That surfaces as a process crash rather than a failed
    /// assertion, which says nothing about which test caused it.
    private func makeRepository() throws -> SwiftDataTodoRepository {
        let container = try SharedModelContainer.createInMemoryContainer()
        return SwiftDataTodoRepository(modelContext: ModelContext(container))
    }

    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(offset)
    }

    // MARK: - fetchMostUrgentIncomplete

    /// The path behind `ToggleUrgentTodoIntent`: silently returning nil here would leave the
    /// control claiming there is nothing due while a deadline passes.
    @Test("fetchMostUrgentIncomplete returns the earliest due incomplete todo")
    func mostUrgentPicksEarliestDue() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "later", dueDate: date(3600)))
        try repository.create(TodoItem(title: "soonest", dueDate: date(60)))
        try repository.create(TodoItem(title: "middle", dueDate: date(600)))

        #expect(try repository.fetchMostUrgentIncomplete()?.title == "soonest")
    }

    /// The optional comparison in the predicate: undated todos must not win.
    @Test("fetchMostUrgentIncomplete ignores todos without a due date")
    func mostUrgentIgnoresNilDueDate() throws {
        let repository = try makeRepository()
        try repository.create(TodoItem(title: "no due date"))
        try repository.create(TodoItem(title: "has due date", dueDate: date(1800)))

        #expect(try repository.fetchMostUrgentIncomplete()?.title == "has due date")
    }

    /// The completion half of the predicate: a completed todo never wins, however urgent.
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

    /// `fetchCount` counts without materialising the objects, so it is a different code path
    /// from `fetchIncomplete().count`; a mismatch shows up only in the control and widget.
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
