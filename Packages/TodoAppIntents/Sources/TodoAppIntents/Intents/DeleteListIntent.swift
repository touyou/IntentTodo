//
//  DeleteListIntent.swift
//  TodoAppIntents
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Deletes a list. The todos filed under it stay, unfiled.
///
/// Deliberately **without** `requestConfirmation`, unlike `DeleteTodoIntent`: no todo is
/// lost — `TodoItem.category` nullifies — so the action is recoverable by filing them
/// again. That is what lets one intent serve both Siri and the app's own button; a
/// confirming intent run from `Button(intent:)` has no surface to answer on and fails
/// silently.
public struct DeleteListIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Delete List" }

    public static var description: IntentDescription {
        IntentDescription(
            "Deletes a list. Todos filed under it are kept and become uncategorized.",
            categoryName: "Todos",
            searchKeywords: ["list", "delete", "remove", "category"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete \(\.$list)")
    }

    // MARK: - Parameters

    @Parameter(title: "List", description: "The list to delete")
    public var list: CategoryAppEntity

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(list: CategoryAppEntity) {
        self.list = list
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.deleteList(listId: list.id)
        return .result()
    }
}
#endif
