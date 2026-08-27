//
//  ControlNotificationHelper.swift
//  TodoAppIntents
//
//  Local notifications used by Control Center intents to report *failures*.
//
//  成功は perform() 完了時の自動リロードでコントロール自身が伝えるので通知しない
//  (二重表示になるうえ通知センターに残る)。失敗だけは他に伝える手段が無い
//  (dialog も snippet も Control では表示されない)。
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
        // `UNMutableNotificationContent` / `UNNotificationRequest` は Sendable ではない
        // ので、Task の中で組む（外で作って渡すと sending 違反になる）。
        Task {
            let content = UNMutableNotificationContent()
            content.title = "Todo Error"
            content.body = message
            content.sound = .default
            // 集中モードの絞り込み中でも黙らされないようにする。`TodoFocusFilterIntent`
            // が返す述語の許可リストは必ずこの criteria を含む（wwdc2022-10121 13:15）。
            content.filterCriteria = TodoFocusFilter.systemNotificationCriteria
            if let todoId {
                content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
            }

            await schedule(content, identifierPrefix: "todo-error")
        }
    }

    /// 通知を出す。**通知が許可されていない場合は記録を残す**。
    ///
    /// `UNUserNotificationCenter.add` は許可が無くても error を返さない（システムが
    /// 黙って捨てる）。ここで許可状態を先に見ておかないと、Control の失敗が
    /// 「通知も出ない / コントロールは前の状態のまま」で完全に無音になる。
    /// 記録は `MissedFeedback` に置き、アプリの一覧が設定誘導のバナーを出す。
    private static func schedule(_ content: UNNotificationContent, identifierPrefix: String) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        // `.ephemeral`（App Clip）は watchOS で unavailable。このアプリは App Clip を
        // 持たないので候補から外す。
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
