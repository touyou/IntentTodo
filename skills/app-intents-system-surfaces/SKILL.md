---
name: app-intents-system-surfaces
description: Decide where an action or piece of content should appear outside your app, and use the right API for that place. Use when you want to put a working button in a home screen or lock screen widget, add something to Control Center, show live status in the Dynamic Island or on the lock screen, support an Apple Watch complication or Smart Stack, wire up the Action button, let the camera or a screenshot find your content, change app behaviour per Focus mode, tell Siri what is currently on screen, or make content findable system-wide — and when the question is "where should this action live?", "which of these places is worth it?", or "can Apple's frameworks even reach that place?".
license: MIT
---

# System surfaces

Where each intent and entity should appear, in what order to design them, and which API each surface expects.

Assumes the rules in `app-intents-centric-design`. Process and registration questions for any of these surfaces are in `app-intents-execution-and-processes`; what the person sees afterwards is in `app-intents-ui-and-feedback`.

## Design from the smallest surface outward

The tightest surface is the clarifier: it forces you to name the *essential* action.

1. **watchOS complication** — what is worth a glance?
2. **Home-screen widget** — what information is checked daily?
3. **Control Center / Action button** — what action is worth firing from anywhere?
4. **Live Activity** — what state genuinely needs continuous tracking?
5. **Shortcuts / Siri** — which verbs are valuable inside automations?
6. **Spotlight** — which entities deserve to be globally findable?
7. **visionOS** — what becomes spatial with unlimited canvas?
8. **Main app UI** — finally, compose the stable intent set into screens.

Starting at step 8 is the common failure: the intents end up mirroring the navigation tree instead of the actions.

> **This is a design order, not a build order.** "Start from the smallest surface" means *let the tightest surface tell you which action is essential*. Delivery order is the level model in `app-intents-centric-design`: one intent reachable from Shortcuts, then the one glance surface that action deserves.

## Surface matrix

| Characteristic of the action / data | Surface | Example |
|---|---|---|
| Glanced at every day | Home widget | today's list, open count |
| Changes often, at a glance | watchOS complication | next deadline, progress |
| Repeated user-initiated action | Shortcuts / Siri | "add a todo", "mark it done" |
| Continuously tracked state | Live Activity | item due within the hour |
| Quick fire-and-forget | Control Center | quick add, complete the chosen item |
| Physically natural trigger | Action button | create new item |
| Globally searchable object | Spotlight (`IndexedEntity`) | todo, category |
| Camera / screenshot context | Visual Intelligence (`IntentValueQuery`) | match a photo to stored items |
| Behaviour that should change per Focus | `SetFocusFilterIntent` | hide non-work items while Working |
| Spatial / immersive | visionOS | ornaments, spatial layout |
| Multi-action workflow | Main app UI | edit, organise, settings |

One intent appearing on many surfaces is the point. `AddTodoIntent` serves Shortcuts, the Action button, a widget button and a control from one definition.

## Per-surface API choice

The surface dictates the API even when the intent is identical.

| Surface | Correct API | Notes |
|---|---|---|
| Widget / Live Activity, opens the app | `Link(destination:)` + `widgetURL(_:)` | Apple: "An interaction with a button or toggle should do more than open the app. If you want to offer an interaction that opens the app, use `Link` and `widgetURL(_:)`" [Apple] |
| Widget, performs an action | `Button(intent:)` | Widgets support **only** Button and Toggle as interactive elements [Apple: wwdc2023-10028 12:15] |
| Widget button ran an intent | nothing to do | The system reloads that widget's timeline when `perform()` returns [Apple: wwdc2023-10028 10:02, 13:47] |
| Control, fire-and-forget | `ControlWidgetButton(action:)` | "Buttons don't have state; use them for fire-and-forget actions" [Apple] |
| Control, two states | `ControlWidgetToggle(isOn:action:)` + `SetValueIntent where ValueType == Bool` | The system fills `value` with the **destination** state — "Don't set or manage the value parameter". Your intent must be an absolute setter, not a flip. |
| Control needing a target | `AppIntentControlConfiguration` + a separate `ControlConfigurationIntent`, `.promptsForUserConfiguration()` | Configuration intent and action intent are separate by design [Apple: wwdc2024-10157] |
| Control showing a value | `StaticControlConfiguration(kind:provider:)` + `ControlValueProvider` | Async fetching belongs in the provider. Throw on failure — never `try?` down to a plausible-looking `0`. |
| Live Activity button | the same intent, conformed to `LiveActivityIntent` under `#if os(iOS)` | Required to start an activity from the background, and documents `perform()` as running in the app process [Apple] |
| Spotlight | `IndexedEntity` + index on mutation | `app-intents-entities-and-search` |
| Camera / screenshot | one `IntentValueQuery` taking a `SemanticContentDescriptor` | [visual-intelligence-and-onscreen](references/visual-intelligence-and-onscreen.md) |

