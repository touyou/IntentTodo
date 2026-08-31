//
//  OpenTodoIntent.swift
//  TodoAppIntents
//
//  Adopts the system `OpenIntent` protocol (WWDC 2026 #344) so the system
//  understands, semantically, that this action opens one of the app's entities.
//  Used for "open the app to this todo" surfaces (Spotlight result tap, Siri).
//

import AppIntents
#if os(iOS) || os(visionOS)
// Importing UIKit alongside AppIntents activates the cross-import overlay that provides
// `UISceneAppIntent`.
import UIKit
#endif

/// Opens the app to a specific todo's detail screen.
///
/// Conforms to `OpenIntent`, the App Intents system intent for "open the
/// associated item". The protocol requires a `target` property whose type is an
/// `AppEntity`; the associated `Target` type is inferred from it.
///
/// Navigation is written to `NavigationModel` via `@Dependency` in `perform()`,
/// matching `LaunchAppIntent`'s cold-start-safe pattern.
/// `URLRepresentableIntent` comes for free: for an `OpenIntent` whose `Target` is a
/// `URLRepresentableEntity`, the SDK synthesises `urlRepresentation`
/// (`intenttodo://todo/<id>`), so a widget `Link` and Siri point at the same destination.
public struct OpenTodoIntent: OpenIntent, URLRepresentableIntent {
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
        applyNavigation()
        return .result()
    }

    /// Idempotent, and called from both `perform()` and the scene delegate.
    @MainActor
    func applyNavigation() {
        navigationModel.navigateToRoot()
        navigationModel.showDetail(for: target)
    }
}

#if os(iOS) || os(visionOS)
/// Combined with `OpenIntent` this also yields a `contentIdentifier` derived from
/// `target.id`, usable as a `handlesExternalEvents` activation condition if window
/// targeting is ever needed. [Apple: wwdc2025-275 23:26]
extension OpenTodoIntent: UISceneAppIntent {
    public func performNavigation(forScene scene: UIScene) {
        MainActor.assumeIsolated {
            applyNavigation()
        }
    }
}
#endif
