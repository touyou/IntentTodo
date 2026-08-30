# App Schema domains

A schema is how you stop relying on your own wording. Without one, Siri reaches your action because a phrase matched. With one, the system knows the action *is* "create a reminder" and can route the sentences you never thought of.

Three macros apply them: `@AppIntent(schema:)`, `@AppEntity(schema:)`, `@AppEnum(schema:)`. [Apple: app-schema-domains]

> **Naming.** The current framework namespace is `AppSchema` (`AppSchema.RemindersIntent`, `AppSchemaIntent`); `AssistantSchemas` is the earlier name for the same idea and still appears in older sessions and code. The macro spelling — `.reminders.createReminder` — is the same either way, so prefer the macro and don't hand-write the protocol name. [Apple]

## The three tiers, and why the tier matters

Not every domain buys Siri understanding. Check the tier before promising anything.

| Tier | What adoption buys | Domains |
|---|---|---|
| **Apple Intelligence + Siri** | Siri understands the concept; phrases are the system's, not yours | mail, messages, clock, calendar, reminders, notes, photos, maps, camera, audio, phone, files, system (open / search / searchInApp) |
| **Shortcuts only** | actions appear in the Shortcuts app with a standard shape — **not** discoverable by Apple Intelligence and Siri | books, browser, journaling, presentation, reader, spreadsheet, whiteboard, word processor |
| **Single-purpose** | integrates one specific system surface outside Siri | visual intelligence (camera results), assistant (Japan side-button conversational apps) |

[Apple: app-schema-domains — the Shortcuts-only tier is stated explicitly: "Schemas in these domains work with the Shortcuts app but don't make your conforming types discoverable by Apple Intelligence and Siri"]

That table is what the SDK docs listed on 2026-08-21, and domains are added every cycle. **Re-derive it with `DocumentationSearch` on `app-schema-domains` before telling anyone a domain does not exist.**

## All-or-nothing domains

**mail, clock, messages** require every schema in the group once you adopt one. Xcode validates this at build time. [Apple]

Consequence for planning: these three are not incremental. Do not adopt `.messages.sendMessage` "to try it" — budget the whole group or none of it. Every other domain can be adopted one schema at a time.

## Procedure

1. **Name your app's category in the system's words.** Not "a todo app with projects" — "reminders, plus a bit of notes". An app can adopt several domains.
2. **Read the domain page's example phrases.** `DocumentationSearch` for `app-schema-domain-<name>`. The phrase table is the real specification: if the phrases are not things your users would say about your app, the domain is wrong regardless of how well the properties line up.
3. **Adopt only genuine matches.** [Apple, emphatic: "Only apply schemas for actions and content that genuinely match the domain's intended purpose."] A forced fit makes Siri confidently wrong, which is worse than not being there.
4. **Start with the smallest entity in the domain**, not the headline one. A list / folder / album schema is a few properties; the central object usually drags in nested sub-entities.
5. **Let the macro generate.** In Xcode, typing `<domain>_` offers a template with the required members. The macro also infers `@Property` for members that are part of the schema, so don't add it yourself. [Apple]
6. **Verify it landed** with the metadata inspector (`app-intents-testing`) — look for the `assistantDefinedSchemas` entry. A failed conformance still leaves the macro-generated display name in place, so the source looks fine.

## What the macro does and does not give you

| | |
|---|---|
| generates | the schema conformance, required properties' `@Property`, `typeDisplayRepresentation` (delete your hand-written one) |
| does **not** generate | `Hashable` / `Equatable`, your query, your `perform()`, an initialiser |
| cannot be split with `#if` | a macro-annotated declaration cannot have `#if` between the attribute and the body — you write the whole type twice [measured] |

"The generated init clashes with mine" is a common worry and not a real one: the macro adds conformances, not initialisers.

## ⚠️ watchOS / tvOS have no App Schema, and the workaround has a trap

**All 23 domains are `@available(watchOS, unavailable)` / `@available(tvOS, unavailable)`.** Not a `.reminders` quirk — every domain, no exceptions, confirmed by scanning the SDK swiftinterfaces for iPhoneOS / MacOSX / WatchOS / AppleTVOS / XROS [measured, Xcode 27 beta 6]. `.assistant` is iOS-only and `.visualIntelligence` also excludes visionOS.

The reason is the feature's scope, not an oversight:

> "The new Siri AI is available on iPhone, iPad, Mac, and visionOS." [Apple: WWDC 2026 Apple Intelligence Group Lab 35:34]

App Schema is how you hand vocabulary to that Siri, so the availability line traces the Siri line exactly. Changing domain cannot help, and neither can rolling your own.

> The `@AppEntity(schema:)` **macro itself** is available on watchOS. There is simply no domain you can pass it, so that availability is vacuous.

### Do not hand-write `__appSchemaEntity`

It compiles, and it is wrong on three counts:

- **It is not a protocol requirement.** `AssistantEntity` / `AssistantSchemaEntity` are effectively empty protocols; `__appSchemaEntity` is a private arrangement between the macro and the metadata extractor (`@attached(extension, …, names: named(__appSchemaEntity))`). Apple's own guidance says never to emit non-public or underscore-prefixed symbols. If the name changes, the schema disappears **with the build still green**.
- **There is no public back door either** — `AppSchema.Entity(_:)` is `@usableFromInline internal`.
- **It is untrue as content.** It writes "this type is `reminders.ReminderEntity`" into metadata for a platform where the feature does not exist.

