# 03 — `supportedModes` and execution control

Per-Intent control of background vs. foreground execution. `supportedModes` replaces `openAppWhenRun` for new code and is the modern way to express what `ForegroundContinuableIntent` used to do.

## The four modes

| Mode | Behavior | Equivalent to |
|---|---|---|
| `.background` | Runs without opening the app. | `openAppWhenRun = false` |
| `.foreground(.immediate)` | Opens the app right after parameter resolution. | `openAppWhenRun = true` |
| `.foreground(.dynamic)` | Decides at runtime inside `perform()` whether to bring the app forward. | **Replacement for** `ForegroundContinuableIntent` |
| `.foreground(.deferred)` | Starts in background; can request foregrounding inside `perform()` or via the returned result. | New iOS 26+ mode |

`supportedModes` is an option set, so combining modes is allowed:

```swift
struct AddTodoIntent: AppIntent {
    static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }
    // …
}
```

## When to use each

- **Pure data action that always finishes silently** → `.background`. Most "add", "toggle", "delete", "favorite" intents fall here.
- **Always opens the app** → `.foreground(.immediate)`. Use for "open editor", "open detail screen", "compose new draft".
- **Conditional foregrounding** → `.foreground(.dynamic)`. Use when `perform()` may need to escalate (e.g. validation failed, ask the user inline; otherwise finish in background).
- **Optimistic background → escalate if needed** → `.foreground(.deferred)`. Similar to `.dynamic` but the system can defer the foregrounding decision until after `perform()` returns.

## Deprecated patterns

> "`ForegroundContinuableIntent` is deprecated; please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead." — Apple Developer Documentation

Do **not** adopt `ForegroundContinuableIntent` for new intents. If you encounter it in a legacy code path, migration is mechanical:

```diff
- struct EditDraftIntent: ForegroundContinuableIntent { … }
+ struct EditDraftIntent: AppIntent {
+     static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
+     // body unchanged
+ }
```

## Foregrounding from inside `perform()`

When you choose `.foreground(.dynamic)` or `.foreground(.deferred)`, you can promote to foreground based on runtime state. The exact API depends on the iOS version — verify against the current Apple docs before committing.

```swift
struct EditDraftIntent: AppIntent {
    static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
    @Parameter(title: "Draft") var draft: DraftAppEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        let draftIsValid = try DraftService.shared.validate(id: draft.id)
        if draftIsValid {
            try DraftService.shared.publish(id: draft.id)
            return .result()
        }
        // Validation failed — user needs to see and fix the draft.
        // Promote to foreground and let the scene present the editor.
        try await requestToContinueInForeground()
        AppDependencyManager.shared.navigation.openDraft(id: draft.id)
        return .result()
    }
}
```

(Symbol names like `requestToContinueInForeground()` may differ across iOS releases — check current docs.)

## Mode and process: not the same thing

A common confusion: `supportedModes` controls whether the **app is brought forward**, not which **process** the Intent runs in.

| Caller | Process |
|---|---|
| Siri / Shortcuts | Main app process |
| UI `Button(intent:)` | Main app process |
| Widget `Button(intent:)` with `.foreground(.immediate)` | Main app process |
| Widget `Button(intent:)` with `.background` | **Widget Extension process** |
| Control Center `ControlWidgetButton` | **Widget Extension process** (controls live in widget extensions) |
| Live Activity button (`LiveActivityIntent`) | Main app process |

Decide both **mode** (background/foreground) and **process implications** (which `AppDependencyManager` hosts the dependencies) for every Intent. See `04-process-and-dependencies.md`.

## Reference

- <https://developer.apple.com/documentation/appintents/appintent/supportedmodes>
- <https://developer.apple.com/documentation/appintents/foregroundcontinuableintent> (deprecated)
- <https://developer.apple.com/documentation/widgetkit/adding-interactivity-to-widgets-and-live-activities>
