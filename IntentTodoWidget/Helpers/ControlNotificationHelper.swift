//
//  ControlNotificationHelper.swift
//  IntentTodoWidget
//
//  Helper for sending local notifications from Control Center widgets.
//  Control Widgets use .background mode intents with notification feedback
//  because opening the app from Control Widgets is unreliable on iOS 26.
//  See docs/INSIGHTS.md Section 18 for details.
//

import UserNotifications

/// Helper for sending feedback notifications from Control Center widgets.
///
/// Control Widgets run `.background` mode intents and use local notifications
/// to provide user feedback and optionally guide them to open the app.
enum ControlNotificationHelper {
    // MARK: - Todo Completion

    /// Notification when a todo is completed.
    static func sendCompletedNotification(todoTitle: String) {
        let content = UNMutableNotificationContent()
        content.title = "Todo Completed"
        content.body = "✅ \(todoTitle)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "todo-completed-\(UUID().uuidString)",
            content: content,
            trigger: nil
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

    // MARK: - Quick Add

    /// Notification prompting the user to add a new todo.
    /// Tapping the notification triggers the add todo flow via AppDelegate's
    /// `didReceive response:` handler which checks for `userInfo["action"] == "addTodo"`.
    static func sendQuickAddNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Add New Todo"
        content.body = "Tap to open the app and add a new todo."
        content.sound = .default
        content.categoryIdentifier = "ADD_TODO_CATEGORY"
        content.userInfo = ["action": "addTodo"]

        let request = UNNotificationRequest(
            identifier: "quick-add-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Todo Count

    /// Notification showing the current incomplete todo count.
    static func sendTodoCountNotification(count: Int) {
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
