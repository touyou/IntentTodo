# Surface catalogue

Every place an `AppIntent` or `AppEntity` can show up, the conformance it needs, and the gate. `SKILL.md` decides *which* surfaces your app deserves; this file exists so you never conclude "App Intents can't do that" when a protocol for it already ships.

**Read the evidence column.** `[Apple]` means the framework vends it and the documentation says what it does — enough to design with, not proof it behaves as you imagine. `[measured]` means it was run. Nothing in this file is a recommendation to adopt: most apps should touch three or four rows.

## Discovery and invocation

| Surface | What it needs | Gate | Evidence |
|---|---|---|---|
| Shortcuts app, automations | any `AppIntent` with `isDiscoverable` true (the default) | parameters are editable only if listed in `parameterSummary` (`app-intents-parameters-and-prompts`) | [Apple] |
| Siri phrase | `AppShortcutsProvider` in the **app target**, ≤10 entries | only `AppEntity` / `AppEnum` can be embedded in a phrase [Apple: wwdc2022-10170 14:40]; parameterised phrases need `updateAppShortcutParameters()` | placement [measured] |
| Spotlight top hits / actions | `IndexedEntity` + intents; `OpenIntent` to open a result | index on mutation; the declarative `indexingKey:` form supports iOS/macOS/visionOS | [Apple] (`app-intents-entities-and-search`) |
| Siri Suggestions, proactive prediction | `PredictableIntent` + `IntentPrediction` descriptions | the system decides when to suggest; you only control the phrasing | [Apple: `PredictableIntent`; wwdc2025-275] |
| Home-screen / lock-screen widget | `Button(intent:)` or `Toggle`; `Link` to merely open | Button and Toggle are the **only** interactive elements | [Apple: wwdc2023-10028 12:15] |
| Control Center, lock screen, Action button control | `ControlWidgetButton(action:)` / `ControlWidgetToggle(isOn:action:)` | extension target; no visionOS; no dialog or snippet | [measured] ([controls](controls.md)) |
| Live Activity / Dynamic Island | `LiveActivityIntent` under `#if os(iOS)` | required to start an activity from the background | [Apple] |
| Apple Watch complication / Smart Stack | WidgetKit in the watch app | watchOS lacks `Button(role:intent:)` and **all** App Schema domains | [measured] (`app-intents-execution-and-processes`) |
| Apple Watch Ultra Action button | any intent; `systemContext` carries a precise start timestamp on watchOS | timestamp is watchOS-specific context | [Apple: `IntentSystemContext`] |
| Visual Intelligence (camera / screenshot) | `IntentValueQuery` + `SemanticContentDescriptor`, results `openable` | **one** such query per app; absent from the iOS simulator SDK | [Apple: wwdc2026-297 11:39] ([visual-intelligence-and-onscreen](visual-intelligence-and-onscreen.md)) |
| Onscreen references ("that one", "this song") | `userActivity` + `appEntityIdentifier`, or `.appEntityIdentifier(forSelectionType:)` on a `List` | `List`-only for the collection form; fails silently elsewhere | [Apple: sample code] ([visual-intelligence-and-onscreen](visual-intelligence-and-onscreen.md)) |
| Focus filters (per-Focus app behaviour) | `SetFocusFilterIntent` | the system runs it on Focus changes, not on demand | [Apple: wwdc2022-10121] |
| Universal links in / out | `OpenURLIntent`, `URLRepresentableEntity` / `URLRepresentableEnum` | only for entities that genuinely have a URL; **declare on the concrete type, not through a `typealias`** | [Apple: app-intent-types]; typealias limit [measured] |
| Side-button conversational assistant (Japan) | `.assistant` schema domain | region- and category-specific; iOS only | [Apple: app-schema-domains] |

## Action semantics the system already knows

Conforming to one of these tells the system *what kind of action* it is, which is what makes an intent usable without a phrase. Prefer them over inventing an equivalent of your own.

