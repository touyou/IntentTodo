//
//  TodoFocusFilterTests.swift
//  TodoAppIntents
//
//  集中モード絞り込みの判定と永続化。
//
//  ここが壊れると「Focus を切ったのに一覧が絞られたまま」「Focus 中に失敗通知が
//  黙らされる」という形で出る。どちらもアプリを立ち上げて Focus を切り替えないと
//  気づけないので、値の解釈は純関数に寄せてテストで押さえる。
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("Todo focus filter")
struct TodoFocusFilterTests {
    // MARK: - Fixtures

    private static let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private static func todo(
        id: String,
        categoryID: String? = nil,
        isCompleted: Bool = false,
        dueIn: TimeInterval? = nil
    ) -> TodoAppEntity {
        TodoAppEntity(
            id: id,
            title: "Todo \(id)",
            isCompleted: isCompleted,
            dueDate: dueIn.map { now.addingTimeInterval($0) },
            category: categoryID.map { CategoryAppEntity(id: $0, name: "Category \($0)") }
        )
    }

    private static let work = "11111111-1111-1111-1111-111111111111"
    private static let home = "22222222-2222-2222-2222-222222222222"

    // MARK: - isActive

    @Test("何も設定されていなければ非アクティブ")
    func inactiveWhenNothingConfigured() {
        #expect(!TodoFocusFilter.inactive.isActive)
        #expect(TodoFocusFilter(categoryID: Self.work).isActive)
        #expect(TodoFocusFilter(showsUrgentOnly: true).isActive)
        #expect(TodoFocusFilter(hidesCompleted: true).isActive)
    }

    // MARK: - apply

    @Test("非アクティブな設定は一覧をそのまま通す")
    func inactiveFilterPassesEverything() {
        let todos = [Self.todo(id: "a"), Self.todo(id: "b", isCompleted: true)]
        #expect(TodoFocusFilter.inactive.apply(to: todos, now: Self.now) == todos)
    }

    @Test("カテゴリ指定は他カテゴリと未分類を落とす")
    func categoryFilterKeepsOnlyMatching() {
        let todos = [
            Self.todo(id: "a", categoryID: Self.work),
            Self.todo(id: "b", categoryID: Self.home),
            Self.todo(id: "c")
        ]
        let result = TodoFocusFilter(categoryID: Self.work).apply(to: todos, now: Self.now)
        #expect(result.map(\.id) == ["a"])
    }

    @Test("完了を隠す設定は完了済みを落とす")
    func hidesCompletedDropsCompleted() {
        let todos = [
            Self.todo(id: "a"),
            Self.todo(id: "b", isCompleted: true)
        ]
        let result = TodoFocusFilter(hidesCompleted: true).apply(to: todos, now: Self.now)
        #expect(result.map(\.id) == ["a"])
    }

    @Test("急ぎのみの設定は期限切れと 1 時間以内だけ残す")
    func urgentOnlyKeepsOverdueAndDueSoon() {
        let todos = [
            Self.todo(id: "overdue", dueIn: -60),
            Self.todo(id: "dueSoon", dueIn: 30 * 60),
            Self.todo(id: "later", dueIn: 6 * 3600),
            Self.todo(id: "noDueDate")
        ]
        let result = TodoFocusFilter(showsUrgentOnly: true).apply(to: todos, now: Self.now)
        #expect(result.map(\.id) == ["overdue", "dueSoon"])
    }

    @Test("完了済みは期限を過ぎていても急ぎ扱いにしない")
    func completedIsNeverUrgent() {
        let todos = [Self.todo(id: "done", isCompleted: true, dueIn: -3600)]
        #expect(TodoFocusFilter(showsUrgentOnly: true).apply(to: todos, now: Self.now).isEmpty)
    }

    @Test("複数条件は AND で効く")
    func conditionsCombineWithAnd() {
        let todos = [
            Self.todo(id: "match", categoryID: Self.work, dueIn: -60),
            Self.todo(id: "wrongCategory", categoryID: Self.home, dueIn: -60),
            Self.todo(id: "notUrgent", categoryID: Self.work, dueIn: 6 * 3600),
            Self.todo(id: "completed", categoryID: Self.work, isCompleted: true, dueIn: -60)
        ]
        let filter = TodoFocusFilter(categoryID: Self.work, showsUrgentOnly: true, hidesCompleted: true)
        #expect(filter.apply(to: todos, now: Self.now).map(\.id) == ["match"])
    }

