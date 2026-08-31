---
name: app-intents-design-session
description: Work out, with the person, which App Intents and App Entities a specific app should have — and design how each one shows up. Use when someone asks what their app should expose to Siri or Shortcuts, wants to take an inventory of an existing App Intents adoption and find what is missing, wants to go from features or screens to actions, is choosing which actions deserve a widget, control or App Shortcut slot, is deciding how to name intents and what Siri should say back, or asks for help planning an adoption before any code is written. This is the facilitated session; the rules it applies live in app-intents-centric-design.
license: MIT
---

# Design session

A conversation that ends with a written intent set for **this** app, not a lecture about App Intents.

Everything here is procedure. The rules being applied belong to the sibling skills — most of all `app-intents-centric-design`, whose eleven non-negotiables and verb/noun rule this session assumes. Read that first if you have not.

## What this produces

Four artifacts, in this order. Templates and a worked example: [artifacts](references/artifacts.md).

| # | Artifact | Decided in round | Done when |
|---|---|---|---|
| 1 | **Use-case table** — one row per "*who* can *do what* to *which thing*" | 1–2 | every row has a verb, and rows whose value is "navigate here" are struck out |
| 2 | **Intent + entity set** — the types, their parameters, what is merged and what is split | 2 | no two rows differ only by which caller uses them |
| 3 | **Surface assignment** — which intent appears where, what that surface shows, and what failure looks like there | 3 | each assignment survives the four questions in `app-intents-system-surfaces` |
| 4 | **Names and copy** — type names, titles, `shortTitle`, `systemImageName`, the dialog line, phrase shapes | 4 | someone who has not read the code can tell what each action does from its name alone |

Stop at the artifact the person actually needs. A retrofit conversation often ends at 2, having found that the app already has the right intents and the wrong surfaces.

## Before the first question

Never open with "what does your app do" if the code can answer it.

```bash
python3 ../app-intents-centric-design/scripts/audit_intents.py . --gap
python3 ../app-intents-centric-design/scripts/audit_intents.py . --coverage
```

`--gap` lists the intents and entities that exist, how many App Shortcut slots are used, the action methods no intent reaches, and the other places actions hide (URL handlers, notification buses, menu commands, unwired buttons). `--coverage` lists which system surfaces the project reaches. How to read them, and what to ask about each kind of finding: [gap-analysis](references/gap-analysis.md).

Then skim, in this order: the `AppShortcutsProvider` (what the app claims are its top actions), the main list/detail screens (what people actually touch), and the service or view-model layer (what the app can already do). Come to the conversation with a draft you are willing to be wrong about — a list to react to beats a blank page, and it is faster to correct than to elicit.

For a greenfield app there is nothing to run: start at round 1 with the questions in [interview](references/interview.md).

## The session, in four rounds

One round per exchange or two. Do not run ahead — each round's output is the next round's input, and a surface chosen before the action is settled has to be redone.

| Round | Goal | You ask about | You write |
|---|---|---|---|
| **1. Actions** | find the repeated things people do | what someone does in the app several times a week, and what they came to do today | use-case sentences |
| **2. Verbs and nouns** | turn sentences into a type set | which things are referred to ("this one"), what identifies them, which variants are the same action with a different value | intent + entity set |
| **3. Surfaces** | decide where each action lives | frequency, whether the surface can show the truth, what failure should look like | surface assignment |
| **4. Names and copy** | make it legible to a stranger and to Siri | what they would call this out loud, what Siri should say back | names and copy |

Round 2 is where the design is won or lost. The two decisions that cost the most to unwind later are **what identifies an entity** (`id` must survive relaunch, reinstall and sync — `app-intents-entities-and-search`) and **whether two things are one action with a parameter or two actions** (`app-intents-centric-design`, [actions-and-intents](../app-intents-centric-design/references/actions-and-intents.md)).

## How to ask

The failure mode of this session is an interview that reads like a form. These keep it a conversation.

