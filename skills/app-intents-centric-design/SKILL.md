---
name: app-intents-centric-design
description: Design an Apple platform app (iOS/iPadOS/macOS/watchOS/visionOS) so that everything a person can do is an App Intent and everything they act on is an App Entity, then reach Siri, Shortcuts, widgets, controls, Spotlight and Apple Intelligence from that one definition. Use when you want to make your app's features usable from Siri or the Shortcuts app, are adding App Intents to an app for the first time, are moving actions out of view models or URL handlers, want a review of an existing App Intents adoption, or are deciding what should be an intent at all. Start here when you are not sure which part of App Intents your question belongs to — this skill holds the rules that apply everywhere and points at the sibling skill that covers each specific job.
license: MIT
---

# App Intent-centric design

## What this is

In the Liquid Glass era, UI chrome dissolves into the background and **content + actions become the product surface**. App Intents stopped being "the Shortcuts layer": they are the substrate that powers Siri, widgets, controls, Live Activities, Spotlight, the Action button, Visual Intelligence and visionOS ornaments from one definition.

This skill applies **App Intent-centric design**, which fuses:

- **App Intent Driven Development** (SwiftLee) — intents as the unit of code reuse and system integration.
- **Action-Centered Design** (Vidit Bhargava) — design starts from actions, not screens.
- **Model-based UI design** — the use-case sentence "*who* can *do what* to *which thing*" maps onto `AppEntity` (noun) + `AppIntent` (verb).

Intent + Entity is the **atomic design unit**. UI and platform are later layers that compose those atoms for one surface.

## Where to go for what

This skill is the entry point and the cross-cutting rules. Each job below has its own skill; invoke it directly if you already know which one you need.

| What you are doing | Skill |
|---|---|
| Working out *with someone* which intents this app should have, taking an inventory of an existing adoption, going from screens to actions | `app-intents-design-session` |
| Deciding where an action should appear — widget, Control Center, Watch, Live Activity, Action button, camera, Focus | `app-intents-system-surfaces` |
| Choosing `supportedModes` / `allowedExecutionTargets`, registering `@Dependency`, laying out packages, platform guards | `app-intents-execution-and-processes` |
| Running intents from your own SwiftUI UI, navigation, dialogs / snippets / notifications | `app-intents-ui-and-feedback` |
| Adding parameters, parameter summaries, asking the person to confirm or choose, partial updates | `app-intents-parameters-and-prompts` |
| Modelling content as entities, Spotlight, queries, `AppEnum`, App Schema domains, scale | `app-intents-entities-and-search` |
| Proving any of it works: AppIntentsTesting, UI tests, metadata inspection | `app-intents-testing` |
| Translating intent names, descriptions, Siri responses and phrases | `app-intents-localization` |

### Symptom → skill

Failures here are almost always silent, so the symptom rarely names the cause.

| Symptom | Usually | Skill |
|---|---|---|
| Tapping a button does nothing at all, no error | interactive intent from a button, or a manual `perform()` | `app-intents-ui-and-feedback` |
| A widget or control button does nothing | dependency not registered in that process | `app-intents-execution-and-processes` |
| `Failed to retrieve dependency of type X` in the log | same | `app-intents-execution-and-processes` |
| The action never appears in the Shortcuts app | inspect `actions`, discoverability and target membership; for a preconfigured App Shortcut, inspect `autoShortcuts` and provider placement | `app-intents-execution-and-processes`, then `app-intents-testing` |
| Parameters exist in code but cannot be edited in Shortcuts | missing from `parameterSummary` | `app-intents-parameters-and-prompts` |
| Shortcuts cannot filter or read a value | the member is not a `@Property` | `app-intents-entities-and-search` |
| A parameter picker is empty | no `suggestedEntities()` | `app-intents-entities-and-search` |
| Content is missing from Spotlight or Siri only | index or schema conformance did not land | `app-intents-entities-and-search`, `app-intents-testing` |
| The app opens when it should not, or does not open when it should | `supportedModes` | `app-intents-execution-and-processes` |
| An action worked but a control or widget still shows the old value | reload fan-out | this skill, [side-effects](references/service-and-side-effects.md) |
| Nothing was said or shown after the action | wrong feedback channel for that caller | `app-intents-ui-and-feedback` |
| Everything is translated except the intent's own words | intent copy is not auto-extracted | `app-intents-localization` |
| Build is green, feature does not exist | any of the above | `app-intents-testing` |

