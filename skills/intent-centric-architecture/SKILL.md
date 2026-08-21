---
name: intent-centric-architecture
description: Design Apple platform apps (iOS/iPadOS/macOS/watchOS/visionOS) where every user action is an `AppIntent` and every domain object is an `AppEntity`, then route that one definition through Shortcuts, Siri, widgets, controls, Live Activities, Spotlight, Focus filters and Visual Intelligence. Use when adopting App Intents in any app (a single-target one included), retrofitting actions that live in view models or URL handlers, deciding the UI-vs-Intent boundary, choosing `supportedModes` / `allowedExecutionTargets`, registering `@Dependency` per process, placing `AppIntentsPackage` / `AppShortcutsProvider`, picking a per-caller feedback channel, choosing which system surface an action deserves, adopting an `AppSchema` domain or the entity APIs, or validating with AppIntentsTesting.
---

# Intent-centric architecture

## What this is

In the Liquid Glass era, UI chrome dissolves into the background and **content + actions become the product surface**. App Intents stopped being "the Shortcuts layer": they are the substrate that powers Siri, widgets, controls, Live Activities, Spotlight, the Action button, Visual Intelligence and visionOS ornaments from one definition.

This skill applies **App Intent-centric design**, which fuses:

- **App Intent Driven Development** (SwiftLee) — intents as the unit of code reuse and system integration.
- **Action-Centered Design** (Vidit Bhargava) — design starts from actions, not screens.
- **Model-based UI design** — the use-case sentence "*who* can *do what* to *which thing*" maps onto `AppEntity` (noun) + `AppIntent` (verb).

Intent + Entity is the **atomic design unit**. UI and platform are later layers that compose those atoms for one surface.

## Start at the smallest level that is true for this project

Most of the hard rules below exist because of a second *process* or a second *platform*. A one-target app owes four of them. Find the level, apply that level's rules, and stop.

| Level | The project has | Rules that apply | Detail |
|---|---|---|---|
| **0** | one app target | all but 4, 6, 10 | [00](references/00-adoption-levels.md) |
| **1** | + widget / control / Live Activity | + 4, 6, 10 — the three that cost real work | [00](references/00-adoption-levels.md), [04](references/04-process-and-dependencies.md) |
| **2** | + a second platform | + availability guards | [08](references/08-platform-and-availability.md) |
| **3** | + Spotlight / schemas / Visual Intelligence | + entity-surface quality | [10](references/10-advanced-entity-apis.md), [13](references/13-schema-domains.md) |

A minimum viable adoption is one service, one intent, one `AppShortcutsProvider` and one `Button(intent:)` — a single file's worth, shown in [00](references/00-adoption-levels.md). Retrofitting an existing app starts there too, by inventorying where actions live today (view models, URL handlers, menu commands) rather than by designing a new surface.

## Non-negotiables

Ten rules that are cheap to follow and expensive to discover. **From** is the level at which each starts to apply; **audit** names the `audit_intents.py` rule that catches it, where one can.

