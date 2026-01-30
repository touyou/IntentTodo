//
//  OpenAddTodoIntent.swift
//  IntentTodo
//

import AppIntents

/// Intent to open app with add todo sheet.
///
/// This intent is used by:
/// - Widgets: Quick add button
/// - Control Center: Quick add control
/// - Action Button: Physical button press on iPhone 15 Pro+
/// - Shortcuts: Open to add screen
public struct OpenAddTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Open Add Todo", comment: "Intent title for opening add todo")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Opens the app to add a new todo",
                comment: "Intent description for opening add todo"
            ),
            categoryName: "Todos",
            searchKeywords: ["add", "create", "new", "quick", "action button"]
        )
    }

    public static var openAppWhenRun: Bool { true }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult {
        .result()
    }
}