## Start at the smallest level that is true for this project

Three of the eleven rules below exist only because of a second *process*; a one-target app owes the other eight. Find the level, apply that level's rules, and stop.

| Level | The project has | Rules that apply |
|---|---|---|
| **0** | one app target | all but 4, 6, 10 |
| **1** | + widget / control / Live Activity | + 4, 6, 10 — the three that cost real work |
| **2** | + a second platform | + availability guards (`app-intents-execution-and-processes`) |
| **3** | + Spotlight / schemas / Visual Intelligence | + entity-surface quality (`app-intents-entities-and-search`) |

A minimum viable adoption is one service, one intent, one `AppShortcutsProvider` and one `Button(intent:)` — a single file's worth, shown in [adoption-levels](references/adoption-levels.md). Retrofitting an existing app starts there too, by inventorying where actions live today (view models, URL handlers, menu commands) rather than by designing a new surface.

## Non-negotiables

Eleven rules that are cheap to follow and expensive to discover. **From** is the level at which each starts to apply; **audit** names the `audit_intents.py` rule that catches it, where one can.

| # | From | Rule | Why it bites | Detail |
|---|---|---|---|---|
| 1 | 0 | Every user-visible action is an `AppIntent`; UI triggers it with `Button(intent:)` | Logic that lives only in a view model is invisible to Siri, Shortcuts, widgets and controls forever | [actions-and-intents](references/actions-and-intents.md) |
| 2 | 0 | One action = one intent, regardless of caller | Per-caller clones drift; the entity re-resolves from its `id` before `perform()` anyway | [actions-and-intents](references/actions-and-intents.md) |
| 3 | 0 | Intents stay thin; a `@MainActor` service owns persistence + side effects | Keeps `perform()` retriable and the logic testable without `AppDependencyManager` | [side-effects](references/service-and-side-effects.md) · audit `swiftdata-in-intent` |
| 4 | 1 | Register `@Dependency` in **every** process that may execute the intent | Process choice is a heuristic, not a rule; an unregistered dependency traps at runtime with a green build | `app-intents-execution-and-processes` |
| 5 | 0 | `AppShortcutsProvider` lives in the app target, never in a package | `autoShortcuts` is the one key not aggregated from packages: shortcuts silently never register | `app-intents-execution-and-processes` · audit `shortcuts-provider-placement` |
| 6 | 1 | Declare `AppIntentsPackage` in the package **and** in every consuming target with `includedPackages` | Apple's documented indexing/validation step | `app-intents-execution-and-processes` · audit `app-intents-package-registration` |
| 7 | 0 | Never call `intent.perform()` yourself | `@Dependency` is only injected on system dispatch; a manual call is zero-initialised and crashes | `app-intents-ui-and-feedback` · audit `manual-perform` |
| 8 | 0 | Keep runtime prompts out of in-app/widget `Button(intent:)` paths | From an in-app or widget button they fail with no error UI — *nothing happens* | `app-intents-parameters-and-prompts` · audit `interactive-intent-from-button` |
| 9 | 0 | Pick the feedback channel from the **caller**, not from the intent | Controls present neither dialog nor snippet; UI buttons present neither | `app-intents-ui-and-feedback` · audit `control-feedback` |
| 10 | 1 | A data mutation reloads timelines **and** controls | They are separate APIs; the system only auto-reloads the one control that ran the intent | [side-effects](references/service-and-side-effects.md) · audit `widget-reload-coverage` |
| 11 | 0 | Donate from the app's UI, never from `perform()` | Apple's rule is per-caller and `perform()` cannot see the caller | [side-effects](references/service-and-side-effects.md) · audit `donate-inside-perform` |

