# 06 — Feedback channels: Dialog vs. notification

`.result(dialog:)` is read aloud by Siri, shown by Shortcuts — and silently swallowed by Control Widgets and most UI invocations. Choosing the right channel per surface is the difference between an Intent that feels finished and one that feels broken.

## The reality matrix

How `.result(dialog:)` and local notifications behave per caller:

| Caller | `.result(dialog:)` | Local notification |
|---|---|---|
| Siri | Read aloud ✅ | Shown ✅ |
| Shortcuts | Shown in result panel ✅ | Shown ✅ |
| UI `Button(intent:)` | Not shown | Shown ✅ |
| Widget `Button(intent:)` | Not shown | Shown ✅ |
| **Control Widget (`ControlWidgetButton`)** | **Not shown** (verified on-device 2026-04) | Shown ✅ |
| Live Activity button | Not shown | Shown ✅ |

Verify the row for any new caller before assuming — Apple has changed Control Widget behavior between iOS releases, and what is silent today may render tomorrow.

## Routing rules

- **Voice / Shortcuts is the primary surface** → ship `.result(dialog:)`. Optional notification.
- **Control Center is the primary surface** → ship a **local notification**. Dialog will be silently lost.
- **Widget `Button(intent:)` is the primary surface** → no dialog needed, no notification needed if the widget itself reflects the change. Add a notification only if the action has a delayed effect the user would otherwise miss.
- **UI `Button(intent:)` is the primary surface** → no dialog, no notification. The UI updates immediately.
- **Live Activity button is the primary surface** → update the Activity itself; add a notification only on terminal state changes (e.g. "Activity ended").

## Dialog snippets that actually help

When you do return a dialog, write it as a sentence the user is happy to hear out loud:

```swift
return .result(dialog: "Added \"\(title)\" to your todos.")
```

Avoid:

- `.result(dialog: "Success")` — provides no information.
- `.result(dialog: "Error: nil")` — exposes implementation detail.
- Multi-paragraph dialogs — Siri will trail off; Shortcuts will hide the rest.

For Shortcuts, you can also return `IntentResult & ReturnsValue<T>` so the next Shortcut step can chain on the result:

```swift
return .result(value: entity, dialog: "Added \(title).")
```

## Notification setup

A reusable helper avoids scattering `UNUserNotificationCenter` boilerplate.

```swift
@MainActor
enum IntentFeedback {
    static func notify(title: String, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let body { content.body = body }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // immediate
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
```

Use it in Control / Widget intents:

```swift
struct ToggleUrgentTodoIntent: AppIntent {
    static var supportedModes: IntentModes { .background }
    @Dependency var todoService: TodoService

    @MainActor
    func perform() async throws -> some IntentResult {
        let title = try todoService.toggleNextUrgent()
        IntentFeedback.notify(title: "Marked urgent done", body: title)
        return .result()
    }
}
```

## When in doubt

- If the action has any visible side effect on a surface the user is currently looking at, that **is** the feedback. No dialog, no notification.
- If the action is fired-and-forget from a glance surface (Control Center, complication), assume the user will not see Dialog. Use notification.
- If the action is entirely voice-driven, Dialog is the whole feedback. Make it short and grammatical.
