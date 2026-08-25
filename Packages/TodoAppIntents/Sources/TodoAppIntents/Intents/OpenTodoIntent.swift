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
// AppIntents + UIKit を揃えて import すると cross-import overlay 経由で
// UISceneAppIntent が使えるようになる。
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
        applyNavigation()
        return .result()
    }

    /// 対象 Todo の詳細へ遷移する。`perform()` とシーン経由の両方から呼ぶ（冪等）。
    @MainActor
    func applyNavigation() {
        navigationModel.navigateToRoot()
        navigationModel.showDetail(for: target)
    }
}

#if os(iOS) || os(visionOS)
/// `OpenIntent` と組み合わせると `contentIdentifier`（`target.id` 由来）が自動で
/// 手に入る。SwiftUI の `handlesExternalEvents` で宛先ウィンドウを選ばせたくなった
/// ときに、この識別子をそのまま活性化条件に使える（wwdc2025-275 23:26）。
extension OpenTodoIntent: UISceneAppIntent {
    public func performNavigation(forScene scene: UIScene) {
        MainActor.assumeIsolated {
            applyNavigation()
        }
    }
}
#endif
