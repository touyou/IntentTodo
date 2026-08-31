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
import Foundation

/// Updates selected fields of an existing todo, leaving unmentioned fields intact.
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
        Summary("Update \(\.$todo)") {
            \.$title
            \.$todoDescription
            \.$dueDate
            \.$isFavorite
            \.$estimatedDuration
            \.$assigneeName
            \.$tags
            \.$urls
            \.$recurrenceFrequency
            \.$recurrenceInterval
            \.$locationTriggerEvent
        }
    }

    @Parameter(title: "Todo", description: "The todo to update")
    public var todo: TodoAppEntity

    @Parameter(title: "Title")
    public var title: String?

    @Parameter(title: "Description")
    public var todoDescription: String?

    @Parameter(title: "Due Date")
    public var dueDate: Date?

    @Parameter(title: "Favorite")
    public var isFavorite: Bool?

    @Parameter(title: "Estimated Duration")
    public var estimatedDuration: Duration?

    @Parameter(title: "Assignee")
    public var assigneeName: String?

    // MARK: - Reminders Schema Attributes
    //
    // Exposed here rather than in a separate intent so they ride the same tri-state
    // `valueState` handling. An attribute the entity publishes but no intent can write
    // shows up in Shortcuts as readable-but-not-settable.

    /// Replaces the tag set. `.set(nil)` (an explicitly empty value) clears all tags.
    @Parameter(title: "Tags", description: "Replaces the todo's tags")
    public var tags: [String]?

    /// Replaces the attached links.
    @Parameter(title: "URLs", description: "Replaces the links attached to the todo")
    public var urls: [URL]?

    /// How often the todo repeats. Clearing it stops the repeat.
    @Parameter(title: "Recurrence", description: "How often the todo repeats")
    public var recurrenceFrequency: TodoRecurrenceFrequency?

    /// How many frequency units sit between occurrences (2 + weekly = every other week).
    @Parameter(title: "Repeat Every", description: "Number of frequency units between occurrences")
    public var recurrenceInterval: Int?

    /// Whether arriving at or leaving the todo's location should surface it.
    ///
    /// Only has an effect once the todo has a location — `TodoLocationTriggerAppEntity`
    /// needs both halves, so an event on a todo with no place stays inert rather than
    /// being rejected (the person may set the location afterwards).
    @Parameter(title: "Location Trigger Event", description: "Surface the todo on arrival or departure")
    public var locationTriggerEvent: TodoLocationTriggerEvent?

    @Dependency
    var todoService: TodoService

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    /// Creates an intent that changes only the reminders-schema attributes.
    ///
    /// Every parameter is assigned, so each one's `valueState` becomes `.set` — including
    /// `.set(nil)`, which is how the app's editor clears a field. Parameters this init
    /// doesn't touch stay `.unset` and are left alone by `perform()`.
    public init(
        todo: TodoAppEntity,
        tags: [String],
        urls: [URL],
        recurrenceFrequency: TodoRecurrenceFrequency?,
        recurrenceInterval: Int,
        locationTriggerEvent: TodoLocationTriggerEvent?
    ) {
        self.todo = todo
        self.tags = tags
        self.urls = urls
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceInterval = recurrenceInterval
        self.locationTriggerEvent = locationTriggerEvent
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

        let entity = try todoService.update(
            todoId: todo.id,
            title: Self.requiredUpdate($title.valueState),
            todoDescription: Self.optionalUpdate($todoDescription.valueState),
            dueDate: Self.optionalUpdate($dueDate.valueState),
            isFavorite: Self.requiredUpdate($isFavorite.valueState),
            estimatedDuration: estimatedDurationUpdate,
            assigneeName: Self.optionalUpdate($assigneeName.valueState),
            // Collection fields treat "no value" and "empty" alike, so `.set(nil)`
            // collapses to `.set([])`: clearing and passing an empty array mean the same.
            tags: Self.collectionUpdate($tags.valueState),
            urls: Self.collectionUpdate($urls.valueState),
            recurrenceFrequency: Self.optionalUpdate($recurrenceFrequency.valueState),
            recurrenceInterval: Self.requiredUpdate($recurrenceInterval.valueState),
            locationTriggerEvent: Self.optionalUpdate($locationTriggerEvent.valueState)
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

    /// For collection fields stored non-optionally: `.set(nil)` means "clear", which
    /// for a collection is the empty collection rather than "leave alone".
    private static func collectionUpdate<T>(_ state: IntentParameter<[T]?>.ValueState) -> FieldUpdate<[T]> {
        if case .set(let value) = state { return .set(value ?? []) }
        return .unchanged
    }
}
