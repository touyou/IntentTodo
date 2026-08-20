//
//  IntentExecutionTargetsTests.swift
//  TodoAppIntents
//
//  SwiftData を書き換える Intent が実行プロセスをアプリ本体に固定していることを守る。
//
//  この指定を落とすとビルドもテストも通ってしまい、症状は「アプリ未起動のときだけ
//  Widget Extension プロセスが同じストアに書く」という形でしか出ない。
//  詳細: docs/insights/03-app-intents-core.md（allowedExecutionTargets）
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

/// 1 件分の期待値。パラメータ化テストの引数にするため型名を文字列で持つ。
struct MutatingIntentCase: Sendable, CustomStringConvertible {
    let name: String
    let targets: IntentExecutionTargets

    var description: String { name }
}

@Suite("Intent execution targets")
struct IntentExecutionTargetsTests {
    /// `TodoService` の変更メソッドを呼ぶ Intent の一覧。
    /// 新しい書き込み系 Intent を足したらここにも追加する
    /// （追加漏れは `everyMutatingIntentIsListed` が検出する）。
    private static let mutatingIntents: [MutatingIntentCase] = [
        .init(name: "AddTodoIntent", targets: AddTodoIntent.allowedExecutionTargets),
        .init(name: "UpdateTodoIntent", targets: UpdateTodoIntent.allowedExecutionTargets),
        .init(name: "DeleteTodoIntent", targets: DeleteTodoIntent.allowedExecutionTargets),
        .init(name: "DeleteTodoImmediatelyIntent", targets: DeleteTodoImmediatelyIntent.allowedExecutionTargets),
        .init(name: "DeleteTodosIntent", targets: DeleteTodosIntent.allowedExecutionTargets),
        .init(name: "CompleteTodosIntent", targets: CompleteTodosIntent.allowedExecutionTargets),
        .init(name: "ToggleTodoCompletionIntent", targets: ToggleTodoCompletionIntent.allowedExecutionTargets),
        .init(name: "SetTodoCompletionIntent", targets: SetTodoCompletionIntent.allowedExecutionTargets),
        .init(name: "ToggleFavoriteIntent", targets: ToggleFavoriteIntent.allowedExecutionTargets),
        .init(name: "ToggleUrgentTodoIntent", targets: ToggleUrgentTodoIntent.allowedExecutionTargets),
        .init(name: "SnoozeTodoIntent", targets: SnoozeTodoIntent.allowedExecutionTargets),
        .init(name: "QuickSnoozeTodoIntent", targets: QuickSnoozeTodoIntent.allowedExecutionTargets),
        .init(name: "ReorderTodosIntent", targets: ReorderTodosIntent.allowedExecutionTargets)
    ]

    @Test("書き込み系 Intent はアプリ本体プロセスに固定されている", arguments: mutatingIntents)
    func mutatingIntentPinsExecutionToMainApp(intentCase: MutatingIntentCase) {
        #expect(
            intentCase.targets == [.main],
            """
            \(intentCase.name) は allowedExecutionTargets = [.main] を宣言していること。
            未指定だとシステムのヒューリスティクスで Widget Extension が
            SwiftData の書き手になり得る (WWDC 2026 #345 16:30)。
            """
        )
    }

    /// 読み取り専用の Intent は既定 (`.default`) のままにしておく。
    /// アプリを起こさずに Extension で応答できるほうが速いので、固定する理由がない。
    @Test("読み取り専用 Intent は実行先を固定しない")
    func readOnlyIntentsStayUnpinned() {
        #expect(GetTodoSummaryIntent.allowedExecutionTargets == .default)
        #expect(ShowTodoCountIntent.allowedExecutionTargets == .default)
        #expect(SearchEverythingIntent.allowedExecutionTargets == .default)
    }

    /// 上のリストへの追加漏れを検出する。
    ///
    /// `Intents/` のソースを読み、`todoService` の変更メソッドを呼んでいるファイルが
    /// `allowedExecutionTargets` を宣言しているかを直接確かめる。型を実行時に列挙する
    /// 手段がないため、ソースを真とする。
    @Test("TodoService を変更する Intent はすべて実行先を宣言している")
    func everyMutatingIntentDeclaresExecutionTargets() throws {
        let mutatingCalls = [
            "todoService.create(",
            "todoService.update(",
            "todoService.delete(",
            "todoService.toggleCompletion(",
            "todoService.setCompletion(",
            "todoService.markCompleted(",
            "todoService.toggleFavorite(",
            "todoService.toggleMostUrgentTodo(",
            "todoService.snooze(",
            "todoService.reorderTodos("
        ]

        let intentsDirectory = URL(filePath: #filePath)
            .deletingLastPathComponent()   // TodoAppIntentsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // TodoAppIntents (package root)
            .appending(path: "Sources/TodoAppIntents/Intents")

        let files = try FileManager.default
            .contentsOfDirectory(at: intentsDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty, "Intents ディレクトリを解決できていない: \(intentsDirectory.path)")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            let mutates = mutatingCalls.contains { source.contains($0) }
            guard mutates else { continue }

            #expect(
                source.contains("allowedExecutionTargets"),
                """
                \(file.lastPathComponent) は TodoService を変更するのに
                allowedExecutionTargets を宣言していない。[.main] を足し、
                mutatingIntents リストにも追加すること。
                """
            )
        }
    }
}
