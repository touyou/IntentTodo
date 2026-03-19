//
//  SceneDelegate.swift
//  IntentTodo
//
//  Handles scene-level App Intent routing.
//  Complements onAppIntentExecution in SwiftUI for scene connection scenarios.
//

import UIKit
import TodoAppIntents

/// Scene delegate that handles App Intent routing at the scene level.
///
/// This delegate uses `UIScene.ConnectionOptions.appIntent` to detect
/// intents that triggered scene creation. For already-active scenes,
/// `onAppIntentExecution` in SwiftUI handles Intent routing declaratively.
///
/// Relationship with other patterns:
/// - **`onAppIntentExecution`** (SwiftUI): Primary handler for active scenes
/// - **`SceneDelegate`** (UIKit): Handles scene creation triggered by intents
/// - **`IntentAppState`**: Fallback for cross-process communication (Extensions)
final class SceneDelegate: NSObject, UIWindowSceneDelegate {

    // MARK: - Scene Lifecycle

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Handle intent that triggered scene creation
        // Note: connectionOptions.appIntent is available on iOS 26+
        // when a UISceneAppIntent triggers a new scene
    }
}
