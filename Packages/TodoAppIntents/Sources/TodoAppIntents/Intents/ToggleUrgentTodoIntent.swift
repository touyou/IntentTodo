//
//  ToggleUrgentTodoIntent.swift
//  TodoAppIntents
//
//  Auto-selects the most urgent (earliest-due) incomplete todo and toggles it.
//  Designed for Control Center (no parameter picking available there).
//

import AppIntents

public struct ToggleUrgentTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Urgent Todo"
    public static let description = IntentDescription("Toggles completion of the most urgent todo")
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let result = try todoService.toggleMostUrgentTodo() else {
            return .result()
        }
        // Control Center では Dialog が表示されない (2026-04-14 検証済み) ため、
        // 通知でフィードバックを返す。
        ControlNotificationHelper.sendToggledNotification(
            todoTitle: result.title,
            isCompleted: result.isNowCompleted
        )
        return .result()
    }
}