Rules 1, 2 and 4 are the ones no linter can check — they are design decisions, and they are also the three whose violation is most expensive to unwind.

## Workflow

1. **Find the actions, not the screens.** Write use cases as "*who* can *do what* to *which thing*". Verbs are intent candidates, nouns are entity candidates. Drop anything whose only value is "navigate here". ([actions-and-intents](references/actions-and-intents.md); to do this *with* the person — question sets, gap triage, artifact templates — use `app-intents-design-session`)
2. **Design from the smallest surface outward** — complication → widget → control → Live Activity → Shortcuts/Siri → Spotlight → visionOS → main app UI. Constraint is the clarifier; the main app is the most permissive surface and therefore the least informative one to start from. (`app-intents-system-surfaces`)
3. **Define the minimal entity surface.** `id` + `displayRepresentation` + the few `@Property` members the system actually reads. (`app-intents-entities-and-search`)
4. **Put the logic in a service, inject it with `@Dependency`.** Register it synchronously at each process entry point. ([side-effects](references/service-and-side-effects.md), `app-intents-execution-and-processes`)
5. **Choose mode and process per intent** — `supportedModes` decides foregrounding, `allowedExecutionTargets` decides the process. They are different questions. (`app-intents-execution-and-processes`)
6. **Claim the semantics the system already knows** — `OpenIntent`, `DeleteIntent`, `SetValueIntent`, media/camera conformances, a schema domain if one genuinely matches. Reach is usually a new conformance on an intent you already have, not a new intent. (`app-intents-system-surfaces`, `app-intents-entities-and-search`)
7. **Compose the app UI last**, out of the now-stable intent set. (`app-intents-ui-and-feedback`)
8. **Climb the verification ladder** before believing any of it works. (`app-intents-testing`)

## Workarounds that are already known to be wrong

Each of these looks like the obvious fix at the moment it occurs to you. Each one has cost real debugging time.

| Tempting | What actually happens | Do instead |
|---|---|---|
| `try? await MyIntent(...).perform()` to reuse logic | `@Dependency` is zero-initialised → trap | both callers call the service (`app-intents-ui-and-feedback`) |
| `…FromWidgetIntent` twin taking a `String` id | two definitions drift; unnecessary since iOS 27 | one intent, build a partial entity ([actions-and-intents](references/actions-and-intents.md)) |
| `Router.shared` / `Dependencies.shared` singleton | silently a different instance per process | `@Dependency` registered per entry point (`app-intents-execution-and-processes`) |
| `try? provider() ?? 0` in a control value provider | renders a confident lie ("all done") | throw; the system knows how to show that (`app-intents-ui-and-feedback`) |
| `#if canImport(X)` as an availability check | simulator green, device build fails | pair with `os()` (`app-intents-execution-and-processes`) |
| `if el.waitForExistence(...) { XCTAssert… }` | green when the element never appears | assert first, then act (`app-intents-testing`) |
| `.onChange(of: queryResults)` caching a projection | array of classes compares by identity → stale | map in `body` ([side-effects](references/service-and-side-effects.md)) |
| adopting an adjacent schema domain "for the plumbing" | Siri becomes confidently wrong | no domain + `.system.searchInApp` (`app-intents-entities-and-search`) |
| a custom URL scheme to open a detail screen | not understood by Spotlight, Siri or Shortcuts | `OpenIntent` (`app-intents-system-surfaces`) |
| a widget `Button(intent:)` whose only job is opening the app | Apple says use a link | `Link` / `widgetURL(_:)` (`app-intents-system-surfaces`) |
| `donate()` at the end of `perform()` | also donates the Siri/Shortcuts runs, which Apple says not to donate | donate from the UI, or not at all ([side-effects](references/service-and-side-effects.md)) |
| adding a `@Parameter` and assuming Shortcuts can set it | absent from `parameterSummary` = absent from the editor | list every settable parameter (`app-intents-parameters-and-prompts`) |
| `LocalizedStringResource(stringLiteral: entity.title)` | the runtime value becomes a localization *key* | `"\(entity.title)"` (`app-intents-entities-and-search`) |
| a `#if os(watchOS)` twin of a schema type under the **same** type name | the watch slice silently overwrites the iOS entity in the shipping metadata | a distinct type name (`app-intents-entities-and-search`) |
| hand-writing `__appSchemaEntity` to get a schema where the SDK has none | non-public symbol; breaks green on any rename | do not declare the conformance there (`app-intents-entities-and-search`) |
| a hand-written `attributeSet` key that a `@Property(indexingKey:)` also maps | undocumented precedence; semantic text gets replaced | disjoint key sets (`app-intents-entities-and-search`) |
| `lowercased().contains()` in `entities(matching:)` | locale-independent: kana, diacritics and dotless I stop matching | `localizedStandardContains(_:)` (`app-intents-entities-and-search`) |
| `.appEntityIdentifier(forSelectionType:)` on a `ScrollView`+`ForEach` | silent no-op; the app looks identical | it is `List`-only (`app-intents-system-surfaces`) |
| putting intent copy in a package String Catalog | extracted but never read at runtime | manual keys in each linking target (`app-intents-localization`) |