- **One or two questions per turn.** A numbered list of eight is a questionnaire; people answer the first three.
- **Offer options, not blanks.** "Is this closer to *toggle* or *set to a value*?" gets an answer; "how should this behave?" gets a shrug.
- **Take screens and translate them.** When someone describes a screen, say the verb back: "so the thing being done there is *snooze this todo* — is that right?" Do not correct them for talking about screens; that is how apps are usually held in mind.
- **Ask for frequency, not importance.** Everything is important. Only repetition justifies a surface.
- **Name the trade-off when you recommend.** "Two intents means Shortcuts users see both — worth it only because one asks a question and the other cannot." A recommendation without its cost gets accepted and then resented.
- **Do not use the vocabulary as a gate.** `parameterSummary`, `supportedModes`, `EntityQuery` do not belong in the questions. Ask about behaviour; translate afterwards.
- **Write it down as you go.** Show the growing table back. The artifact is the deliverable; a conversation nobody wrote down was not a design session.

## What "design" means in round 3

Round 3 is design work, not configuration. For each assignment, the session decides — and records — four things:

| Decision | Bad answer | Why it matters |
|---|---|---|
| What the surface **shows** at rest | "the todo" | a control shows one glyph and one state; a widget shows a few lines; a snippet shows a small view. What is the one thing worth that space? |
| What happens **after** the action | "it updates" | who sees the change: the same surface, a dialog, a snippet, a notification, nothing (`app-intents-ui-and-feedback`) |
| What **failure** looks like there | "an error" | a control can present neither dialog nor snippet. If failure is indistinguishable from nothing happening, the assignment is not finished |
| Which **existing** intent it reuses | "a new one" | a different caller is not a different action |

Ordering, the surface matrix and the four go/no-go questions are in `app-intents-system-surfaces` — that skill owns the *what fits where*; this one owns *asking the person and writing it down*. Snippet layout is in `app-intents-ui-and-feedback`, phrase shapes in `app-intents-localization`.

## Stop conditions

Say so out loud when one of these is hit; a session that keeps going past them produces work nobody wants.

- **The App Shortcut slots are the scarce resource, and they are not a target.** Slots left over are a healthy outcome (`app-intents-system-surfaces` for the budget rules).
- **An action nobody repeats does not get a surface.** Write it down as an intent if it is a real action, and leave it discoverable in Shortcuts only.
- **A "navigate here" row is not an action.** One `OpenIntent` per entity type covers navigation; more is menu-building.
- **When the answer needs a measurement, stop designing and measure.** "Can a control show that?" is answerable in an afternoon (`app-intents-testing`), and designing on top of a guess is how the expensive kind of rework starts.
- **Do not design the whole grid.** Every surface can show stale data and every exposed intent is one a person can build an automation on and depend on forever.

## Hand-off

The session ends with artifacts, not code. Then:

| Artifact | Implemented with |
|---|---|
| intent + entity set | `app-intents-centric-design` ([templates](../app-intents-centric-design/references/templates.md)), `app-intents-entities-and-search` |
| parameters and prompts | `app-intents-parameters-and-prompts` |
| surface assignment | `app-intents-system-surfaces`, then `app-intents-execution-and-processes` for process and registration |
| feedback per surface | `app-intents-ui-and-feedback` |
| names and copy | `app-intents-localization` |
| "did any of it land" | `app-intents-testing` |

Re-run `--gap` after implementation: the actions that were gaps should now be reached, and the ones still listed should be there on purpose.

## References

| File | Covers |
|---|---|
| [interview](references/interview.md) | the question sets — greenfield and retrofit, per-round, plus the questions that reveal entity identity and failure modes |
| [gap-analysis](references/gap-analysis.md) | reading `--gap` / `--coverage` output, the triage categories, what each finding usually means and what to ask about it |
| [artifacts](references/artifacts.md) | the four templates, with a filled example |
