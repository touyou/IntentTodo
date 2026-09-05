# Service layer and side effects

Making a mutation land everywhere, survive repetition, and not lie to the user.

## The service is the only place with persistence

One `@MainActor final class` per domain, holding the repository. Intents call it; they never touch SwiftData themselves.

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

The payoff: the service is unit-testable with a mock repository and no `AppDependencyManager`, and the intent file stays short enough to read in one screen.

Use `container.mainContext`, not a fresh `ModelContext(container)` per call — a new context does not see unsaved state from the other one.

This replaces `MyRouter.shared` / `Dependencies.shared` singletons, which silently break across processes and cannot be substituted in tests. Registration is per process: `app-intents-execution-and-processes`.

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

Call it **once per logical mutation**, from the service's `defer`, so no intent can forget:

```swift
public func toggleCompletion(todoId: String) throws -> TodoToggleResult {
    defer { WidgetReloader.reloadAllWidgets() }
    // …
}
```

If the same `defer` also has to notify the system that App Shortcut parameter values changed (`updateAppShortcutParameters()`), put that there too — one hook, everything downstream of a mutation.

### Is the manual reload always needed?

No — an intent invoked from a widget's own `Button(intent:)` gets an automatic timeline reload when `perform()` returns, and reloads initiated by an interaction are guaranteed [Apple: wwdc2023-10028 10:02, 13:47]. It *is* needed for every non-widget path: Siri, Shortcuts, app UI, notifications. Calling it unconditionally skips the case analysis; the duplicate reload costs nothing.

Other surfaces to refresh from the same place: Live Activities (`Activity.update` / `.end`), watch complications (WidgetKit reload), and the Spotlight index — on insert, delete and changes to indexed content. Determine that content from the entity’s `indexingKey:` mappings and `attributeSet`, not just its title.

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

This cleanup is correct regardless of who ran the delete. **Donating** is not.

## Undo for destructive actions

`UndoableIntent` buys the gesture people already know ("swipe left with three fingers to undo"). The system supplies "the most relevant undo manager through this property, even when those intents are run in your extensions", which keeps UI and intent undo in one stack. [Apple: wwdc2025-275 15:19–16:06]

The two details that decide whether undo is *real*:

```swift
@MainActor
func perform() async throws -> some IntentResult {
    // 1. Snapshot BEFORE mutating — afterwards the rows are gone, and a SwiftData
    //    @Model is neither readable nor Sendable, so it cannot be captured for undo.
    let snapshots = try entities.compactMap { try model.snapshot(id: $0.id) }
    for e in entities { try model.delete(e.id) }

    // 2. Restore with the SAME id, or Spotlight / donations / widget references
    //    all point at a different object than the "restored" one.
    undoManager?.registerUndo(withTarget: model) { manager in
        Task { @MainActor in snapshots.forEach { try? manager.restore($0) } }
    }
    undoManager?.setActionName(
        String(localized: "Delete ^[\(entities.count) Todo](inflect: true)")
    )
    return .result()
}
```

- `setActionName` is what the undo affordance says out loud; without it the gesture is unlabelled.
- Restore must be **idempotent** — the system may replay it.
- Undoing a *completion* is "set the previous value absolutely", not "toggle back".
- **`undoManager` is `nil` when the caller did not supply one** (a widget `Button(intent:)`, for instance). The registration becoming a no-op there is expected, not a bug to work around.
- If more than one code path deletes, put the registration in **one** registrar type. Three delete intents means three places to forget.

Hard-deleting rows makes `UndoableIntent` a design change rather than a conformance: something has to be able to reconstruct the row under its original id.

## Donations belong to the app's UI, never to `perform()`

Apple is explicit: "Restrict your donations to direct interactions with your app's interface, and **not to interactions started by Siri or the Shortcuts app**" [Apple: *Donations and discovery*].

`perform()` cannot honour that split, because **it cannot tell who called it**: `systemContext` exposes `currentMode`, `isVoiceOnly`, `locale` and `preciseTimestamp`, and there is no invocation-source property. So `donate()` inside `perform()` always fires on the Siri/Shortcuts path too. `audit`: `donate-inside-perform`

**And in an intent-centric app there is usually nothing left to donate.** `Button(intent:)` taps are already recorded by the system: with no `donate()` call anywhere in the app, one in-app `Button(intent:)` tap produced exactly one new donation record, three taps produced three, and a negative control produced none [measured 2026-08-30, iOS 27 simulator, via the Biome donation stream]. Apple's samples need explicit donation because their UI calls a manager directly — across four samples, `Button(intent:)` appears **zero** times. Different premise, different answer.

So:

| Your UI | Donate? |
|---|---|
| every button is `Button(intent:)` | no — the system already has it |
| some UI paths call the service directly, bypassing intents | yes, at those sites: a `donateIntent:` flag on the service method, or a donation manager called from the view's action closure [Apple: sample code] |
| you want to donate a specific in-app site deliberately | `AppIntent.callAsFunction(donate:)` — "runs the intent's action after resolving any parameters, and optionally donates the intent to the system" |

`deleteDonations(matching:)` is correct regardless of caller — it is cleanup, not a suggestion. Put it on every delete path.

Whichever you choose, **write down which and why**: the failure mode of guessing is a documented-rule violation that nothing in the build or the test suite will surface. Callers from another process (widget, control) are not measured — treat their donation behaviour as `[inferred]`.

## SwiftData + CloudKit constraints

[Apple: "Define a CloudKit compatible schema"]

- **`@Attribute(.unique)` is not enforced** — "CloudKit is unable to enforce the unique property option". `#Unique<T>` relies on the same mechanism. Enforce uniqueness in the service if you need it.
- **All relationships must be optional**; `.deny` delete rules are unsupported.
- **Every property needs a default or must be optional** (sync conflict handling). A new property with a default value also gets you a lightweight migration without a `VersionedSchema`.

Consequences at the intent boundary: do not expose a non-optional relationship on an entity when the model's is optional, and synthesise sane defaults rather than crashing on `nil`.

Three more SwiftData rules worth carrying:

- **No `didSet` on `@Model` properties.** The macro swizzles property access; CloudKit merges and KVC writes may not fire the observer, so an "auto-update `modifiedAt`" side effect works locally and silently doesn't when syncing. Set it explicitly in the service.
- **`@Model` classes are not `Sendable`** (the macro adds an unavailable conformance). Keep the repository `@MainActor` rather than trying to cross actor boundaries with models.
- **Never read a `@Model`'s *array* attribute from a `View`'s `body`.** Reading an array attribute of a deleted object **traps**; scalars survive by returning the last value, which is why the bug only shows up on collection properties and only after a delete. Take a snapshot in `@State` and refresh it with `.task(id: model.modifiedAt)` — a scalar trigger, readable even when deleted — going through the entity's `@DeferredProperty` (which re-fetches by id). The same applies to a sheet's `content` closure, which can be re-evaluated while presented. [measured 2026-08-29]

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
