---
name: app-intents-parameters-and-prompts
description: Give an App Intent its inputs, and let it ask the person for what it needs. Use when adding parameters to an intent, when parameters exist in the code but cannot be edited in the Shortcuts app, when the Shortcuts editor shows fewer fields than you wrote, when you want the person to confirm before something destructive or pick from a few options, when a field cannot be cleared or emptied from Shortcuts, when you need to tell "leave this alone" apart from "set this to nothing", when a parameter picker offers no suggestions, or when adding a location, photo, link or audio-search parameter — which currently trips an SDK bug that silently removes voice training data.
---

# Parameters and prompts

Everything about an intent's inputs: declaring them, making them reachable, and asking the person for them at run time.

Assumes the rules in `app-intents-centric-design`. The *values* those parameters carry — entities, enums, queries and their suggestions — are in `app-intents-entities-and-search`.

## `parameterSummary` is the Shortcuts editor's allowlist, not decoration

This is the rule most worth knowing in this file, because breaking it costs nothing at build time and removes features from the product.

> "`ParameterSummary` is not cosmetic — it is the allowlist for which parameters the Shortcuts editor surfaces. […] every other `@Parameter` is **silently omitted** from the editor UI, even though it still exists and still resolves." [Apple: App Intents guidance]

Only two things become editable rows:

1. parameters **interpolated into the `Summary("…")` sentence**, and
2. parameters **listed in the trailing `@ParameterKeyPathsBuilder` block**.

```swift
public static var parameterSummary: some ParameterSummary {
    Summary("Add todo titled \(\.$title)") {
        \.$dueDate            // ← without these lines, none of them
        \.$isFavorite         //   can be set from the Shortcuts app
        \.$estimatedDuration
        \.$assignee
        \.$location
    }
}
```

Consequences:

- **An intent with eleven parameters and `Summary("Update \(\.$todo)")` is a one-field action** in the Shortcuts editor. Everything else you built is unreachable there.
- **Display order is the summary's order** (interpolated first, then the trailing block), not the declaration order.
- Adding a `@Parameter` is *not* the same as adding a write path. If the point of the parameter is that people can set it, the summary edit is part of the change.
- Conditional display is `When(\.$p, .equalTo, v) { … } otherwise: { … }` or `Switch(\.$p) { Case(v) { … } }`.

**Why this hides so well:** the build is green, the intent still resolves the parameter, and Siri still works if you name the value out loud. Only opening the Shortcuts app shows it — so check the metadata instead:

```bash
python3 ../app-intents-testing/scripts/inspect_appintents_metadata.py --find MyProject -v
# actionConfiguration.actionSummary.wrapper.otherParameterIdentifiers  ← the trailing block
```

Diff that list against the intent's `@Parameter` declarations and the gap is mechanical to find. [measured 2026-08-29 — eleven parameters across two intents were absent from the editor]

## ⚠️ System value types break voice training when used as a `@Parameter`

`GeoToolbox.PlaceDescriptor`, `LinkPresentation.LinkMetadata`, `MediaIntents.AudioSearch` and `Photos.PHAsset` — types Apple's own documentation lists as supported parameter types — make `AppIntentsSSUTraining` emit `GeoToolbox.PlaceDescriptorEntity must match regular expression …` and **skip generating the target's voice-understanding assets entirely**, when the intent is registered in an `AppShortcutsProvider`. The tool exits 0, so the build says `BUILD SUCCEEDED`; only a CI archive notices.

The firing condition is narrow, and it matters:

| Shape | Result |
|---|---|
| `@Parameter var place: PlaceDescriptor?` on an intent **in `AppShortcutsProvider`** | ❌ error, no `nlu` assets for the whole target |
| the same intent **not** registered as an App Shortcut | ✅ |
| an entity's `@Property var place: PlaceDescriptor` | ✅ — entity properties never become SSU variables |
| a schema-derived declaration (`@AppIntent(schema:)` / `@AppEntity(schema:)`) | ✅ |
| `Transferable`'s `ValueRepresentation(exporting:) -> PlaceDescriptor` | ✅ |

So the workaround is only ever needed on the `@Parameter`: carry a `String` (plus coordinates, if you have them) there and reassemble the real type inside `perform()`. Leave entity properties and value representations alone.

Reported as **FB24548956**; reproduces on released Xcode 26.6 as well as 27 betas, so it is not a beta-only issue. [measured 2026-08-28/29]

**Judging it requires a clean build** — `AppIntentsSSUTraining` does not re-run when `Metadata.appintents` is unchanged, and an incremental log replays the previous output. And in a localised app the assets land in `<locale>.lproj/nlu.appintents/`, not `Metadata.appintents/nlu/`; look in the right place before concluding they are missing.

## Choosing a parameter shape

| Need | Use |
|---|---|
| A closed set of options | `AppEnum` — cheap, fixed picker, embeddable in a Siri phrase |
| A reference to one of the app's objects | `AppEntity` — embeddable in a phrase, resolves by id |
| Many objects at once | `EntityCollection<T>` — skips per-id resolution (`app-intents-entities-and-search`) |
| Free text | `String` — **cannot** be embedded in a phrase; Siri asks for it afterwards |
| Either of two entity types | `@UnionValue` enum |
| A value the system owns (place, photo, link) | see the SSU warning above |
| A tri-state update ("set" / "clear" / "leave alone") | read `$param.valueState` — see [asking-and-updating](references/asking-and-updating.md) |

A non-optional `AppEnum` parameter auto-disambiguates: the system asks the person to pick rather than failing. That is usually better than an optional with a default.

**`AppEnum` raw values are a two-way contract.** They are persisted by string in every shortcut a person has built, so cases can be added but never renamed or reordered. If the same enum is also a stored model value, it is a contract twice over.

## Asking at run time

| API | Asks for | Available from |
|---|---|---|
| `requestValue` | one missing parameter | any caller that can prompt |
| `needsValueError` | same, thrown | same |
| `requestConfirmation` | yes / no before acting | **Siri / Shortcuts only** |
| `requestChoice` | one of a few options | **Siri / Shortcuts only** |

The last two **fail silently from a button** — no error, nothing happens (`app-intents-ui-and-feedback`). Keep a non-interactive twin for those callers. Details, `IntentChoiceOption` pitfalls and the confirmation ordering rule are in [asking-and-updating](references/asking-and-updating.md).

## Copy

`@Parameter(title:)` and `@Parameter(description:)` are **not extracted into any String Catalog** — only `parameterSummary` is. Localising them means manual catalog keys (`app-intents-localization`).

## References

| File | Covers |
|---|---|
| [parameter-summaries](references/parameter-summaries.md) | the allowlist rule in full, conditional summaries, ordering, verifying against the built metadata, system value types and the SSU bug |
| [asking-and-updating](references/asking-and-updating.md) | `requestValue`, `requestConfirmation`, `requestChoice`, why they are Siri-only, partial updates with `valueState`, the typed-nil test requirement |
