//
//  ShowTodosIntent.swift
//  IntentTodo
//

import AppIntents

/// Shows todos, optionally filtered.
public struct ShowTodosIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show Todos" }
    public static let description = IntentDescription("Shows your todo items")

    // WWDC 2026 Intent Modes: prefer the background (so Siri / Shortcuts can read
    // the count without opening the app) and transition to the foreground only
    // when the system permits — see `perform()`. `.foreground(.dynamic)` replaces
    // the deprecated `ForegroundContinuableIntent`.
    public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

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

        // Background-first: only bring the app forward (and route to the matching
        // screen) when the current run mode allows it. If the system denies the
        // transition, fall through and just return the spoken/displayed dialog.
        if systemContext.currentMode.canContinueInForeground {
            do {
                try await continueInForeground(alwaysConfirm: false)
                navigationModel.navigateToRoot()
            } catch {
                // Foreground transition unavailable — continue in the background.
            }
        }

        return .result(value: entities, dialog: dialog(for: entities))
    }

    /// filter → 表示画面のマッピング。`perform()` のフォアグラウンド遷移は現状すべて
    /// ルートのリストを開く (LaunchAppIntent と同じ挙動) が、フィルタ別画面を追加する際の
    /// 単一ルーティング地点として純関数で保持し、SPM テストで網羅検証する。
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
