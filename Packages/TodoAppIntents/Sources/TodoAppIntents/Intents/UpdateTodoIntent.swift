//
//  UpdateTodoIntent.swift
//  TodoAppIntents
//
//  Partial update of a todo's optional fields. Exercises WWDC 2026 #344's
//  `IntentParameter.valueState`, which distinguishes three states per parameter:
//  - `.set(value)`  → the caller provided a new value
//  - `.set(nil)`    → the caller explicitly cleared an optional field
//  - `.unset`       → the caller didn't mention the field → leave it untouched
//
//  A plain `nil` check collapses the first/second/third cases, so "clear the due
//  date" and "leave the due date alone" become indistinguishable. `valueState`
//  preserves the distinction; each parameter is mapped to a `FieldUpdate` and
//  handed to `TodoService.update(...)`.
//

import AppIntents
import Domain
import Foundation

/// Updates selected fields of an existing todo, leaving unmentioned fields intact.
#if !os(watchOS)
@AppIntent(schema: .reminders.updateReminder)
#endif
public struct UpdateTodoIntent: AppIntent {
    public static var title: LocalizedStringResource { "Update Todo" }

    public static var description: IntentDescription {
        IntentDescription(
            "Updates a todo's details. Fields you leave blank are kept as-is.",
            categoryName: "Todos",
            searchKeywords: ["update", "edit", "change", "modify", "tag", "repeat"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    /// **The summary is the allowlist for the Shortcuts editor**, not just a label: a
    /// `@Parameter` named nowhere in it still resolves but is never offered as an
    /// editable row, so a field that isn't listed here has no write path from
    /// Shortcuts at all. Everything this intent can change is therefore listed.
    public static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$target)") {
            \.$title
            \.$note
            \.$dueDate
            \.$isFlagged
            \.$isCompleted
            \.$estimatedDuration
            \.$assigneeName
            \.$locationName
            \.$tags
            \.$urls
            \.$recurrence
            #if !os(watchOS)
            \.$locationTrigger
            #endif
            \.$locationTriggerEvent
            \.$list
            \.$section
            \.$images
        }
    }

    /// The todo being changed. Named `target` because that is the schema's spelling — a
    /// parameter outside the schema would have to be optional, which the subject of an
    /// update cannot be.
    @Parameter(title: "Todo", description: "The todo to update")
    public var target: TodoAppEntity

    @Parameter(title: "Title")
    public var title: String?

    /// The schema's name and type for the longer text (the model stores a `String`).
    @Parameter(title: "Description")
    public var note: AttributedString?

    /// `DateComponents` rather than `Date`, as the schema declares.
    @Parameter(title: "Due Date")
    public var dueDate: DateComponents?

    /// The schema's name for what the app calls a favorite.
    @Parameter(title: "Favorite")
    public var isFlagged: Bool?

    /// Completion, which the schema includes in an update.
    ///
    /// `SetTodoCompletionIntent` remains the control-facing way to write it; both land in
    /// `TodoService`, which keeps `completionDate` in step.
    @Parameter(title: "Completed")
    public var isCompleted: Bool?

    @Parameter(title: "Estimated Duration")
    public var estimatedDuration: Duration?

    @Parameter(title: "Assignee")
    public var assigneeName: String?

    /// Place name. A `String` for the same reason as `AddTodoIntent.location`: a system
    /// value type here would take the voice-training assets down with it (FB24548956).
    @Parameter(title: "Location", description: "Place associated with the todo")
    public var locationName: String?

    // MARK: - Reminders Schema Attributes
    //
    // Exposed here rather than in a separate intent so they ride the same tri-state
    // `valueState` handling. An attribute the entity publishes but no intent can write
    // shows up in Shortcuts as readable-but-not-settable.

    /// Replaces the tag set. `.set(nil)` (an explicitly empty value) clears all tags.
    ///
    /// A `Set` is the schema's shape, so the stored order is chosen by the write path.
    @Parameter(title: "Tags", description: "Replaces the todo's tags")
    public var tags: Set<String>?

    /// Replaces the attached links.
    @Parameter(title: "URLs", description: "Replaces the links attached to the todo")
    public var urls: [URL]?

    /// How often the todo repeats, as a whole rule. Clearing it stops the repeat.
    @Parameter(title: "Recurrence", description: "How often the todo repeats")
    public var recurrence: Calendar.RecurrenceRule?

    /// Place plus arrive/depart event, as the schema models it.
    #if !os(watchOS)
    @Parameter(title: "Location Trigger", description: "Surface the todo on arrival or departure")
    public var locationTrigger: TodoLocationTriggerAppEntity?
    #endif

