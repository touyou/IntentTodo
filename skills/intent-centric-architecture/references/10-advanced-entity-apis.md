# 10 — Advanced entity APIs

Everything beyond `id` + `displayRepresentation`: derived properties, Spotlight semantics, transient values, unions, cross-device identity, export, and assistant schemas.

Start from [01](01-actions-and-entities.md); adopt from here only when a concrete need appears.

## Property macros

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

Two traps:

- **Entities cannot use `@Dependency`** ([04](04-process-and-dependencies.md)). A deferred getter reads an ambient `@MainActor` store that every process registers.
- **Property macros generate non-`Hashable` `EntityProperty` backing**, which breaks synthesised `Hashable` / `Equatable`. Implement `==` and `hash(into:)` explicitly (hash on `id`, compare the snapshot).

## Spotlight

`IndexedEntity` gets an entity into Spotlight. Two complementary paths:

**Keyword indexing** — hand-write `attributeSet`:

```swift
#if os(iOS) || os(macOS)
extension TodoAppEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let a = CSSearchableItemAttributeSet()
        a.displayName = title                    // .displayName ≠ .title — no collision
        if let dueDate { a.dueDate = dueDate }
        a.keywords = ["todo", title]
            + (isCompleted ? ["completed"] : ["incomplete", "pending"])
            + (isFavorite ? ["favorite", "starred"] : [])
        return a
    }
}
#endif
```

**Semantic indexing** — `@Property(title:indexingKey:)` maps a value onto a `PartialKeyPath<CSSearchableItemAttributeSet>` declaratively, feeding meaning-based search and Q&A [Apple: wwdc2026-240].

```swift
@Property(title: "Title", indexingKey: \.title) public var title: String
@Property(title: "Notes", indexingKey: \.contentDescription) public var notes: String?
```

- **Never write the same key from both.** `indexingKey` adds the semantic path alongside the attribute set, but which side wins on a shared key is not documented, so a hand-written `a.contentDescription = isCompleted ? "Completed" : "Incomplete"` can quietly replace the notes text you meant to put into semantic search. Keep `attributeSet` to the keys **no** `indexingKey:` claims (`dueDate`, `keywords`, `displayName`), and express status as keywords. `audit`: `spotlight-attribute-collision`
- The key path is not type-checked against your property's type — the same `indexingKey:` overloads accept `String?` and `AttributedString?` alike [measured]. So choose by **meaning**: `contentDescription` (documents: "a description of the item") over `textContent` (messaging: full message body) for an item's notes.
- **`indexingKey:` is only vended on iOS and macOS.** watchOS/visionOS fail with `Extra argument 'indexingKey'` + `Cannot infer key path type`. Guard with `#if os(iOS) || os(macOS)` and fall back to plain `@Property` [measured].

Index at launch on a low priority (`Task(priority: .utility)`) and incrementally on mutation from the Service. `IndexedEntityQuery` lets the system drive reindexing instead.

To force a reindex while testing: `mdutil -cr <bundle id>` on macOS, Settings → Developer → CoreSpotlight Testing on iOS [Apple: CosmoTunes sample].

### Skip the launch-time full reindex with a client state

A named index (which you should be using anyway — the default index is documented as prototyping-only) supports `beginBatch()` / `endBatch(withClientState:)` / `fetchLastClientState()`. Commit a digest of what you indexed, and a launch whose digest matches can skip the whole pass. Three details make or break it [Apple: CosmoTunes sample]:

- Client state is capped at **250 bytes** — hash the id set (e.g. SHA-256 → 32 bytes) rather than storing it. Sort before hashing, or `Set` iteration order makes the digest unstable.
- Open `beginBatch()` **before** the index/delete calls. Calling `endBatch(withClientState:)` on an empty no-op batch can leave the state unpersisted, which silently means a full reindex on every launch.
- Commit only when **every** per-entity call succeeded, so an interrupted launch leaves the previous state in place and the next launch retries.

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

## `SyncableEntity`

Add the conformance; if `id` is already stable across devices (a UUID string replicated by CloudKit), **nothing else changes** [measured]. Siri conversations can then refer to the same entity across devices. If local and stable identity differ, type `id` as `SyncableEntityIdentifier<Local, Stable>`.

Confirm it landed: the metadata inspector prints `com.apple.appintents.entity.Syncable` next to the entity.

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

## `Transferable` + `ValueRepresentation`

Export an entity into other apps and into system value types.

```swift
extension TodoAppEntity: Transferable {
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

## Schemas (`AppSchema`, formerly `AssistantSchemas`)

`@AppEntity(schema:)` / `@AppEnum(schema:)` / `@AppIntent(schema:)` let Siri and Apple Intelligence understand your content semantically instead of by name. **Which domain to adopt, what each tier actually buys, and the all-or-nothing groups are in [13](13-schema-domains.md)** — this section is only the entity-side mechanics.

What worked here:

- **Small schemas are straightforward.** `@AppEntity(schema: .reminders.list)` needs `id` / `name` / `type`, with `@AppEnum(schema: .reminders.listType)` for the type. The macro generates `typeDisplayRepresentation` (delete the hand-written one) and infers `@Property` for members the schema defines [Apple], but it does not generate `Hashable` — implement it.
- **`.system.searchInApp`** works well for "take me to search results" ([11](11-interaction-and-scale.md)). It is the current name of the `.system.search` schema introduced in iOS 17 — a rename, not a removed capability [Apple: wwdc2026-343 14:50].
- **The `.reminders` domain is iOS 27+**, which pushes the package's deployment target.
- **watchOS has no assistant schemas at all** — see [08](08-platform-and-availability.md) for the duplicate-declaration workaround.

What did not work, and why it is worth knowing before you start:

- **A rich core entity conforming to `.reminders.reminder` is still blocked here.** The requirements are knowable (nested `section` and `locationTrigger` sub-entities, `dueDate: DateComponents?`, non-optional `list`, recursive `subtasks`), and a conforming shape does compile. The blocker is elsewhere: the schema requires `locationTrigger`, whose entity requires `place: GeoToolbox.PlaceDescriptor` as a `@Property`, and adopting that emits an SSU training error (`GeoToolbox.PlaceDescriptorEntity must match regular expression …`) on a clean build [measured 2026-08-12]. That is an SDK bug, not a design problem — wait it out.
- The macro adds **conformances, not an initialiser**, so "the generated init clashes with mine" is not the obstacle it is often assumed to be.
- Crucially, **the new Siri integration works without core-entity schema conformance**: a `.reminders.list` conformance, discoverable intents, `OpenIntent` / `DeleteIntent`, `.system.searchInApp` and semantic Spotlight indexing together deliver understanding, search and navigation. The same combination is the fallback for an app that fits no domain at all ([13](13-schema-domains.md)).

Verify adoption with the metadata inspector — a schema that fails to register still leaves the macro-generated display name in place, so the source looks correct.

## `RelevantEntities`: not universally adoptable

`RelevantEntities.shared.updateEntities(_:for:)` needs an `AppEntityContext`, and the available contexts are domain-specific: `.audio(.nowPlaying)`, `.audio(.workout(activityType:))`, plus contexts defined by framework overlays such as HealthKit. **There is no general or reminders/todo context** [measured, via documentation search]. Donating a todo under an audio context would be semantically wrong.

If contextual suggestion matters, look at `RelevantIntent` / `RelevantIntentManager` (widget-configuration based) instead — a different axis. Recheck when Apple adds domain contexts.
