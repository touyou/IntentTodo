//
//  ControlNotificationHelper.swift
//  TodoAppIntents
//
//  Local notifications used by Control Center intents for user feedback.
//  Control Center は dialog を出さないため (docs/insights/06-control-widget-ios26.md
//  で実機検証済み)、通知が唯一のフィードバック経路。スケジュール失敗時はログを残す。
//

import AppIntents
import os.log
import UserNotifications

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "ControlNotification")

/// Helper for sending feedback notifications from Control Center widgets.
public enum ControlNotificationHelper {
    public static func sendToggledNotification(todoTitle: String, isCompleted: Bool, todoId: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = isCompleted ? "Todo Completed" : "Todo Reopened"
        content.body = "\(isCompleted ? "✅" : "⏳") \(todoTitle)"
        content.sound = .default
        // Associate the affected todo so Siri / Apple Intelligence understand the
        // notification's context even off-screen (WWDC 2026 #343). Persistent
        // AppEntity required (TransientAppEntity not supported here).
        if let todoId {
            content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
        }

        schedule(content, identifierPrefix: "todo-toggle")
    }

    public static func sendTodoCountNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Summary"
        content.body = count > 0
            ? "You have \(count) incomplete todo\(count == 1 ? "" : "s"). Tap to view."
            : "All todos completed! 🎉"
        content.sound = .default

        schedule(content, identifierPrefix: "todo-count")
    }

    /// Surface a fetch / lookup error to the user when no other feedback channel
    /// is available (Control Center context).
    public static func sendErrorNotification(message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Error"
        content.body = message
        content.sound = .default

        schedule(content, identifierPrefix: "todo-error")
    }

    private static func schedule(_ content: UNNotificationContent, identifierPrefix: String) {
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("notification schedule failed (\(identifierPrefix)): \(String(reflecting: error))")
            }
        }
    }
}
