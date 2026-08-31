//
//  NotificationHandler.swift
//  IntentTodo
//
//  The notification delegate. `UNUserNotificationCenterDelegate` has the same signature on
//  every platform, so it lives in one platform-independent class that the iOS and macOS app
//  delegates both install.
//

import TodoAppIntents
import UserNotifications

/// Shared cross-platform notification delegate.
///
/// Notification taps navigate by writing to the `NavigationModel` injected at launch, the
/// same object intents write to.
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    /// Injected by `IntentTodoApp.init()`; written to when a notification is tapped.
    @MainActor var navigationModel: NavigationModel?

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
            navigationModel?.showAddTodo()
        }
    }
}
