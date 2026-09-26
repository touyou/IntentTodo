//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents

/// Shows todos, optionally filtered.
public struct ShowTodosIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show Todos" }
    public static let description = IntentDescription("Shows your todo items")
    // Returns the list and never opens the app, whoever runs it. Opening is
    // `LaunchAppIntent`'s job, reached from the snippet's button. A foreground mode here
    // would be refused where the app cannot come forward (Shortcuts with "Open When Run"
    // off), and taken every time from Siri, where it always can.
    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$filter) todos")
    }

    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType

    @Dependency
    var todoService: TodoService

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog & ShowsSnippetIntent {
        let entities = try todoService.listTodos(filter: filter)
        return .result(
            value: entities,
            dialog: dialog(for: entities),
            snippetIntent: ShowTodosSnippetIntent(filter: filter)
        )
    }

    /// Pure function so it is testable: `perform()` needs system dispatch to resolve
    /// `@Dependency` and cannot run from SPM tests.
    static func screenTarget(for filter: TodoFilterType) -> AppScreenTarget {
        switch filter {
        case .all, .completed:
            return .todoList
        case .incomplete:
            return .incompleteTodos
        case .favorites:
            return .favoriteTodos
        }
    }

    // MARK: - Dialog

    /// Both singular and plural forms are localized. Building English inflection in Swift
    /// (`"\(noun)s"`) produces a `String` that never reaches the String Catalog and gets
    /// substituted into `%@`, leaving English nouns inside translated sentences.
    private var categoryNoun: (singular: LocalizedStringResource, plural: LocalizedStringResource) {
        switch filter {
        case .all: ("todo", "todos")
        case .incomplete: ("incomplete todo", "incomplete todos")
        case .completed: ("completed todo", "completed todos")
        case .favorites: ("favorite todo", "favorite todos")
        }
    }

    private func dialog(for entities: [TodoAppEntity]) -> IntentDialog {
        let count = entities.count
        let noun = categoryNoun
        let singular = String(localized: noun.singular)
        let plural = String(localized: noun.plural)

        if count == 0 {
            return IntentDialog(
                full: "You have no \(plural).",
                supporting: "No \(plural)."
            )
        }
        return IntentDialog(
            full: "You have \(count) \(count == 1 ? singular : plural).",
            supporting: count == 1 ? "Here is your \(singular)." : "Here are your \(plural)."
        )
    }
}

// MARK: - Filter Type for Intents

public enum TodoFilterType: String, AppEnum {
    case all
    case incomplete
    case completed
    case favorites

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Filter"

    public static let caseDisplayRepresentations: [TodoFilterType: DisplayRepresentation] = [
        .all: "All",
        .incomplete: "Incomplete",
        .completed: "Completed",
        .favorites: "Favorites"
    ]
}
