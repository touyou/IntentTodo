# 12 — Surface catalogue

Every place an `AppIntent` or `AppEntity` can show up, the conformance it needs, and the gate. [02](02-multi-surface-mapping.md) decides *which* surfaces your app deserves; this file exists so you never conclude "App Intents can't do that" when a protocol for it already ships.

**Read the evidence column.** `[Apple]` means the framework vends it and the documentation says what it does — enough to design with, not proof it behaves as you imagine. `[measured]` means it was run here. Nothing in this file is a recommendation to adopt: most apps should touch three or four rows.

## Discovery and invocation

| Surface | What it needs | Gate | Evidence |
|---|---|---|---|
| Shortcuts app, automations | any `AppIntent` with `isDiscoverable` true (the default) | none — this is free with the intent | [Apple] |
| Siri phrase | `AppShortcutsProvider` in the **app target**, ≤10 entries | only `AppEntity` / `AppEnum` can be embedded in a phrase [Apple: wwdc2022-10170 14:40] | placement [measured] ([04](04-process-and-dependencies.md)) |
| Spotlight top hits / actions | `IndexedEntity` + intents; `OpenIntent` to open a result | index on mutation; the semantic `indexingKey:` form is iOS/macOS only ([08](08-platform-and-availability.md)) | [Apple] ([10](10-advanced-entity-apis.md)) |
| Siri Suggestions, proactive prediction | `PredictableIntent` + `IntentPrediction` descriptions | the system decides when to suggest; you only control the phrasing | [Apple: `PredictableIntent`; wwdc2025-275] |
| Home-screen / lock-screen widget | `Button(intent:)` or `Toggle`; `Link` to merely open | Button and Toggle are the **only** interactive elements | [Apple: wwdc2023-10028 12:15] |
| Control Center, lock screen, Action button control | `ControlWidgetButton(action:)` / `ControlWidgetToggle(isOn:action:)` | extension target; no visionOS; no dialog or snippet | [measured] ([06](06-feedback-channels.md)) |
| Live Activity / Dynamic Island | `LiveActivityIntent` under `#if os(iOS)` | required to start an activity from the background | [Apple] |
| Apple Watch complication / Smart Stack | WidgetKit in the watch app | watchOS lacks `Button(role:intent:)` and assistant schemas | [measured] ([08](08-platform-and-availability.md)) |
| Apple Watch Ultra Action button | any intent; `systemContext` carries a precise start timestamp on watchOS | timestamp is watchOS-specific context | [Apple: `IntentSystemContext`] |
| Visual Intelligence (camera / screenshot) | `IntentValueQuery` + `SemanticContentDescriptor`, results `openable` | **one** such query per app; absent from the iOS simulator SDK | [Apple: wwdc2026-297 11:39] ([11](11-interaction-and-scale.md)) |
| Focus filters (per-Focus app behaviour) | `SetFocusFilterIntent` | the system runs it on Focus changes, not on demand; unverified here | [Apple: wwdc2022-10121] `[inferred]` for current OS behaviour |
| Universal links in / out | `OpenURLIntent`, `URLRepresentableEntity` / `URLRepresentableEnum` | only for entities that genuinely have a URL | [Apple: app-intent-types] |
| Side-button conversational assistant (Japan) | `.assistant` schema domain | region- and category-specific | [Apple: app-schema-domains, single-purpose domains] |

## Action semantics the system already knows

Conforming to one of these tells the system *what kind of action* it is, which is what makes an intent usable without a phrase. Prefer them over inventing an equivalent of your own.