    /// Whether arriving at or leaving the todo's location should surface it.
    ///
    /// Kept next to the schema's `locationTrigger` because that entity needs **both**
    /// halves, so an event set on a todo with no place yet stays inert rather than being
    /// rejected (the person may add the location afterwards). `locationTrigger` wins when
    /// both arrive.
    @Parameter(title: "Location Trigger Event", description: "Surface the todo on arrival or departure")
    public var locationTriggerEvent: TodoLocationTriggerEvent?

    /// Moves the todo to another list. `.set(nil)` files it as uncategorized, which also
    /// drops any section (a section belongs to one list).
    @Parameter(title: "List", description: "The list the todo belongs to")
    public var list: CategoryAppEntity?

    /// Moves the todo to a section. A section carries its own list, so it wins over `list`.
    @Parameter(title: "Section", description: "The section the todo belongs to")
    public var section: TodoSectionAppEntity?

    /// Replaces the attached images. `.set(nil)` (an explicitly empty value) removes them.
    ///
    /// `.reminders.updateReminder` does not carry images, so this is one of the app's own
    /// parameters — which the schema requires to be optional.
    @Parameter(title: "Images", description: "Replaces the images attached to the todo")
    public var images: [IntentFile]?

    @Dependency
    var todoService: TodoService

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    /// Creates an intent carrying every editable field, as the app's edit form does.
    ///
    /// Every parameter is assigned, so each one's `valueState` becomes `.set` — including
    /// `.set(nil)`, which is how the form clears a field. No parameter has a default: a
    /// field added to the intent has to be answered here, which is what keeps the form
    /// from silently editing less than `AddTodoIntent` creates.
    ///
    /// The form is therefore last-write-wins over the whole todo, not a partial patch:
    /// it starts from the current values, so a field left untouched is written back as-is.
    public init(
        todo: TodoAppEntity,
        title: String,
        todoDescription: String?,
        dueDate: Date?,
        isFavorite: Bool,
        estimatedDuration: Duration?,
        assigneeName: String?,
        locationName: String?,
        tags: [String],
        urls: [URL],
        recurrenceFrequency: TodoRecurrenceFrequency?,
        recurrenceInterval: Int,
        locationTriggerEvent: TodoLocationTriggerEvent?,
        list: CategoryAppEntity?,
        section: TodoSectionAppEntity?,
        images: [TodoAttachmentValue]
    ) {
        self.target = todo
        self.title = title
        self.note = todoDescription.map { AttributedString($0) }
        self.dueDate = TodoDueDate.components(from: dueDate)
        self.isFlagged = isFavorite
        // The form does not edit completion (the checkbox has its own intent), so this
        // stays `.unset` and the stored value is left alone.
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.locationName = locationName
        self.tags = Set(tags)
        self.urls = urls
        self.recurrence = recurrenceFrequency.flatMap {
            TodoRecurrence.rule(frequency: $0.rawValue, interval: recurrenceInterval)
        }
        self.locationTriggerEvent = locationTriggerEvent
        self.list = list
        self.section = section
        // The form already holds stored attachments as values; re-wrapping them as
        // `IntentFile` keeps one parameter for both callers, and `applyAttachments`
        // matches the ids back to the rows it already has.
        self.images = images.map(TodoAttachments.intentFile(from:))
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // Estimated duration is stored as a `TimeInterval` on the model, so bridge
        // the system `Duration` here while preserving the three-way value state.
        let estimatedDurationUpdate: FieldUpdate<TimeInterval?>
        if case .set(let duration) = $estimatedDuration.valueState {
            estimatedDurationUpdate = .set(duration.map { TimeInterval($0.components.seconds) })
        } else {
            estimatedDurationUpdate = .unchanged
        }

        #if !os(watchOS)
        let trigger = locationTrigger.map { TodoPlace.decompose($0.place) }
        let triggerEventState: FieldUpdate<TodoLocationTriggerEvent?> =
            if let event = locationTrigger?.event { .set(event) }
            else { Self.optionalUpdate($locationTriggerEvent.valueState) }
        #else
        let trigger: TodoPlace.Components? = nil
        let triggerEventState = Self.optionalUpdate($locationTriggerEvent.valueState)
        #endif

        let entity = try todoService.update(
            todoId: target.id,
            title: Self.requiredUpdate($title.valueState),
            todoDescription: Self.attributedUpdate($note.valueState),
            dueDate: Self.dueDateUpdate($dueDate.valueState),
            isFavorite: Self.requiredUpdate($isFlagged.valueState),
            isCompleted: Self.requiredUpdate($isCompleted.valueState),
            estimatedDuration: estimatedDurationUpdate,
            assigneeName: Self.optionalUpdate($assigneeName.valueState),
            // A trigger names its own place, so it wins over the bare name.
            locationName: trigger.map { .set($0.name) }
                ?? Self.optionalUpdate($locationName.valueState),
            // Collection fields treat "no value" and "empty" alike, so `.set(nil)`
            // collapses to `.set([])`: clearing and passing an empty array mean the same.
            tags: Self.tagsUpdate($tags.valueState),
            urls: Self.collectionUpdate($urls.valueState),
            recurrenceFrequency: Self.recurrenceUpdate($recurrence.valueState).frequency,
            recurrenceInterval: Self.recurrenceUpdate($recurrence.valueState).interval,
            locationTriggerEvent: triggerEventState,
            listId: Self.entityUpdate($list.valueState),
            sectionId: Self.entityUpdate($section.valueState),
            attachments: Self.attachmentUpdate($images.valueState)
        )
        // A no-op unless the attribute editor is open, mirroring `AddTodoIntent`.
        navigationModel.dismissAttributeEditor()
        return .result(value: entity)
    }

