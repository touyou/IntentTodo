//
//  AppDelegate.swift
//  IntentTodo
//
//  The iOS / visionOS `UIApplicationDelegate`. The notification delegate body lives in
//  `NotificationHandler`; this installs it and wires up the SceneDelegate.
//

#if os(iOS) || os(visionOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        NotificationHandler.shared.install()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}
#endif