| Protocol | Meaning | Note |
|---|---|---|
| `OpenIntent` | open the associated entity | prerequisite for Spotlight results and Visual Intelligence results |
| `DeleteIntent` | delete entities | takes an **array**; a single-entity delete cannot conform |
| `SetValueIntent` | set a value absolutely | what `ControlWidgetToggle` requires |
| `ShowInAppSearchResultsIntent` | take the person to search results, with `StringSearchScope` | pairs with the `.system.searchInApp` schema |
| `AudioPlaybackIntent` / `AudioStartingIntent` / `AudioRecordingIntent` | this action changes audio state | the system avoids interrupting with dialogue |
| `CameraCaptureIntent` | launches camera capture | makes the intent eligible for the Camera quick action |
| `PlayVideoIntent`, `PushToTalkTransmissionIntent` | media / PTT semantics | narrow, but free if they fit |
| `LongRunningIntent`, `CancellableIntent`, `ProgressReportingIntent` | bulk work with progress and cancellation | [11](11-interaction-and-scale.md) |
| `UndoableIntent` | participates in the system undo stack | the system hands you the right `undoManager` "even when those intents are run in your extensions" [Apple: wwdc2025-275 15:19–16:06] |
| `DeprecatedAppIntent` | this action is retired; here is its replacement | how you retire an intent without breaking shortcuts people already built |

All of them are `SystemIntent` refinements — conform directly, no schema macro needed.

## Entity shapes the system already knows

| Type | Use when | Note |
|---|---|---|
| `AppEntity` | queryable app object | the default |
| `TransientAppEntity` | computed snapshot nobody queries back | no `defaultQuery`, no indexing ([10](10-advanced-entity-apis.md)) |
| `UniqueAppEntity` | a value that only ever has one instance — global settings | avoids a fake query over one row |
| `FileEntity` | the entity *is* a document or file | before hand-rolling a path-carrying entity |
| `IndexedEntity` | should be findable in Spotlight | index incrementally on mutation |
| `SyncableEntity` | the same object across a person's devices | free if `id` is already stable |
| `OwnershipProvidingEntity` | shared / owned content where the system should know who owns it | not adopted here |
| `@UnionValue` enum | one value that may be several entity types | required for a multi-type value query |

## Choosing by app kind

A shortcut for the first pass. One row is usually enough to start.

| App kind | The surface that pays first | Then |
|---|---|---|
| Tracker / list / habit | widget with today's state | control for the one repeated action |
| Player / audio | `AudioPlaybackIntent` + Live Activity | Siri phrases for "play X in <app>" |
| Capture (camera, scanner, voice memo) | `CameraCaptureIntent` / `AudioRecordingIntent`, Action button | `.camera` / `.audio` schema domain |
| Document / notes editor | `FileEntity` / document entity + `OpenIntent` | Spotlight index, then a Shortcuts-tier domain ([13](13-schema-domains.md)) |
| Utility with one switch | control (`SetValueIntent`) | `UniqueAppEntity` for its settings |
| Content library / catalogue | Spotlight index + `OpenIntent` | `EntityPropertyQuery` for "Find X where…" |
| Communication | the `.messages` / `.mail` domain — **all-or-nothing** ([13](13-schema-domains.md)) | onscreen entities |

## Before adding a surface

Four questions, in order. A no at any point means stop.

1. **Is the action repeated?** A surface for a once-a-month action is maintenance, not reach.
2. **Can the surface show the truth?** A control needs a fixed target whose state the provider can read back ([02](02-multi-surface-mapping.md)); a widget needs data available in the extension's process.
3. **Is failure distinguishable from nothing happening?** If not, you owe an error path ([06](06-feedback-channels.md)).
4. **Which existing intent does it reuse?** If the answer is "a new one", check it is a genuinely different behaviour and not a per-caller clone ([01](01-actions-and-entities.md)).

## When a surface is not in this file

Search before concluding it does not exist: `DocumentationSearch` on `AppIntents` for the noun ("focus", "camera", "undo", "ownership"), then the local WWDC index. The framework grows every cycle and the additions are usually *new conformances on the intents you already have*, which is the cheapest kind of reach there is. Add what you find here with an evidence label, and if you could not run it, say `[inferred]` and do not design around the timing or the UI it produces.
