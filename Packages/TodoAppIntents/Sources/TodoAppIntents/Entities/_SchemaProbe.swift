//
//  _SchemaProbe.swift
//  TodoAppIntents
//
//  TEMPORARY probe to validate how to initialize a `.reminders.reminder`
//  schema-conforming entity. Delete after the approach is confirmed.
//

import AppIntents

@AppEntity(schema: .reminders.reminder)
struct ReminderProbe: Hashable {
    var id: String
    var title: String
    var note: AttributedString?
    var images: [IntentFile]
    var subtasks: [ReminderProbe]
    var tags: Set<String>
    var urls: [URL]
    var dueDate: DateComponents?
    var recurrence: Calendar.RecurrenceRule?
    var isCompleted: Bool
    var isFlagged: Bool?
    var creationDate: Date?
    var completionDate: Date?
    var list: CategoryAppEntity

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    static var defaultQuery = ReminderProbeQuery()

    // Explicit memberwise init (per SDK 27 @State-as-macro guidance: the macro
    // skips synthesizing it). Params map 1:1 to properties.
    init(
        id: String,
        title: String,
        note: AttributedString?,
        images: [IntentFile],
        subtasks: [ReminderProbe],
        tags: Set<String>,
        urls: [URL],
        dueDate: DateComponents?,
        recurrence: Calendar.RecurrenceRule?,
        isCompleted: Bool,
        isFlagged: Bool?,
        creationDate: Date?,
        completionDate: Date?,
        list: CategoryAppEntity
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.images = images
        self.subtasks = subtasks
        self.tags = tags
        self.urls = urls
        self.dueDate = dueDate
        self.recurrence = recurrence
        self.isCompleted = isCompleted
        self.isFlagged = isFlagged
        self.creationDate = creationDate
        self.completionDate = completionDate
        self.list = list
    }
}

struct ReminderProbeQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [ReminderProbe] { [] }
    func suggestedEntities() async throws -> [ReminderProbe] { [] }
}
