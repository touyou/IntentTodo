//
//  CreateListIntent.swift
//  TodoAppIntents
//
//  Conforms to the reminders `createList` schema, so Siri can make a list ("make a Work
//  list in Intento") and the app's own management screen goes through the same action.
//
//  Excluded on watchOS along with the rest of the list-management actions: the schema
//  domain does not exist there, and the watch has no surface that organises lists.
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Creates a list to file todos under.
///
/// Repeating a name returns the existing list instead of inserting a second one — see
/// `TodoService.createList(name:colorHex:)` for why that is the right answer rather than a
/// validation error.
@AppIntent(schema: .reminders.createList)
public struct CreateListIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Create List" }

    public static var description: IntentDescription {
        IntentDescription(
            "Creates a list to file todos under",
            categoryName: "Todos",
            searchKeywords: ["list", "category", "create", "new", "folder"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Create a list named \(\.$name)") {
            \.$type
        }
    }

    // MARK: - Parameters

    @Parameter(title: "Name", description: "The name of the new list")
    public var name: String

    /// The schema's kind-of-list. Only one case exists, so the system resolves it without
    /// asking; the default keeps a caller that omits it from being prompted at all.
    @Parameter(title: "List Type", description: "The kind of list", default: .standard)
    public var type: TodoListType

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(name: String) {
        self.name = name
        self.type = .standard
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<CategoryAppEntity> {
        .result(value: try todoService.createList(name: name))
    }
}
#endif
