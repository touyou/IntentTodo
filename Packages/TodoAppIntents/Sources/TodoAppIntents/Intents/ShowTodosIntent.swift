//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that shows todos, optionally filtered.
///
/// One intent handles all filtering — `filter` defaults to `.all`.
/// Used by Siri and Shortcuts to display todos and open the matching screen.
public struct ShowTodosIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Show Todos", comment: "Intent title for showing todos")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Shows your todo items",
                comment: "Intent description for showing todos"
            )
        )
    }

    /// Opens the app in foreground when run.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Parameters

    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType

    // MARK: - Initialization

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let todos: [TodoItem]
        let screenTarget: AppScreenTarget

        switch filter {
        case .all, .completed:
            todos = try repository.fetchAll()
            screenTarget = .todoList
        case .incomplete:
            todos = try repository.fetchIncomplete()
            screenTarget = .incompleteTodos
        case .favorites:
            todos = try repository.fetchFavorites()
            screenTarget = .favoriteTodos
        }

        let entities = todos.map { TodoAppEntity(from: $0) }
        return .result(
            value: entities,
            opensIntent: LaunchAppIntent(target: screenTarget)
        )
    }
}

// MARK: - Filter Type for Intents

/// Filter type for use in App Intents.
public enum TodoFilterType: String, AppEnum {
    case all
    case incomplete
    case completed
    case favorites

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Filter", comment: "Filter type name")
        )
    }

    public static var caseDisplayRepresentations: [TodoFilterType: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(
                title: LocalizedStringResource("All", comment: "All filter"),
                image: .init(systemName: "list.bullet")
            ),
            .incomplete: DisplayRepresentation(
                title: LocalizedStringResource("Incomplete", comment: "Incomplete filter"),
                image: .init(systemName: "circle")
            ),
            .completed: DisplayRepresentation(
                title: LocalizedStringResource("Completed", comment: "Completed filter"),
                image: .init(systemName: "checkmark.circle")
            ),
            .favorites: DisplayRepresentation(
                title: LocalizedStringResource("Favorites", comment: "Favorites filter"),
                image: .init(systemName: "star")
            )
        ]
    }
}
