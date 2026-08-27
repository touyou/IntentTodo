//
//  SelectTodoConfigurationIntent.swift
//  IntentTodoWidget
//
//  Configuration intent for `ToggleTodoControl`: lets the person pick which todo
//  the control acts on when they add it to Control Center / Lock Screen / Action button.
//

#if !os(visionOS)
import AppIntents
import TodoAppIntents

/// Lets someone choose the todo a control toggles.
///
/// A `ControlWidgetToggle` needs a value that stays put between reloads, so the
/// control has to act on a *fixed* todo. Picking it here is what makes the toggle
/// honest: on means that todo is completed, and turning it off reopens the same todo.
struct SelectTodoConfigurationIntent: ControlConfigurationIntent {
    static let title: LocalizedStringResource = "Select Todo"
    static let description = IntentDescription("Choose which todo this control completes")

    /// Optional so the control can render an "unconfigured" state instead of
    /// failing to resolve; `promptsForUserConfiguration()` asks for it on add.
    @Parameter(title: "Todo")
    var todo: TodoAppEntity?

    init() {}

    init(todo: TodoAppEntity?) {
        self.todo = todo
    }
}
#endif
