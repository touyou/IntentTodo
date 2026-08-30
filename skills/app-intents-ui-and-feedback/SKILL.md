---
name: app-intents-ui-and-feedback
description: Run App Intents from your own app's UI and tell the person what happened. Use when wiring a SwiftUI button to an intent, when tapping a button does nothing at all and no error appears, when a confirmation prompt never shows up, when you want an intent to navigate somewhere or open a specific screen (including from a cold launch), when you need Siri to say something back or read a result aloud, when you want to show a small interactive result view, when a notification never arrives, or when an action clearly succeeded but nothing visible changed on screen or in Control Center.
---

# UI integration and feedback

How the app's own UI triggers intents, how intents drive navigation, and how the person finds out what happened.

Assumes the rules in `app-intents-centric-design`.

## `Button(intent:)` is the execution path

```swift
import AppIntents   // required for Button(intent:)

Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark.circle")
}

Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
    Label("Delete", systemImage: "trash")
}
```

Same execution path as Siri and Shortcuts, no boilerplate, no duplicated logic.

**Argument order: `role` comes first.** `Button(intent:role:)` resolves to a different init and fails with `"extraneous argument label 'intent:'"` [measured — hit on a visionOS build]. `Button(role:intent:)` does not exist on watchOS; drop `role:` there.

## The three ways a button silently does nothing

This is the single most common symptom in App Intents, and it has exactly three causes worth checking, in this order.

| Check | Symptom | Fix |
|---|---|---|
| Are you calling `perform()` yourself? | crash or trap, sometimes swallowed by `try?` | use `Button(intent:)`; `@Dependency` is only injected on system dispatch |
| Does the intent call `requestConfirmation` / `requestChoice`? | nothing at all, no error UI | it cannot be run from a button — see below |
| Is the dependency registered in the process that ran it? | nothing; `Failed to retrieve dependency of type X.` on stderr | `app-intents-execution-and-processes` |

### Never call `perform()` yourself

```swift
// ❌ crashes: @Dependency is zero-initialised, the ModelContainer access traps
Button { Task { try? await AddTodoIntent(title: t).perform() } } label: { … }

// ✅ system dispatch resolves dependencies
Button(intent: AddTodoIntent(title: t)) { … }
```

`@Dependency` is injected by the system when it dispatches the intent. A manual call skips that entirely. `audit_intents.py` flags this (`manual-perform`).

If two callers need the same logic and only one of them is an intent, **both call the service** — that is what the service layer is for.

### ⚠️ Interactive intents cannot be called from a button

An intent that calls `requestConfirmation` or `requestChoice` **fails when invoked from an in-app or widget button** — there is no surface to answer on. It fails with `LNPerformActionErrorCodeUnsupportedValueType`, **shows no error, and nothing happens** [measured 2026-08-12].

This is nasty for three reasons: it looks like a dead button, the same intent succeeds through Siri / Shortcuts / AppIntentsTesting, and therefore **AppIntentsTesting cannot catch it** — only a UI test can, and only one that asserts unconditionally (`app-intents-testing`).

```swift
// Siri / Shortcuts: the intent asks.
public struct DeleteTodoIntent: AppIntent {
    public func perform() async throws -> some IntentResult {
        try await requestConfirmation(dialog: IntentDialog("Delete “\(todo.title)”?"))
        try todoService.delete(todoId: todo.id)
        return .result()
    }
}

// UI: SwiftUI asks, then runs the non-interactive twin (isDiscoverable = false).
.confirmationDialog("Delete this todo?", isPresented: $showingDelete) {
    Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
        Text("Delete")
    }
}
```

Details of the interactive APIs themselves are in `app-intents-parameters-and-prompts`.

## Feedback: the caller decides, not the intent

The same intent tells the person what happened in different ways depending on **who called it**. Getting this wrong produces actions that feel broken while working perfectly.

| Caller | `.result(dialog:)` | `snippetIntent:` | local notification |
|---|---|---|---|
| Siri | spoken ✅ | shown ✅ | shown ✅ |
| Spotlight / Shortcuts | shown in result ✅ | shown ✅ | shown ✅ |
| App UI `Button(intent:)` | — | — | shown ✅ |
| Widget `Button(intent:)` | — | — | shown ✅ |
| **Control Center (Button or Toggle)** | **—** [measured 2026-04-14] | **—** [measured 2026-08-12] | shown ✅ |
| Live Activity button | — | — | shown ✅ |

Routing rules:

- **Siri / Shortcuts is the primary surface** → return a dialog, optionally a snippet. Write it as a sentence someone is happy to hear aloud.
- **Control Center is the primary surface** → the feedback is the **control redrawing itself** when `perform()` returns [Apple]. Do not return a dialog or snippet; they are dropped. Notify on failure only (`app-intents-system-surfaces`).
- **Widget / app button** → the surface already updates. Nothing extra.
- **Live Activity** → update or end the activity itself; notify only on terminal states.

Because `perform()` cannot see the caller, you cannot branch on it. Return everything a rich caller could use and accept that poorer callers drop it — but never make a *dropped* channel the only one that reports failure.

Full matrix, how the control row was settled, dialog writing and notification context: [feedback-channels](references/feedback-channels.md).

## Fast decisions

| Goal | Use | Not |
|---|---|---|
| Element that only opens the app (widget, Live Activity) | `Link(destination:)` / `widgetURL(_:)` | `Button(intent:)` — Apple: an interaction "should do more than open the app" |
| Element that acts | `Button(intent:)` | manual `perform()` |
| Confirm before a destructive action, in the app | SwiftUI `.confirmationDialog` + non-interactive twin intent | `requestConfirmation` |
| Confirm before a destructive action, via Siri | `requestConfirmation` inside `perform()` | a SwiftUI sheet |
| Navigate somewhere after an intent runs | `@Dependency` on a navigation model, written in `perform()` | `onAppIntentExecution` if you need cold-start reliability or macOS/watchOS |
| Show a result the person can act on | `snippetIntent:` returning a `SnippetIntent` | a dialog with a long sentence |
| Open an entity from anywhere | `OpenIntent` | a custom URL scheme |
| Close the sheet an intent was submitted from | write dismissal state in `perform()` | `dismiss()` in the button action — it fires even when the intent fails |

## References

| File | Covers |
|---|---|
| [ui-integration](references/ui-integration.md) | `Button(intent:)` rules, intent → UI navigation, the pending-value handshake, `onAppIntentExecution` vs `@Dependency`, view structure |
| [feedback-channels](references/feedback-channels.md) | the matrix and how it was settled, routing, writing dialogs, notifications that carry context, silent-channel failures |
| [snippets](references/snippets.md) | `SnippetIntent`, buttons inside a snippet, re-running on every press, where snippets do and do not render |
| [templates](references/templates.md) | navigation intent (cold-start safe), confirmation pair, snippet |