    // MARK: - Notification criteria

    @Test("カテゴリ未指定なら通知は絞らない")
    func noCategoryMeansNoNotificationFiltering() {
        #expect(TodoFocusFilter(showsUrgentOnly: true).allowedNotificationCriteria == nil)
    }

    @Test("通知の許可リストは対象カテゴリとシステム通知を含み、他カテゴリを含まない")
    func allowedCriteriaKeepsSystemNotifications() throws {
        let allowed = try #require(TodoFocusFilter(categoryID: Self.work).allowedNotificationCriteria)
        let predicate = NSPredicate(format: "SELF IN %@", allowed)

        // 失敗通知が黙らされると「何も起きなかった」と区別できなくなる。
        #expect(predicate.evaluate(with: TodoFocusFilter.systemNotificationCriteria))
        #expect(predicate.evaluate(with: TodoFocusFilter.notificationCriteria(categoryID: Self.work)))
        #expect(!predicate.evaluate(with: TodoFocusFilter.notificationCriteria(categoryID: Self.home)))
        #expect(!predicate.evaluate(with: TodoFocusFilter.notificationCriteria(categoryID: nil)))
    }

    // MARK: - Shared storage

    @Test("共有ストレージへ往復しても設定が保たれる")
    func roundTripsThroughSharedDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "TodoFocusFilterTests.roundTrip"))
        defer { defaults.removeObject(forKey: TodoFocusFilter.sharedDefaultsKey) }

        let filter = TodoFocusFilter(
            categoryID: Self.work,
            categoryName: "Work",
            showsUrgentOnly: true,
            hidesCompleted: true
        )
        filter.saveToSharedDefaults(defaults)

        #expect(TodoFocusFilter.loadFromSharedDefaults(defaults) == filter)
    }

    @Test("非アクティブな設定を保存するとキーごと消える")
    func savingInactiveClearsStorage() throws {
        let defaults = try #require(UserDefaults(suiteName: "TodoFocusFilterTests.clear"))
        defer { defaults.removeObject(forKey: TodoFocusFilter.sharedDefaultsKey) }

        TodoFocusFilter(categoryID: Self.work).saveToSharedDefaults(defaults)
        TodoFocusFilter.inactive.saveToSharedDefaults(defaults)

        #expect(defaults.data(forKey: TodoFocusFilter.sharedDefaultsKey) == nil)
        #expect(TodoFocusFilter.loadFromSharedDefaults(defaults) == .inactive)
    }

    @Test("壊れた保存値は非アクティブとして読む")
    func corruptStorageFallsBackToInactive() throws {
        let defaults = try #require(UserDefaults(suiteName: "TodoFocusFilterTests.corrupt"))
        defer { defaults.removeObject(forKey: TodoFocusFilter.sharedDefaultsKey) }

        defaults.set(Data("not json".utf8), forKey: TodoFocusFilter.sharedDefaultsKey)

        #expect(TodoFocusFilter.loadFromSharedDefaults(defaults) == .inactive)
    }

    // MARK: - Intent bridging

    @Test("Intent のパラメータが値型へそのまま落ちる")
    func intentBridgesParametersToValue() {
        let intent = TodoFocusFilterIntent(
            category: CategoryAppEntity(id: Self.work, name: "Work"),
            showsUrgentOnly: true,
            hidesCompleted: false
        )

        #expect(intent.resolvedFilter == TodoFocusFilter(
            categoryID: Self.work,
            categoryName: "Work",
            showsUrgentOnly: true,
            hidesCompleted: false
        ))
    }

    @Test("Focus filter は実行先を固定しない")
    func focusFilterDoesNotPinExecutionTarget() {
        // 実行先は Focus の仕組みが決める（アプリ / AppIntents Extension）。
        // ここを [.main] で固定すると将来 Extension を足したときに噛み合わない。
        #expect(TodoFocusFilterIntent.allowedExecutionTargets == .default)
    }
}
