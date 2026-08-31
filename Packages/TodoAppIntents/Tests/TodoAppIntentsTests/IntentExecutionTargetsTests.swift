//
//  IntentExecutionTargetsTests.swift
//  TodoAppIntents
//
//  Guards that every intent writing SwiftData pins execution to the app process.
//
//  Dropping the declaration builds and tests clean; the only symptom is the widget extension
//  writing to the same store while the app is not running.
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

/// One expectation. The type name is a string so it can be a test parameter.
struct MutatingIntentCase: Sendable, CustomStringConvertible {
    let name: String
    let targets: IntentExecutionTargets

    var description: String { name }
}

@Suite("Intent execution targets")
struct IntentExecutionTargetsTests {
    /// Every intent that calls a mutating `TodoService` method. New ones belong here;
    /// `everyMutatingIntentIsListed` catches omissions.
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

    /// Read-only intents stay `.default`: answering from an extension without waking the app
    /// is faster, and there is nothing to protect.
    @Test("読み取り専用 Intent は実行先を固定しない")
    func readOnlyIntentsStayUnpinned() {
        #expect(GetTodoSummaryIntent.allowedExecutionTargets == .default)
        #expect(ShowTodoCountIntent.allowedExecutionTargets == .default)
        #expect(SearchEverythingIntent.allowedExecutionTargets == .default)
    }

    /// Catches intents missing from the list above.
    ///
    /// Reads the sources under `Intents/` and checks that any file calling a mutating
    /// `todoService` method also declares `allowedExecutionTargets`. There is no way to
    /// enumerate the types at runtime, so the source is the reference.
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
