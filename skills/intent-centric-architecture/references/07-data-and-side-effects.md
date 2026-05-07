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

## SwiftData `@Query` and `.onChange(of:)` — a frequent foot-gun

It is tempting to "optimize" away the per-`body` cost of converting `[TodoItem]` (SwiftData `@Model`) into a presentation type by caching the conversion in a `@Observable` view model and updating it via `.onChange(of: todoItems)`:

```swift
// ❌ This looks reasonable but is broken.
@MainActor @Observable
final class TodoListViewModel {
    public private(set) var entities: [TodoAppEntity] = []
    public func update(from todos: [TodoItem]) {
        entities = todos.map { TodoAppEntity(from: $0) }
    }
}

// In the view:
.onChange(of: todoItems, initial: true) {
    viewModel.update(from: todoItems)
}
```

**Why it breaks**: SwiftData's `@Query` returns `[PersistentModel]`, where each element is a *class*. The array's `Equatable` is identity-based — comparing two snapshots checks whether the same objects are at the same indices, not whether their attributes have changed. So when the user toggles `isCompleted` or edits a `title` in place, `todoItems` is "the same" array, `.onChange(of: todoItems)` does **not** fire, and the cached `entities` go stale. Insertion/deletion (which changes the element identities) does fire `.onChange`, which is why this bug is invisible until you start mutating in place.

**The fix**: do the conversion in `body`. SwiftUI's dependency tracking re-evaluates the view when SwiftData's tracked attributes change, so the in-place mutation propagates correctly. The per-`body` `map` is cheap up to a few hundred items.

```swift
// ✅ Correct.
private var filteredTodos: [TodoAppEntity] {
    viewModel.filteredTodos(from: todoItems.map { TodoAppEntity(from: $0) })
}
```

**If you genuinely have thousands of items**, fix it by:

- Using a SwiftData fetch that returns a lightweight `struct` projection (only the fields you need), so the `map` itself is unnecessary.
- Filtering / sorting at the `@Query(filter:sort:)` macro level so the array reaching the view is already small.
- Pushing pagination — show 100 at a time, load more on scroll.

Do not reach for `.onChange(of: todoItems)` caching. The bug is silent and surfaces in production as "toggles don't update".
