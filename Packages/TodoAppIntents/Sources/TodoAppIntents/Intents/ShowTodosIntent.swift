//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that shows all todos.
///
/// This intent is used by Siri and Shortcuts to display all todos.
/// It returns a list of entities that can be displayed in the UI.
public struct ShowTodosIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Show All Todos", comment: "Intent title for showing all todos")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Shows all your todo items",
                comment: "Intent description for showing all todos"
            )
        )
    }

    /// Opens the app in foreground when run.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchAll()
        let entities = todos.map { TodoAppEntity(from: $0) }

        return .result(
            value: entities,
            opensIntent: LaunchAppIntent(target: .todoList)
        )
    }
}

/// An intent that shows only incomplete todos.
public struct ShowIncompleteTodosIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Show Incomplete Todos", comment: "Intent title for showing incomplete todos")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Shows your incomplete todo items",
                comment: "Intent description for showing incomplete todos"
            )
        )
    }

    /// Opens the app in foreground when run.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let incompleteTodos = try repository.fetchIncomplete()
        let entities = incompleteTodos.map { TodoAppEntity(from: $0) }

        return .result(
            value: entities,
            opensIntent: LaunchAppIntent(target: .incompleteTodos)
        )
    }
}

/// An intent that shows only favorite todos.
public struct ShowFavoriteTodosIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Show Favorite Todos", comment: "Intent title for showing favorite todos")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Shows your favorite todo items",
                comment: "Intent description for showing favorite todos"
            )
        )
    }

    /// Opens the app in foreground when run.
    public static var supportedModes: IntentModes { .foreground }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let favoriteTodos = try repository.fetchFavorites()
        let entities = favoriteTodos.map { TodoAppEntity(from: $0) }

        return .result(
            value: entities,
            opensIntent: LaunchAppIntent(target: .favoriteTodos)
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
