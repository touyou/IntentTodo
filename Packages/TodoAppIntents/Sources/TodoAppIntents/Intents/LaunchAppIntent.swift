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
#if os(iOS) || os(visionOS)
// AppIntents + UIKit の両方を import した時点で cross-import overlay
// (_AppIntents_UIKit) が有効になり、UISceneAppIntent が見えるようになる。
import UIKit
#endif

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
        applyNavigation()
        return .result()
    }

    /// `target` に対応するナビゲーション状態を書き込む。
    ///
    /// `perform()` と（シーンのあるプラットフォームでは）`performNavigation(forScene:)`
    /// の両方から呼ぶため切り出してある。同じ遷移先を 2 回書いても結果は同じ（冪等）。
    @MainActor
    func applyNavigation() {
        switch target {
        case .addTodo:
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        case .todoList, .incompleteTodos, .favoriteTodos:
            // 列挙が約束した遷移先は、必ず対応する状態書き込みまでやること。
            // ここを `break` にすると「アプリを開くだけ」になる。
            navigationModel.showList(filter: Self.listFilter(for: target))
        }
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
/// `UISceneAppIntent` は `TargetContentProvidingIntent` を継承しているので、
/// これ 1 本で `.onAppIntentExecution` 側の要件も満たす。
///
/// シーンを受け取れることの意味は「どのウィンドウに向けた実行なのかが確定した状態で
/// ナビゲーションを書ける」こと。とくに cold start では `.onAppIntentExecution` が
/// 取りこぼす経路があり、`SceneDelegate` が `UIScene.ConnectionOptions.appIntent`
/// からここを呼ぶことで確定的に遷移できる（wwdc2025-275 23:52）。
///
/// SwiftUI 側の代替は `contentIdentifier` と `handlesExternalEvents` の組み合わせで
/// 「どのシーンが処理するか」を宣言する形（同 23:12）。本アプリは `WindowGroup` が
/// 1 つで宛先の選択が要らないため、cold start を確定させられる delegate 側を採った。
///
/// 詳細: docs/insights/04-ui-integration.md（UISceneAppIntent）
extension LaunchAppIntent: UISceneAppIntent {
    public func performNavigation(forScene scene: UIScene) {
        // 呼び出しは常にシーンデリゲート（メインスレッド）から。
        MainActor.assumeIsolated {
            applyNavigation()
        }
    }
}
#endif

// MARK: - Convenience Factory Methods

public extension LaunchAppIntent {
    static func addTodo() -> LaunchAppIntent { LaunchAppIntent(target: .addTodo) }
    static func todoList() -> LaunchAppIntent { LaunchAppIntent(target: .todoList) }
    static func incompleteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .incompleteTodos) }
    static func favoriteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .favoriteTodos) }
}
