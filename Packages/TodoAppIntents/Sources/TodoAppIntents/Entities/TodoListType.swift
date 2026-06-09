//
//  TodoListType.swift
//  TodoAppIntents
//

import AppIntents

/// The kind of list a category represents, conforming to the reminders
/// `listType` assistant schema so Siri / Apple Intelligence understand it.
@AppEnum(schema: .reminders.listType)
public enum TodoListType: String {
    case standard

    public static let caseDisplayRepresentations: [TodoListType: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}