The compile error that tempts you into it (`Property 'list' type does not match required AppSchemaEntity property type 'ListEntity'`) is not "you are doing something the schema dislikes" — it is validation firing because you declared a conformance that should not exist on that platform. The fix is to not declare it there.

### The fix is a differently *named* type

A same-named `#if os(watchOS)` twin **silently deletes the schema and most properties from the shipping iOS metadata**. Mechanism [measured 2026-08-29/30, Xcode 27 beta 6]:

1. If the project embeds a watchOS app, the **iOS app's `appintentsmetadataprocessor` receives the watchOS slices as input**. Xcode generates that file list (`<App>.DependencyMetadataFileList`); it is not yours to configure.
2. Entries are matched by **type name without the module** — not by mangled name. So a same-named type in a *different* module collides too.
3. On collision the later entry **replaces the earlier one wholesale**, and the winner is decided by **input order**, not by which one has a schema. Xcode's list is path-ordered, so `Debug-iphonesimulator` < `Debug-watchsimulator` and the watch slice always comes last and always wins.

| Run | Input | `TodoAppEntity` |
|---|---|---|
| control | watch uses a distinct type name | `reminders.ReminderEntity`, 20 properties |
| collision | watch declares the same type name | **`[]`, 10 properties** |
| collision, order reversed | same input, watch first | `reminders.ReminderEntity` |

Exit code 0, zero warnings, in every run.

So:

```swift
// non-watchOS
@AppEntity(schema: .reminders.reminder)
public struct TodoAppEntity: Hashable { … }

// watchOS — different NAME, not just different body
public struct WatchTodoAppEntity: AppEntity, Hashable { … }
public typealias TodoAppEntity = WatchTodoAppEntity     // call sites stay identical
```

Rules for the fallback side:

- **Spell out `@Property(title:)` and `typeDisplayRepresentation`.** The schema variant gets them from the macro and protocol defaults; a plain `AppEntity` gets neither and would ship with zero properties.
- **Do not carry the schema's required properties.** `note` / `creationDate` / `isFlagged` / `list` / `dueDate` as `DateComponents` / `completionDate` / `tags` / `urls` / `recurrence` / `locationTrigger` exist for the schema. A platform with no schema does not need them, and they cost real duplication.
- **A type only the schema needs gets excluded entirely** — `#if !os(watchOS)` around the whole file. A referenced-by-nothing fallback just puts a dead entity in the watch metadata.
- **Share everything that is not a property declaration.** Display, queries, equality and deferred loaders go in one `+Shared.swift` reached through the `typealias`; only the stored properties and initialisers are duplicated.
- **`Transferable` and `URLRepresentableEntity` must be declared on the concrete type.** These are read by const extraction, which does not follow a `typealias` — `extension TodoAppEntity: Transferable` fails in the watch slice with `The property 'transferRepresentation' must be static, have a compile-time constant value, and cannot be computed or dynamic`.
- **Intents that only make sense with a schema** (an in-app search intent) are excluded wholesale with `#if !os(watchOS)`. Nothing is lost: watchOS does not route those experiences.

Reported as **FB24570185**. Apple's four Apple Intelligence samples all ship without a watch target, so the combination has never been exercised officially, and the documentation does not mention multi-target metadata merging at all.

**How to check you got it right:** run the metadata inspector and confirm that **exactly one type claims each schema**. A summary count of "all clear" does not catch two types claiming `reminders.ListEntity`.

> Method note: the first description of this was "the schema-less side wins", which was an inference one step past the observation. Only a run with the input order reversed showed that it is last-wins. Change one variable.

## The system domain is the cheap one

`.system.open`, `.system.search` / `.system.searchInApp` apply to almost any app with a search field and openable content, and they need no domain match at all.

`.system.searchInApp` is the current name of the search schema introduced in iOS 17 as `.system.search` — a rename, not a deprecation of the capability. [Apple: wwdc2026-343 14:50] It lets people search in your app through Siri "no matter which other domains you adopt, and even if you don't index your entities" — which makes it the highest-leverage single schema for an app that fits no domain.

```swift
@AppIntent(schema: .system.searchInApp)
struct SearchInAppIntent: ShowInAppSearchResultsIntent {
    static var searchScopes: [StringSearchScope] = [.general]
    var criteria: StringSearchCriteria

    func perform() async throws -> some IntentResult {
        // navigate to your own search UI with criteria.term
    }
}
```

## Deployment target

The `.reminders` domain is iOS 27+, which pulls the whole package up with it. Check the domain's availability before promising a schema on a lower target.

## If no domain fits

That is a normal outcome, not a gap to work around. **The central entity's schema is not the price of entry either** — a list-level conformance plus the following already delivers understanding, search and navigation [measured — that was the shipping configuration here while the core entity was unconformed]:

1. Well-named discoverable intents with real `IntentDescription` search keywords.
2. `@Property` coverage so Shortcuts can filter and Siri can read values.
3. `IndexedEntity` + `indexingKey:` for meaning-based Spotlight search ([spotlight](spotlight.md)).
4. `OpenIntent` / `DeleteIntent` so the standard verbs work.
5. `.system.searchInApp`.

Do not invent a "schema-like" naming convention, and do not adopt an adjacent domain to get the plumbing. Neither buys understanding; both cost you the ability to adopt the right domain later.
