//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents

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
    var todoService: TodoService

    public init() {
        self.filter = .all
    }

    public init(filter: TodoFilterType) {
        self.filter = filter
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog & OpensIntent {
        let entities = try todoService.listTodos(filter: filter)
        return .result(
            value: entities,
            opensIntent: LaunchAppIntent(target: Self.screenTarget(for: filter)),
            dialog: dialog(for: entities)
        )
    }

    /// 画面遷移先と filter のマッピングは Intent perform() の外でも検証したいので
    /// 純関数として切り出す (perform は @Dependency 解決の都合で SPM テストが書きにくい)。
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
