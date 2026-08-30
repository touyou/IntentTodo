# Entity surface

## Keep it minimal

`AppEntity` is **not** the persistence model. Three things and no more:

1. `id` — stable across launches and devices.
2. `displayRepresentation`.
3. The few `@Property` members the system actually consumes.

**Only `@Property` members are visible to the system.** A plain `var` is invisible to Shortcuts filters, Siri and Spotlight — and to `AnyAppEntity` dynamic lookup in tests. Verify with the metadata inspector (`app-intents-testing`), which prints the property list the build actually emitted; an entity showing `0 props` is a display-only shell.

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

`id` itself is normally *not* a `@Property`. That is fine at runtime, but in AppIntentsTesting the type-erased `entity.id` then fails with `castingFailed(elementType: "NSNull")` — use `entity.identifier.instanceIdentifier` there.

**A schema macro supplies `typeDisplayRepresentation` and infers `@Property` for schema members** — a plain `AppEntity` supplies neither, so a hand-written fallback type needs both spelled out explicitly or it ships with zero properties ([schema-domains](schema-domains.md)).

## `displayRepresentation` is display text, spoken text and match input at once

The same three fields feed the Shortcuts picker, Siri disambiguation, Siri's *voice* output and Spotlight results. Five rules, all cheap:

- **Pass runtime values by interpolation: `"\(title)"`, never `LocalizedStringResource(stringLiteral: title)`.** `stringLiteral:` treats the runtime string as a **localization key**, so every render is a lookup for a key no catalogue contains, and the string never gets extracted for translation. Apple's samples use the interpolated form throughout. `audit`: `localized-string-literal`
- **Return `nil`, not `""`, when there is nothing to show.** `subtitle` is optional; an empty `LocalizedStringResource("")` is an empty-key lookup.
- **Siri reads the subtitle aloud.** A positional format is read character by character — `"5:00"` becomes "five colon zero zero". Use `Duration.formatted(.units(width: .wide))` → "5 minutes" and `Date.FormatStyle` → "7:30 AM" instead of `DateComponentsFormatter` or a hand-built `"\(h):\(m)"` [Apple: CosmoTunes sample].
- **`synonyms:` widens what Siri will match** without adding phrases — `synonyms: ["\(title) mix tape", "\(title) playlist"]`.
- **Defer the image with the trailing-closure form.** The system materialises only the components a context needs, so a text-only request never pays for artwork.

```swift
public var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
        title: "\(title)",                                   // interpolated, not stringLiteral:
        subtitle: subtitle,                                  // LocalizedStringResource? — nil when empty
        synonyms: ["todo \(title)", "task \(title)"]
    ) {
        DisplayRepresentation.Image(systemName: icon)         // resolved only if a context needs it
    }
}
```

Counts need inflection: `"^[\(count) todo](inflect: true)"`, not `"\(count) todos"`. Never build the plural in Swift — see `app-intents-localization`.

For many identifiers at once, implement `EntityQuery.displayRepresentations(for:)` and build the representations from a relationship-free lightweight entity — Apple: "Return full representations; the system materializes only the components it needs (for example, dropping a deferred image when only text is required)." It avoids constructing N full entities to draw a picker.

**Entity `DisplayRepresentation` strings are not extracted into any String Catalog.** Localising them means manual keys in each linking target (`app-intents-localization`).

## `AppEnum` before `AppEntity`

For closed sets (filters, sort orders, screen targets), use `AppEnum`: cheaper to reason about, and the system renders a fixed picker. Reach for `AppEntity` only when the set is dynamic, stored, or large.

Two hard rules:

- **Raw values are persisted by string.** A shortcut a user built keeps the old string; renaming or renumbering a case silently breaks their automation. [Apple]
- **Every case needs a `caseDisplayRepresentations` entry** — a missing one is a runtime `fatalError`, not a compile error. [Apple]

```swift
public enum TodoFilterType: String, AppEnum {
    case all, incomplete, completed, favorites

    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Filter" }
    public static var caseDisplayRepresentations: [TodoFilterType: DisplayRepresentation] {
        [.all: "All", .incomplete: "Incomplete", .completed: "Completed", .favorites: "Favorites"]
    }
}
```

**Reuse the case labels in your own UI instead of duplicating them.** `AppEnum` inherits `CaseDisplayRepresentable`, which vends `localizedStringResource` by default:

```swift
Text(option.localizedStringResource)   // renders caseDisplayRepresentations[option]
```

That keeps Siri and the app saying the same words. Keeping a second copy in a UI package's catalog is how they drift apart. `CaseIterable` is also transitively required, so `allCases` works without adding the conformance.

> Adding a case to a navigation-target enum does nothing on its own: the `switch` in `perform()` must write the matching state, or the new case silently falls through to "just open the app" (`app-intents-ui-and-feedback`).

## Queries: pick the narrowest one that works

| Protocol | Gives you | Cost |
|---|---|---|
| `EntityQuery` | `entities(for:)` — id resolution. The minimum. | none |
| `EntityStringQuery` | `entities(matching:)` — free-text lookup from Siri/Shortcuts | you filter; the framework does **not** filter for you [Apple] |
| `EnumerableEntityQuery` | `allEntities()` — the full list in the Shortcuts picker | loads everything; wrong for large stores |
| `EntityPropertyQuery` | "Find X where…" with `properties` / `sortingOptions` / `comparators` | you execute the predicate; the framework only parses it [Apple] |
| `IndexedEntityQuery` | system-driven Spotlight reindex | [spotlight](spotlight.md) |
| `IntentValueQuery` | Visual Intelligence input; may return a `@UnionValue`, *can* use `@Dependency` | `app-intents-system-surfaces` |

`suggestedEntities()` is what fills parameter pickers. Returning an empty default means "no suggestions" — users see an empty picker and assume the app is broken. If it is cheap, implement it.

**`entities(for:)` is batched** — resolve the whole `[ID]` in one fetch, not in a loop.

**Since you own the filtering in `entities(matching:)`, own it correctly.** The input is something a person said or typed, so compare with `localizedStandardContains(_:)` — `lowercased().contains()` is locale-independent and treats kana/katakana, diacritics and Turkish dotless I as different characters. `audit`: `locale-insensitive-entity-match`

`EnumerableEntityQuery` makes Shortcuts synthesise a "Find X" action for free; give it `static var findIntentDescription: IntentDescription?` so that action arrives with a description, a `categoryName`, search keywords and a `resultValueName` instead of appearing bare.

For a large store, `EntityPropertyQuery` is the right answer rather than `EnumerableEntityQuery`: the framework hands you parsed comparators and you turn them into one fetch, instead of loading everything and filtering in memory.

Queries *can* use `@Dependency`; entities cannot (`app-intents-execution-and-processes`).

## Naming

- Entities: noun + `AppEntity` — `TodoAppEntity`, `CategoryAppEntity`.
- Enums: domain noun — `TodoSortOrder`, `AppScreenTarget`.
- Platform-specific fallback types get a **prefix that says why they exist** — `WatchTodoAppEntity` — because the name is load-bearing for the metadata merge ([schema-domains](schema-domains.md)), not just documentation.

Consistent naming makes the Shortcuts gallery and Siri training data legible without extra annotation.
