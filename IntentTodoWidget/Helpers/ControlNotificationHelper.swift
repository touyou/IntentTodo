//
//  ControlNotificationHelper.swift
//  IntentTodoWidget
//
//  Helper for sending local notifications from Control Center widgets.
//

import UserNotifications

/// Helper for sending feedback notifications from Control Center widgets.
///
/// With iOS 26+, `OpenIntent` and `supportedModes` replace the notification-based
/// workaround for opening apps. This helper now only provides feedback notifications
/// for actions like completing/uncompleting todos.
enum ControlNotificationHelper {
    // MARK: - Notification Types

    /// Notification when a todo is completed.
    static func sendCompletedNotification(todoTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Completed"
        content.body = "✅ \(todoTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request)
    }

    /// Notification when a todo is marked incomplete.
    static func sendUncompletedNotification(todoTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Reopened"
        content.body = "⏳ \(todoTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-uncompleted-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
