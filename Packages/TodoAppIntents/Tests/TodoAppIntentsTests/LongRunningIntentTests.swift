//
//  LongRunningIntentTests.swift
//  TodoAppIntents
//
//  バルク完了（`CompleteTodosIntent`）が長時間実行の 3 つの約束を守っていることを守る。
//
//  `LongRunningIntent` は SDK 上 `ProgressReportingIntent` を継承しているため、
//  `progress` の更新はプロトコル準拠ではなく**実装の中身**の問題になる。落としても
//  ビルドもテストも通り、症状は「大量選択のときだけシステムにタスクを打ち切られる」
//  という形でしか出ないので、ソースを真として押さえる（`IntentExecutionTargetsTests`
//  の `everyMutatingIntentDeclaresExecutionTargets` と同じ方針）。
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("Long running intent contract")
struct LongRunningIntentTests {
    private static func source() throws -> String {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()   // TodoAppIntentsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // TodoAppIntents (package root)
            .appending(path: "Sources/TodoAppIntents/Intents/CompleteTodosIntent.swift")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test("進捗を報告している（総数と完了数の両方）")
    func reportsProgress() throws {
        let source = try Self.source()
        // 総数だけ入れて完了数を更新しないと、進捗 0% のまま打ち切られ得る。
        #expect(source.contains("progress.totalUnitCount"))
        #expect(source.contains("progress.completedUnitCount"))
    }

    @Test("バックグラウンドタスクとして走り、キャンセルを観測している")
    func runsAsBackgroundTaskAndObservesCancellation() throws {
        let source = try Self.source()
        #expect(source.contains("performBackgroundTask"))
        #expect(source.contains("onCancel:"))
        // CancellableIntent を宣言しても checkCancellation が無ければ止まらない。
        #expect(source.contains("Task.checkCancellation()"))
    }

    @Test("件数の文言は inflection に任せている")
    func countWordingUsesInflection() throws {
        let source = try Self.source()
        #expect(source.contains("inflect: true"))
        #expect(
            !source.contains("\"todos\""),
            "手書きの複数形は他言語で崩れる。^[\\(n) todo](inflect: true) を使うこと"
        )
    }
}
