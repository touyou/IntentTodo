# 03 — Execution modes

`supportedModes` answers one question only: **does the app come to the foreground?** It does *not* decide which process runs the intent — that is [04](04-process-and-dependencies.md).

## The four modes

| Mode | Behaviour | Replaces |
|---|---|---|
| `.background` | runs without opening the app | `openAppWhenRun = false` |
| `.foreground` / `.foreground(.immediate)` | foreground right after parameter resolution | `openAppWhenRun = true` |
| `.foreground(.dynamic)` | `perform()` decides at runtime | **`ForegroundContinuableIntent`**, now deprecated |
| `.foreground(.deferred)` | starts in background, system foregrounds during or after `perform()` | new in iOS 26 |

[Apple: `supportedModes` documentation; wwdc2025-275 19:31–20:14]

> "This protocol is deprecated, please include `.foreground(.dynamic)` in the `supportedModes` of your app intent instead." — Apple, on `ForegroundContinuableIntent`

`IntentModes` is an option set, so modes combine:

```swift
public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }
```

## Choosing

| Situation | Mode |
|---|---|
| Silent data action (add / toggle / delete / favourite) | `.background` |
| "Open the editor", "show this detail" | `.foreground(.immediate)` |
| Usually silent, occasionally needs the user | `[.background, .foreground(.dynamic)]` |
| Optimistically background, escalate on the way out | `[.background, .foreground(.deferred)]` |

The exact semantics of `.deferred` (when exactly the system foregrounds) are not spelled out in Apple's documentation [inferred + measured 2026-04-15]: it behaved as "background first, guaranteed foreground before `perform()` returns". Verify before depending on the timing.

## Escalating from inside `perform()`

```swift
public static var supportedModes: IntentModes { [.background, .foreground(.dynamic)] }

func perform() async throws -> some IntentResult & ReturnsValue<[TodoAppEntity]> & ProvidesDialog {
    let entities = try todoService.listTodos(filter: filter)

    if systemContext.currentMode.canContinueInForeground {
        do {
            try await continueInForeground(alwaysConfirm: false)
            navigationModel.navigateToRoot()          // now safe: we are foreground
        } catch {
            // The person declined — finish in the background, still return a result.
        }
    }
    return .result(value: entities, dialog: dialog(for: entities))
}
```

- `systemContext.currentMode.canContinueInForeground` tells you whether escalation is even possible for this caller.
- `continueInForeground()` **throws** when refused. Treat that as a normal path, not an error.

### `OpensIntent` contradicts dynamic mode

Returning `OpensIntent` always opens the app, which defeats "background unless needed". With `.foreground(.dynamic)`, foreground by calling `continueInForeground()` and then writing navigation state directly ([05](05-ui-integration.md)). Keep `OpensIntent` for intents that are unconditionally about opening something.

Dedicated "open the app" intents stay `.foreground(.immediate)`. Do not make them dynamic.

## Modes are not processes

A frequent and expensive confusion:

- `.background` does **not** mean "runs in the extension".
- `.foreground(.immediate)` does mean the app is brought forward, and therefore that `perform()` runs there.
- For everything else, the process is chosen by heuristics unless you pin it with `allowedExecutionTargets`.

[Apple: wwdc2026-345 15:59–16:55]. Full matrix and consequences in [04](04-process-and-dependencies.md).

## Control Center caveat

Calling `continueInForeground()` from a control-invoked intent is **unverified** here [inferred]. Controls are designed for actions that complete in place; if you need to take the person somewhere, use a `.foreground(.immediate)` launch intent from `ControlWidgetButton` instead ([06](06-feedback-channels.md)).
