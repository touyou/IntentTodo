//
//  AddTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Foundation

/// An intent that creates a new todo item.
///
/// This intent can be triggered via:
/// - Siri: "Add a todo called 'Buy groceries' in IntentTodo"
/// - Shortcuts: Add Todo action
/// - UI: `Button(intent: AddTodoIntent(title: "..."))`
public struct AddTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        "Add Todo"
    }

    public static var description: IntentDescription {
        IntentDescription(
            "Creates a new todo item",
            categoryName: "Todos",
            searchKeywords: ["create", "new", "add", "task", "todo"]
        )
    }

    /// Creating a todo never needs the app on screen: `perform()` returns a value and a
    /// snippet, so there is no path that would actually bring it forward.
    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process — two processes writing the
    /// same store can conflict. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    /// **The summary is the allowlist for the Shortcuts editor**: a `@Parameter` that
    /// appears neither in the sentence nor in the trailing block still resolves but is
    /// never offered as an editable row. Listing every parameter is what makes them
    /// settable from Shortcuts.
    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$title)") {
            \.$todoDescription
            \.$dueDate
            \.$isFavorite
            \.$estimatedDuration
            \.$assignee
            \.$location
            \.$tags
            \.$urls
            \.$recurrenceFrequency
            \.$recurrenceInterval
            \.$locationTriggerEvent
        }
    }

    // MARK: - Parameters

    @Parameter(title: "Title", description: "The title of the new todo")
    public var title: String

    @Parameter(title: "Description", description: "Optional description for the todo")
    public var todoDescription: String?

    @Parameter(title: "Due Date", description: "Optional due date for the todo")
    public var dueDate: Date?

    @Parameter(title: "Mark as Favorite", description: "Whether to mark as favorite", default: false)
    public var isFavorite: Bool

    /// Estimated time to complete. Uses the App Intents native `Duration` type
    /// (WWDC 2026) so Siri / Shortcuts present a proper duration picker.
    @Parameter(title: "Estimated Duration", description: "Estimated time to complete")
    public var estimatedDuration: Duration?

    /// Person to assign the todo to. Uses the App Intents native
    /// `PersonNameComponents` type (WWDC 2026) so Siri can resolve a name.
    @Parameter(title: "Assignee", description: "Person responsible for the todo")
    public var assignee: PersonNameComponents?

    /// Place name, deliberately a `String` rather than `GeoToolbox.PlaceDescriptor`.
    ///
    /// A system value type in the `@Parameter` of an App Shortcut-registered intent makes
    /// `AppIntentsSSUTraining` emit `GeoToolbox.PlaceDescriptorEntity` as a variable name;
    /// the dot fails its `^[a-zA-Z_][a-zA-Z_$0-9]*$` check and **no voice-training assets
    /// are produced at all** — while the local build still reports success. SDK bug,
    /// reported as FB24548956. `TodoPlace` rebuilds a `PlaceDescriptor` from this name plus
    /// the coordinates.
    @Parameter(title: "Location", description: "Place associated with the todo")
    public var location: String?

    // MARK: - Reminders Schema Attributes

    /// Free-form tags to attach to the new todo.
    @Parameter(title: "Tags", description: "Tags to attach to the todo")
    public var tags: [String]?

    /// Links to attach to the new todo.
    @Parameter(title: "URLs", description: "Links to attach to the todo")
    public var urls: [URL]?

    /// How often the todo should repeat.
    @Parameter(title: "Recurrence", description: "How often the todo repeats")
    public var recurrenceFrequency: TodoRecurrenceFrequency?

    /// How many frequency units sit between occurrences.
    @Parameter(title: "Repeat Every", description: "Number of frequency units between occurrences")
    public var recurrenceInterval: Int?

    /// Whether arriving at or leaving `location` should surface the todo. Inert until
    /// the todo has a location — both halves are needed to form a trigger.
    @Parameter(title: "Location Trigger Event", description: "Surface the todo on arrival or departure")
    public var locationTriggerEvent: TodoLocationTriggerEvent?

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    @Dependency
    var navigationModel: NavigationModel

    // MARK: - Initialization

    public init() {}

    /// Creates an intent with the specified parameters.
    public init(
        title: String,
        todoDescription: String? = nil,
        dueDate: Date? = nil,
        isFavorite: Bool = false,
        estimatedDuration: Duration? = nil,
        assignee: PersonNameComponents? = nil,
        location: String? = nil,
        tags: [String]? = nil,
        urls: [URL]? = nil,
        recurrenceFrequency: TodoRecurrenceFrequency? = nil,
        recurrenceInterval: Int? = nil,
        locationTriggerEvent: TodoLocationTriggerEvent? = nil
    ) {
        self.title = title
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
        self.estimatedDuration = estimatedDuration
        self.assignee = assignee
        self.location = location
        self.tags = tags
        self.urls = urls
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceInterval = recurrenceInterval
        self.locationTriggerEvent = locationTriggerEvent
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog & ShowsSnippetIntent {
        let entity = try todoService.create(
            title: title,
            todoDescription: todoDescription,
            dueDate: dueDate,
            isFavorite: isFavorite,
            estimatedDuration: estimatedDuration.map { Double($0.components.seconds) },
            assigneeName: assignee.map { PersonNameComponentsFormatter().string(from: $0) },
            locationName: location.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 },
            locationLatitude: nil,
            locationLongitude: nil,
            tags: tags ?? [],
            urls: urls ?? [],
            recurrenceFrequency: recurrenceFrequency,
            recurrenceInterval: recurrenceInterval ?? TodoRecurrence.minimumInterval,
            locationTriggerEvent: locationTriggerEvent
        )
        // A no-op unless the add sheet is open, which ties "sheet closes" to "intent
        // succeeded" instead of to a row count that other devices can also change.
        navigationModel.dismissAddTodo()

        // Deliberately no `donate()` here. Apple: "Restrict your donations to direct
        // interactions with your app's interface, and not to interactions started by Siri
        // or the Shortcuts app" — and `perform()` cannot tell the caller apart.
        //
        // The dialog and snippet only surface for Siri / Shortcuts / Spotlight callers;
        // `Button(intent:)` shows neither.
        return .result(
            value: entity,
            dialog: IntentDialog("Added \"\(entity.title)\"."),
            snippetIntent: TodoSnippetIntent(todoId: entity.id)
        )
    }
}
