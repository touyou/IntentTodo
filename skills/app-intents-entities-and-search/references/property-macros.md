# Property macros

| Macro | Getter | Sent to the system |
|---|---|---|
| `@Property` | stored | ✅ Spotlight, Shortcuts, Siri |
| `@ComputedProperty` | synchronous, derived from the snapshot | ✅ |
| `@DeferredProperty` | `get async throws`, fetched on demand | ❌ **not** indexed, not sent automatically |

```swift
@ComputedProperty(title: "Is overdue")
public var isOverdue: Bool { !isCompleted && (dueDate.map { $0 < .now } ?? false) }

@DeferredProperty(title: "Subtask progress")
public var subtaskProgress: Double {
    get async throws { try await TodoEntityStore.progress(for: id) }
}
```

Choosing between them:

- `@Property` when the value is already in the snapshot you built the entity from.
- `@ComputedProperty` when it is a pure function of that snapshot. It still reaches Shortcuts filters, which makes "is overdue" filterable without storing a redundant column.
- `@DeferredProperty` when getting the value needs a fetch. It is also the right home for a value that is **unsafe to read from the original model object** — a `@DeferredProperty` re-fetches by `id`, so it survives the model row being deleted, where a stored property populated in `init(from:)` would have trapped while reading it.

## Two traps

**Entities cannot use `@Dependency`** (`app-intents-execution-and-processes`). A deferred getter reads an ambient `@MainActor` store that every process registers:

```swift
@MainActor
public enum TodoEntityStore {
    private static var container: ModelContainer?
    public static func register(container: ModelContainer) { Self.container = container }

    static func progress(for id: String) throws -> Double { /* fetch via container */ }
}
```

Registering the `@Dependency` service but *not* this store gives you a working intent with an empty snippet — register both, in every process.

**Property macros generate non-`Hashable` `EntityProperty` backing**, which breaks synthesised `Hashable` / `Equatable`. Implement them explicitly:

```swift
public static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id && lhs.title == rhs.title && lhs.isCompleted == rhs.isCompleted
}
public func hash(into hasher: inout Hasher) { hasher.combine(id) }
```

Hash on `id` alone; compare on the snapshot fields you care about. A schema macro does not generate these either.

## Ordering and determinism

A `@DeferredProperty` returning a `Set` has no order, so the display order is yours to choose. Pick a deterministic one (`localizedStandardCompare` for user-visible strings) and use the same order when you write the value back, or the list appears to shuffle between reads.

## Where the value lands in Spotlight

`@Property(title:indexingKey:)` maps a property onto a `CSSearchableItemAttributeSet` key path, which is what feeds meaning-based search. That is the same key space a hand-written `attributeSet` writes into, and the two must not overlap — [spotlight](spotlight.md).