**A toggle needs a fixed target.** `isOn` must be a value the provider can read back on the next reload. "Complete the most urgent item" cannot be a toggle: completing it makes the provider return a *different*, incomplete item, so the on-state never persists. Either pin the target through configuration, or use a button.

**Control `kind` strings are system-wide identifiers.** Use reverse-DNS (`com.example.MyApp.MyTarget.MyControl`) as every Apple sample does.

## App Shortcuts budget

- **Maximum 10 `AppShortcut` entries per app** [Apple: wwdc2022-10169 4:02, wwdc2023-10102 20:58]. Aim to leave slack.
- **Maximum ~1,000 phrases** across them [Apple].
- **Exactly one `AppShortcutsProvider` per app** [Apple: wwdc2023-10102 3:44, wwdc2025-244 9:22]; a second one is a build error. It must live in the app target — see `app-intents-execution-and-processes`.
- **Only `AppEntity` and `AppEnum` parameters can be embedded in a phrase.** A free-text `String` parameter cannot [Apple: wwdc2022-10170 14:40–15:15]; Siri asks for it afterwards instead.

```swift
// One slot, many phrasings, one AppEnum parameter — instead of four separate shortcuts.
AppShortcut(
    intent: ShowTodosIntent(),
    phrases: [
        "Show my todos in \(.applicationName)",
        "Show \(\.$filter) todos in \(.applicationName)",
    ],
    shortTitle: "Show todos",
    systemImageName: "list.bullet"
)
```

A parameterised phrase **does nothing until `updateAppShortcutParameters()` has been called at least once** — wire it at launch and again from the service's post-mutation hook (`app-intents-centric-design`) [Apple: wwdc2023-10102 9:24].

Keep one parameter-free phrase per intent so Siri can ask for the value instead of failing to match.

**Phrase variations should vary the vocabulary, not the grammar.** `Snooze` / `Delay` add a recognition path; "snooze it" / "snooze this" do not. Translating them mechanically collapses the variations into one — see `app-intents-localization`.

Skip a shortcut slot for anything a widget or control already reaches (a pure "open the app" intent, for instance). System intents (`OpenIntent`, `DeleteIntent`) are understood semantically without a shortcut entry too.

`AppShortcutsProvider` also carries `static let shortcutTileColor: ShortcutTileColor`, which sets the background of every tile the Shortcuts app draws for the app. One line, and the default is a colour nobody chose.

## Reuse rules

- **Same intent, different surfaces.** Reuse before inventing. A different caller is not a different action.
- **Same parameter shape everywhere.** Complication, widget and Siri all pass the entity.
- **Only the output forks.** Dialog, snippet, notification, redraw — feedback is per-caller (`app-intents-ui-and-feedback`); input and logic are not.

## Before adding a surface

Four questions, in order. A no at any point means stop.

1. **Is the action repeated?** A surface for a once-a-month action is maintenance, not reach.
2. **Can the surface show the truth?** A control needs a fixed target whose state the provider can read back; a widget needs data available in the extension's process.
3. **Is failure distinguishable from nothing happening?** If not, you owe an error path (`app-intents-ui-and-feedback`).
4. **Which existing intent does it reuse?** If the answer is "a new one", check it is a genuinely different behaviour and not a per-caller clone.

## A useful first pass

Roughly a level-1 project — not a level-0 one, which is a single intent and no extension at all.

- 1 open-app intent (`.foreground(.immediate)`).
- 2–3 background action intents (add / toggle / delete).
- 1–2 entity types with one query each.
- 1 `AppShortcutsProvider` in the app target with 3–5 entries.
- 1 widget configuration intent if the widget is configurable.
- 1 control if there is a single high-frequency action.

Skip on the first pass: settings-as-intents, "open tab N", bulk operations that need heavy UI, and anything whose value is "the user can navigate here from Shortcuts". Navigation is not a feature.

Run `python3 ../app-intents-centric-design/scripts/audit_intents.py . --coverage` to see which surfaces the project already reaches and what each missing one would take.

## References

| File | Covers |
|---|---|
| [surface-catalog](references/surface-catalog.md) | every surface an intent can reach, the conformance each needs, action semantics the system already knows, choosing by app kind |
| [controls](references/controls.md) | Control Center specifics: buttons vs toggles, configuration, value providers, templates |
| [visual-intelligence-and-onscreen](references/visual-intelligence-and-onscreen.md) | camera / screenshot search, telling Siri what is on screen, the `List`-only annotation trap |
