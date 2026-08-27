# 13 — Schema domains

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
6. **Verify it landed** with `scripts/inspect_appintents_metadata.py` — look for the `assistantDefinedSchemas` entry. A failed conformance still leaves the macro-generated display name in place, so the source looks fine ([09](09-verification.md)).

## What the macro does and does not give you

| | |
|---|---|
| generates | the schema conformance, required properties' `@Property`, `typeDisplayRepresentation` (delete your hand-written one) |
| does **not** generate | `Hashable` / `Equatable`, your query, your `perform()` |
| cannot be split with `#if` | a macro-annotated declaration cannot have `#if` between the attribute and the body — you write the whole type twice ([08](08-platform-and-availability.md)) [measured] |

## Known blockers, measured here

- **watchOS has no assistant schemas.** `'reminders' is unavailable in watchOS`, same for `'system'`. A shared intents package compiles for watchOS, so every schema-annotated type needs a plain twin under `#if os(watchOS)`, and schema-only intents get excluded wholesale. [measured, Xcode 27 beta 5]
- **Nested requirements can block a domain you otherwise fit.** `.reminders.reminder` requires a `locationTrigger`, whose entity requires `place: GeoToolbox.PlaceDescriptor` as a `@Property`; adopting that emits an SSU training error on a clean build. The shape compiles — the toolchain is the blocker. [measured 2026-08-12]
- **Deployment target moves.** The `.reminders` domain is iOS 27+, which pulls the whole package up with it.

Corollary worth remembering: **the central entity's schema is not the price of entry.** A list-level schema conformance plus discoverable intents, `OpenIntent` / `DeleteIntent`, `.system.searchInApp` and semantic Spotlight indexing already deliver understanding, search and navigation. [measured — that is the shipping configuration here]

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

## If no domain fits

That is a normal outcome, not a gap to work around. What replaces it:

1. Well-named discoverable intents with real `IntentDescription` search keywords.
2. `@Property` coverage so Shortcuts can filter and Siri can read values.
3. `IndexedEntity` + `indexingKey:` for meaning-based Spotlight search ([10](10-advanced-entity-apis.md)).
4. `OpenIntent` / `DeleteIntent` so the standard verbs work.
5. `.system.searchInApp`.

Do not invent a "schema-like" naming convention, and do not adopt an adjacent domain to get the plumbing. Neither buys understanding; both cost you the ability to adopt the right domain later.
