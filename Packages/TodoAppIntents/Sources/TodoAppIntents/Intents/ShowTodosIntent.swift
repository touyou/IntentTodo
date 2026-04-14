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
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog & OpensIntent {
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
            opensIntent: LaunchAppIntent(target: screenTarget),
            dialog: dialog(for: entities)
        )
    }

    // MARK: - Dialog

    /// Siri/Shortcuts の結果表示 / 読み上げ用メッセージ。
    /// Control Center からの呼出では表示されないが、データ更新が無いためフィードバック不要。
    private func dialog(for entities: [TodoAppEntity]) -> IntentDialog {
        let count = entities.count
        let categoryLabel: String = {
            switch filter {
            case .all: return "todo"
            case .incomplete: return "incomplete todo"
            case .completed: return "completed todo"
            case .favorites: return "favorite todo"
            }
        }()

        if count == 0 {
            return IntentDialog("No \(categoryLabel)s.")
        }
        let plural = count == 1 ? categoryLabel : "\(categoryLabel)s"
        return IntentDialog("You have \(count) \(plural).")
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
