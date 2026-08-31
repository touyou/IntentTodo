//
//  LongRunningIntentTests.swift
//  TodoAppIntents
//
//  Checks the three obligations of the bulk-complete intent.
//
//  `LongRunningIntent` inherits `ProgressReportingIntent`, so updating `progress` is a matter
//  of implementation rather than conformance: dropping it builds and tests clean, and only
//  shows up as the system cutting the task short on large selections. Hence reading the
//  source, as in `IntentExecutionTargetsTests`.
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
        // A total with no completed count leaves progress at 0% and invites termination.
        #expect(source.contains("progress.totalUnitCount"))
        #expect(source.contains("progress.completedUnitCount"))
    }

    @Test("バックグラウンドタスクとして走り、キャンセルを観測している")
    func runsAsBackgroundTaskAndObservesCancellation() throws {
        let source = try Self.source()
        #expect(source.contains("performBackgroundTask"))
        #expect(source.contains("onCancel:"))
        // Conforming to `CancellableIntent` does nothing without `checkCancellation`.
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
