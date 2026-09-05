---
name: app-intents-testing
description: Find out whether App Intents actually work, given that they fail with no error at all. Use when the build succeeds but a feature never appears in Shortcuts, Siri or Spotlight, when an action shows up but its parameters or values are missing, when you want automated tests for intents instead of checking by hand, when writing AppIntentsTesting or XCUITest cases for intents, when a test passes but the feature is visibly broken, when you need to see what the build actually told the system, or when you are trying to settle a question like "does that surface support this?" without guessing.
license: MIT
---

# Verifying App Intents

App Intents fail quietly. The build is green, the IDE is clean, and the feature simply never appears. This skill is how you find that out on purpose instead of by accident.

Assumes the rules in `app-intents-centric-design`.

## The ladder

[Apple: wwdc2026-240 24:13–25:57, "progressive validation"]

| Rung | Tool | Proves |
|---|---|---|
| **0** | the built metadata | that the system was told about it at all |
| 1 | **AppIntentsTesting** | intent execution and entity/query integration in a live app process; no Siri language routing |
| 2 | **Shortcuts app** | the shape of the intent: parameters, parameter summary, action list |
| 3 | **Spotlight** | that content is indexed and findable |
| 4 | **Siri** | natural language, entity resolution, onscreen references, cross-app — end to end |

**AppIntentsTesting does not exercise rung 4.** "Be sure to test your intents **manually** with Siri and the Shortcuts app" [Apple: wwdc2026-295 24:46]. AppIntentsTesting's public API contains no phrase / utterance / shortcut symbol at all, and it looks intents up by **type name** — the `AppShortcutsProvider` phrase path is structurally out of reach.

Below the ladder sit two static checks that cost nothing:

```bash
python3 ../app-intents-centric-design/scripts/audit_intents.py .              # architectural rules
python3 ../app-intents-centric-design/scripts/audit_intents.py . --coverage   # which surfaces exist at all
python3 scripts/inspect_appintents_metadata.py --find MyProject               # what the system will read
```

`--coverage` answers a different question from the rest of the ladder: not "does this work" but "does this exist". A declaration it reports as reached has still proved nothing about runtime behaviour.

**Before doing anything by hand, ask what could be a test instead.** Manual checks do not catch regressions; tests do. A surprising amount of what looks like it needs a device — entity id resolution, suggestions, Spotlight indexing, transient entity values, onscreen annotations, tri-state parameter clearing — is reachable from AppIntentsTesting.

## Symptom → rung

| Symptom | Start at |
|---|---|
| Ordinary action absent from the Shortcuts action list | rung 0 — check `actions`, discoverability and package aggregation |
| Preconfigured App Shortcut or its phrases absent | rung 0 — check `autoShortcuts`, then SSU assets and phrase routing |
| Action present, fields missing | rung 0 — `actionSummary.wrapper` (`app-intents-parameters-and-prompts`) |
| Shortcuts cannot filter on a value | rung 0 — the entity's property count |
| Schema conformance seems not to apply | rung 0 — `assistantDefinedSchemas`, and check for two types claiming one schema |
| Widget/Live Activity button does nothing | rung 1 — `entities(identifiers:)` |
| Parameter picker blank | rung 1 — `suggestedEntities()` |
| Content missing from search only | rung 1 — `spotlightQuery(_:)`, polled |
| Button in the app does nothing, Siri works | **UI test** — AppIntentsTesting cannot see this |
| A test is green but the feature is broken | [tests-that-lie](references/tests-that-lie.md) |

## What stays manual

After automated checks, keep manual coverage for these system experiences; this list is not a claim that all other paths are automatable:

1. **App Shortcut phrase routing** — say one phrase to Siri.
2. **How system UI actually looks** — dialog read aloud, snippet rendering, control appearance.
3. **Anything the simulator lacks** — Visual Intelligence, and the real Control Center gesture path.

Record the remaining checks by caller and destination. Passing `run()` does not verify a widget, control or Live Activity button’s actual invocation path.

## Method for settling "does surface X do Y?"

1. Build the smallest probe that isolates **one** variable.
2. Run the *same* intent from two callers, changing nothing else.
3. Record the result with date, OS and Xcode version, and label it `[measured]`.
4. If you cannot run it, label the claim `[inferred]` and do not design around it.

Two traps that have each produced a wrong design:

- **A positive list in documentation does not imply exclusion.** "Siri, Spotlight and Shortcuts display snippets" does not say controls don't.
- **Do not infer the mechanism from the effect.** "The schema-less side wins the metadata merge" was really "the last input wins"; only a run with the inputs reordered showed it. Observing *that* something happens and concluding *why* are two experiments.

And when a measurement comes back empty, check whether the thing you are reading is even written yet. Two false negatives here came from trusting a file's `mtime` (mmap writes do not update it) and from reading a derived stream before the system had generated it (minutes, not seconds). A **positive control** — run the thing that definitely should appear — only helps if it is also given time to appear.

## Scripts

| Script | Answers |
|---|---|
| `scripts/inspect_appintents_metadata.py` | what the build actually told the system: counts, schema conformances, entity properties, parameter summaries, App Shortcut phrases, per-target aggregation |
| `scripts/inspect_donation_stream.py` | whether a run was recorded as a donation. **Simulator, verification only** — it reads a private path that can vanish on any OS update. Never ship code that depends on it |
| `../app-intents-centric-design/scripts/audit_intents.py` | 24 static rules, and surface coverage |

```bash
python3 scripts/inspect_appintents_metadata.py --find MyProject
python3 scripts/inspect_appintents_metadata.py path/to/MyApp.app -v

python3 scripts/inspect_donation_stream.py --snapshot
# … perform exactly one action …
python3 scripts/inspect_donation_stream.py --diff --bundle ""
```

`inspect_appintents_metadata.py` is the only way to see several failures at all: an `AppShortcutsProvider` that registered nothing, an entity that exposes zero properties, a parameter absent from the Shortcuts editor, a schema conformance that did not land, two types claiming the same schema. None of them break the build.

## References

| File | Covers |
|---|---|
| [metadata](references/metadata.md) | rung 0 in full: what to read, what each anomaly means, doing it without the script |
| [appintents-testing](references/appintents-testing.md) | setup, the string-keyed API, every measured pitfall, what to cover, getting to a known state, platform limits |
| [tests-that-lie](references/tests-that-lie.md) | conditional assertions, fixed sleeps, localised labels, missing scheme entries, parallelisation |
| [templates](references/templates.md) | an AppIntentsTesting base class and a representative case |
