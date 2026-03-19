//
//  AppDelegate.swift
//  IntentTodo
//
//  Handles notification delegate callbacks for Control Center widget actions.
//

import UIKit
import UserNotifications
import TodoAppIntents

/// App delegate for handling notification interactions.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Register notification categories
        registerNotificationCategories()

        return true
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }

    private func registerNotificationCategories() {
        // Category for Add Todo notifications
        let addTodoCategory = UNNotificationCategory(
            identifier: "ADD_TODO_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([addTodoCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        return [.banner, .sound]
    }

    /// Handle notification tap.
    ///
    /// Dispatches based on `userInfo["action"]` set by `ControlNotificationHelper`.
    /// Also checks `categoryIdentifier` as a fallback.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let userInfo = content.userInfo

        // Check if this is an Add Todo action (via userInfo or category)
        let isAddTodoAction = (userInfo["action"] as? String) == "addTodo"
            || content.categoryIdentifier == "ADD_TODO_CATEGORY"

        if isAddTodoAction {
            await MainActor.run {
                IntentAppState.shared.requestShowAddTodo()
            }
        }
    }
}
