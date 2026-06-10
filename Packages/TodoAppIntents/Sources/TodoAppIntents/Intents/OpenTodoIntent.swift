//
//  OpenTodoIntent.swift
//  TodoAppIntents
//
//  Adopts the system `OpenIntent` protocol (WWDC 2026 #344) so the system
//  understands, semantically, that this action opens one of the app's entities.
//  Used for "open the app to this todo" surfaces (Spotlight result tap, Siri).
//

import AppIntents

/// Opens the app to a specific todo's detail screen.
///
/// Conforms to `OpenIntent`, the App Intents system intent for "open the
/// associated item". The protocol requires a `target` property whose type is an
/// `AppEntity`; the associated `Target` type is inferred from it.
///
/// Navigation is written to `NavigationModel` via `@Dependency` in `perform()`,
/// matching `LaunchAppIntent`'s cold-start-safe pattern.
public struct OpenTodoIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Todo"
    public static let description = IntentDescription("Opens the app to a specific todo")
    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Todo", description: "The todo to open")
    public var target: TodoAppEntity

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    public init(target: TodoAppEntity) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        navigationModel.navigateToRoot()
        navigationModel.showDetail(for: target)
        return .result()
    }
}
