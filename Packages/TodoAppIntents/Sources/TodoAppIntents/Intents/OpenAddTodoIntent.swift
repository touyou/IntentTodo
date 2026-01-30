//
//  OpenAddTodoIntent.swift
//  TodoAppIntents
//
//  Intent to open app with add todo screen.
//

import AppIntents

/// Intent to open app with add todo sheet.
///
/// This intent is used by widgets and control center to open the app
/// directly to the add todo screen.
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
            )
        )
    }

    public static var openAppWhenRun: Bool { true }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult {
        // The app will handle showing the add todo sheet
        return .result()
    }
}

/// Intent for Action Button integration.
///
/// Allows quick todo creation with physical button press.
public struct ActionButtonAddTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        LocalizedStringResource("Quick Add Todo", comment: "Intent title for quick add")
    }

    public static var description: IntentDescription {
        IntentDescription(
            LocalizedStringResource(
                "Create a new todo with Action Button",
                comment: "Intent description for action button add"
            )
        )
    }

    public static var openAppWhenRun: Bool { true }

    // MARK: - Initialization

    public init() {}

    // MARK: - Perform

    public func perform() async throws -> some IntentResult {
        // Opens app to add todo screen
        return .result()
    }
}
