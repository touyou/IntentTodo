---
name: app-intents-entities-and-search
description: Model your app's content so the system can find it, refer to it and understand what it is. Use when turning your data into something Siri and Shortcuts can act on, when the Shortcuts app cannot filter or read your values, when a parameter picker or "Find X where…" action is empty, when you want your content to appear in Spotlight or in meaning-based search, when Siri reads a value aloud badly or fails to match what someone typed, when handling hundreds or thousands of items in one action, when sharing content with other apps or across devices, or when you want Siri to understand your app by category — reminders, notes, mail, media and the other App Schema domains — rather than by the words you happened to choose.
license: MIT
---

# Entities and search

The noun side of intent-centric design: what the system can see of your data, and how it finds it.

Assumes the rules in `app-intents-centric-design`. The *verb* side is there too.

## Entity surface

`AppEntity` is **not** the persistence model. Keep it to:

1. `id` — stable across launches and devices. (Stability is what makes `SyncableEntity` free later.)
2. `displayRepresentation` — title, optional subtitle, optional image.
3. The few `@Property` members the system actually consumes.

**Only `@Property` members are visible to the system.** A plain `var` is invisible to Shortcuts filters, Siri and Spotlight — and to `AnyAppEntity` dynamic lookup in tests. An entity showing `0 props` in the metadata inspector is a display-only shell.

```swift
public struct TodoAppEntity: AppEntity, Identifiable {
    public var id: String

    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    @Property(title: "Due date") public var dueDate: Date?

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    public static let defaultQuery = TodoEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: isCompleted ? "Done" : "Open")
    }
}
```

`id` itself is normally *not* a `@Property`. Fine at runtime, but in AppIntentsTesting the type-erased `entity.id` then fails with `castingFailed(elementType: "NSNull")` — use `entity.identifier.instanceIdentifier` there (`app-intents-testing`).

**Check for a system shape before writing your own**: `UniqueAppEntity` for a value with exactly one instance, `FileEntity` when the entity *is* a document, `TransientAppEntity` for a computed snapshot nobody queries back. Catalogue in `app-intents-system-surfaces`.

**`AppEnum` before `AppEntity`** for closed sets — cheaper, and the system renders a fixed picker. Raw values are persisted by string in people's shortcuts, so cases can be added but never renamed or reordered (`app-intents-parameters-and-prompts`).

Details, `displayRepresentation` rules and query choice: [entity-surface](references/entity-surface.md).

## Queries: pick the narrowest one that works

| Protocol | Gives you | Cost |
|---|---|---|
| `EntityQuery` | `entities(for:)` — id resolution. The minimum. | none |
| `EntityStringQuery` | `entities(matching:)` — free-text lookup from Siri/Shortcuts | you filter; the framework does **not** filter for you [Apple] |
| `EnumerableEntityQuery` | `allEntities()` — the full list in the Shortcuts picker | loads everything; wrong for large stores |
| `EntityPropertyQuery` | "Find X where…" with `properties` / `sortingOptions` / `comparators` | you execute the predicate; the framework only parses it [Apple] |
| `IndexedEntityQuery` | system-driven Spotlight reindex | [spotlight](references/spotlight.md) |
| `IntentValueQuery` | Visual Intelligence input; may return a `@UnionValue`, *can* use `@Dependency` | `app-intents-system-surfaces` |

Three things that go wrong here:

- **`suggestedEntities()` is what fills parameter pickers.** The empty default means "no suggestions" — users see a blank picker and assume the app is broken.
- **`entities(for:)` is batched** — resolve the whole `[ID]` in one fetch, not in a loop.
- **`entities(matching:)` must use `localizedStandardContains(_:)`.** `lowercased().contains()` is locale-independent and treats kana/katakana, diacritics and Turkish dotless I as different characters. `audit`: `locale-insensitive-entity-match`

Queries *can* use `@Dependency`; entities cannot (`app-intents-execution-and-processes`).

## Spotlight in one paragraph

`IndexedEntity` + `@Property(title:indexingKey:)` gets you meaning-based search; a hand-written `attributeSet` gets you keywords. **Never write the same `CSSearchableItemAttributeSet` key from both** — precedence is undocumented, so a status string can quietly replace the note text you meant to make searchable. Keep `attributeSet` to keys no `indexingKey:` claims. `indexingKey:` is iOS/macOS only. Details: [spotlight](references/spotlight.md).

## App Schema in one paragraph

A schema is how you stop relying on your own wording: Siri knows the action *is* "create a reminder" and can route sentences you never thought of. Three tiers (full Siri understanding / Shortcuts-only / single-purpose), three all-or-nothing domain groups, and one hard platform fact: **App Schema does not exist on watchOS or tvOS in any domain**, and the watch workaround has a trap that silently deletes properties from your iOS metadata. Details: [schema-domains](references/schema-domains.md).

## Fast decisions

| Goal | Use | Not |
|---|---|---|
| Let Shortcuts filter and read a value | `@Property` | a plain `var` |
| A value derived from the snapshot | `@ComputedProperty` | recomputing in every call site |
| A value that needs a fetch | `@DeferredProperty` (not indexed, not sent automatically) | a stored property you have to populate eagerly |
| Reach the store from an entity | an ambient `@MainActor` store registered per process | `@Dependency` — entities cannot use it |
| A closed set | `AppEnum` | an entity with a fake query |
| A computed summary | `TransientAppEntity` | an `AppEntity` with a query that cannot really resolve |
| Hundreds of items in one action | `EntityCollection<T>` + `LongRunningIntent` | `[MyEntity]` and hope |
| Export to other apps | `Transferable` + `ProxyRepresentation` / `ValueRepresentation` | a custom pasteboard type |
| The same object across devices | `SyncableEntity` | nothing — it is nearly free if `id` is stable |
| Siri to understand the *category* of your app | a genuinely matching schema domain | an adjacent domain "for the plumbing" |

## References

| File | Covers |
|---|---|
| [entity-surface](references/entity-surface.md) | minimal surface, `displayRepresentation` as display + speech + match input, `AppEnum`, queries in full, naming |
| [property-macros](references/property-macros.md) | `@Property` / `@ComputedProperty` / `@DeferredProperty`, the `Hashable` breakage, the ambient store |
| [spotlight](references/spotlight.md) | `IndexedEntity`, `indexingKey:` vs `attributeSet` and the collision, incremental indexing, client-state batching, forcing a reindex |
| [schema-domains](references/schema-domains.md) | the three tiers, all-or-nothing groups, adoption procedure, the watchOS absence and the type-name collision that deletes metadata |
| [entity-shapes-and-scale](references/entity-shapes-and-scale.md) | `TransientAppEntity`, `SyncableEntity`, `@UnionValue`, `Transferable`, `EntityCollection` / `LongRunningIntent` / `CancellableIntent` |
| [templates](references/templates.md) | entity + query, transient entity, union value, bulk intent |