| Protocol | Meaning | Note |
|---|---|---|
| `OpenIntent` | open the associated entity | prerequisite for Spotlight results and Visual Intelligence results; `var target: Target where Target: AppEntity`, use `.foreground(.immediate)` |
| `DeleteIntent` (`: SystemIntent`) | delete entities | takes an **array**; a single-entity delete cannot conform — make a separate bulk intent |
| `SetValueIntent` | set a value absolutely | what `ControlWidgetToggle` requires |
| `ShowInAppSearchResultsIntent` | take the person to search results, with `StringSearchScope` | pairs with the `.system.searchInApp` schema |
| `AudioPlaybackIntent` / `AudioStartingIntent` / `AudioRecordingIntent` | this action changes audio state | the system avoids interrupting with dialogue |
| `CameraCaptureIntent` | launches camera capture | makes the intent eligible for the Camera quick action |
| `PlayVideoIntent`, `PushToTalkTransmissionIntent` | media / PTT semantics | narrow, but free if they fit |
| `LongRunningIntent`, `CancellableIntent`, `ProgressReportingIntent` | bulk work with progress and cancellation | `app-intents-entities-and-search` (scale) |
| `UndoableIntent` | participates in the system undo stack | the system hands you the right `undoManager` "even when those intents are run in your extensions" [Apple: wwdc2025-275 15:19–16:06]; `app-intents-centric-design` |
| `SetFocusFilterIntent` | per-Focus app configuration | runs on Focus change; make it affect every surface, not just the main list |
| `DeprecatedAppIntent` | this action is retired; here is its replacement | how you retire an intent without breaking shortcuts people already built |

All of them are `SystemIntent` refinements — conform directly, no schema macro needed. Neither `OpenIntent` nor `DeleteIntent` needs an App Shortcut slot, which protects the 10-slot budget.

## Entity shapes the system already knows

| Type | Use when | Note |
|---|---|---|
| `AppEntity` | queryable app object | the default |
| `TransientAppEntity` | computed snapshot nobody queries back | no `defaultQuery`, no indexing |
| `UniqueAppEntity` | a value that only ever has one instance — global settings | avoids a fake query over one row |
| `FileEntity` | the entity *is* a document or file | before hand-rolling a path-carrying entity |
| `IndexedEntity` | should be findable in Spotlight | index incrementally on mutation |
| `SyncableEntity` | the same object across a person's devices | free if `id` is already stable |
| `OwnershipProvidingEntity` | shared / owned content where the system should know who owns it | not exercised here |
| `@UnionValue` enum | one value that may be several entity types | required for a multi-type value query |

Details in `app-intents-entities-and-search`.

## Choosing by app kind

A shortcut for the first pass. One row is usually enough to start.

| App kind | The surface that pays first | Then |
|---|---|---|
| Tracker / list / habit | widget with today's state | control for the one repeated action |
| Player / audio | `AudioPlaybackIntent` + Live Activity | Siri phrases for "play X in <app>" |
| Capture (camera, scanner, voice memo) | `CameraCaptureIntent` / `AudioRecordingIntent`, Action button | `.camera` / `.audio` schema domain |
| Document / notes editor | `FileEntity` / document entity + `OpenIntent` | Spotlight index, then a Shortcuts-tier domain |
| Utility with one switch | control (`SetValueIntent`) | `UniqueAppEntity` for its settings |
| Content library / catalogue | Spotlight index + `OpenIntent` | `EntityPropertyQuery` for "Find X where…" |
| Communication | the `.messages` / `.mail` domain — **all-or-nothing** | onscreen entities |

## When a surface is not in this file

Search before concluding it does not exist: `DocumentationSearch` on `AppIntents` for the noun ("focus", "camera", "undo", "ownership"), then the WWDC session index. The framework grows every cycle and the additions are usually *new conformances on the intents you already have*, which is the cheapest kind of reach there is.

Add what you find here with an evidence label, and if you could not run it, say `[inferred]` and do not design around the timing or the UI it produces.

For a todo app, there is no matching context in the Xcode 27 beta 6 public SDK [Apple SDK: `AppEntityContext`, `AudioContext`]. `RelevantEntities.shared.updateEntities(_:for:)` needs an `AppEntityContext`; the exposed factory is `.audio(_:)`, with `.nowPlaying` as the available `AudioContext` value. Do not copy a `.workout(activityType:)` example without finding its declaration in the target SDK. There is **no general context**, so a list/todo/document entity has nothing correct to donate under. If contextual suggestion matters, look at `RelevantIntent` / `RelevantIntentManager` (widget-configuration based) instead — a different axis. Recheck when Apple adds domain contexts.
