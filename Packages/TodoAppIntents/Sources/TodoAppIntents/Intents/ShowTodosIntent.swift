//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents

/// Shows todos, optionally filtered.
public struct ShowTodosIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show Todos" }
    public static let description = IntentDescription("Shows your todo items")
    // Background-first. A foreground-only intent is refused outright wherever the app
    // cannot come forward — Shortcuts with "Open When Run" off answers "not allowed" — so
    // the list is returned from the background and the app is opened only when the
    // system permits it.
    public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

    // Read-only, but it navigates: `NavigationModel` is registered in the app, not the
    // widget extension, and an unresolved `@Dependency` fails the intent without a trace.
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$filter) todos")
    }

    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType

    @Dependency
    var todoService: TodoService

    @Dependency
    var navigationModel: NavigationModel

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog {
        let entities = try todoService.listTodos(filter: filter)

        // `OpensIntent` cannot be used here: it is part of the result type, so it would
        // open the app even on a run that asked to stay in the background.
        if systemContext.currentMode.canContinueInForeground {
            do {
                try await continueInForeground(alwaysConfirm: false)
                navigationModel.showList(
                    filter: LaunchAppIntent.listFilter(for: Self.screenTarget(for: filter))
                )
            } catch {
                // The system declined the transition; the dialog still answers.
            }
        }

        return .result(value: entities, dialog: dialog(for: entities))
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