## Finding the right answer instead of inventing one

App Intents changes every cycle and the documentation is incomplete in ways that reward guessing and then punish it. Order of resort:

1. **Apple's own documentation search, scoped to `AppIntents`**, by the noun you want ("focus", "undo", "camera", "ownership", "schema domains"). In Xcode that is the `DocumentationSearch` MCP tool — fast, local, and newer than any model's training data; otherwise developer.apple.com. Most "App Intents can't do that" conclusions die here.
2. **The framework's own catalogue pages** — `app-intent-types`, `app-entities`, `app-schema-domains` — when you need to know what *exists* rather than how one symbol works. New reach is usually a conformance on an intent you already have.
3. **Apple's sample code**, when the question is "what does a correct adoption look like end to end". Prose documents one symbol at a time; the samples are the only place the *composition* is written down. Find them from the sample's documentation page; the downloadable archive URL lives in that page's JSON (`https://developer.apple.com/tutorials/data/<path>.json` → `sampleCodeDownload.action.identifier`, fetched from `https://docs-assets.developer.apple.com/published/<id>`). Keep them **outside** the project directory: an Xcode synchronized folder will pull a sample's `.xcodeproj` into your tracked `project.pbxproj`, which `.gitignore` cannot prevent.
4. **The WWDC transcripts** for behaviour that only a session states (execution process, reload guarantees, limits). Cite session + timestamp.
5. **The build**, per destination, when the question is availability. `XcodeRefreshCodeIssuesInFile` sees one context only.
6. **The built metadata** (`inspect_appintents_metadata.py` in `app-intents-testing`), when the question is "did the system actually get it".
7. **A single-variable probe**, when nothing above answers it — then label the result `[measured]` with date and OS.

If you cannot get past step 7, the claim is `[inferred]`: write it down as a hypothesis and design around not knowing.

Samples are evidence, not authority. Apple's own ship deprecated API (`static let openAppWhenRun = true` where `supportedModes` is now the documented spelling) and patterns these skills argue against. Read them for composition; check each individual call against its own documentation page.

For a beta SDK or a conflict between a sample and its declaration, use [source verification](references/source-verification.md). It covers local Xcode documentation, availability checks and the limits of each evidence type.

## Scripts

Four scripts across these skills. All are standard-library Python and work in any project, whether or not the skills are installed.

