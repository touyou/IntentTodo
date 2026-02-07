//
//  QuickAddTodoControl.swift
//  IntentTodoWidget
//
//  Control Center widget for quickly adding a new todo.
//

import SwiftUI
import WidgetKit

/// Control widget for quickly adding a new todo.
///
/// Uses `StaticControlConfiguration` with `LocalOpenAddTodoIntent` for reliable app launch.
/// This uses a simple, parameterless intent which works more reliably with Control Center.
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LocalOpenAddTodoIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}
