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
    ///
    /// WWDC 2026 (#343): `IntentDialog(full:supporting:)` で音声単独用と視覚併用を分ける。
    /// - `full`: 画面が無い文脈(音声のみ)で読み上げる、それ単体で完結するメッセージ。
    /// - `supporting`: 返却した一覧が視覚表示される文脈で、リストに添える短い一言。
    /// 名詞は単数形 / 複数形とも訳文側で決める。Swift 側で `"\(noun)s"` のように
    /// 英語の屈折を組み立てると、その `String` は catalog に載らないまま `%@` に
    /// 差し込まれ、訳文の中に英語の名詞がそのまま出る。
    /// 詳細: docs/insights/03-app-intents-core.md「Intent のコピーがどこから引かれるか」
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
