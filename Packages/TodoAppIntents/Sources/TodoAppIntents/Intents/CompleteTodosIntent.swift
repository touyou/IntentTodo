//
//  CompleteTodosIntent.swift
//  TodoAppIntents
//
//  Bulk-completes a collection of todos. Exercises three WWDC 2026 (#345) APIs:
//  - EntityCollection: stores identifiers without forcing entity resolution.
//  - LongRunningIntent: extends background runtime + reports progress.
//  - CancellableIntent: graceful cancellation via performBackgroundTask(onCancel:).
//

import AppIntents
import Foundation
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "CompleteTodosIntent")

/// Marks every todo in the collection as completed.
///
/// Uses `EntityCollection<TodoAppEntity>` so the system stores only identifiers
/// and skips hydrating each `TodoAppEntity` during parameter resolution — the
/// completion logic needs only ids. The work runs inside `performBackgroundTask`
/// (LongRunningIntent) so a large batch can exceed the 30s background limit, and
/// reports `progress` so the system doesn't end the task prematurely.
public struct CompleteTodosIntent: LongRunningIntent, CancellableIntent {
    public static var title: LocalizedStringResource { "Complete Todos" }

    public static var description: IntentDescription {
        IntentDescription(
            "Marks multiple todos as completed",
            categoryName: "Todos",
            searchKeywords: ["complete", "finish", "done", "bulk"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Bulk SwiftData mutation belongs in the main app process. We don't ship an
    /// App Intents extension, so pin execution to `.main` (WWDC 2026 #345).
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Complete \(\.$todos)")
    }

    @Parameter(title: "Todos", description: "The todos to complete")
    public var todos: EntityCollection<TodoAppEntity>

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todos: EntityCollection<TodoAppEntity>) {
        self.todos = todos
    }

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Only identifiers are needed — never resolve the full entities.
        let ids = todos.identifiers
        let total = ids.count

        let completed = try await performBackgroundTask {
            progress.totalUnitCount = Int64(total)
            progress.localizedDescription = "Completing todos"
            var done = 0
            for id in ids {
                try Task.checkCancellation()
                try await todoService.markCompleted(todoId: id)
                done += 1
                progress.completedUnitCount = Int64(done)
            }
            return done
        } onCancel: { reason in
            logger.notice("CompleteTodosIntent cancelled: \(String(describing: reason), privacy: .public)")
        }

        // Siri がこの dialog を読み上げるので、複数形は手書きの三項演算子ではなく
        // inflection に任せる（他言語では単複の切り替えだけでは足りない）。
        return .result(dialog: IntentDialog("Completed ^[\(completed) todo](inflect: true)."))
    }
}
