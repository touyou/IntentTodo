//
//  LaunchAppIntent.swift
//  TodoAppIntents
//

import AppIntents
import Foundation
import os.log
#if os(iOS) || os(visionOS)
// Importing UIKit alongside AppIntents activates the _AppIntents_UIKit cross-import
// overlay, which is where `UISceneAppIntent` comes from.
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

    /// Writes the navigation state for `target`.
    ///
    /// Idempotent, and called from both `perform()` and — where scenes exist —
    /// `performNavigation(forScene:)`. Keeping it in one place is what stops the two
    /// entry points from drifting apart.
    @MainActor
    func applyNavigation() {
        switch target {
        case .addTodo:
            navigationModel.navigateToRoot()
            navigationModel.showAddTodo()
        case .todoList, .incompleteTodos, .favoriteTodos:
            // Every case the enum promises needs a matching state write. Falling through
            // to `break` here degrades silently into "just opens the app".
            navigationModel.showList(filter: Self.listFilter(for: target))
        }
    }

    /// Screen target to list filter. Extracted as a pure function because `perform()`
    /// cannot run from SPM tests (`@Dependency` is only injected on system dispatch).
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
/// Receiving the scene means navigation is written with the target window already known.
/// It also covers cold start, where `SceneDelegate` calls this from
/// `UIScene.ConnectionOptions.appIntent`. [Apple: wwdc2025-275 23:52]
///
/// The SwiftUI alternative is `contentIdentifier` + `handlesExternalEvents` (same session,
/// 23:12); with a single `WindowGroup` there is no destination to choose, so the delegate
/// route wins for being deterministic on cold start.
extension LaunchAppIntent: UISceneAppIntent {
    public func performNavigation(forScene scene: UIScene) {
        // Only ever called from the scene delegate, i.e. the main thread.
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
