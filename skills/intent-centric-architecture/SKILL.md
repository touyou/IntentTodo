---
name: intent-centric-architecture
description: Design multi-platform Apple apps (iOS/iPadOS/macOS/watchOS/visionOS) where every user action is an `AppIntent` and every domain object is an `AppEntity`, then route that one surface through Shortcuts, Siri, widgets, controls, Live Activities, Spotlight and Visual Intelligence. Use when applying Action-Centered Design, deciding the UI-vs-Intent boundary, choosing `supportedModes` / `allowedExecutionTargets`, registering `@Dependency` across app and extension processes, placing `AppIntentsPackage` / `AppShortcutsProvider`, picking a feedback channel per caller, adopting entity APIs (`@ComputedProperty`, `IndexedEntity`, `TransientAppEntity`, `@UnionValue`, assistant schemas), or validating an adoption with AppIntentsTesting.
---

# Intent-centric architecture

## What this is

In the Liquid Glass era, UI chrome dissolves into the background and **content + actions become the product surface**. App Intents stopped being "the Shortcuts layer": they are the substrate that powers Siri, widgets, controls, Live Activities, Spotlight, the Action button, Visual Intelligence and visionOS ornaments from one definition.

This skill applies **App Intent-centric design**, which fuses:

- **App Intent Driven Development** (SwiftLee) — intents as the unit of code reuse and system integration.
- **Action-Centered Design** (Vidit Bhargava) — design starts from actions, not screens.
- **Model-based UI design** — the use-case sentence "*who* can *do what* to *which thing*" maps onto `AppEntity` (noun) + `AppIntent` (verb).

Intent + Entity is the **atomic design unit**. UI and platform are later layers that compose those atoms for one surface.

## Non-negotiables

Ten rules that are cheap to follow and expensive to discover. Each links to the reference with the evidence.

| # | Rule | Why it bites | Detail |
|---|---|---|---|
| 1 | Every user-visible action is an `AppIntent`; UI triggers it with `Button(intent:)` | Any logic that lives only in a ViewModel is invisible to Siri, Shortcuts, widgets and controls forever | [01](references/01-actions-and-entities.md) |
| 2 | One action = one intent, regardless of caller | Per-caller clones drift; the entity re-resolves from its `id` before `perform()` anyway | [01](references/01-actions-and-entities.md) |
| 3 | Intents stay thin; a `@MainActor` Service owns persistence + side effects | Keeps `perform()` retriable and the logic testable without `AppDependencyManager` | [07](references/07-data-and-side-effects.md) |
| 4 | Register `@Dependency` in **every** process that may execute the intent | Process choice is a heuristic, not a rule; an unregistered dependency traps at runtime with a green build | [04](references/04-process-and-dependencies.md) |
| 5 | `AppShortcutsProvider` lives in the app target, never in a package | `autoShortcuts` is the one key not aggregated from packages: shortcuts silently never register | [04](references/04-process-and-dependencies.md) |
| 6 | Declare `AppIntentsPackage` in the package **and** in every consuming target with `includedPackages` | Apple's documented indexing/validation step | [04](references/04-process-and-dependencies.md) |
| 7 | Never call `intent.perform()` yourself | `@Dependency` is only injected on system dispatch; a manual call is zero-initialised and crashes | [05](references/05-ui-integration.md) |
| 8 | Interactive intents (`requestConfirmation` / `requestChoice`) are Siri/Shortcuts-only | From an in-app or widget button they fail with no error UI — *nothing happens* | [05](references/05-ui-integration.md) |
| 9 | Pick the feedback channel from the **caller**, not from the intent | Controls present neither dialog nor snippet; UI buttons present neither | [06](references/06-feedback-channels.md) |
| 10 | A data mutation reloads timelines **and** controls | They are separate APIs; the system only auto-reloads the one control that ran the intent | [07](references/07-data-and-side-effects.md) |

## Workflow

1. **Find the actions, not the screens.** Write use cases as "*who* can *do what* to *which thing*". Verbs are intent candidates, nouns are entity candidates. Drop anything whose only value is "navigate here".
2. **Design from the smallest surface outward** — complication → widget → control → Live Activity → Shortcuts/Siri → Spotlight → visionOS → main app UI. Constraint is the clarifier; the main app is the most permissive surface and therefore the least informative one to start from. ([02](references/02-multi-surface-mapping.md))
3. **Define the minimal entity surface.** `id` + `displayRepresentation` + the few `@Property` members the system actually reads. Prefer `AppEnum` for closed sets. ([01](references/01-actions-and-entities.md))
4. **Put the logic in a Service, inject it with `@Dependency`.** Register it synchronously at each process entry point. ([04](references/04-process-and-dependencies.md))
5. **Choose mode and process per intent** — `supportedModes` decides foregrounding, `allowedExecutionTargets` decides the process. They are different questions. ([03](references/03-execution-modes.md), [04](references/04-process-and-dependencies.md))
6. **Compose the app UI last**, out of the now-stable intent set. ([05](references/05-ui-integration.md))
7. **Climb the verification ladder** before believing any of it works. ([09](references/09-verification.md))

## Fast decisions

**Which API on which surface**

| Goal | Use | Not |
|---|---|---|
| Widget/Live Activity element that only opens the app | `Link(destination:)` / `widgetURL(_:)` | `Button(intent:)` — Apple: an interaction "should do more than open the app" |
| Widget element that acts | `Button(intent:)` | manual `perform()` |
| Control, fire-and-forget | `ControlWidgetButton(action:)` | a toggle over a moving target |
| Control, two states of a **fixed** target | `ControlWidgetToggle(isOn:action:)` + `SetValueIntent` + `AppIntentControlConfiguration` | a flipping toggle intent — the system supplies the destination state |
| Control that shows a value | `ControlValueProvider` (throw on failure) | fetching inside `body`, `try?` to a fake zero |

