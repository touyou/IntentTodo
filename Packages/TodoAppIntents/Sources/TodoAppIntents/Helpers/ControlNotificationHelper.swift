//
//  ControlNotificationHelper.swift
//  TodoAppIntents
//
//  Local notifications used by Control Center intents to report *failures*.
//
//  成功時のフィードバックは通知ではなくコントロール自身の再描画で行う
//  (Apple: perform() が返ると system が control をリロードする)。数や完了状態は
//  コントロール面に既に出ているので、成功通知は二重表示になるうえ通知センターに
//  残り続ける。失敗だけは他に伝える手段が無い (dialog も snippet も Control では
//  表示されない) ため通知に残している。詳細は docs/insights/06-control-widget-ios26.md。
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
        let content = UNMutableNotificationContent()
        content.title = "Todo Error"
        content.body = message
        content.sound = .default
        if let todoId {
            content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
        }

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
