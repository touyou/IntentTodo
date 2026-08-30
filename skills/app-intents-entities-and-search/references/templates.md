# Templates — entities and queries

## Entity + query

```swift
public struct TodoAppEntity: AppEntity, Identifiable, Hashable {
    public var id: String

    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    @Property(title: "Due date") public var dueDate: Date?

    @ComputedProperty(title: "Is overdue")
    public var isOverdue: Bool { !isCompleted && (dueDate.map { $0 < .now } ?? false) }

    // Re-fetches by id, so it survives the model row being deleted.
    @DeferredProperty(title: "Tags")
    public var tags: Set<String> { get async throws { try await TodoEntityStore.tags(for: id) } }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    public static var defaultQuery: TodoEntityQuery { TodoEntityQuery() }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",                                  // interpolated, not stringLiteral:
            subtitle: subtitleResource,                         // nil, never ""
            synonyms: ["task \(title)"]
        ) {
            DisplayRepresentation.Image(
                systemName: isCompleted ? "checkmark.circle.fill" : "circle")   // deferred
        }
    }

    // Property macros break synthesised Hashable/Equatable.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.isCompleted == rhs.isCompleted
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct TodoEntityQuery: EntityQuery {
    @Dependency var todoService: TodoService      // queries CAN use @Dependency; entities cannot
    public init() {}

    @MainActor public func entities(for ids: [String]) async throws -> [TodoAppEntity] {
        try todoService.entities(matching: ids)   // batched — one fetch, not a loop
    }

    // Without this, every parameter picker is blank.
    @MainActor public func suggestedEntities() async throws -> [TodoAppEntity] {
        try todoService.incompleteEntities(limit: 8)
    }
}

extension TodoEntityQuery: EntityStringQuery {
    @MainActor public func entities(matching string: String) async throws -> [TodoAppEntity] {
        // The framework does NOT filter for you, and the input is human-typed:
        // localizedStandardContains, never lowercased().contains.
        try todoService.entities(titleContains: string)
    }
}
```

## Spotlight conformance

```swift
#if os(iOS) || os(macOS)
extension TodoAppEntity: IndexedEntity {
    /// Only keys that NO @Property(indexingKey:) claims. Precedence is undocumented.
    public var attributeSet: CSSearchableItemAttributeSet {
        let a = CSSearchableItemAttributeSet()
        a.displayName = title
        if let dueDate { a.dueDate = dueDate }
        a.keywords = ["todo", title] + (isCompleted ? ["completed"] : ["incomplete", "pending"])
        return a
    }
}
#endif
```

## Ambient store (entities cannot use `@Dependency`)

```swift
@MainActor
public enum TodoEntityStore {
    private static var container: ModelContainer?

    /// Call from EVERY process entry point: App.init(), WidgetBundle.init(), …
    public static func register(container: ModelContainer) { Self.container = container }

    static func tags(for id: String) throws -> Set<String> {
        guard let container else { return [] }
        // fetch by id — never hold on to the model object
        …
    }
}
```

## Transient summary entity

```swift
public struct TodoListSummaryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List Summary"

    @Property(title: "Pending Todos") public var pendingCount: Int
    @Property(title: "Overdue Todos") public var overdueCount: Int

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "^[\(pendingCount) pending todo](inflect: true)")
    }

    public init() {}
    public init(pendingCount: Int, overdueCount: Int) {
        self.pendingCount = pendingCount
        self.overdueCount = overdueCount
    }
}
```

## Union value + Visual Intelligence query

```swift
@UnionValue
public enum TodoOrCategory: Sendable {     // Sendable must be explicit for a public enum
    case todo(TodoAppEntity)
    case category(CategoryAppEntity)
}

#if canImport(VisualIntelligence) && !os(visionOS)
import VisualIntelligence

public struct TodoVisualIntelligenceQuery: IntentValueQuery {
    @Dependency var todoService: TodoService        // value queries CAN use @Dependency
    public init() {}

    public func values(for input: SemanticContentDescriptor) async throws -> [TodoOrCategory] {
        let labels = input.labels                   // generic English labels only
        let todos = try await MainActor.run { try todoService.listTodos(filter: .all) }
        return todos.filter { t in labels.contains { t.title.localizedCaseInsensitiveContains($0) } }
                    .map(TodoOrCategory.todo)
    }
}
#endif
```

Both `TodoAppEntity` and `CategoryAppEntity` need an `OpenIntent`, or the app does not appear in results — and only a macOS build tells you.

## Bulk intent

```swift
public struct CompleteTodosIntent: AppIntent, LongRunningIntent, CancellableIntent {
    public static var title: LocalizedStringResource { "Complete Todos" }
    public static var supportedModes: IntentModes { .background }
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    public static var parameterSummary: some ParameterSummary { Summary("Complete \(\.$todos)") }

    @Parameter(title: "Todos") public var todos: EntityCollection<TodoAppEntity>
    @Dependency var todoService: TodoService
    public init() {}

    public func perform() async throws -> some IntentResult {
        let ids = todos.identifiers            // no full entity resolution
        progress.totalUnitCount = Int64(ids.count)

        try await performBackgroundTask(operation: { [progress] in
            for (i, id) in ids.enumerated() {
                try Task.checkCancellation()
                try await todoService.markCompleted(id)   // hops to MainActor
                progress.completedUnitCount = Int64(i + 1)   // keep updating, or you get cut short
            }
        }, onCancel: { _ in /* clean up */ })

        return .result()
    }
}
```

## watchOS fallback for a schema type

```swift
// TodoAppEntity.swift
#if os(watchOS)
/// No App Schema exists on watchOS. A DIFFERENT TYPE NAME is required: a same-named twin
/// wins the metadata merge in the iOS app and deletes the schema there.
public struct WatchTodoAppEntity: AppEntity, Identifiable, Hashable {
    public var id: String
    // Spell these out: the macro is not here to supply them.
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    // No schema-required properties: note / list / tags / recurrence / locationTrigger …
}
public typealias TodoAppEntity = WatchTodoAppEntity
#else
@AppEntity(schema: .reminders.reminder)
public struct TodoAppEntity: Identifiable, Hashable {
    public var id: String
    public var title: String            // @Property inferred by the macro
    …
}
#endif

// TodoAppEntity+Shared.swift — display, query, equality, loaders: one copy via the typealias.

// Transferable must name the CONCRETE type (const extraction ignores typealias).
#if os(watchOS)
extension WatchTodoAppEntity: Transferable { … }
#else
extension TodoAppEntity: Transferable { … }
#endif
```
