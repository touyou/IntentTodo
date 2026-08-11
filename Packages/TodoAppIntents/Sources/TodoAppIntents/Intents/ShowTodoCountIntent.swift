//
//  ShowTodoCountIntent.swift
//  TodoAppIntents
//
//  Sends a notification with the current incomplete todo count.
//  Designed for Control Center.
//

import AppIntents

public struct ShowTodoCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Todo Count"
    public static let description = IntentDescription("Shows the current incomplete todo count as a notification")
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        // Control Center は dialog を出さないため通知で返す。
        // fetch 失敗を `try? ?? 0` で握りつぶすと「全部完了!」と嘘表示するため、
        // エラー時は明示的にエラー通知 + throw で Siri / Shortcuts 側にも伝える。
        do {
            let count = try todoService.incompleteCount()
            ControlNotificationHelper.sendTodoCountNotification(count: count)
            return .result(value: count)
        } catch {
            ControlNotificationHelper.sendErrorNotification(
                message: "Couldn't read todos. Open the app to retry."
            )
            throw error
        }
    }
}
