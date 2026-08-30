# Control Center

Controls are the surface with the least feedback and the tightest correctness requirements, so they are worth their own file.

## Button or toggle

| | `ControlWidgetButton(action:)` | `ControlWidgetToggle(isOn:action:)` |
|---|---|---|
| State | none — "use them for fire-and-forget actions" [Apple] | two, and the provider must be able to read the current one back |
| Intent | any `AppIntent` | `SetValueIntent where ValueType == Bool` |
| Who decides the new value | your intent | **the system**: it fills `value` with the destination state. "Don't set or manage the value parameter" [Apple] |

**A toggle needs a fixed target.** `isOn` must be a value the provider can read back on the next reload. "Complete the most urgent item" cannot be a toggle: completing it makes the provider return a *different*, incomplete item, so the on-state never persists. Either pin the target through configuration, or use a button.

Because the system supplies the destination state, a toggle's intent must be an **absolute setter**, not a flip. That is the one legitimate reason to have both `ToggleXIntent` and `SetXIntent` (`app-intents-centric-design`).

## Configuration

A control that acts on a *chosen* target needs two intents, by design [Apple: wwdc2024-10157]:

- a `ControlConfigurationIntent` that resolves which target the person picked, and
- the action intent that runs when they tap.

```swift
AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in … }
    .promptsForUserConfiguration()
```

A `ControlConfigurationIntent` the app never references can stay **in the widget extension target**. Putting it in a shared package compiles it for watchOS and visionOS too, where it has no meaning.

**The configuration's entity snapshot is stale.** Re-read by id on every `currentValue(configuration:)`, and fall back to an "unconfigured" state if the target was deleted meanwhile — otherwise the control renders a title for a row that no longer exists.

## Value providers must throw

```swift
struct Provider: ControlValueProvider {
    var previewValue: Int { 3 }        // gallery preview; for a toggle, return the OFF state
    func currentValue() async throws -> Int {
        try await MainActor.run { … }  // throw, don't paper over
    }
}
```

"You can also throw an error to tell the system that the state couldn't be computed" [Apple: wwdc2024-10157 10:26]. Collapsing to `try? … ?? 0` displays a **confident lie** — "all done", "nothing due" — which is worse than an error state, because the person acts on it.

Async fetching belongs in the provider, not in `body`; the system runs provider → body on reload.

## Feedback: three channels, and none of them is a dialog

Controls present **neither `.result(dialog:)` nor `snippetIntent:`** [measured 2026-08-12, iOS 27]. That is not inferred from a documentation omission — it was settled by running the same intent from Spotlight (snippet appears) and from a control (it does not), changing nothing else. Full method and matrix in `app-intents-ui-and-feedback`.

What you do have:

1. **Automatic reload after `perform()` returns** — "the system automatically reloads it when the control's app intent's `perform()` function returns" [Apple]. This is the primary feedback: the control redraws with the new truth.
2. **`controlWidgetStatus(_:)`** — transient status text. Apple: "Use status text sparingly and only in situations where important information isn't conveyed by the control." If the toggle state or the count already says it, this is noise.
3. **`controlWidgetActionHint(_:)`** — the Action button hint. Verb-first ("Complete Todo").

**Notify on failure only.** A failed control action redraws in the previous state, which is indistinguishable from "nothing happened". Success needs no notification: it would double up with the redraw and linger in Notification Center.

And **do not let the only channel fail silently**: `UNUserNotificationCenter.add` returns no error when notifications are denied. Check `authorizationStatus` before sending, and if you cannot send, record the miss somewhere the app can surface later (a banner offering to open Settings). Same for a Live Activity disabled in Settings.

If the point is to *read* something, a control is the wrong surface. Send the person to the right screen with a `.foreground(.immediate)` launch intent, and put the summary in Siri / Spotlight / Shortcuts where dialogs and snippets do render.

Calling `continueInForeground()` from a control-invoked intent is **unverified** [inferred]. Use a `.foreground(.immediate)` launch intent from `ControlWidgetButton` instead.

## Availability

- **No Control Center on visionOS** [Apple: "Developing a WidgetKit strategy" support table]. Guard with `#if !os(visionOS)`; `if #available` cannot stop type resolution.
- `ControlCenter.shared.reloadAllControls()` has the same gate — see the reload helper in `app-intents-centric-design`.
- **Control `kind` strings are system-wide identifiers.** Use reverse-DNS.

## Templates

### Toggle over a configured target

```swift
struct ToggleTodoControl: ControlWidget {
    static let kind = "com.example.MyApp.MyWidget.ToggleTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetToggle(
                snapshot.title,
                isOn: snapshot.isCompleted,
                action: SetTodoCompletionIntent(todoId: snapshot.todoId ?? "")
            ) { isOn in
                Label(isOn ? "Completed" : "To Do",
                      systemImage: isOn ? "checkmark.circle.fill" : "circle")
                    .controlWidgetActionHint(isOn ? "Complete Todo" : "Reopen Todo")
            }
        }
        .promptsForUserConfiguration()
        .displayName("Complete Todo")
        .description("Complete or reopen a todo you choose.")
    }
}

extension ToggleTodoControl {
    struct Provider: AppIntentControlValueProvider {
        // Gallery preview: per Apple's guidance, return the off state.
        func previewValue(configuration: SelectTodoConfigurationIntent) -> Snapshot { .placeholder }

        // The configuration's entity snapshot is stale — re-read by id every time,
        // and fall back to "unconfigured" if the target was deleted meanwhile.
        func currentValue(configuration: SelectTodoConfigurationIntent) async throws -> Snapshot { … }
    }
}

public struct SetTodoCompletionIntent: SetValueIntent {
    public static let title: LocalizedStringResource = "Set Todo Completion"
    public static let supportedModes: IntentModes = [.background]
    public static let isDiscoverable = false          // control-only
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }  // it writes

    @Parameter(title: "Todo ID") public var todoId: String

    /// The system fills this with the toggle's destination state. Never set it yourself.
    @Parameter(title: "Completed") public var value: Bool

    @Dependency var todoService: TodoService
    public init() {}
    public init(todoId: String) { self.todoId = todoId }

    @MainActor
    public func perform() async throws -> some IntentResult {
        do {
            try todoService.setCompletion(todoId: todoId, isCompleted: value)   // absolute, not a flip
        } catch {
            // Success is conveyed by the control's own redraw; only failure needs a notification.
            ControlNotificationHelper.sendErrorNotification(
                message: "Couldn't update the todo. Open the app to retry.", todoId: todoId)
            throw error
        }
        return .result()
    }
}
```

### Value display

```swift
struct TodoCountControl: ControlWidget {
    static let kind = "com.example.MyApp.MyWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: LaunchAppIntent.incompleteTodos()) {
                Label { Text("\(count)") } icon: { Image(systemName: "checklist") }
                    .controlWidgetActionHint("Show Incomplete Todos")
            }
        }
        .displayName("Todo Count")
    }
}

extension TodoCountControl {
    struct Provider: ControlValueProvider {
        var previewValue: Int { 3 }
        func currentValue() async throws -> Int {
            // Throw on failure — `try? … ?? 0` would render a confident lie ("all done").
            try await MainActor.run {
                let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isCompleted })
                return try sharedWidgetModelContainer.mainContext.fetchCount(descriptor)
            }
        }
    }
}
```
