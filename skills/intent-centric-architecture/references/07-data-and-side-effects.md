# 07 — Data and side effects

Making a mutation land everywhere, survive repetition, and not lie to the user.

## Surface refresh is part of the action

**Home widgets and Control Center are separate APIs.** `WidgetCenter.shared.reloadAllTimelines()` does not touch controls, and the system only auto-reloads *the one control that ran the intent*. Every other control keeps rendering a stale value.

```swift
public enum WidgetReloader {
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #if !os(visionOS)                       // ControlCenter is unavailable on visionOS
        ControlCenter.shared.reloadAllControls()
        #endif
        #endif
    }
}
```

Measured symptom: with only `reloadAllTimelines()`, completing an item through a toggle control leaves the neighbouring count control stuck at `2`; with `reloadAllControls()` it drops to `1` at the same moment. [measured 2026-08-12, iOS 27 simulator]

Call it **once per logical mutation**, from the Service's `defer`, so no intent can forget:

```swift
public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
    defer { WidgetReloader.reloadAllWidgets() }
    // …
}
```

### Is the manual reload always needed?

No — an intent invoked from a widget's own `Button(intent:)` gets an automatic timeline reload when `perform()` returns, and reloads initiated by an interaction are guaranteed [Apple: wwdc2023-10028 10:02, 13:47]. It *is* needed for every non-widget path: Siri, Shortcuts, app UI, notifications. Calling it unconditionally skips the case analysis; the duplicate reload costs nothing.

Other surfaces to refresh from the same place: Live Activities (`Activity.update` / `.end`), watch complications (WidgetKit reload), and the Spotlight index — but only on insert, title change and delete.

## `perform()` is retriable — order the side effects

The system may restart `perform()`. Do irreversible work **last**, and never report success before the write lands.

1. Persist (truth of record).
2. Update navigation / Activity state.
3. Reload surfaces, update the index.
4. Build the dialog / notification.
5. Return.

Reloading before persisting produces a visible stale flash; building feedback before persisting risks announcing a write that then fails.

## Idempotency

Voice, automations and double taps all repeat. Design for it.

- **Toggles** are inherently non-idempotent — usually "toggle again" is the right semantics; if not, guard on state or a timestamp. For a control, use an absolute setter (`SetValueIntent`) instead, which is idempotent by construction.
- **Creates** should not silently de-duplicate: two "add milk" commands usually mean two items.
- **Deletes** should tolerate "already gone" and return success.

```swift
public func delete(todoId: String) throws {
    defer { WidgetReloader.reloadAllWidgets() }
    do { try repository.delete(id: todoId) }
    catch RepositoryError.notFound { return }   // idempotent
}
```

Deleting an entity should also drop its donations, or the system keeps suggesting an action it cannot perform:

```swift
_ = try? await IntentDonationManager.shared.deleteDonations(
    matching: .entityIdentifiers([EntityIdentifier(for: todo)])
)
```

## Division of labour

| Concern | Intent | Service |
|---|---|---|
| Parameter declarations, parameter summary | ✅ | — |
| Dialog / notification text | ✅ | — |
| Input-only validation | ✅ | — |
| Validation that needs stored state | — | ✅ |
| Persistence | — | ✅ |
| Surface reload (`defer`) | — | ✅ |
| Spotlight indexing | — | ✅ |
| Navigation writes via `@Dependency` | ✅ | — |

The payoff: the Service is unit-testable with a mock repository and no `AppDependencyManager`, and the intent file stays short enough to read in one screen.

## SwiftData + CloudKit constraints

[Apple: "Define a CloudKit compatible schema"]

- **`@Attribute(.unique)` is not enforced** — "CloudKit is unable to enforce the unique property option". `#Unique<T>` relies on the same mechanism. Enforce uniqueness in the Service if you need it.
- **All relationships must be optional**; `.deny` delete rules are unsupported.
- **Every property needs a default or must be optional** (sync conflict handling). A new property with a default value also gets you a lightweight migration without a `VersionedSchema`.

Consequences at the intent boundary: do not expose a non-optional relationship on an entity when the model's is optional, and synthesise sane defaults rather than crashing on `nil`.

Two more SwiftData rules worth carrying:

- **No `didSet` on `@Model` properties.** The macro swizzles property access; CloudKit merges and KVC writes may not fire the observer, so an "auto-update `modifiedAt`" side effect works locally and silently doesn't when syncing. Set it explicitly in the Service.
- **`@Model` classes are not `Sendable`** (the macro adds an unavailable conformance). Keep the repository `@MainActor` rather than trying to cross actor boundaries with models.

### Migration is one process's job

Several processes share the App Group store, and **after an update a widget can run before the app does**. If both carry a migration plan, the extension may start migrating while the app does the same.

Give the `SchemaMigrationPlan` **only to the app's container**; extensions open the store without one and simply read the migrated file. Have the extension fall back to "open the app" if the store is not ready yet.

> This one has no Apple source: it is reasoning from the shared-store situation, not a documented rule. [inferred]

## The `@Query` + `.onChange` foot-gun

Tempting, and broken:

```swift
// ❌ silently goes stale
.onChange(of: todoItems, initial: true) { viewModel.update(from: todoItems) }
```

`@Query` returns `[PersistentModel]` — an array of **classes**. Array equality is identity-based, so an in-place attribute change (toggling `isCompleted`, editing a title) leaves the array "equal", `.onChange` never fires, and the cached projection goes stale. Insertions and deletions *do* change identities, which is why the bug hides until someone edits in place.

Map in `body` instead — SwiftUI's dependency tracking re-evaluates on tracked-attribute changes, and mapping a few hundred items is cheap:

```swift
private var todos: [TodoAppEntity] {
    viewModel.filtered(todoItems.map(TodoAppEntity.init))
}
```

With thousands of rows, fix it properly: filter and sort in `@Query(filter:sort:)`, fetch a lightweight `struct` projection, or paginate. Do not reach for `.onChange` caching.

### `#Predicate` and optionals

`#Predicate` requires both sides to have the same type; the implicit optional promotion that plain Swift gives you does not apply after macro expansion. Exactly one shape fails [measured 2026-08-12 — not a platform or toolchain difference]:

| Expression | Result |
|---|---|
| non-optional property `==` optional value (`$0.id == optionalUUID`) | ❌ compile error |
| optional property `==` optional value | ✅ |
| optional property `==` non-optional value | ✅ |
| optional property `!= nil` | ✅ |
| the same expression outside `#Predicate` | ✅ |

Fix by capturing a non-optional constant first:

```swift
let targetId = UUID(uuidString: entity.id) ?? UUID()   // a value that cannot match
_todoItems = Query(filter: #Predicate<TodoItem> { $0.id == targetId })
```
