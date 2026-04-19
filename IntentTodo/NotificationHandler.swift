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
///
/// 通知タップ時の「Add Todo 画面を開く」導線は、IntentTodoApp 起動時に注入される
/// `NavigationModel` に直接書き込むことで実現する（旧 `IntentAppState` 経路は削除）。
final class NotificationHandler: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationHandler()

    /// 起動時に `IntentTodoApp.init()` から注入される。通知タップ時にここへ書き込む。
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
