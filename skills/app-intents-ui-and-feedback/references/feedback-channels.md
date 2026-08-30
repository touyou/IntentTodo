# Feedback channels

The same intent tells the user what happened in different ways depending on **who called it**. Getting this wrong produces actions that feel broken while working perfectly.

## The matrix

| Caller | `.result(dialog:)` | `snippetIntent:` | local notification |
|---|---|---|---|
| Siri | spoken ✅ | shown ✅ | shown ✅ |
| Spotlight / Shortcuts | shown in result ✅ | shown ✅ | shown ✅ |
| App UI `Button(intent:)` | — | — | shown ✅ |
| Widget `Button(intent:)` | — | — | shown ✅ |
| **Control Center (Button or Toggle)** | **—** [measured 2026-04-14] | **—** [measured 2026-08-12] | shown ✅ |
| Live Activity button | — | — | shown ✅ |

## How the control row was settled — and why the method matters

Apple's positive lists say snippets appear in "Siri, Spotlight, and the Shortcuts app" [Apple: Visual presentation docs; wwdc2025-281 0:29]. They never say controls are excluded — and wwdc2025-275 (1:40–1:59) shows "I'll tap on the control that runs an App Intent […] the intent will show a snippet".

So neither the documentation nor the demo settles it, and reading "not in the list" as "not supported" is not an argument. What settled it was **changing only the caller**:

| Condition | Snippet |
|---|---|
| Spotlight → `ShowTodoCountIntent` → `TodoSummarySnippetIntent` | appears ✅ |
| Control (Button) → same intent, same snippet | none ❌ |
| same + `allowedExecutionTargets = [.main]` | none ❌ |
| Control (Toggle, `SetValueIntent`) → snippet | none ❌ |

Snippet implementation, parameters, execution process, `isDiscoverable` and metadata were all held constant and all worked from Spotlight. The only remaining difference was the caller. [measured 2026-08-12, iOS 27 / Xcode 27 beta 5]

Cross-session evidence agrees: the Controls session (wwdc2024-10157) never mentions dialogs or snippets, the Snippets session (wwdc2025-281) never mentions controls, and wwdc2025-275 never uses the words "Control Center", "controls" or "ControlWidget" anywhere — that demo's "control" was an in-app button.

**Generalise the method, not just the result:** hold everything constant, change the caller, run the same intent. An experiment that moves process, shape and implementation together cannot settle anything.

## Routing rules

- **Siri / Shortcuts is the primary surface** → return a dialog, optionally a snippet. Write it as a sentence someone is happy to hear aloud.
- **Control Center is the primary surface** → the feedback is the **control redrawing itself** when `perform()` returns [Apple]. Do not return a dialog or snippet; they are dropped.
- **Widget / app button** → the surface already updates. Nothing extra.
- **Live Activity** → update or end the activity itself; notify only on terminal states.

`perform()` cannot see the caller (`systemContext` has `currentMode` and `isVoiceOnly`, no invocation source), so this is a design-time decision, not a runtime branch.

### Controls have exactly three channels

1. **Automatic reload after `perform()` returns** — "the system automatically reloads it when the control's app intent's `perform()` function returns" [Apple].
2. **`controlWidgetStatus(_:)`** — transient status text in Control Center. Apple: "Use status text sparingly and only in situations where important information isn't conveyed by the control." If the toggle state or the count already says it, this is noise.
3. **`controlWidgetActionHint(_:)`** — the Action button hint. Verb-first ("Complete Todo").

**Notify on failure only.** A failed control action redraws in the previous state, which is indistinguishable from "nothing happened". Success needs no notification: it would double up with the redraw and linger in Notification Center.

```swift
do {
    try todoService.setCompletion(todoId: todoId, isCompleted: value)
} catch {
    ControlNotificationHelper.sendErrorNotification(
        message: "Couldn't update the todo. Open the app to retry.",
        todoId: todoId          // attaches appEntityIdentifiers — see below
    )
    throw error
}
```

In a `ControlValueProvider`, **throw** rather than notify: "You can also throw an error to tell the system that the state couldn't be computed" [Apple: wwdc2024-10157 10:26]. Collapsing an error to `try? … ?? 0` displays a confident lie ("all done", "nothing due").

If the point is to *read* something, a control is the wrong surface. Send the person to the right screen with a `.foreground(.immediate)` launch intent, and put the summary in Siri / Spotlight / Shortcuts where dialogs and snippets do render.

## Do not let the only channel fail silently

When a notification is the *sole* feedback path (as it is for controls), a person who declined notifications gets nothing at all — and `UNUserNotificationCenter.add` **returns no error** when authorisation is missing. Two halves to the fix:

1. Check `authorizationStatus` before sending.
2. If you could not send, **record the miss** somewhere durable, and have the app surface it later ("Notifications are off, so Control Center actions can't report failures") with a link to Settings. Clear the record once shown.

The same applies to a Live Activity that is disabled in Settings: the code path succeeds, the person sees nothing.

## Writing dialogs

```swift
return .result(value: entity, dialog: "Added \(title).")
```

`IntentDialog(full:supporting:)` splits voice-only from visual-accompanied [Apple: wwdc2026-343 2:45]:

- `full` — self-contained, for a screenless context. "You have 4 pending todos."
- `supporting` — a short line next to the returned value on screen. "4 pending."

```swift
return .result(
    value: entities,
    dialog: IntentDialog(
        full: "You have \(entities.count) incomplete todos.",
        supporting: "Here are your incomplete todos."
    )
)
```

Avoid: `"Success"` (says nothing), error text with implementation detail, and multi-paragraph dialogs (Siri trails off, Shortcuts truncates).

**Never assemble grammar in Swift.** `"\(noun)s"`, `count == 1 ? "is" : "are"` and the like put English into a `%@` that translators cannot reach — the translated sentence keeps an English fragment. Let inflection do it: `"You have ^[\(pending) pending todo](inflect: true)."` See `app-intents-localization`.

Return `ReturnsValue<T>` alongside the dialog so the next Shortcuts step can chain on it.

## Notifications that carry context

Attach the entity so Siri understands what a notification is about even off-screen:

```swift
let content = UNMutableNotificationContent()
content.title = "Couldn't update the todo"
content.appEntityIdentifiers = [EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)]
```

[Apple: wwdc2026-343, iOS 27, `import AppIntents`]. **Persistent `AppEntity` only** — `TransientAppEntity` is not allowed here [Apple: wwdc2026-343 21:38].

## Rule of thumb

- If the action visibly changes a surface the person is already looking at, **that is the feedback**.
- If it was fired from a glance surface, assume dialogs and snippets are invisible.
- If it was purely spoken, the dialog is the entire experience. Make it short and grammatical.
