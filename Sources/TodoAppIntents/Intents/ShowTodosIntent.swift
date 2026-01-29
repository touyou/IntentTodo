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

    public static var openAppWhenRun: Bool { true }

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
            opensIntent: OpenTodoListIntent()
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

    public static var openAppWhenRun: Bool { true }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchAll()
        let incompleteTodos = todos.filter { !$0.isCompleted }
        let entities = incompleteTodos.map { TodoAppEntity(from: $0) }

        return .result(
            value: entities,
            opensIntent: OpenTodoListIntent(filter: .incomplete)
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

    public static var openAppWhenRun: Bool { true }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = try IntentDependencies.shared.createRepository()
        let todos = try repository.fetchAll()
        let favoriteTodos = todos.filter { $0.isFavorite }
        let entities = favoriteTodos.map { TodoAppEntity(from: $0) }

        return .result(
            value: entities,
            opensIntent: OpenTodoListIntent(filter: .favorites)
        )
    }
}

// MARK: - Open App Intent

/// An intent that opens the todo list with an optional filter.
public struct OpenTodoListIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Todo List", comment: "Intent title for opening the todo list")
    }

    public static var openAppWhenRun: Bool { true }

    // MARK: - Parameters

    @Parameter(title: "Filter")
    public var filter: TodoFilterType?

    // MARK: - Initialization

    public init() {}

    public init(filter: TodoFilterType?) {
        self.filter = filter
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult {
        // This intent just opens the app; the UI will handle the filter
        return .result()
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