| # | From | Rule | Why it bites | Detail |
|---|---|---|---|---|
| 1 | 0 | Every user-visible action is an `AppIntent`; UI triggers it with `Button(intent:)` | Logic that lives only in a view model is invisible to Siri, Shortcuts, widgets and controls forever | [01](references/01-actions-and-entities.md) |
| 2 | 0 | One action = one intent, regardless of caller | Per-caller clones drift; the entity re-resolves from its `id` before `perform()` anyway | [01](references/01-actions-and-entities.md) |
| 3 | 0 | Intents stay thin; a `@MainActor` service owns persistence + side effects | Keeps `perform()` retriable and the logic testable without `AppDependencyManager` | [07](references/07-data-and-side-effects.md) · audit `swiftdata-in-intent` |
| 4 | 1 | Register `@Dependency` in **every** process that may execute the intent | Process choice is a heuristic, not a rule; an unregistered dependency traps at runtime with a green build | [04](references/04-process-and-dependencies.md) |
| 5 | 0 | `AppShortcutsProvider` lives in the app target, never in a package | `autoShortcuts` is the one key not aggregated from packages: shortcuts silently never register | [04](references/04-process-and-dependencies.md) · audit `shortcuts-provider-placement` |
| 6 | 1 | Declare `AppIntentsPackage` in the package **and** in every consuming target with `includedPackages` | Apple's documented indexing/validation step | [04](references/04-process-and-dependencies.md) · audit `app-intents-package-registration` |
| 7 | 0 | Never call `intent.perform()` yourself | `@Dependency` is only injected on system dispatch; a manual call is zero-initialised and crashes | [05](references/05-ui-integration.md) · audit `manual-perform` |
| 8 | 0 | Interactive intents (`requestConfirmation` / `requestChoice`) are Siri/Shortcuts-only | From an in-app or widget button they fail with no error UI — *nothing happens* | [05](references/05-ui-integration.md) · audit `interactive-intent-from-button` |
| 9 | 0 | Pick the feedback channel from the **caller**, not from the intent | Controls present neither dialog nor snippet; UI buttons present neither | [06](references/06-feedback-channels.md) · audit `control-feedback` |
| 10 | 1 | A data mutation reloads timelines **and** controls | They are separate APIs; the system only auto-reloads the one control that ran the intent | [07](references/07-data-and-side-effects.md) · audit `widget-reload-coverage` |

Rules 1, 2 and 4 are the ones no linter can check — they are design decisions, and they are also the three whose violation is most expensive to unwind.

## Workflow

1. **Find the actions, not the screens.** Write use cases as "*who* can *do what* to *which thing*". Verbs are intent candidates, nouns are entity candidates. Drop anything whose only value is "navigate here".
2. **Design from the smallest surface outward** — complication → widget → control → Live Activity → Shortcuts/Siri → Spotlight → visionOS → main app UI. Constraint is the clarifier; the main app is the most permissive surface and therefore the least informative one to start from. ([02](references/02-multi-surface-mapping.md))
3. **Define the minimal entity surface.** `id` + `displayRepresentation` + the few `@Property` members the system actually reads. Prefer `AppEnum` for closed sets, and check whether a system entity shape (`UniqueAppEntity`, `FileEntity`, `TransientAppEntity`) already fits. ([01](references/01-actions-and-entities.md), [12](references/12-surface-catalog.md))
4. **Put the logic in a service, inject it with `@Dependency`.** Register it synchronously at each process entry point. ([04](references/04-process-and-dependencies.md))
5. **Choose mode and process per intent** — `supportedModes` decides foregrounding, `allowedExecutionTargets` decides the process. They are different questions. ([03](references/03-execution-modes.md), [04](references/04-process-and-dependencies.md))
6. **Claim the semantics the system already knows** — `OpenIntent`, `DeleteIntent`, `SetValueIntent`, media/camera conformances, a schema domain if one genuinely matches. Reach is usually a new conformance on an intent you already have, not a new intent. ([12](references/12-surface-catalog.md), [13](references/13-schema-domains.md))
7. **Compose the app UI last**, out of the now-stable intent set. ([05](references/05-ui-integration.md))
8. **Climb the verification ladder** before believing any of it works. ([09](references/09-verification.md))

## Fast decisions

**Which API on which surface**

| Goal | Use | Not |
|---|---|---|
| Widget/Live Activity element that only opens the app | `Link(destination:)` / `widgetURL(_:)` | `Button(intent:)` — Apple: an interaction "should do more than open the app" |
| Widget element that acts | `Button(intent:)` | manual `perform()` |
| Control, fire-and-forget | `ControlWidgetButton(action:)` | a toggle over a moving target |
| Control, two states of a **fixed** target | `ControlWidgetToggle(isOn:action:)` + `SetValueIntent` + `AppIntentControlConfiguration` | a flipping toggle intent — the system supplies the destination state |
| Control that shows a value | `ControlValueProvider` (throw on failure) | fetching inside `body`, `try?` to a fake zero |
| Open an entity from anywhere | `OpenIntent` | a custom URL scheme |
| Retire an action people built shortcuts on | `DeprecatedAppIntent` with a `ReplacementIntent` | deleting the type |

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

## Workarounds that are already known to be wrong