    // MARK: - valueState → FieldUpdate mapping

    /// For optional model fields: `.set(value)` (incl. `.set(nil)` = explicit
    /// clear) maps straight through; `.unset` means leave the field alone.
    private static func optionalUpdate<T>(_ state: IntentParameter<T?>.ValueState) -> FieldUpdate<T?> {
        if case .set(let value) = state { return .set(value) }
        return .unchanged
    }

    /// For required model fields exposed as optional parameters: a present value
    /// updates the field; `.set(nil)` and `.unset` both leave it unchanged (a
    /// required field can't be cleared).
    private static func requiredUpdate<T>(_ state: IntentParameter<T?>.ValueState) -> FieldUpdate<T> {
        if case .set(let value?) = state { return .set(value) }
        return .unchanged
    }

    /// For entity-typed parameters the service takes by id: the three states carry over,
    /// with `.set(nil)` meaning "unfile".
    private static func entityUpdate<T: AppEntity>(
        _ state: IntentParameter<T?>.ValueState
    ) -> FieldUpdate<String?> where T.ID == String {
        if case .set(let value) = state { return .set(value?.id) }
        return .unchanged
    }

    /// Attachments follow the collection rule (`.set(nil)` means "remove them all"),
    /// with each file mapped to the value type the service stores.
    private static func attachmentUpdate(
        _ state: IntentParameter<[IntentFile]?>.ValueState
    ) -> FieldUpdate<[TodoAttachmentValue]> {
        if case .set(let files) = state {
            return .set((files ?? []).map(TodoAttachments.value(from:)))
        }
        return .unchanged
    }

    /// `AttributedString` is the schema's type for the note; the model stores plain text.
    private static func attributedUpdate(
        _ state: IntentParameter<AttributedString?>.ValueState
    ) -> FieldUpdate<String?> {
        if case .set(let value) = state { return .set(value.map { String($0.characters) }) }
        return .unchanged
    }

    /// The schema's `DateComponents` resolved against the current calendar.
    private static func dueDateUpdate(
        _ state: IntentParameter<DateComponents?>.ValueState
    ) -> FieldUpdate<Date?> {
        if case .set(let value) = state { return .set(TodoDueDate.date(from: value)) }
        return .unchanged
    }

    /// Tags arrive as a `Set`, so the stored order is chosen here — collation order, which
    /// at least makes it deterministic.
    private static func tagsUpdate(
        _ state: IntentParameter<Set<String>?>.ValueState
    ) -> FieldUpdate<[String]> {
        if case .set(let value) = state {
            return .set((value ?? []).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        }
        return .unchanged
    }

    /// A whole rule split into the primitives the model stores. `.set(nil)` clears the
    /// repeat, which is why the interval falls back to the minimum rather than staying put.
    private static func recurrenceUpdate(
        _ state: IntentParameter<Calendar.RecurrenceRule?>.ValueState
    ) -> (frequency: FieldUpdate<TodoRecurrenceFrequency?>, interval: FieldUpdate<Int>) {
        guard case .set(let rule) = state else { return (.unchanged, .unchanged) }
        let parts = TodoRecurrence.decompose(rule)
        return (.set(parts.frequency), .set(parts.interval))
    }

    /// For collection fields stored non-optionally: `.set(nil)` means "clear", which
    /// for a collection is the empty collection rather than "leave alone".
    private static func collectionUpdate<T>(_ state: IntentParameter<[T]?>.ValueState) -> FieldUpdate<[T]> {
        if case .set(let value) = state { return .set(value ?? []) }
        return .unchanged
    }
}
