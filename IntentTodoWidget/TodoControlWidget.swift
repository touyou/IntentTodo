//
//  TodoControlWidget.swift
//  IntentTodoWidget
//
//  Control Center widget for quick todo access.
//  Supports iOS 18+ Control Center integration.
//

import AppIntents
import Domain
import Repository
import SwiftData
import SwiftUI
import TodoAppIntents
import WidgetKit

// MARK: - Model Container for Control Widget

private let controlWidgetModelContainer: ModelContainer = {
    let schema = Schema([TodoItem.self, SubTask.self, Category.self])
    let config = ModelConfiguration(schema: schema)
    // swiftlint:disable:next force_try
    return try! ModelContainer(for: schema, configurations: [config])
}()

// MARK: - Quick Add Control Widget

/// Control widget for quickly adding a new todo.
@available(iOS 18.0, *)
struct QuickAddTodoControl: ControlWidget {
    static let kind = "QuickAddTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: QuickAddTodoControlIntent.self
        ) { _ in
            ControlWidgetButton(action: QuickAddTodoControlIntent()) {
                Label("New Todo", systemImage: "plus.circle.fill")
            }
        }
        .displayName("Add Todo")
        .description("Quickly add a new todo.")
    }
}

/// Intent for quick add control.
///
/// Note: ControlConfigurationIntent must be defined in the extension target,
/// not in a package, due to platform-specific requirements.
@available(iOS 18.0, *)
struct QuickAddTodoControlIntent: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Add Todo"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & OpensIntent {
        // Uses OpenAddTodoIntent from TodoAppIntents package
        return .result(opensIntent: OpenAddTodoIntent())
    }
}

// MARK: - Todo Count Control Widget

/// Control widget showing incomplete todo count.
@available(iOS 18.0, *)
struct TodoCountControl: ControlWidget {
    static let kind = "TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTodoListIntent()) {
                Label {
                    Text("Todos")
                } icon: {
                    Image(systemName: "checklist")
                }
            }
        }
        .displayName("Todo Count")
        .description("View your incomplete todos.")
    }
}

// MARK: - Toggle Todo Control Widget

/// Control widget for toggling the most urgent todo.
///
/// Note: Using button-based approach instead of toggle due to iOS 18 API constraints.
@available(iOS 18.0, *)
struct ToggleUrgentTodoControl: ControlWidget {
    static let kind = "ToggleUrgentTodoControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenTodoListIntent()) {
                Label("Urgent Todo", systemImage: "clock.badge.exclamationmark")
            }
        }
        .displayName("Urgent Todo")
        .description("View your most urgent todo.")
    }
}
