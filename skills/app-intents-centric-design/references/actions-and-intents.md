# Actions and intents

Picking the smallest useful set of `AppIntent` types, and knowing when *not* to split one. For the *noun* side — entities, queries, `AppEnum` — see `app-intents-entities-and-search`.

## The verb–noun rule

Write every use case as a sentence: **"*\<who\>* can *\<verb\>* *\<noun\>*"**.

- The verb is an `AppIntent` candidate.
- The noun is an `AppEntity` candidate.
- "*who*" is rarely system-facing — usually the signed-in user, implicit.

| Use-case sentence | Intent | Entity |
|---|---|---|
| User can **add** a **todo** | `AddTodoIntent` | none needed (input is `String`) |
| User can **toggle completion** on a **todo** | `ToggleTodoCompletionIntent` | `TodoAppEntity` |
| User can **filter** todos by **category** | `ShowTodosIntent(filter:)` | `CategoryAppEntity` |

If a sentence has no clear verb, it is a screen, not an action. Drop it from the first pass.

## One action, one intent

**The same action uses the same intent no matter who calls it.** A Live Activity button and Siri both call `ToggleTodoCompletionIntent(todo:)`. If the caller only holds an id and a title, build a partial entity and pass it — the system re-resolves it from the id through `EntityQuery.entities(for:)` before `perform()` runs. [Apple: wwdc2026-345 7:37 — entity resolution happens before execution]

```swift
// Live Activity view — the activity only knows id + title, and that is enough.
let entity = TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark.circle.fill")
}
```

### The measurement behind it

The usual reason for splitting an intent per caller is fear of entity pre-resolution running somewhere hostile. Wiring an entity-parameter intent straight to a Live Activity lock-screen button [measured 2026-08-12, iOS 27 / Xcode 27 beta 5 simulator]:

| Case | `entities(for:)` ran in | `perform()` ran in | crash |
|---|---|---|---|
| app running + `LiveActivityIntent` | main app | main app | none |
| app killed (cold start) + `LiveActivityIntent` | main app | main app | none |
| app killed + plain `AppIntent` | main app | main app | none |

Note the contrast measured in the same session: during **widget timeline rendering**, `entities(for:)` runs in the *widget extension* process. "Entity resolution always happens in the app" is false in general — it is specific to Live Activity buttons. See `app-intents-execution-and-processes`.

### The only legitimate reasons to split

Split on **behaviour**, never on which process calls you.

| Pair | Why they are different actions |
|---|---|
| `SnoozeTodoIntent` / `QuickSnoozeTodoIntent` | The first asks with `requestChoice`. A Live Activity button runs in the background with no surface to answer on, so the second applies a fixed 30 minutes. |
| `DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` | The first asks with `requestConfirmation`. In-app buttons cannot present that, so the UI confirms with `.confirmationDialog` and calls the second. |
| `ToggleTodoCompletionIntent` / `SetTodoCompletionIntent` | Toggle vs absolute set. `ControlWidgetToggle` hands you the destination state via `SetValueIntent`, which a flipping toggle cannot express. |

All three splits exist because of **whether the caller can be asked a question**, not because of which process it runs in. Details of the interactive half are in `app-intents-parameters-and-prompts`.

Internal-only twins get `isDiscoverable = false` and stay out of App Shortcuts.

### Merge intents that differ only by a value

Prefer a parameter over a new type: `ShowTodosIntent(filter: TodoFilterType)` beats four `ShowXTodosIntent` types, and it protects the 10-slot App Shortcut budget (`app-intents-system-surfaces`).

The merged parameter must then appear in `parameterSummary`, or Shortcuts users can reach only the default — a merge that hides the distinction is worse than the four types it replaced (`app-intents-parameters-and-prompts`).

## Retiring an intent

A shortcut someone built keeps a reference to your intent **type**, so deleting the type breaks their automation silently. `DeprecatedAppIntent` marks the action as retired and names its `ReplacementIntent`, so the system can tell them what to use instead. [Apple: app-intent-types]

Same discipline as `AppEnum` raw values (`app-intents-entities-and-search`): the public surface is a contract with the user's automations, not just with the compiler.

## Naming

- Intents: imperative verb + object + `Intent` — `AddTodoIntent`, `ToggleFavoriteIntent`, `SnoozeTodoIntent`.
- Entities: noun + `AppEntity` — `TodoAppEntity`, `CategoryAppEntity`.
- Enums: domain noun — `TodoSortOrder`, `AppScreenTarget`.
- Non-interactive twins: name the behaviour, not the caller — `QuickSnoozeTodoIntent`, `DeleteTodoImmediatelyIntent`. Never `…FromWidgetIntent`; the caller is not the difference.

Consistent naming makes the Shortcuts gallery and Siri training data legible without extra annotation.
