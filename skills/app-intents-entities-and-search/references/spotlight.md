# Spotlight

`IndexedEntity` gets an entity into Spotlight. Two complementary paths, and they must not overlap.

## Keyword indexing — hand-written `attributeSet`

```swift
#if os(iOS) || os(macOS) || os(visionOS)
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

## Semantic indexing — `@Property(indexingKey:)`

Maps a value onto a `PartialKeyPath<CSSearchableItemAttributeSet>` declaratively, feeding meaning-based search and Q&A [Apple: wwdc2026-240].

`indexingKey:` is available on iOS 18.4+, macOS 15.4+ and visionOS 2.4+; watchOS and tvOS are unavailable [Apple SDK: Xcode 27 beta 6, `EntityProperty.init(title:indexingKey:)`]. In a shared package targeting these versions, branch the declaration:

```swift
#if os(iOS) || os(macOS) || os(visionOS)
@Property(title: "Title", indexingKey: \.title) public var title: String
@Property(title: "Notes", indexingKey: \.contentDescription) public var notes: String?
#else
@Property(title: "Title") public var title: String
@Property(title: "Notes") public var notes: String?
#endif
```

The fallback keeps the property visible to Shortcuts and Siri; only the semantic Spotlight mapping is missing, which is correct — those platforms have no `CoreSpotlight` semantic index to map into.

## ⚠️ Never write the same key from both

`indexingKey` adds the semantic path **alongside** the attribute set, and which side wins on a shared key is **not documented**. So a hand-written `a.contentDescription = isCompleted ? "Completed" : "Incomplete"` can quietly replace the notes text you meant to put into semantic search — the index is populated, the search is worse, and nothing reports it.

Rule: keep `attributeSet` to the keys **no** `indexingKey:` claims (`dueDate`, `keywords`, `displayName`), and express status as keywords. `audit`: `spotlight-attribute-collision`

Two more details:

- **The key path is not type-checked against your property's type** — the same `indexingKey:` overloads accept `String?` and `AttributedString?` alike [measured]. So choose by **meaning**: `contentDescription` (documents: "a description of the item") over `textContent` (messaging: full message body) for an item's notes.
- **Verify declaration availability separately from search behaviour.** The beta 6 SDK exposes `IndexedEntity`, `indexingKey:` and `IndexedEntityQuery` on visionOS. This permits indexing; it does not prove that every Spotlight or Siri presentation behaves like iOS.

## Use a named index

Apple: "use a named `CSSearchableIndex` type and not the default index. Use the default index only for prototyping and testing." A named index is also what unlocks the batching below.

## When to index

Index at launch on a low priority (`Task(priority: .utility)`) and incrementally from the service whenever **indexed content changes**: insert, delete, or a change to a mapped property or `attributeSet` value. In the example above, notes, due dates, completion and favourite keywords matter as well as the title. Unrelated changes need no reindex.

`IndexedEntityQuery` lets the system drive reindexing instead of you scheduling it.

To force a reindex while testing: `mdutil -cr <bundle id>` on macOS, Settings → Developer → CoreSpotlight Testing on iOS [Apple: CosmoTunes sample].

## Skip the launch-time full reindex with a client state

A named index supports `beginBatch()` / `endBatch(withClientState:)` / `fetchLastClientState()`. Commit a digest of what you indexed, and a launch whose digest matches can skip the whole pass. Three details make or break it [Apple: CosmoTunes sample]:

- Client state is capped at **250 bytes**. Store a compact change token or deterministic digest (e.g. SHA-256 → 32 bytes) covering indexed content and the indexing schema version. An id-only digest detects membership changes but misses edits to existing entities. **Sort before hashing** unordered collections.
- Open `beginBatch()` **before** the index/delete calls. Calling `endBatch(withClientState:)` on an empty no-op batch can leave the state unpersisted, which silently means a full reindex on every launch.
- Commit only when **every** per-entity call succeeded, so an interrupted launch leaves the previous state in place and the next launch retries.

## Linking an existing `CSSearchableItem` to an entity

If you already index items through Core Spotlight directly, `relatedAppEntityIdentifier` associates that item with your `AppEntity` so a Spotlight hit can run your intents. Cheaper than migrating the whole index to `IndexedEntity`.

## Verifying

Indexing is asynchronous and failing to index is invisible. `spotlightQuery(_:)` in AppIntentsTesting is the automatable check — poll it with a timeout rather than asserting straight after a `run()` (`app-intents-testing`).
