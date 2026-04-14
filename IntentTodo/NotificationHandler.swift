//
//  NotificationHandler.swift
//  IntentTodo
//
//  通知デリゲート本体。`UNUserNotificationCenterDelegate` は全プラットフォームで
//  同一シグネチャのため、プラットフォーム非依存の1クラスに集約し、
//  iOS / macOS それぞれの AppDelegate から委譲する（Paul Hudson / Swift by Sundell の定番パターン）。
//

import TodoAppIntents
import UserNotifications

/// Shared cross-platform notification delegate.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    private override init() {}

    /// Installs this handler as the shared notification center's delegate and registers categories.
    func install() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self

        let addTodoCategory = UNNotificationCategory(
            identifier: "ADD_TODO_CATEGORY",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        center.setNotificationCategories([addTodoCategory])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    @MainActor
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        let userInfo = content.userInfo
        let isAddTodoAction = (userInfo["action"] as? String) == "addTodo"
            || content.categoryIdentifier == "ADD_TODO_CATEGORY"

        if isAddTodoAction {
            IntentAppState.shared.requestShowAddTodo()
        }
    }
}
