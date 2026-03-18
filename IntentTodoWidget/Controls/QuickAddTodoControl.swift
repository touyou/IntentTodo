import SwiftUI
import WidgetKit

/// Control Widget for quickly adding a new todo.
/// Sends a notification prompting the user to open the app.
/// Uses .background intent because opening the app directly from
/// Control Widgets is unreliable on iOS 26.
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: QuickAddTodoNotifyIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}
