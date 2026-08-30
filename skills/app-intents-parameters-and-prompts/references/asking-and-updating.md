# Asking the person, and partial updates

## Asking for a missing value

| API | Shape |
|---|---|
| `requestValue` | `let title = try await $title.requestValue("What should it say?")` |
| `needsValueError` | `throw $title.needsValueError("What should it say?")` — thrown, so it unwinds |

Use `requestValue` when you want to continue in the same `perform()`; throw `needsValueError` when the rest of `perform()` has nothing useful to do without the value. A non-optional `AppEnum` parameter needs neither: the system disambiguates automatically.

## `requestConfirmation`

```swift
try await requestConfirmation(dialog: IntentDialog("Delete “\(todo.title)”?"))
try todoService.delete(todoId: todo.id)
```

Throws (cancelling the intent) when declined. **Put it before any irreversible work** — `perform()` is retriable, so anything done before the prompt may be done twice.

## `requestChoice`

The multi-way version [Apple: wwdc2026-343]:

```swift
let choice = try await requestChoice(
    between: [
        IntentChoiceOption(title: "30 minutes"),
        IntentChoiceOption(title: "1 hour"),
        .cancel,
    ],
    dialog: IntentDialog("Snooze “\(todo.title)” for how long?")
)
```

- Returns the chosen `IntentChoiceOption`. It is `Equatable` but has **no stable identifier**, so keep the options and their meanings in **one** enum and match with `IntentChoiceOption(title:) == choice`. Building the option list in one place and the mapping in another is how the two drift apart.
- Including `.cancel` means selecting it throws a cancellation error.
- `style` is `.default` / `.destructive` / `.cancel`. `requestChoice(between:dialog:view:)` also exists.
- Callable from a `.background` intent: it surfaces in the Siri / Shortcuts UI.

## ⚠️ Both are Siri/Shortcuts-only

From an in-app button, widget button or control, `requestConfirmation` and `requestChoice` fail with `LNPerformActionErrorCodeUnsupportedValueType` and **nothing visible happens** [measured 2026-08-12].

Consequences:

- Keep a **non-interactive twin** for those callers, named after the behaviour (`QuickSnoozeTodoIntent`, `DeleteTodoImmediatelyIntent`), with `isDiscoverable = false`. This is one of the three legitimate reasons to split an intent (`app-intents-centric-design`).
- The UI does the asking itself: `.confirmationDialog` then `Button(intent: TheImmediateOne(...))` (`app-intents-ui-and-feedback`).
- **AppIntentsTesting cannot exercise them either** — nothing can answer. Test the twin, and cover the button path with a UI test (`app-intents-testing`).

## Undo instead of confirmation

For a destructive action that a person triggers often, a confirmation on every run is friction. `UndoableIntent` is frequently the better trade: act immediately, register an undo (`app-intents-centric-design`). `requestChoice` composes with it — offer "Archive" as an alternative before deleting, and undo as the safety net after.

## Partial updates: `IntentParameter.valueState`

An update intent must distinguish "new value" / "clear it" / "leave it alone". A plain `nil` check collapses the last two.

```swift
// $param.valueState is IntentParameter<Value>.ValueState: .set(Value) | .unset
// For an optional parameter: .set(nil) == explicit clear, .unset == not supplied
```

[Apple: wwdc2026-344 20:17]

Mirror it in the service with `enum FieldUpdate<Value> { case unchanged, set(Value) }`:

- **optional model column:** `if case .set(let v) = state { .set(v) } else { .unchanged }` — passes `.set(nil)` through as a clear.
- **required model column exposed as optional:** `if case .set(let v?) = state { .set(v) } else { .unchanged }` — `.set(nil)` means leave alone, since the column cannot be emptied.

Two things that make this work end to end:

- **The parameter must be in `parameterSummary`** ([parameter-summaries](parameter-summaries.md)), or nobody can reach the tri-state from Shortcuts and the whole mechanism is dead code.
- **Testing it needs a typed nil.** `makeIntent(x: nil)` produces `.unset`, not `.set(nil)`:

  ```swift
  let explicitNull: any IntentValueExpressing = String?.none
  _ = try await definitions.intents["UpdateTodoIntent"]
      .makeIntent(todo: entity, todoDescription: explicitNull).run()
  ```

  The symptom of getting this wrong is indistinguishable from an app-side bug, so suspect the test first.

## Collections: replace, don't diff

For an array attribute (`tags`, `urls`), make the parameter mean **the new whole value**. "Add one tag" is then expressed by the caller passing current + new.

The reason is the editor: Shortcuts edits an array as a whole, so a diff-shaped parameter ("tag to add") means the intent and the UI disagree about what the field is. Replacement keeps one mental model.

If duplicates matter, decide the comparison deliberately. `compare(_:options:)` ignoring case and diacritics is consistent with `localizedStandardContains` search — but **`localizedStandardCompare` is a sort order, not an equality test**: `"Work".localizedStandardCompare("WORK")` is `.orderedAscending`, not `.orderedSame`.
