//
//  LaunchAppIntent.swift
//  TodoAppIntents
//
//  Unified intent for launching the app to specific screens.
//  Used by Widgets, Shortcuts, and Action Button.
//

import AppIntents

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
        navigationModel.navigateToRoot()
        switch target {
        case .addTodo:
            navigationModel.showAddTodo()
        case .todoList, .incompleteTodos, .favoriteTodos:
            break
        }
        return .result()
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
