# Gap analysis

Reading `audit_intents.py --gap` and `--coverage` as material for the conversation. Neither output is a defect list; both are grep-level, deliberately over-inclusive on the candidate side, and wrong in the specific ways noted below.

```bash
python3 ../app-intents-centric-design/scripts/audit_intents.py . --gap
python3 ../app-intents-centric-design/scripts/audit_intents.py . --gap --json   # full lists, no cap
python3 ../app-intents-centric-design/scripts/audit_intents.py . --coverage
```

The text output caps each list at 12 entries and says how many it dropped; `--json` has everything.

## What `--gap` prints

| Section | What it is | What it is not |
|---|---|---|
| `intent` lines | every `AppIntent` type, marked `App Shortcut` / `schema` / `not discoverable` | proof any of it works — that is `app-intents-testing` |
| `entity` lines | every `AppEntity`, with its `@Property` count | a judgement about whether those are the right properties |
| App Shortcut slots used | how much of the 10-slot budget is spent | a target to fill |
| Actions no intent reaches | action-verb methods on `*Service` / `*Store` / `*ViewModel` / `*Manager`-shaped types that no intent-declaring file calls | a list of missing intents; plumbing looks identical to a missing action from the outside |
| Other places actions hide | URL handlers, `NotificationCenter` posts, menu commands, quick actions, hand-built deep links, and `Button`s not wired to an intent | reliable — see the false positives below |

## Triage categories

Every row in the last two sections is one of these four. Deciding which is the whole point of the exercise, and it needs the person.

| Category | Looks like | What to do |
|---|---|---|
| **Real action, no intent** | a verb a person would say out loud: snooze, archive, share | add it to the use-case table; it is a round-2 candidate |
| **Plumbing** | `startActivity`, `updateWidgets`, `saveContext`, `resetCache` | leave it; it is a consequence of an action, not an action. If it fires after mutations, it belongs in the service's side-effect path (`app-intents-centric-design`) |
| **Action that already exists, reached the wrong way** | a button calling a view model directly while an intent for the same action exists | rule 1: the UI should run the intent. This is a fix, not a design decision |
| **Local UI state** | add a tag row to a form being edited, discard a draft, expand a section | not an action in the App Intents sense. Nothing to do |

The third category is the most valuable finding and the easiest to miss, because the feature *works* — it is only invisible to Siri, Shortcuts and every glance surface.

## Known false positives

Say these out loud rather than presenting the list as findings; a triage list you have to defend stops being useful.

| Signal | Why it fires wrongly |
|---|---|
| `Button` with no `intent:` | destructive buttons that confirm first and then run a non-asking twin are correct (`app-intents-parameters-and-prompts`), and only the confirm step is visible on the matched line |
| `Button` inside a form | adding a tag or link to a draft being edited is state, not an action |
| `favoriteCount`-shaped methods | an action verb followed by a noun is usually a projection. Names ending in `Count`, `Text`, `Label`, `Icon`, `Color`, `Description`, `Predicate`, `Formatter`, `Descriptor` are already excluded; other read-only verbs will still slip through |
| custom URL scheme | a scheme used for OS integration the app does not own (OAuth callbacks, MDM) is not a deep link to replace |
| action method reached by *no* file | a method called only from another service method reads as unreached; check the caller before calling it a gap |

## What `--coverage` adds

`--gap` answers "which of this app's actions can the system reach". `--coverage` answers "which parts of the system are reached at all", and lists what each missing surface would take.

Read it as a menu, never as a checklist — the coverage output says so itself. The useful pattern is the reverse of completeness:

- **Surfaces reached with nothing worth putting there.** A widget in the project and no repeated action to fill it is maintenance cost.
- **Cheap semantics not claimed.** `OpenIntent`, `DeleteIntent`, `SetValueIntent` are usually a conformance on an intent that already exists, and each unlocks a surface (`app-intents-system-surfaces`).
- **Entities with zero properties.** Invisible to Shortcuts filters, Siri and Spotlight, and the fix is small (`app-intents-entities-and-search`).

## Order of the conversation

1. Run both. Read the intent list back and ask whether it matches what people actually do (round 1).
2. Triage the gap rows *with* the person, in the four categories above. Real actions join the use-case table.
3. Only then look at `--coverage`, and only for actions that survived round 1's frequency question.
4. After implementation, re-run `--gap`. Rows that remain should be rows you decided to keep.
