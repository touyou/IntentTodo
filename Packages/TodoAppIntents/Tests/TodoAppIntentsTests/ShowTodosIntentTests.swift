//
//  ShowTodosIntentTests.swift
//  TodoAppIntents
//
//  `perform()` needs `@Dependency` resolution, so only the filter-to-screen mapping is
//  extracted as a pure function; all four cases are covered here.
//

import Testing
@testable import TodoAppIntents

@Suite("ShowTodosIntent")
struct ShowTodosIntentTests {
    @Test("filter .all routes to .todoList")
    func filterAll() {
        #expect(ShowTodosIntent.screenTarget(for: .all) == .todoList)
    }

    @Test("filter .completed routes to .todoList")
    func filterCompleted() {
        // `.completed` and `.all` open the same screen; both are expressed in the full list.
        #expect(ShowTodosIntent.screenTarget(for: .completed) == .todoList)
    }

    @Test("filter .incomplete routes to .incompleteTodos")
    func filterIncomplete() {
        #expect(ShowTodosIntent.screenTarget(for: .incomplete) == .incompleteTodos)
    }

    @Test("filter .favorites routes to .favoriteTodos")
    func filterFavorites() {
        #expect(ShowTodosIntent.screenTarget(for: .favorites) == .favoriteTodos)
    }
}
