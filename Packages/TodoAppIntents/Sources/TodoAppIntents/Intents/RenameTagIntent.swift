//
//  RenameTagIntent.swift
//  TodoAppIntents
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Renames a tag on every todo that carries it.
///
/// Renaming onto a tag that already exists merges the two, because that is all the stored
/// value can express — a todo holding both ends up with one. So this is also how two
/// spellings of the same tag get folded together, and there is no separate merge action.
public struct RenameTagIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Rename Tag" }

    public static var description: IntentDescription {
        IntentDescription(
            "Renames a tag across every todo that carries it. Renaming onto an existing tag merges them.",
            categoryName: "Todos",
            searchKeywords: ["tag", "rename", "merge", "tidy"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Rename the tag \(\.$tag) to \(\.$newName)")
    }

    // MARK: - Parameters

    @Parameter(title: "Tag", description: "The tag to rename")
    public var tag: String

    @Parameter(title: "New Name", description: "The name to give the tag")
    public var newName: String

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(tag: String, newName: String) {
        self.tag = tag
        self.newName = newName
    }

    // MARK: - Perform

    /// Returns how many todos changed, so a Shortcut can branch on "did that match
    /// anything" instead of guessing.
    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        .result(value: try todoService.renameTag(tag, to: newName))
    }
}
#endif
