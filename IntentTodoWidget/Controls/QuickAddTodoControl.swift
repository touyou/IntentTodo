#if os(iOS)
import AppIntents
import SwiftUI
import TodoAppIntents
import WidgetKit

/// Control Widget for quickly adding a new todo.
/// Tapping launches the app directly to the add todo screen.
/// Uses LaunchAppIntent.addTodo() (.foreground(.immediate)) with the correct reverse-domain kind.
struct QuickAddTodoControl: ControlWidget {
    static let kind = "dev.touyou.IntentTodo.IntentTodoWidget.QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LaunchAppIntent.addTodo()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}
#endif
