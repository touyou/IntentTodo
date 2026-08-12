//
//  LaunchAppIntent.swift
//  TodoAppIntents
//
//  Unified intent for launching the app to specific screens.
//  Used by Widgets, Shortcuts, and Action Button.
//

import AppIntents
import Foundation
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "LaunchAppIntent")

// MARK: - App Screen Enum

public enum AppScreenTarget: String, AppEnum {
    case addTodo
    case todoList
    case incompleteTodos
    case favoriteTodos

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "App Screen"

    public static let caseDisplayRepresentations: [AppScreenTarget: DisplayRepresentation] = [
        .addTodo: "Add Todo",
        .todoList: "Todo List",
        .incompleteTodos: "Incomplete Todos",
        .favoriteTodos: "Favorite Todos"
    ]
}

// MARK: - Launch App Intent

/// Opens the app to a specific screen.
///
/// Navigation is written to `NavigationModel` via `@Dependency` in `perform()`.
public struct LaunchAppIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Todo App"
    public static let description = IntentDescription("Opens the Todo app to a specific screen")
    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Target")
    public var target: AppScreenTarget

    @Dependency
    var navigationModel: NavigationModel

    public init() {
        self.target = .todoList
    }

    public init(target: AppScreenTarget) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        logger.info("LaunchAppIntent.perform() pid=\(ProcessInfo.processInfo.processIdentifier) processName=\(ProcessInfo.processInfo.processName) target=\(target.rawValue)")
        switch target {
        case .addTodo:
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        case .todoList, .incompleteTodos, .favoriteTodos:
            // 以前はここが `break` で、リスト系のターゲットは root に戻すだけだった。
            // その結果「未完了だけ見せる」つもりのコントロール / Siri 応答が
            // 「アプリを開くだけ」になっていたため、filter を明示的に伝える。
            navigationModel.showList(filter: Self.listFilter(for: target))
        }
        return .result()
    }

    /// 画面ターゲット → リストの絞り込み。`perform()` は `@Dependency` 解決の都合で
    /// SPM テストから叩けないため、対応表は純関数として切り出して検証する
    /// (`ShowTodosIntent.screenTarget(for:)` と同じ方針)。
    static func listFilter(for target: AppScreenTarget) -> TodoFilterType {
        switch target {
        case .incompleteTodos:
            return .incomplete
        case .favoriteTodos:
            return .favorites
        case .todoList, .addTodo:
            return .all
        }
    }
}

#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif

// MARK: - Convenience Factory Methods

public extension LaunchAppIntent {
    static func addTodo() -> LaunchAppIntent { LaunchAppIntent(target: .addTodo) }
    static func todoList() -> LaunchAppIntent { LaunchAppIntent(target: .todoList) }
    static func incompleteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .incompleteTodos) }
    static func favoriteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .favoriteTodos) }
}
