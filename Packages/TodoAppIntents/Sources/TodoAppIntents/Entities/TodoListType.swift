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
///
/// The fallback carries a distinct type name for the same reason as
/// `WatchCategoryAppEntity`: sharing one mangled name across a schema variant and a
/// schema-less variant lets the merge into the iOS app's unified metadata drop the
/// schema. See `CategoryAppEntity` for the full note.
#if os(watchOS)
public enum WatchTodoListType: String, AppEnum {
    case standard

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "List Type"

    public static let caseDisplayRepresentations: [WatchTodoListType: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}

// スキーマ識別子は文字列なので watchOS でも手書きで適合できる。
// 詳細: CategoryAppEntity の同名 extension のコメント
extension WatchTodoListType: AssistantSchemaEnum {
    // swiftlint:disable:next identifier_name
    public static let __appSchemaEnum = "reminders.listType"
}

/// Call sites use the shared name on every platform.
public typealias TodoListType = WatchTodoListType
#else
@AppEnum(schema: .reminders.listType)
public enum TodoListType: String {
    case standard

    public static let caseDisplayRepresentations: [TodoListType: DisplayRepresentation] = [
        .standard: "Standard"
    ]
}
#endif
