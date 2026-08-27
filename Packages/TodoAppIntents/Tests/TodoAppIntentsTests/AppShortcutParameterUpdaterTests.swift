//
//  AppShortcutParameterUpdaterTests.swift
//  TodoAppIntents
//
//  パラメータ入りの App Shortcut フレーズ ("Complete <todo> in IntentTodo") は、
//  `updateAppShortcutParameters()` が呼ばれていないと候補が古いまま一致しなくなる。
//  呼び出しはパッケージ → アプリの間接層を経由するので、その線がつながっているかを見る。
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

/// `AppShortcutParameterUpdater` のハンドラはプロセス全体で 1 つなので、
/// 並列実行すると互いのハンドラを上書きし合う。`.serialized` で直列化する。
@Suite("App Shortcut parameter updates", .serialized)
@MainActor
struct AppShortcutParameterUpdaterTests {
    /// 各テストで自前のハンドラを差し込み、呼ばれた回数を数える。
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

    /// entity が増減したら候補を取り直させる必要がある（wwdc2023-10102 9:24）。
    /// `TodoService` の変更メソッドが `dataDidChange()` を通っていることの確認でもある。
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
