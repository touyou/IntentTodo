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
        let count = (try? todoService.incompleteCount()) ?? 0

        // Control Center では Dialog が表示されない (2026-04-14 検証済み) ため通知で返す。
        // ReturnsValue<Int> は Siri / Shortcuts から呼んだときの後続アクション用途。
        ControlNotificationHelper.sendTodoCountNotification(count: count)
        return .result(value: count)
    }
}