Each of these looks like the obvious fix at the moment it occurs to you. Each one has cost real debugging time here.

| Tempting | What actually happens | Do instead |
|---|---|---|
| `try? await MyIntent(...).perform()` to reuse logic | `@Dependency` is zero-initialised → trap | both callers call the service ([05](references/05-ui-integration.md)) |
| `…FromWidgetIntent` twin taking a `String` id | two definitions drift; unnecessary since iOS 27 | one intent, build a partial entity ([01](references/01-actions-and-entities.md)) |
| `Router.shared` / `Dependencies.shared` singleton | silently a different instance per process | `@Dependency` registered per entry point ([04](references/04-process-and-dependencies.md)) |
| `try? provider() ?? 0` in a control value provider | renders a confident lie ("all done") | throw; the system knows how to show that ([06](references/06-feedback-channels.md)) |
| `#if canImport(X)` as an availability check | simulator green, device build fails | pair with `os()` ([08](references/08-platform-and-availability.md)) |
| `if el.waitForExistence(...) { XCTAssert… }` | green when the element never appears | assert first, then act ([09](references/09-verification.md)) |
| `.onChange(of: queryResults)` caching a projection | array of classes compares by identity → stale | map in `body` ([07](references/07-data-and-side-effects.md)) |
| adopting an adjacent schema domain "for the plumbing" | Siri becomes confidently wrong | no domain + `.system.searchInApp` ([13](references/13-schema-domains.md)) |
| a custom URL scheme to open a detail screen | not understood by Spotlight, Siri or Shortcuts | `OpenIntent` ([11](references/11-interaction-and-scale.md)) |
| a widget `Button(intent:)` whose only job is opening the app | Apple says use a link | `Link` / `widgetURL(_:)` ([02](references/02-multi-surface-mapping.md)) |

## Finding the right answer instead of inventing one

App Intents changes every cycle and the documentation is incomplete in ways that reward guessing and then punish it. Order of resort:

1. **Apple's own documentation search, scoped to `AppIntents`**, by the noun you want ("focus", "undo", "camera", "ownership", "schema domains"). In Xcode that is the `DocumentationSearch` MCP tool — fast, local, and newer than any model's training data; otherwise developer.apple.com. Most "App Intents can't do that" conclusions die here.
2. **The framework's own catalogue pages** — `app-intent-types`, `app-entities`, `app-schema-domains` — when you need to know what *exists* rather than how one symbol works. New reach is usually a conformance on an intent you already have.
3. **The WWDC transcripts** for behaviour that only a session states (execution process, reload guarantees, limits). Cite session + timestamp.
4. **The build**, per destination, when the question is availability. `XcodeRefreshCodeIssuesInFile` sees one context only.
5. **`inspect_appintents_metadata.py`**, when the question is "did the system actually get it".
6. **A single-variable probe**, when nothing above answers it — then label the result `[measured]` with date and OS.

If you cannot get past step 6, the claim is `[inferred]`: write it down as a hypothesis and design around not knowing.

## Scripts

Two scripts, three questions. `audit_intents.py` needs no build; `inspect_appintents_metadata.py` reads a built bundle. Both are standard-library Python and work in any project, whether or not this skill is installed.

