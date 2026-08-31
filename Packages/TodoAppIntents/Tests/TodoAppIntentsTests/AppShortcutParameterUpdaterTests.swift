//
//  AppShortcutParameterUpdaterTests.swift
//  TodoAppIntents
//
//  Parameterised App Shortcut phrases stop matching when the suggestions go stale, so this
//  checks that the package-to-app indirection which triggers a refetch stays connected.
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

/// The handler is process-wide, so parallel tests would overwrite each other's.
@Suite("App Shortcut parameter updates", .serialized)
@MainActor
struct AppShortcutParameterUpdaterTests {
    /// Installs a counting handler for the duration of one test.
    private func makeCounter() -> Counter {
        let counter = Counter()
        AppShortcutParameterUpdater.register { counter.increment() }
        return counter
    }

    @MainActor
    private final class Counter {
        private(set) var count = 0
        func increment() { count += 1 }
    }

    @Test("notifyEntitiesChanged が登録済みハンドラを呼ぶ")
    func notifyCallsRegisteredHandler() {
        let counter = makeCounter()
        AppShortcutParameterUpdater.notifyEntitiesChanged()
        #expect(counter.count == 1)
    }

    /// Suggestions must be refetched whenever entities appear or disappear
    /// [Apple: wwdc2023-10102 9:24], which also proves the mutating methods reach
    /// `dataDidChange()`.
    @Test("TodoService の変更が App Shortcut パラメータ更新を促す")
    func mutationTriggersUpdate() throws {
        let counter = makeCounter()
        let service = TodoService(repository: MockTodoRepository())

        let entity = try service.create(
            title: "Parameterized phrase target",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false
        )
        #expect(counter.count == 1, "作成は候補の集合を変える")

        _ = try service.toggleCompletion(todoId: entity.id)
        #expect(counter.count == 2, "完了状態は displayRepresentation に出るので更新が要る")

        try service.delete(todoId: entity.id)
        #expect(counter.count == 3, "削除しても候補に残ると存在しない todo を指すフレーズになる")
    }
}
