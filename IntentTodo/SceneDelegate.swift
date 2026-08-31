//
//  SceneDelegate.swift
//  IntentTodo
//
//  iOS / visionOS only: native macOS has no UIKit.
//
//  As an `AppIntentSceneDelegate`, it applies the navigation of App Intents targeted at this
//  scene. [Apple: wwdc2025-275 23:52]
//
//

#if os(iOS) || os(visionOS)
import AppIntents
import TodoAppIntents
import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate, AppIntentSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Cold start: when an App Intent is what created the scene, it arrives through the
        // connection options rather than `willPerformAppIntent`. Missing this line means
        // "the app opens but not on the right screen".
        guard let appIntent = connectionOptions.appIntent else { return }
        appIntent.performNavigation(forScene: scene)
    }

    /// Runs against an existing scene. Each `UISceneAppIntent` knows its own navigation, so
    /// this only hands over the target scene — no per-intent branching.
    func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent) {
        appIntent.performNavigation(forScene: scene)
    }
}
#endif