```bash
# 20 static rules: provider placement, package registration, interactive-intent misuse,
# manual perform(), reload coverage, control feedback, platform guards, test shape…
python3 scripts/audit_intents.py . --fail-on error
python3 scripts/audit_intents.py . --list-rules      # rule catalogue
python3 scripts/audit_intents.py . --json            # machine-readable

# Which system surfaces this project reaches today, and what each missing one needs.
python3 scripts/audit_intents.py . --coverage

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
| [00-adoption-levels](references/00-adoption-levels.md) | minimum viable adoption, what each level adds, retrofitting an existing app, exit criteria |
| [01-actions-and-entities](references/01-actions-and-entities.md) | verb/noun rule, entity surface, one-action-one-intent and the three legitimate splits, `AppEnum`, query types, naming |
| [02-multi-surface-mapping](references/02-multi-surface-mapping.md) | design order, surface matrix, per-surface API choice, App Shortcut budget and phrase limits |
| [03-execution-modes](references/03-execution-modes.md) | `supportedModes`, `continueInForeground()`, `systemContext`, deprecations, why `OpensIntent` conflicts with dynamic |
| [04-process-and-dependencies](references/04-process-and-dependencies.md) | execution heuristics, `allowedExecutionTargets`, registration per process, `AppIntentsPackage` / `includedPackages`, provider placement, package layout |
| [05-ui-integration](references/05-ui-integration.md) | `Button(intent:)` rules, interactive-intent trap, `onAppIntentExecution` vs `@Dependency` navigation, pending-value handshake |
| [06-feedback-channels](references/06-feedback-channels.md) | dialog / snippet / notification per caller, control feedback, `IntentDialog(full:supporting:)` |
| [07-data-and-side-effects](references/07-data-and-side-effects.md) | surface reload, service `defer`, retriable `perform()`, SwiftData + CloudKit, migration ownership, the `@Query` + `onChange` foot-gun |
| [08-platform-and-availability](references/08-platform-and-availability.md) | availability matrix, `os()` vs `canImport`, watchOS schema gaps, Liquid Glass placement, `#Predicate`, macOS/visionOS/watchOS quirks |
| [09-verification](references/09-verification.md) | the ladder, AppIntentsTesting patterns and pitfalls, what stays manual, test shapes that lie |
| [10-advanced-entity-apis](references/10-advanced-entity-apis.md) | property macros, Spotlight indexing keys, `TransientAppEntity`, `SyncableEntity`, `@UnionValue`, `Transferable`, schema adoption notes |
| [11-interaction-and-scale](references/11-interaction-and-scale.md) | `requestConfirmation` / `requestChoice`, snippets, `EntityCollection`, `LongRunningIntent`, system intents, undo, partial updates, Visual Intelligence |
| [12-surface-catalog](references/12-surface-catalog.md) | every surface an intent can reach, the conformance each needs, choosing by app kind, questions to pass before adding one |
| [13-schema-domains](references/13-schema-domains.md) | `AppSchema` tiers, all-or-nothing domains, adoption procedure, what the macro generates, what to do when no domain fits |
| [code-templates](references/code-templates.md) | copy-and-adapt templates for every pattern above |

## Evidence discipline

App Intents behaviour changes every cycle, and the docs are incomplete in ways that are easy to paper over with reasoning. Every claim in the references carries a tag:

- **[Apple]** — stated in Apple documentation or a WWDC session (cited).
- **[measured]** — observed by running it, with date and OS. Re-check on SDK bumps.
- **[inferred]** — reasoning only. Treat as a hypothesis; verify before designing around it.

What you will *not* find here is how each rule was arrived at — which hypothesis failed, what the previous version of a rule said, which bug took a month to spot. That is deliberate: this skill states the current rule and what backs it, so it stays readable in any project. The label is the handle you need — a `[measured 2026-08-12, iOS 27]` line tells you exactly what to re-run when the SDK moves, without the story attached.

Two method rules, both learned the expensive way:

- **Never conclude "not supported" from a positive list.** "Siri, Spotlight and Shortcuts display snippets" does not say controls don't. Settle it by running *the same intent from a different caller* and changing nothing else ([06](references/06-feedback-channels.md)).
- **Change one variable at a time.** An experiment that moves process, shape and implementation together cannot settle anything, however long it runs.
- **Never record an inference as a measurement.** If it was not run, the label is `[inferred]` — a mislabelled line is worse than a missing one, because the next reader stops checking.

Also treat "platform-limited" as a statement about the SDK at the time it was written. On an SDK bump, delete the guard and let the build answer — that is how Visual Intelligence on macOS turned out to be possible after all.

When another reviewer (performance, Liquid Glass, SwiftUI-pattern skills) suggests a change, treat it as a *candidate*. Those reviewers read guidance as coverage targets ("this could use X, so it should") and miss Apple's "where **not** to use it" and platform-availability limits. Filter every suggestion through [08](references/08-platform-and-availability.md) and [07](references/07-data-and-side-effects.md) first.
