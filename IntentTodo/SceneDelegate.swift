//
//  SceneDelegate.swift
//  IntentTodo
//
//  iOS / visionOS 専用。macOS native ビルドでは UIKit が存在しないためビルドから除外する。
//

#if os(iOS) || os(visionOS)
import TodoAppIntents
import UIKit

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // iOS 26+ の UISceneAppIntent 連携はここで処理予定
    }
}
#endif
