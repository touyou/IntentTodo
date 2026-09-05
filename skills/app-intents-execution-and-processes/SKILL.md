---
name: app-intents-execution-and-processes
description: Work out where an App Intent actually runs, what it can reach there, and whether the app comes to the foreground. Use when a button in a widget, Control Center or a Live Activity does nothing, when an intent crashes or logs "Failed to retrieve dependency of type X", when the app opens on an action that should have stayed silent (or stays closed when it should open), when you moved intents into a Swift package and they stopped appearing in Shortcuts or Siri, when choosing supportedModes or allowedExecutionTargets, when sharing a database or shared state between an app and its extensions, or when adding a second platform and needing to know which APIs exist where.
license: MIT
---

# Execution, processes and packaging

Two questions that look like one and are not:

| Question | Answered by |
|---|---|
| Does the app come to the foreground? | `supportedModes` |
| Which **process** runs `perform()`? | `allowedExecutionTargets`, or a heuristic if you leave it unset |

Confusing them is the most expensive mistake in this area. `.background` does **not** mean "runs in the extension".

Assumes the rules in `app-intents-centric-design`.

## Symptoms this skill covers

| Symptom | Cause |
|---|---|
| Widget / control / watch button does nothing, no error UI | the dependency it needs is not registered in the process that ran it |
| `Failed to retrieve dependency of type X.` on stderr | same — and note it *only* fails the run; nothing crashes |
| Preconfigured App Shortcut never appears | inspect provider placement and `autoShortcuts`; ordinary action discovery uses `actions` instead |
| Intent exists in the package bundle but not the app bundle | target membership or a missing `includedPackages` |
| Snippet renders empty when resolved from a widget | the ambient entity store was registered in only one process |
| Widget shows different data than the app | two containers, no App Group |
| App opens for a silent action, or does not open for a navigation | `supportedModes` |
| Simulator build green, device or Xcode Cloud build red | `canImport` used as an availability check |

## The process is a heuristic, not a rule

When intents live in a package linked by several targets, **the system picks the process by heuristics** — it prefers the app if the app is already running, otherwise it launches an extension. [Apple: wwdc2026-345 15:59–16:55]

Pin it when you care:

```swift
public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
```

`.main` / `.appIntentsExtension` / `.widgetKitExtension` are the three options [Apple: wwdc2026-345 16:55]. It controls **who performs**, not whether entity resolution happens — resolution runs regardless.

**Rule of thumb: pin every intent that writes to the store to `[.main]`, and leave read-only intents unpinned.** A shared package linked into a widget extension otherwise lets the extension become a second writer to the same store when the app is not running — the configuration wwdc2026-345 16:30 names as the one to avoid. Read-only intents are better left free: answering from an already-running extension is faster than launching the app.

A test can enforce that: enumerate the intents that call a mutating service method and assert each declares `[.main]`. It is a rule no linter knows about and a forgotten declaration has no symptom.

### Registration matrix

`AppDependencyManager.shared` is **per process**. Anything resolved with `@Dependency` must be registered in the process that executes.

| Caller | Executes in | Register in |
|---|---|---|
| Siri / Shortcuts | main app for app-only or `[.main]` intents; otherwise check eligible extension targets | each eligible process |
| App UI `Button(intent:)` | main app | `App.init()` |
| Widget `Button(intent:)`, `.foreground(.immediate)` | main app | `App.init()` |
| Live Activity button | main app — `perform()` guaranteed [Apple]; entity pre-resolution measured there too [measured 2026-08-12] | `App.init()` |
| Widget timeline rendering (`entities(for:)`) | **widget extension** [measured 2026-08-12] | `WidgetBundle.init()` |
| Widget / control `.background`, no `allowedExecutionTargets` | **heuristic** — either | **both**, as insurance |
| …with a single `allowedExecutionTargets` value | `perform()` pinned | that process for execution; retain registrations required by queries/rendering elsewhere |

As long as any intent leaves `allowedExecutionTargets` unset, dual registration cannot be removed. That is the cost of the default, and it is cheap.

> Apple's line "If you adopt the `AppIntent` protocol, add your custom app intent to your widget extension target and your app target" is about **target membership at build time**, not a promise about the runtime process. [Apple]

**Register everything the process might need, not just what you think runs there.** The same package is linked into every target, so the set of intents present is identical on every platform; a watch app whose entry point registers only half the dependencies has half its actions failing silently.

## `supportedModes`

| Mode | Behaviour | Replaces |
|---|---|---|
| `.background` | runs without opening the app | `openAppWhenRun = false` |
| `.foreground` / `.foreground(.immediate)` | foreground right after parameter resolution | `openAppWhenRun = true` |
| `.foreground(.dynamic)` | `perform()` decides at runtime | **`ForegroundContinuableIntent`**, now deprecated |
| `.foreground(.deferred)` | starts in background, system foregrounds during or after `perform()` | new in iOS 26 |

[Apple: `supportedModes` documentation; wwdc2025-275 19:31–20:14]

| Situation | Mode |
|---|---|
| Silent data action (add / toggle / delete / favourite) | `.background` |
| "Open the editor", "show this detail" | `.foreground(.immediate)` |
| Usually silent, occasionally needs the user | `[.background, .foreground(.dynamic)]` |
| Optimistically background, escalate on the way out | `[.background, .foreground(.deferred)]` |

Details, escalation from inside `perform()`, and why `OpensIntent` conflicts with dynamic mode: [execution-modes](references/execution-modes.md).

## Fast decisions

**Where does this go?**

| Thing | Placement |
|---|---|
| Intents, entities, enums, queries, the service | shared Swift package |
| `AppIntentsPackage` | the package **and** every consuming target (`includedPackages`) |
| `AppShortcutsProvider` | **app target only** — never a package |
| `ControlConfigurationIntent` the app never references | the widget extension target |
| Views, view models | packages, so they stay previewable and testable |
| Extension targets | `@main` declaration, Info.plist, entitlements, `AppIntentsPackage`, a registration shim — nothing else |

**Which guard?**

| Condition | Use for |
|---|---|
| `#if os(iOS) \|\| os(visionOS)` | UIKit-dependent code, `.topBarTrailing`, scene delegates |
| `#if os(macOS)` | AppKit-dependent code |
| `#if os(iOS)` | ActivityKit / Live Activities |
| `#if !os(visionOS)` | controls |
| `#if os(watchOS)` | complication views; App Schema absence |
| `#if canImport(X) && os(...)` | anything whose API support is narrower than its framework |

Never `#if canImport(X)` alone as an availability test — details and the two measured cases in [platform-availability](references/platform-availability.md).

## References

| File | Covers |
|---|---|
| [execution-modes](references/execution-modes.md) | the four modes, choosing, `continueInForeground()`, `systemContext`, deprecations, control caveat |
| [dependencies-and-registration](references/dependencies-and-registration.md) | registering synchronously per process, what can and cannot use `@Dependency`, the ambient store for entities, service-as-dependency |
| [packaging](references/packaging.md) | `AppIntentsPackage` / `includedPackages`, provider placement and the `autoShortcuts: 0` failure, thin extension targets, package graph, App Groups |
| [platform-availability](references/platform-availability.md) | availability matrix, `canImport` vs `os()`, watchOS / macOS / visionOS specifics, Liquid Glass placement |
| [templates](references/templates.md) | app entry point, widget bundle entry point, `AppIntentsPackage` set, `AppShortcutsProvider` |
