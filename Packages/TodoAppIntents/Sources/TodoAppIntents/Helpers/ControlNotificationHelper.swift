//
//  ControlNotificationHelper.swift
//  TodoAppIntents
//
//  Local notifications used by Control Center intents for user feedback.
//

import UserNotifications

/// Helper for sending feedback notifications from Control Center widgets.
public enum ControlNotificationHelper {
    public static func sendToggledNotification(todoTitle: String, isCompleted: Bool) {
        let content = UNMutableNotificationContent()
        content.title = isCompleted ? "Todo Completed" : "Todo Reopened"
        content.body = "\(isCompleted ? "✅" : "⏳") \(todoTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-toggle-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    public static func sendTodoCountNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Summary"
        content.body = count > 0
            ? "You have \(count) incomplete todo\(count == 1 ? "" : "s"). Tap to view."
            : "All todos completed! 🎉"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-count-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