| Script | Lives in | Answers |
|---|---|---|
| `audit_intents.py` | this skill (`scripts/`) | 24 static rules, which system surfaces the project reaches, and which of the app's actions no intent reaches |
| `inspect_appintents_metadata.py` | `app-intents-testing` | what the build actually told the system |
| `inspect_donation_stream.py` | `app-intents-testing` | did a run get donated (simulator only, verification only) |
| `check_intent_copy_localization.py` | `app-intents-localization` | which intent copy is missing from the String Catalogs |

```bash
# 24 static rules: provider placement, package registration, interactive-intent misuse,
# manual perform(), reload coverage, control feedback, donation placement, Spotlight key
# collisions, localization keys, locale-sensitive matching, platform guards, test shape…
python3 scripts/audit_intents.py . --fail-on error
python3 scripts/audit_intents.py . --list-rules      # rule catalogue
python3 scripts/audit_intents.py . --json            # machine-readable

# Which system surfaces this project reaches today, and what each missing one needs.
python3 scripts/audit_intents.py . --coverage

# What exists (intents / entities / App Shortcut slots) vs the actions in the app
# that no intent reaches. Material for a design session, not a defect list.
python3 scripts/audit_intents.py . --gap
```

## Evidence discipline

App Intents behaviour changes every cycle, and the docs are incomplete in ways that are easy to paper over with reasoning. Use the following tags for technical claims, with a source or measurement scope:

- **[Apple]** — stated in Apple documentation or a WWDC session (cited).
- **[Apple SDK]** — a public declaration or availability attribute in a named Xcode build. This proves API shape, not runtime behaviour.
- **[measured]** — observed by running it, with date, OS, destination and Xcode build. Re-check on SDK bumps.
- **[inferred]** — reasoning only. Treat as a hypothesis; verify before designing around it.

What you will *not* find here is how each rule was arrived at — which hypothesis failed, what the previous version of a rule said, which bug took a month to spot. That is deliberate: these skills state the current rule and what backs it, so they stay readable in any project. The label is the handle you need — a `[measured 2026-08-12, iOS 27]` line tells you exactly what to re-run when the SDK moves, without the story attached.

Three method rules, all learned the expensive way:

- **Never conclude "not supported" from a positive list.** "Siri, Spotlight and Shortcuts display snippets" does not say controls don't. Settle it by running *the same intent from a different caller* and changing nothing else.
- **Change one variable at a time.** An experiment that moves process, shape and implementation together cannot settle anything, however long it runs. Two wrong conclusions here came from observing an effect and inferring its mechanism one step too far — "the schema-less side wins" was really "the last input wins", and only a reordered single-variable run showed it.
- **Never record an inference as a measurement.** If it was not run, the label is `[inferred]` — a mislabelled line is worse than a missing one, because the next reader stops checking.

Also treat "platform-limited" as a statement about the SDK at the time it was written. On an SDK bump, delete the guard and let the build answer — that is how Visual Intelligence on macOS turned out to be possible after all.

When another reviewer (performance, Liquid Glass, SwiftUI-pattern skills) suggests a change, treat it as a *candidate*. Those reviewers read guidance as coverage targets ("this could use X, so it should") and miss Apple's "where **not** to use it" and platform-availability limits. Filter every suggestion through `app-intents-execution-and-processes` and [side-effects](references/service-and-side-effects.md) first.

## References

| File | Covers |
|---|---|
| [source-verification](references/source-verification.md) | pin the SDK, reconcile bundled examples with public declarations, distinguish declaration checks from runtime evidence |
| [adoption-levels](references/adoption-levels.md) | minimum viable adoption in one file, what each level adds, retrofitting an existing app, exit criteria |
| [actions-and-intents](references/actions-and-intents.md) | verb/noun rule, one-action-one-intent and the three legitimate splits, merging by parameter, naming |
| [service-and-side-effects](references/service-and-side-effects.md) | the service layer, surface reload fan-out, retriable `perform()`, idempotency, donations, SwiftData + CloudKit, the `@Query` + `onChange` foot-gun |
| [templates](references/templates.md) | service, reload helper, background intent, one-intent-all-callers |