**Where to register the dependency** — full matrix in [04](references/04-process-and-dependencies.md)

| Caller | Executes in | Register in |
|---|---|---|
| Siri / Shortcuts / app UI | main app | `App.init()` |
| Live Activity button | main app (`perform()` guaranteed; entity pre-resolution measured there too) | `App.init()` |
| Widget timeline entity resolution | **widget extension** | `WidgetBundle.init()` |
| Widget / control `.background` intent, no `allowedExecutionTargets` | **heuristic** (running app preferred, else extension) | **both** |
| …with `allowedExecutionTargets` set | pinned | that process only |

**Feedback channel** — full matrix in [06](references/06-feedback-channels.md)

| Caller | dialog | snippet | notification |
|---|---|---|---|
| Siri | spoken | shown | shown |
| Spotlight / Shortcuts | shown | shown | shown |
| App / widget `Button(intent:)` | — | — | shown |
| **Control Center** | **—** | **—** | shown |

Controls get exactly three official channels: the redraw after `perform()` returns, `controlWidgetStatus(_:)`, `controlWidgetActionHint(_:)`.

## Scripts

Two deterministic checks. Run the first any time; the second needs a build.

```bash
# 17 static rules: provider placement, package registration, interactive-intent misuse,
# manual perform(), reload coverage, control feedback, platform guards, test shape…
python3 scripts/audit_intents.py . --fail-on error
python3 scripts/audit_intents.py . --list-rules      # rule catalogue
python3 scripts/audit_intents.py . --json            # machine-readable

# What the system actually reads: counts, schema conformances, entity properties,
# App Shortcut phrases, per-target aggregation.
python3 scripts/inspect_appintents_metadata.py --find MyProject
python3 scripts/inspect_appintents_metadata.py path/to/MyApp.app -v
```

`inspect_appintents_metadata.py` is the only way to see several failures at all: an `AppShortcutsProvider` that registered nothing, an entity that exposes zero properties, a schema conformance that did not land. None of them break the build.

## References

Read on demand — each is self-contained.

| File | Covers |
|---|---|
| [01-actions-and-entities](references/01-actions-and-entities.md) | verb/noun rule, entity surface, one-action-one-intent and the three legitimate splits, `AppEnum`, query types, naming |
| [02-multi-surface-mapping](references/02-multi-surface-mapping.md) | design order, surface matrix, per-surface API choice, App Shortcut budget and phrase limits |
| [03-execution-modes](references/03-execution-modes.md) | `supportedModes`, `continueInForeground()`, `systemContext`, deprecations, why `OpensIntent` conflicts with dynamic |
| [04-process-and-dependencies](references/04-process-and-dependencies.md) | execution heuristics, `allowedExecutionTargets`, registration per process, `AppIntentsPackage` / `includedPackages`, provider placement, package layout |
| [05-ui-integration](references/05-ui-integration.md) | `Button(intent:)` rules, interactive-intent trap, `onAppIntentExecution` vs `@Dependency` navigation, pending-value handshake |
| [06-feedback-channels](references/06-feedback-channels.md) | dialog / snippet / notification per caller, control feedback, `IntentDialog(full:supporting:)` |
| [07-data-and-side-effects](references/07-data-and-side-effects.md) | surface reload, Service `defer`, retriable `perform()`, SwiftData + CloudKit, migration ownership, the `@Query` + `onChange` foot-gun |
| [08-platform-and-availability](references/08-platform-and-availability.md) | availability matrix, `os()` vs `canImport`, watchOS schema gaps, Liquid Glass placement, `#Predicate`, macOS/visionOS/watchOS quirks |
| [09-verification](references/09-verification.md) | the ladder, AppIntentsTesting patterns and pitfalls, what stays manual, test shapes that lie |
| [10-advanced-entity-apis](references/10-advanced-entity-apis.md) | property macros, Spotlight indexing keys, `TransientAppEntity`, `SyncableEntity`, `@UnionValue`, `Transferable`, assistant schemas |
| [11-interaction-and-scale](references/11-interaction-and-scale.md) | `requestConfirmation` / `requestChoice`, snippets, `EntityCollection`, `LongRunningIntent`, system intents, partial updates, Visual Intelligence |
| [code-templates](references/code-templates.md) | copy-and-adapt templates for every pattern above |

## Evidence discipline

App Intents behaviour changes every cycle, and the docs are incomplete in ways that are easy to paper over with reasoning. Every claim in the references carries a tag:

- **[Apple]** — stated in Apple documentation or a WWDC session (cited).
- **[measured]** — observed by running it, with date and OS. Re-check on SDK bumps.
- **[inferred]** — reasoning only. Treat as a hypothesis; verify before designing around it.

Two rules that come from real mistakes:

- **Never conclude "not supported" from a positive list.** "Siri, Spotlight and Shortcuts display snippets" does not say controls don't. Settle it by running *the same intent from a different caller* and changing nothing else. One inference like this drove a wrong design once already.
- **Change one variable at a time.** Experiments that moved process, shape and implementation together stayed inconclusive for weeks; the single-variable comparison settled it in an afternoon.

When another reviewer (performance, Liquid Glass, SwiftUI-pattern skills) suggests a change, treat it as a *candidate*. Those reviewers read guidance as coverage targets ("this could use X, so it should") and miss Apple's "where **not** to use it" and platform-availability limits. Filter every suggestion through [08](references/08-platform-and-availability.md) and [07](references/07-data-and-side-effects.md) first.
