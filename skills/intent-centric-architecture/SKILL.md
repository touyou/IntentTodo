---
name: intent-centric-architecture
description: Design multi-platform Apple apps (iOS/iPadOS/macOS/watchOS/visionOS) where every user action is an `AppIntent` and every domain object is an `AppEntity`, then route the same surface across Shortcuts, Siri, widgets, Live Activities, Control Center, and Spotlight. Use when applying Action-Centered Design, deciding the UI vs. Intent boundary, choosing `supportedModes`, wiring `@Dependency` / `AppDependencyManager` across app and extension processes, splitting `LiveActivityIntent` from regular `AppIntent`, or restructuring an app around iOS 26+ system surfaces (`onAppIntentExecution`, `foreground(.dynamic)`, `AppIntentSceneDelegate`).
---

# Intent-centric architecture

## Overview

In the Liquid Glass era, UI chrome dissolves into the background and **content + actions become the primary surface**. App Intents are no longer "the Shortcuts layer" — they are the system integration substrate that powers Siri, widgets, Live Activities, Control Center, Spotlight, the Action button, and visionOS ornaments from a single source of truth.

This skill applies a model called **App Intent-centric design**, which fuses three ideas:

- **App Intent Driven Development** (SwiftLee) — Intents as the unit of code reuse and system integration.
- **Action-Centered Design** (Vidit Bhargava) — design starts from actions, not screens.
- **Model-based UI design** — the use-case sentence "who can do what to which thing" maps directly to `AppEntity` (the noun) + `AppIntent` (the verb).

The result: Intent + Entity is the **atomic design unit**; UI and platform are secondary layers that compose those atoms for a specific surface.

Read these references as needed:

- `references/01-actions-and-entities.md` — choosing the verb/noun surface; Primary vs. FromExtension intent split.
- `references/02-multi-surface-mapping.md` — the Action-Centered Design mapping table; designing from the smallest screen first.
- `references/03-supported-modes.md` — `.background` / `.foreground(.immediate)` / `.foreground(.dynamic)` / `.foreground(.deferred)`; what replaces `openAppWhenRun` and `ForegroundContinuableIntent`.
- `references/04-process-and-dependencies.md` — `@Dependency` + `AppDependencyManager` across app process, Widget Extension process, and Live Activity Extension process; SPM packaging and `AppIntentsPackage` rules.
- `references/05-ui-integration.md` — `onAppIntentExecution`, `AppIntentSceneDelegate`, and the cold-start fallback for early iOS 26.
- `references/06-feedback-channels.md` — when Dialog is read aloud, when it is silent, and when to fall back to local notifications (Control Widget reality check).
- `references/07-data-and-side-effects.md` — `WidgetReloader.reloadAllWidgets()`, idempotent intents, `TodoService`-style aggregation, the SwiftData `@Query` + `.onChange(of:)` foot-gun.
- `references/08-platform-quirks.md` — visionOS Liquid Glass API availability (`Glass*ButtonStyle` not on visionOS), watchOS CPU constraints, macOS `NavigationSplitView` detail-pane `dismiss()` no-op, multi-platform component consolidation, Liquid Glass philosophy ("where not to use it").
- `references/code-templates.md` — copy-pasteable templates for Service-backed Intent, Primary+FromExtension pair, Entity+Query, `WidgetConfigurationIntent`, and `AppShortcutsProvider`.

## Core principles

1. **Every user-visible action is an `AppIntent`. Every routable domain object is an `AppEntity`.** No exceptions for "this one is just for the UI" — the UI calls the Intent too.
2. **`Button(intent:)` is the only execution path from UI.** Do not duplicate business logic in a ViewModel and an Intent. The Intent is the canonical action.
3. **Intents are thin. Logic lives in a `Service`.** Intents own parameter resolution, dialog/notification, and `WidgetReloader`. The `Service` owns persistence, validation, and side effects.
4. **The same Intent + Entity surface powers every system surface.** Widgets, controls, watch complications, Live Activities, and Shortcuts all consume the same atoms — they just compose them differently.
5. **Design from the smallest screen outward.** Start at watchOS / widget / Control Center. Their constraints force you to identify the *essential* action. The main app UI is the *last* thing you design, because it is the most permissive and therefore the least clarifying.

## Core workflow

### 1) Identify the essential actions, not screens
- Sketch use cases as sentences: "*who* can *do what* to *which thing*". Each verb is an Intent candidate; each noun is an Entity candidate.
- Limit the first pass to the 3–5 actions that make sense **without** the main app UI.
- Reject any "open this screen" item that has no purpose beyond navigation.

### 2) Define the smallest entity surface
- Add `AppEntity` only for objects the system needs to identify, route, or display.
- Keep the entity narrower than your persistence model: id, display representation, the few fields the system reads.
- Add `EntityQuery` only when disambiguation, suggestion, or dependent parameters are real needs.

### 3) Centralize logic in a Service
- Create one `@MainActor final class` Service per domain (e.g. `TodoService`) that wraps the Repository.
- Inject it via `AppDependencyManager.shared.add(dependency:)` at app startup.
- Intents declare `@Dependency var service: ...` and call into it. **Do not put SwiftData / network fetches inside `perform()`**.

### 4) Choose the execution mode and process
- Decide per Intent whether it should run in-place, open the app, or be dynamic. Pick `supportedModes` accordingly (see `references/03-supported-modes.md`).
- Intents called from Widget `Button(intent:)` with `.background` run in the **Widget Extension process** — register `@Dependency` in `WidgetBundle.init()` separately. Intents from Live Activity buttons run in the **app process** when they conform to `LiveActivityIntent`.

