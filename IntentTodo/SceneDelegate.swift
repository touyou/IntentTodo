//
//  SceneDelegate.swift
//  IntentTodo
//
//  iOS / visionOS 専用。macOS native ビルドでは UIKit が存在しないためビルドから除外する。
//
//  現状は空のスキャフォルド。将来 iOS 26+ の UISceneAppIntent を使って
//  Shortcuts / Siri からの特定シーン起動を拾うときにここでハンドリングする。
//  今のところナビゲーション経路は `onOpenURL` と `AppDependencyManager` 経由の
//  NavigationModel 書き込みで足りているため、ハンドラ実装は未着手。
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
        // TODO: iOS 26+ UISceneAppIntent を採用するときはここで接続シーンを
        // NavigationModel に紐付ける。Issue #30 A-1 の cold start 経路検証後に判断。
    }
}
#endif
