# Artifacts

Four tables. Copy them, fill them during the session, and leave them in the repo (a `docs/` file, an issue, or the PR description) — the point is that the next person can see *why* the intent set looks like this without re-running the conversation.

The worked example is [IntentTodo](https://github.com/touyou/IntentTodo), filled in as the session would have produced it.

## 1. Use-case table

One row per sentence. Keep the struck-out rows: knowing what was rejected is most of the value later.

```markdown
| # | Who | Verb | Noun | How often | Notes |
|---|-----|------|------|-----------|-------|
| 1 | user | add | todo | several times a day | usually one line of text, no details |
| 2 | user | complete | todo | many times a day | the most repeated act in the app |
| 3 | user | snooze | todo | daily | "not today" — needs a duration |
| 4 | user | ~~see~~ | ~~the settings screen~~ | — | no verb: this is a screen |
```

Rules being applied: verb → intent candidate, noun → entity candidate, no verb → not an action ([actions-and-intents](../../app-intents-centric-design/references/actions-and-intents.md)).

## 2. Intent + entity set

```markdown
| Intent | Parameters | Entity | Asks anything? | Merged from / split from | Semantics claimed |
|--------|-----------|--------|----------------|--------------------------|-------------------|
| AddTodoIntent | title, plus optional details | — | no | — | — |
| ToggleTodoCompletionIntent | todo | TodoAppEntity | no | — | — |
| SetTodoCompletionIntent | todo, isCompleted | TodoAppEntity | no | split: Control Center toggle needs an absolute set | SetValueIntent |
| ShowTodosIntent | filter | — | no | merged from show-work / show-home / show-starred | — |
| SnoozeTodoIntent | todo | TodoAppEntity | requestChoice (duration) | — | — |
| QuickSnoozeTodoIntent | todo | TodoAppEntity | no — fixed 30 min | split: Live Activity buttons cannot be asked | — |
| DeleteTodoIntent | todos (array) | TodoAppEntity | requestConfirmation | — | DeleteIntent |
| OpenTodoIntent | todo | TodoAppEntity | no | — | OpenIntent |

| Entity | id | Stable across reinstall + sync? | Properties the system reads | Deleted while referenced |
|--------|----|--------------------------------|------------------------------|--------------------------|
| TodoAppEntity | UUID from the store | yes | title, due date, completed, category, … | query returns nothing; intent reports it |
| CategoryAppEntity | UUID | yes | name | same |
```

Every split needs a reason in the "split from" column, and the only legitimate reasons are behavioural — above all *whether the caller can be asked a question*. "A widget calls it" is not one.

## 3. Surface assignment

One row per (intent, surface). The last three columns are the design work; a row with blanks there is not finished.

```markdown
| Intent | Surface | Shows at rest | After it runs | If it fails | Reuses |
|--------|---------|---------------|---------------|-------------|--------|
| ToggleTodoCompletionIntent | widget (small) | next 2 todos, one line each | row redraws | timeline shows a stale-safe empty state | existing intent |
| ToggleUrgentTodoIntent | control | one glyph + done/not-done for the single most urgent todo | control redraws | notification — a control can show neither dialog nor snippet | existing intent |
| QuickSnoozeTodoIntent | Live Activity | title + remaining time | activity updates | activity keeps the old state; no dialog available | split twin |
| ShowTodosIntent | App Shortcut | — | opens the filtered list | Siri says the filter matched nothing | existing intent |
| AddTodoIntent | App Shortcut | — | dialog: "Added <title>." | Siri reads the error | existing intent |
```

App Shortcut slots: **8 of 10 used** — 2 deliberately left. The budget rules and the surface matrix are in `app-intents-system-surfaces`; feedback channels in `app-intents-ui-and-feedback`.

## 4. Names and copy

```markdown
| Intent | Type name | Title | shortTitle | systemImage | Dialog on success | Phrase shapes |
|--------|-----------|-------|------------|-------------|-------------------|---------------|
| add | AddTodoIntent | Add Todo | Add Todo | plus.circle | "Added <title>." | "Add a todo in <app>", "New todo in <app>" |
| complete | ToggleTodoCompletionIntent | Toggle Completion | Complete | checkmark.circle | "Completed <title>." | "Complete <todo> in <app>" |
| snooze | SnoozeTodoIntent | Snooze Todo | Snooze | clock.arrow.circlepath | "Snoozed until <time>." | "Snooze <todo> in <app>" |
```

Collected here, shaped elsewhere: naming convention in [actions-and-intents](../../app-intents-centric-design/references/actions-and-intents.md), phrase requirements and variation rules in `app-intents-localization`, snippet layout in `app-intents-ui-and-feedback`.

Two things to check before calling this done:

- **The type name says the behaviour, not the caller.** `QuickSnoozeTodoIntent`, never `SnoozeFromWidgetIntent`.
- **The dialog says what changed, not that it succeeded.** "Completed *Buy milk*." beats "Done."

## Where to put the filled tables

Wherever the project keeps decisions — but *with the reasons*. The columns that earn their keep six months later are "how often", "split from" and "if it fails": they are the ones that get re-litigated, and the ones no linter can reconstruct.
