//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents
import Repository
import SwiftData

/// Shows todos, optionally filtered.
public struct ShowTodosIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show Todos" }
    public static let description = IntentDescription("Shows your todo items")
    public static var supportedModes: IntentModes { .foreground }

    public static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$filter) todos")
    }

    @Parameter(title: "Filter", default: .all)
    public var filter: TodoFilterType

    @Dependency
    var modelContainer: ModelContainer

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & OpensIntent {
        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)
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
