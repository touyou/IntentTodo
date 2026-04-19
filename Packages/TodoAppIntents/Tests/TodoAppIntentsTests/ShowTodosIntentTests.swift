//
//  ShowTodosIntentTests.swift
//  TodoAppIntents
//
//  Intent perform() は AppDependencyManager 解決の都合で SPM テストでは
//  動かしにくい。代わりに filter → AppScreenTarget マッピングだけ純関数に
//  切り出してあるので、ここでは 4 ケースを exhaustive にカバーする。
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
        // .completed と .all は同じ画面を開く (どちらも Todo 全体ビュー上で表現するため)
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
