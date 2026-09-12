//
//  AddTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Domain
import Foundation

/// An intent that creates a new todo item.
///
/// This intent can be triggered via:
/// - Siri: "Add a todo called 'Buy groceries' in IntentTodo"
/// - Shortcuts: Add Todo action
/// - UI: `Button(intent: AddTodoIntent(title: "..."))`
#if !os(watchOS)
@AppIntent(schema: .reminders.createReminder)
#endif
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
            \.$note
            \.$dueDate
            \.$isFlagged
            \.$estimatedDuration
            \.$assignee
            \.$location
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

    // MARK: - Parameters

    @Parameter(title: "Title", description: "The title of the new todo")
    public var title: String

    /// The todo's longer text. Spelled `note` and typed `AttributedString?` because that
    /// is what `.reminders.createReminder` asks for; the model stores a plain `String`.
    @Parameter(title: "Description", description: "Optional description for the todo")
    public var note: AttributedString?

    /// The due date, as `DateComponents` rather than `Date` — the schema's type, which can
    /// express a day without a time of day.
    @Parameter(title: "Due Date", description: "Optional due date for the todo")
    public var dueDate: DateComponents?

    /// The schema's name for what the app calls a favorite. Optional, as the schema
    /// declares it.
    @Parameter(title: "Mark as Favorite", description: "Whether to mark as favorite")
    public var isFlagged: Bool?

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

    /// Free-form tags. A non-optional `Set` is the schema's shape; ordering is therefore
    /// not the caller's to choose, so the write path sorts before storing.
    ///
    /// **`default: []` is what keeps this from being asked for.** A non-optional parameter
    /// with no default makes the system request a value from every caller that omits it,
    /// which for a collection the schema requires means "add a todo" alone stops working.
    @Parameter(title: "Tags", description: "Tags to attach to the todo", default: [])
    public var tags: Set<String>

    /// Links to attach to the new todo. Defaulted for the same reason as `tags`.
    @Parameter(title: "URLs", description: "Links to attach to the todo", default: [])
    public var urls: [URL]

    /// How often the todo repeats, as a whole rule.
    ///
    /// The schema hands in a `Calendar.RecurrenceRule`, which cannot be a SwiftData
    /// attribute, so `TodoRecurrence.decompose` splits it into the stored primitives.
    @Parameter(title: "Recurrence", description: "How often the todo repeats")
    public var recurrence: Calendar.RecurrenceRule?

    /// Place plus arrive/depart event. The schema models the two together, so a trigger
    /// arrives from Siri as one entity.
    ///
    /// Closed to watchOS along with the entity itself: there is no schema there to require
    /// it, and the watch has no surface that sets a place.
    #if !os(watchOS)
    @Parameter(title: "Location Trigger", description: "Surface the todo on arrival or departure")
    public var locationTrigger: TodoLocationTriggerAppEntity?
    #endif

    /// The arrive/depart half on its own, for callers that set a place through `location`.
    ///
    /// Kept alongside the schema's `locationTrigger` because that entity requires **both**
    /// halves, while the app supports a place with no trigger and a trigger set before the
    /// place. An app parameter outside the schema has to be optional, which this is.
    /// `locationTrigger` wins when both arrive.
    @Parameter(title: "Location Trigger Event", description: "Surface the todo on arrival or departure")
    public var locationTriggerEvent: TodoLocationTriggerEvent?

    // MARK: - Filing

    /// The list to file the new todo under. `nil` leaves it uncategorized.
    @Parameter(title: "List", description: "The list to add the todo to")
    public var list: CategoryAppEntity?

    /// The section within `list` to file it under. A section carries its own list, so
    /// naming one both files and categorizes the todo.
    @Parameter(title: "Section", description: "The section to add the todo to")
    public var section: TodoSectionAppEntity?

    /// Images to attach to the new todo.
    ///
    /// Spelled `images` and non-optional because that is the shape
    /// `.reminders.createReminder` asks for (#138).
    ///
    /// The schema also requires concrete image types here: `public.image` is the supertype
    /// the check is against, so the subtypes have to be listed.
    @Parameter(
        title: "Images",
        description: "Images to attach to the todo",
        default: [],
        supportedTypeIdentifiers: ["public.png", "public.jpeg", "public.heic", "public.tiff"]
    )
    public var images: [IntentFile]

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
        tags: [String] = [],
        urls: [URL] = [],
        recurrenceFrequency: TodoRecurrenceFrequency? = nil,
        recurrenceInterval: Int = TodoRecurrenceFrequency.minimumInterval,
        locationTriggerEvent: TodoLocationTriggerEvent? = nil,
        list: CategoryAppEntity? = nil,
        section: TodoSectionAppEntity? = nil,
        images: [TodoAttachmentValue] = []
    ) {
        self.title = title
        self.note = todoDescription.map { AttributedString($0) }
        self.dueDate = TodoDueDate.components(from: dueDate)
        self.isFlagged = isFavorite
        self.estimatedDuration = estimatedDuration
        self.assignee = assignee
        self.location = location
        self.tags = Set(tags)
        self.urls = urls
        // The form still edits frequency + interval, which is what the model stores; the
        // rule is assembled here so the intent keeps the schema's shape.
        self.recurrence = recurrenceFrequency.flatMap {
            TodoRecurrence.rule(frequency: $0.rawValue, interval: recurrenceInterval)
        }
        #if !os(watchOS)
        self.locationTrigger = nil
        #endif
        self.locationTriggerEvent = locationTriggerEvent
        self.list = list
        self.section = section
        // The form deals in the stored value type; wrapping happens here so the
        // `IntentFile` bridging stays inside this package.
        self.images = images.map(TodoAttachments.intentFile(from:))
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog & ShowsSnippetIntent {
        #if !os(watchOS)
        let trigger = locationTrigger.map { TodoPlace.decompose($0.place) }
        let triggerEvent = locationTrigger?.event ?? locationTriggerEvent
        #else
        let trigger: TodoPlace.Components? = nil
        let triggerEvent = locationTriggerEvent
        #endif
        let recurrenceParts = TodoRecurrence.decompose(recurrence)
        let entity = try todoService.create(
            title: title,
            todoDescription: note.map { String($0.characters) },
            dueDate: TodoDueDate.date(from: dueDate),
            isFavorite: isFlagged ?? false,
            estimatedDuration: estimatedDuration.map { Double($0.components.seconds) },
            assigneeName: assignee.map { PersonNameComponentsFormatter().string(from: $0) },
            // A trigger names its own place, so it wins over the bare `location` string.
            locationName: trigger?.name ?? location.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 },
            locationLatitude: trigger?.latitude,
            locationLongitude: trigger?.longitude,
            // Sorted so the stored order doesn't depend on the set's hashing.
            tags: tags.sorted { $0.localizedStandardCompare($1) == .orderedAscending },
            urls: urls,
            recurrenceFrequency: recurrenceParts.frequency,
            recurrenceInterval: recurrenceParts.interval,
            locationTriggerEvent: triggerEvent,
            listId: list?.id,
            sectionId: section?.id,
            attachments: images.map(TodoAttachments.value(from:))
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
