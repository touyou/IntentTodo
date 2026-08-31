//
//  ControlNotificationHelper.swift
//  TodoAppIntents
//
//  Local notifications used by Control Center intents to report *failures*.
//
//  Success needs no notification: the control redraws itself when the system reloads it
//  after `perform()` returns. Failure has no other channel, because controls present
//  neither dialogs nor snippets.
//

import AppIntents
import os.log
import UserNotifications

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "ControlNotification")

/// Helper for reporting Control Center failures that have no other feedback channel.
public enum ControlNotificationHelper {
    /// Surface a fetch / mutation failure to the user when no other feedback
    /// channel is available (Control Center context).
    ///
    /// - Parameter todoId: The affected todo, when known. Associating it lets
    ///   Siri / Apple Intelligence understand the notification's context even
    ///   off-screen (WWDC 2026 #343). Requires a persistent `AppEntity`
    ///   (`TransientAppEntity` isn't supported here).
    public static func sendErrorNotification(message: String, todoId: String? = nil) {
        // `UNMutableNotificationContent` and `UNNotificationRequest` are not Sendable, so
        // they are built inside the task rather than passed into it.
        Task {
            let content = UNMutableNotificationContent()
            content.title = "Todo Error"
            content.body = message
            content.sound = .default
            // Keeps the notification audible while a Focus filter is active: the predicate
            // returned by `TodoFocusFilterIntent` always allows this criteria.
            // [Apple: wwdc2022-10121 13:15]
            content.filterCriteria = TodoFocusFilter.systemNotificationCriteria
            if let todoId {
                content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
            }

            await schedule(content, identifierPrefix: "todo-error")
        }
    }

    /// Schedules the notification, recording the miss when notifications are denied.
    ///
    /// `UNUserNotificationCenter.add` does not report an error in that case — the system
    /// drops the request — so without checking the status first a failed control action is
    /// completely silent. The record goes to `MissedFeedback`, which the app's list turns
    /// into a banner pointing at Settings.
    private static func schedule(_ content: UNNotificationContent, identifierPrefix: String) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        // `.ephemeral` (App Clip) is unavailable on watchOS and this app has no App Clip,
        // so it is not among the accepted statuses.
        guard status == .authorized || status == .provisional else {
            logger.error("notification dropped (\(identifierPrefix)): not authorized (status=\(status.rawValue))")
            MissedFeedback.record(.notification)
            return
        }
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            logger.error("notification schedule failed (\(identifierPrefix)): \(String(reflecting: error))")
        }
    }
}
