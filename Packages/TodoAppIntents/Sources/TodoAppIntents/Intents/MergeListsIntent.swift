//
//  MergeListsIntent.swift
//  TodoAppIntents
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Moves every todo out of one or more lists into another, then deletes the emptied ones.
///
/// Exists because lists drift into duplicates — two spellings of the same name, or the same
/// name typed twice before `CreateListIntent` started folding repeats together — and
/// re-filing the todos one at a time is the kind of work an app should do for you.
public struct MergeListsIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Merge Lists" }

    public static var description: IntentDescription {
        IntentDescription(
            "Moves the todos from one or more lists into another list, then deletes the emptied lists.",
            categoryName: "Todos",
            searchKeywords: ["list", "merge", "combine", "duplicate", "tidy"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Merge \(\.$lists) into \(\.$destination)")
    }

    // MARK: - Parameters

    @Parameter(title: "Lists", description: "The lists to empty and delete")
    public var lists: [CategoryAppEntity]

    @Parameter(title: "Destination", description: "The list the todos are moved into")
    public var destination: CategoryAppEntity

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(lists: [CategoryAppEntity], destination: CategoryAppEntity) {
        self.lists = lists
        self.destination = destination
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<CategoryAppEntity> {
        .result(
            value: try todoService.mergeLists(
                sourceIDs: lists.map(\.id),
                into: destination.id
            )
        )
    }
}
#endif
