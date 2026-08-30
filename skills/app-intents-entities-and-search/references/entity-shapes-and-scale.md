# Entity shapes and scale

## `TransientAppEntity`

A computed snapshot that no one needs to query back — a summary, a total, a computed report [Apple: wwdc2026-344].

| | `AppEntity` | `TransientAppEntity` |
|---|---|---|
| `defaultQuery` | required | not required |
| corresponds to | stored data | a computed snapshot |
| referenced by id | ✅ | ❌ |
| `@Property` | ✅ | ✅ |
| `IndexedEntity` | ✅ | ❌ meaningless |
| notification `appEntityIdentifiers` | ✅ | ❌ not allowed [Apple: wwdc2026-343 21:38] |

```swift
public struct TodoListSummaryEntity: TransientAppEntity {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo List Summary"

    @Property(title: "Pending Todos") public var pendingCount: Int
    @Property(title: "Overdue Todos") public var overdueCount: Int

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(pendingCount) pending, \(overdueCount) overdue")
    }

    public init() {}                                       // the system may need this
    public init(pendingCount: Int, overdueCount: Int) { … }
}
```

`typeDisplayRepresentation` can be a plain `static let` here. The value: Shortcuts users can branch on "overdue > 0" without fetching every item.

The alternative — an `AppEntity` with a query that cannot really resolve anything — leaves a broken picker and a `defaultQuery` that lies. Prefer transient.

## `SyncableEntity`

Add the conformance; if `id` is already stable across devices (a UUID string replicated by CloudKit), **nothing else changes** [measured]. Siri conversations can then refer to the same entity across devices. If local and stable identity differ, type `id` as `SyncableEntityIdentifier<Local, Stable>`.

Confirm it landed: the metadata inspector prints `com.apple.appintents.entity.Syncable` next to the entity.

This is the main payoff of keeping `id` stable from the start — and the main reason a restore-after-delete must reuse the original id (`app-intents-centric-design`).

## `@UnionValue`

One value that can be any of several entity types — useful as an intent return type and required when a value query must span types.

```swift
@UnionValue
public enum TodoOrCategory: Sendable {     // ← Sendable must be explicit
    case todo(TodoAppEntity)
    case category(CategoryAppEntity)
}
```

- A `public enum` does not get `Sendable` inferred, but the generated code requires it: without `: Sendable` the build fails **inside generated source** with a confusing message [measured].
- Each case carries exactly one value type.
- Usable in `@Parameter`, `ReturnsValue`, and `ParameterSummary`'s `Switch` / `When`.
- If it is a Visual Intelligence result type, **every** case's entity needs an `OpenIntent` (`app-intents-system-surfaces`).

## `Transferable` + `ValueRepresentation`

Export an entity into other apps and into system value types.

```swift
extension TodoAppEntity: Transferable {          // concrete type, never a typealias
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.title)          // plain text anywhere
        ValueRepresentation(exporting: { todo async throws -> IntentPerson in
            guard let name = todo.assigneeName else { throw ExportError.noAssignee }
            return IntentPerson(identifier: .applicationDefined(todo.id),
                                name: .displayName(name),
                                handle: nil)
        })
    }
}
```

- `IntentPerson(identifier:name:handle:)` requires **all** arguments; omitting any gives `Missing arguments for parameters 'identifier', 'handle'`.
- Export closures are `async throws` — **throw** when there is no value, so the representation is simply absent. Don't export an empty placeholder.
- **Export the richest value you hold.** A `ValueRepresentation` that reassembles a `PlaceDescriptor` from a name only, dropping the coordinates you actually store, silently degrades every hand-off to Maps. If the entity carries the native type, return it directly.
- **Declare it on the concrete type name.** Const extraction does not follow a `typealias`, so a shared extension over a typealias fails in that slice ([schema-domains](schema-domains.md)).
- `ValueRepresentation` to a system value type does **not** hit the SSU parameter bug — only `@Parameter` does (`app-intents-parameters-and-prompts`).

`URLRepresentableEntity` / `URLRepresentableIntent` have the same concrete-type requirement, and are worth adopting only for entities that genuinely have a URL.

## Scale: hundreds of entities

```swift
public struct CompleteTodosIntent: AppIntent, LongRunningIntent, CancellableIntent {
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Todos") public var todos: EntityCollection<TodoAppEntity>
    @Dependency var todoService: TodoService

    public func perform() async throws -> some IntentResult {
        let ids = todos.identifiers            // no full entity resolution
        progress.totalUnitCount = Int64(ids.count)

        try await performBackgroundTask(operation: { [progress] in
            for (i, id) in ids.enumerated() {
                try Task.checkCancellation()
                try await todoService.markCompleted(id)   // hops to MainActor
                progress.completedUnitCount = Int64(i + 1)
            }
        }, onCancel: { reason in /* clean up */ })

        return .result()
    }
}
```

[Apple: wwdc2026-345]

- **`EntityCollection<T>`** skips per-id entity resolution at parameter time — a large saving in memory and latency [Apple: wwdc2026-345 8:09]. Use `.identifiers` when ids suffice; `resolvedEntities()` only when you need the whole entity.
- **`LongRunningIntent`** (`: ProgressReportingIntent`) extends the background window via `performBackgroundTask` — but **you must keep updating `progress` or the system cuts the extension short** [Apple: wwdc2026-345 13:55].
- **`CancellableIntent`** supplies `onCancel: (IntentCancellationReason) -> Void`; check `Task.checkCancellation()` in the loop.
- Concurrency: the operation closure is nonisolated `async`, so `try await service.method()` hops to `@MainActor` safely — `perform()` itself does not need `@MainActor`.
- Pinning `allowedExecutionTargets` to `[.main]` is right for bulk persistence work.

On the query side, the matching choice for a large store is `EntityPropertyQuery` rather than `EnumerableEntityQuery` — the framework parses the comparators and you turn them into one fetch ([entity-surface](entity-surface.md)).
