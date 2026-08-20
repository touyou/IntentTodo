//
//  UpdateTodoIntent.swift
//  TodoAppIntents
//
//  Partial update of a todo's optional fields. Exercises WWDC 2026 #344's
//  `IntentParameter.valueState`, which distinguishes three states per parameter:
//  - `.set(value)`  → the caller provided a new value
//  - `.set(nil)`    → the caller explicitly cleared an optional field
//  - `.unset`       → the caller didn't mention the field → leave it untouched
//
//  A plain `nil` check collapses the first/second/third cases, so "clear the due
//  date" and "leave the due date alone" become indistinguishable. `valueState`
//  preserves the distinction; each parameter is mapped to a `FieldUpdate` and
//  handed to `TodoService.update(...)`.
//

import AppIntents
import Foundation

/// Updates selected fields of an existing todo, leaving unmentioned fields intact.
public struct UpdateTodoIntent: AppIntent {
    public static var title: LocalizedStringResource { "Update Todo" }

    public static var description: IntentDescription {
        IntentDescription(
            "Updates a todo's title, description, due date, favorite flag, estimated duration, or assignee. Fields you leave blank are kept as-is.",
            categoryName: "Todos",
            searchKeywords: ["update", "edit", "change", "modify"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to update")
    public var todo: TodoAppEntity

    @Parameter(title: "Title")
    public var title: String?

    @Parameter(title: "Description")
    public var todoDescription: String?

    @Parameter(title: "Due Date")
    public var dueDate: Date?

    @Parameter(title: "Favorite")
    public var isFavorite: Bool?

    @Parameter(title: "Estimated Duration")
    public var estimatedDuration: Duration?

    @Parameter(title: "Assignee")
    public var assigneeName: String?

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // Estimated duration is stored as a `TimeInterval` on the model, so bridge
        // the system `Duration` here while preserving the three-way value state.
        let estimatedDurationUpdate: FieldUpdate<TimeInterval?>
        if case .set(let duration) = $estimatedDuration.valueState {
            estimatedDurationUpdate = .set(duration.map { TimeInterval($0.components.seconds) })
        } else {
            estimatedDurationUpdate = .unchanged
        }

        let entity = try todoService.update(
            todoId: todo.id,
            title: Self.requiredUpdate($title.valueState),
            todoDescription: Self.optionalUpdate($todoDescription.valueState),
            dueDate: Self.optionalUpdate($dueDate.valueState),
            isFavorite: Self.requiredUpdate($isFavorite.valueState),
            estimatedDuration: estimatedDurationUpdate,
            assigneeName: Self.optionalUpdate($assigneeName.valueState)
        )
        return .result(value: entity)
    }

    // MARK: - valueState → FieldUpdate mapping

    /// For optional model fields: `.set(value)` (incl. `.set(nil)` = explicit
    /// clear) maps straight through; `.unset` means leave the field alone.
    private static func optionalUpdate<T>(_ state: IntentParameter<T?>.ValueState) -> FieldUpdate<T?> {
        if case .set(let value) = state { return .set(value) }
        return .unchanged
    }

    /// For required model fields exposed as optional parameters: a present value
    /// updates the field; `.set(nil)` and `.unset` both leave it unchanged (a
    /// required field can't be cleared).
    private static func requiredUpdate<T>(_ state: IntentParameter<T?>.ValueState) -> FieldUpdate<T> {
        if case .set(let value?) = state { return .set(value) }
        return .unchanged
    }
}
