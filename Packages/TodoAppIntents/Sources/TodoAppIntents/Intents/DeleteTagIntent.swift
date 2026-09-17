//
//  DeleteTagIntent.swift
//  TodoAppIntents
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Removes a tag from every todo that carries it.
///
/// No `requestConfirmation`, for the same reason as `DeleteListIntent`: the todos are
/// untouched, only the label goes, so one intent can serve both Siri and the app's button.
public struct DeleteTagIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Delete Tag" }

    public static var description: IntentDescription {
        IntentDescription(
            "Removes a tag from every todo that carries it. The todos themselves are kept.",
            categoryName: "Todos",
            searchKeywords: ["tag", "delete", "remove", "tidy"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Delete the tag \(\.$tag)")
    }

    // MARK: - Parameters

    @Parameter(title: "Tag", description: "The tag to remove")
    public var tag: String

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(tag: String) {
        self.tag = tag
    }

    // MARK: - Perform

    /// Returns how many todos changed, matching `RenameTagIntent`.
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        .result(value: try todoService.deleteTag(tag))
    }
}
#endif
