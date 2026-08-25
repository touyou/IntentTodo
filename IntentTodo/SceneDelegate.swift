//
//  SceneDelegate.swift
//  IntentTodo
//
//  iOS / visionOS 専用。macOS native ビルドでは UIKit が存在しないためビルドから除外する。
//
//  `AppIntentSceneDelegate` として、シーンに向けて実行される App Intent の
//  ナビゲーションをこのシーンに適用する（wwdc2025-275 23:52）。
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
        // cold start 経路。App Intent がきっかけでシーンが作られた場合、その Intent は
        // `willPerformAppIntent` ではなく接続オプションから渡ってくる。ここを拾わないと
        // 「アプリは開くが目的の画面に行かない」になる。
        guard let appIntent = connectionOptions.appIntent else { return }
        appIntent.performNavigation(forScene: scene)
    }

    /// 起動済みのシーンに対する実行。`UISceneAppIntent` 準拠の Intent
    /// (`LaunchAppIntent` / `OpenTodoIntent`) が自分のナビゲーションを知っているので、
    /// ここでは宛先シーンを渡して委譲するだけ。Intent ごとの分岐は書かない。
    func scene(_ scene: UIScene, willPerformAppIntent appIntent: any UISceneAppIntent) {
        appIntent.performNavigation(forScene: scene)
    }
}
#endif