### 5) Map the same Intent surface across system surfaces
- Use the multi-surface mapping table (`references/02-multi-surface-mapping.md`) to decide where the action belongs: widget, control, complication, Live Activity, Action button, Siri, etc.
- For every surface, prefer reusing the existing Intent + Entity. Only invent a new Intent when the parameter shape genuinely differs.

### 6) Build the main app UI last
- Cluster the now-stable Intent set into screens — the screens become *compositions* of actions, not the other way around.
- Use `Button(intent:)` everywhere the UI triggers behavior. The UI ends up as a thin shell over the Intent layer.

## Strong defaults

- One `Service` class per domain, registered as a single `@Dependency`. Repositories live inside the Service, not in Intents.
- Register dependencies in **every process** that hosts intents: `App.init()` for the main app, `WidgetBundle.init()` for the widget extension, and the relevant entry point for any other extension.
- Declare `AppIntentsPackage` **once**, in the SPM package that owns the intents. Never re-declare it in the app target — it must be unique app-wide or Shortcuts routing breaks.
- Use **Primary + FromExtension** split when the same action is invoked both via `@Parameter var entity: SomeAppEntity` (Siri/Shortcuts/UI) and via a raw id from a Live Activity / Widget extension. Mark the FromExtension variant `isDiscoverable = false` and have it accept `String` ids — this avoids `AppEntityQuery.entities(for:)` running in the wrong process.
- For data-mutating intents, call `WidgetReloader.reloadAllWidgets()` (or your equivalent) at the end of the Service method, so every surface refreshes.
- Use `LiveActivityIntent` for any Activity-controlling Intent — it forces execution into the app process and unlocks `Activity.update()` / `.end()`.
- For Control Widget feedback, **do not rely on `.result(dialog:)`** — Control Center silently swallows it. Post a local notification instead.
- Prefer one `onAppIntentExecution(MyIntent.self)` per Intent that needs UI side effects, scoped to the relevant `Scene`. Fall back to `@Dependency var navigationModel` writes inside `perform()` when targeting iOS 26.0–26.3 cold-start.

## Anti-patterns

- Mapping screens 1:1 to Intents. The unit is **action**, not destination.
- Mirroring the persistence model as `AppEntity` types. Entities are display + routing surfaces, not ORM rows.
- Putting SwiftData / network code directly in `perform()` instead of a Service.
- Reaching for a singleton `MyIntentRouter.shared` instead of `AppDependencyManager` + `@Dependency` — singletons silently break cross-process invocations.
- Reusing one `AppIntent` for both UI and Live Activity buttons. Split into Primary + FromExtension.
- Forgetting to register `AppDependencyManager` dependencies in the Widget Extension process — the intent will compile but `@Dependency` resolution will trap at runtime.
- Adopting `ForegroundContinuableIntent` for new code. Apple deprecated it in favor of `supportedModes: [.background, .foreground(.dynamic)]`.
- Declaring `AppIntentsPackage` in both the app target and a SPM package. Apps support exactly one.
- Showing a `.result(dialog:)` from a Control Widget intent and assuming the user will see it.
- Caching SwiftData `@Query` results in a `@Observable` view model via `.onChange(of: todoItems)` to avoid per-`body` mapping. `[PersistentModel]` is identity-equatable, so in-place attribute updates (toggle, edit) do not fire `.onChange` — your cache silently goes stale. Map directly in `body`, or use a SwiftData `struct` projection. (See `references/07-data-and-side-effects.md`.)
- Adding `glassEffect` / `glassBackgroundEffect` to content surfaces (badges, chips, cards, list rows) "to be consistent with Liquid Glass". Apple's HIG positions Liquid Glass as a navigation-layer signal; the standard SwiftUI navigation chrome on iOS 26+ is already glass-rendered automatically. Decorating individual content elements creates noise. (See `references/08-platform-quirks.md`.)
- Using `.buttonStyle(.glass)` / `.glassProminent` in code that compiles for visionOS — those styles are not available on visionOS. (See `references/08-platform-quirks.md`.)

## Notes

- Primary Apple references:
  - <https://developer.apple.com/documentation/appintents/making-actions-and-content-discoverable-and-widely-available>
  - <https://developer.apple.com/documentation/appintents/creating-your-first-app-intent>
  - <https://developer.apple.com/documentation/appintents/adopting-app-intents-to-support-system-experiences>
  - <https://developer.apple.com/documentation/appintents/appintent/supportedmodes>
  - <https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities>
  - <https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities>
- App Intents API and platform behavior shifts every iOS cycle. When uncertain, web-search current Apple Developer documentation before committing to a pattern.
- A healthy first pass usually contains: one open-app intent, two background action intents, one or two `AppEntity` types with a single `EntityQuery`, one `AppShortcutsProvider`, and one `Service` that owns the persistence calls — that is enough to ship to Shortcuts, Siri, Spotlight, and a basic widget.
- Background reading on the design philosophy: <https://goodpatch-tech.hatenablog.com/entry/liquid_glass_and_app_intents>.
- When using this skill alongside performance / Liquid Glass / SwiftUI-pattern reviewers (e.g. `swiftui-performance-audit`, `swiftui-liquid-glass`), treat their output as a *candidate list*, not a verdict. Reviewer skills tend to read guidelines as coverage targets ("this place could use feature X, therefore it should") and miss the more important Apple guidance of "where *not* to use it" or "what platform doesn't support it". Filter every suggestion against the data-flow and platform-availability constraints in this skill before adopting it.
