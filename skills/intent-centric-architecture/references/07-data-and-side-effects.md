# 07 — Data and side effects

How to make data-mutating Intents reload every system surface, stay idempotent under voice retry, and avoid foot-guns specific to SwiftData + CloudKit.

## Surface refresh is part of the action

After every data-mutating Intent, every surface that displays that data must reload:

- Home widgets (`WidgetCenter.shared.reloadAllTimelines()` or `reloadTimelines(ofKind:)`)
- Control widgets (same reload mechanism)
- Live Activities (`Activity.update(...)` or `.end(...)`)
- watchOS complications (`CLKComplicationServer.sharedInstance().reloadTimeline(for:)` or WidgetKit equivalent)
- Spotlight indexes (`CSSearchableIndex` updates) — only on insertion / title changes / deletion.

Encapsulate this in a single helper so individual Intents do not need to remember which surfaces exist.

```swift
@MainActor
public enum WidgetReloader {
    public static func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
```

Call it **once per logical mutation**, ideally inside the `Service`'s `defer` so individual Intents never forget:

```swift
@MainActor
public final class TodoService {
    public func toggleCompletion(id: String) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        try repository.toggleCompletion(id: id)
    }
}
```

Intents that should call this in IntentTodo's vocabulary: `AddTodoIntent`, `DeleteTodoIntent`, `ToggleTodoCompletionIntent`, `ToggleFavoriteIntent`, `SnoozeTodoIntent`, `ToggleUrgentTodoIntent`, and their FromExtension variants.

## Idempotency — assume the user repeats themselves

Voice and Shortcuts can fire the same Intent twice in quick succession (network retry, accidental re-tap, automation loop). Design `perform()` to be safe under repetition.

- **Toggles** are inherently non-idempotent. Either accept the second call as "toggle again" (often correct), or guard with a timestamp / state-check.
- **Creates** should not de-dupe automatically — multiple "add todo X" voice commands probably mean the user wants two todos. But surface a clear dialog like `.result(dialog: "Added two more.")` if you do dedupe.
- **Deletes** should be tolerant of "already deleted" — return success silently rather than throwing.

```swift
public func delete(id: String) throws {
    defer { WidgetReloader.reloadAllWidgets() }
    do {
        try repository.delete(id: id)
    } catch RepositoryError.notFound {
        // Idempotent: deleting an absent item is a no-op.
        return
    }
}
```

## SwiftData + CloudKit constraints

When the persistence layer is SwiftData + CloudKit, a few rules cascade into the Intent layer:

- **`@Attribute(.unique)` is not enforced by CloudKit.** Apple is explicit: "CloudKit is unable to enforce the unique property option." `#Unique<T>` macros use the same mechanism. Validate uniqueness in the `Service` if you actually need it.
- **All relationships must be `optional`.** "CloudKit requires all relationships to be optional." `.deny` delete rules are unsupported.
- **All properties need defaults or be `optional`.** New devices may sync model schema before all property values arrive.

For Intent design, this means:

- Don't expose a non-optional relationship in `AppEntity` if the underlying model has it as optional.
- Be defensive when reading entity properties — synthesize sane defaults rather than crashing on `nil`.
- Spotlight indexing should run as `Task(priority: .utility)` on launch so it doesn't compete with the user-visible cold start.

## Side-effect ordering

Within `perform()`, the order matters:

1. Do the persistence change first (truth-of-record updates).
2. Update navigation / Activity state.
3. Reload widgets / index Spotlight.
4. Build the Dialog / notification feedback.
5. Return.

Putting the widget reload before the persistence write produces a brief race where widgets show stale data; putting feedback before persistence risks reporting success on a write that then fails.

```swift
@MainActor
func perform() async throws -> some IntentResult & ProvidesDialog {
    // 1. Truth of record.
    try todoService.create(title: title, dueDate: dueDate)
    // 2. Optional navigation hint.
    navigation.pendingScrollToTopOfList = true
    // 3-4. Reload + feedback are inside the service via defer + helper.
    return .result(dialog: "Added \(title).")
}
```

## What to put in `Service` vs. `Intent`

| Concern | `Intent` | `Service` |
|---|---|---|
| Parameter type definitions | ✅ | ❌ |
| Dialog / notification text | ✅ | ❌ (return values + side effects only) |
| Persistence calls | ❌ | ✅ |
| Validation that is purely about the input | ✅ (parameter validators) | ❌ |
| Validation that needs persistence state | ❌ | ✅ |
| `WidgetReloader.reloadAllWidgets()` | ❌ | ✅ (in `defer`) |
| Spotlight indexing | ❌ | ✅ |
| Navigation writes via `@Dependency var navigation` | ✅ | ❌ |

Following this division keeps the Intent file small and the Service unit-testable in isolation, without `AppDependencyManager`.
