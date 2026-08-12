//
//  SetTodoCompletionIntent.swift
//  TodoAppIntents
//
//  Backs `ToggleTodoControl` in Control Center. `SetValueIntent` is the protocol
//  Apple requires for a `ControlWidgetToggle` action: the system populates `value`
//  with the state the toggle moved to, and we make the store match it.
//

import AppIntents

/// Sets a specific todo's completion state to an absolute value.
///
/// Takes the todo id as a `String` rather than a `TodoAppEntity` parameter,
/// following the FromExtension convention: the caller (a control) already knows
/// which todo it acts on, so there is no reason to pay for — or risk — the
/// pre-`perform()` entity resolution phase in an extension process.
public struct SetTodoCompletionIntent: SetValueIntent {
    public static let title: LocalizedStringResource = "Set Todo Completion"
    public static let description = IntentDescription("Marks a specific todo as completed or incomplete")
    public static let supportedModes: IntentModes = [.background]

    /// Control-driven only; Siri / Shortcuts users get `ToggleTodoCompletionIntent`,
    /// which takes a real entity parameter and can be picked from a list.
    public static let isDiscoverable = false

    @Parameter(title: "Todo ID")
    public var todoId: String

    /// Populated by the system with the toggle's new state. Never set this yourself.
    @Parameter(title: "Completed")
    public var value: Bool

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todoId: String) {
        self.todoId = todoId
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard !todoId.isEmpty else {
            // Reached when the control hasn't been configured with a todo yet.
            throw IntentError.validation("This control isn't set up with a todo yet")
        }
        do {
            try todoService.setCompletion(todoId: todoId, isCompleted: value)
        } catch {
            // A failed control tap has no other feedback channel: Control Center
            // shows no dialog, and the control simply re-renders its old state,
            // which reads as "nothing happened" rather than "this failed".
            ControlNotificationHelper.sendErrorNotification(
                message: "Couldn't update the todo. Open the app to retry.",
                todoId: todoId
            )
            throw error
        }
        // snippet は返さない。Control は snippet を提示しないことを実機で確認済み
        // (docs/devlog/06-control-widget-ios26.md)。フィードバックは perform() 完了時の
        // 自動リロードによるトグル自身の再描画で行う。
        return .result()
    }
}
