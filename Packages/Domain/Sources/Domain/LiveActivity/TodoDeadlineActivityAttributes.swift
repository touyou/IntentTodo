//
//  TodoDeadlineActivityAttributes.swift
//  Domain
//
//  Attributes for the todo deadline Live Activity.
//  This is defined in Domain so both the main app and
//  the Live Activity extension can access it.
//

import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Attributes for the todo deadline Live Activity.
///
/// Use this to start a Live Activity for a todo that's due soon.
/// The activity shows the todo title, remaining time, and allows
/// completing or snoozing from the Dynamic Island / Lock Screen.
@available(iOS 16.1, *)
public struct TodoDeadlineActivityAttributes: ActivityAttributes {
    // MARK: - Content State

    /// Dynamic content that updates during the activity.
    public struct ContentState: Codable, Hashable, Sendable {
        /// The todo's title.
        public var title: String

        /// The due date/time.
        public var dueDate: Date

        /// Whether the todo is completed.
        public var isCompleted: Bool

        // MARK: - Initialization

        public init(title: String, dueDate: Date, isCompleted: Bool = false) {
            self.title = title
            self.dueDate = dueDate
            self.isCompleted = isCompleted
        }
    }

    // MARK: - Static Attributes

    /// The todo's unique identifier.
    public var todoId: String

    // MARK: - Initialization

    public init(todoId: String) {
        self.todoId = todoId
    }
}
#endif
