//
//  TodoListType.swift
//  TodoAppIntents
//

import AppIntents

/// The kind of list a category represents.
///
/// On most platforms this conforms to the reminders `listType` assistant schema
/// (`@AppEnum(schema: .reminders.listType)`) so Siri / Apple Intelligence understand
/// it. The reminders schemas are unavailable on watchOS (Xcode 27 beta 2), so there
/// it falls back to a plain `AppEnum`. `CategoryAppEntity.type` references this type
/// on every platform, so it must still exist on watchOS.
#if os(watchOS)
public enum TodoListType: String, AppEnum {
    case standard

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "List Type"

    public static let caseDisplayRepresentations: [TodoListType: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}
#else
@AppEnum(schema: .reminders.listType)
public enum TodoListType: String {
    case standard

    public static let caseDisplayRepresentations: [TodoListType: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}
#endif
