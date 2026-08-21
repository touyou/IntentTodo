# 01 — Actions and entities

Picking the smallest useful set of `AppIntent` and `AppEntity` types, and knowing when *not* to split one.

## The verb–noun rule

Write every use case as a sentence: **"*\<who\>* can *\<verb\>* *\<noun\>*"**.

- The verb is an `AppIntent` candidate.
- The noun is an `AppEntity` candidate.
- "*who*" is rarely system-facing — usually the signed-in user, implicit.

| Use-case sentence | Intent | Entity |
|---|---|---|
| User can **add** a **todo** | `AddTodoIntent` | none needed (input is `String`) |
| User can **toggle completion** on a **todo** | `ToggleTodoCompletionIntent` | `TodoAppEntity` |
| User can **filter** todos by **category** | `ShowTodosIntent(filter:)` | `CategoryAppEntity` |

If a sentence has no clear verb, it is a screen, not an action. Drop it from the first pass.

## One action, one intent

**The same action uses the same intent no matter who calls it.** A Live Activity button and Siri both call `ToggleTodoCompletionIntent(todo:)`. If the caller only holds an id and a title, build a partial entity and pass it — the system re-resolves it from the id through `EntityQuery.entities(for:)` before `perform()` runs. [Apple: wwdc2026-345 7:37 — entity resolution happens before execution]

```swift
// Live Activity view — the activity only knows id + title, and that is enough.
let entity = TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark.circle.fill")
}
```

### The measurement behind it

The usual reason for splitting an intent per caller is fear of entity pre-resolution running somewhere hostile. Wiring an entity-parameter intent straight to a Live Activity lock-screen button [measured 2026-08-12, iOS 27 / Xcode 27 beta 5 simulator]:

| Case | `entities(for:)` ran in | `perform()` ran in | crash |
|---|---|---|---|
| app running + `LiveActivityIntent` | main app | main app | none |
| app killed (cold start) + `LiveActivityIntent` | main app | main app | none |
| app killed + plain `AppIntent` | main app | main app | none |

Note the contrast measured in the same session: during **widget timeline rendering**, `entities(for:)` runs in the *widget extension* process. "Entity resolution always happens in the app" is false in general — it is specific to Live Activity buttons. See [04](04-process-and-dependencies.md).

### The only legitimate reasons to split

Split on **behaviour**, never on which process calls you.

| Pair | Why they are different actions |
|---|---|
| `SnoozeTodoIntent` / `QuickSnoozeTodoIntent` | The first asks with `requestChoice`. A Live Activity button runs in the background with no surface to answer on, so the second applies a fixed 30 minutes. |
| `DeleteTodoIntent` / `DeleteTodoImmediatelyIntent` | The first asks with `requestConfirmation`. In-app buttons cannot present that (see [05](05-ui-integration.md)), so the UI confirms with `.confirmationDialog` and calls the second. |
| `ToggleTodoCompletionIntent` / `SetTodoCompletionIntent` | Toggle vs absolute set. `ControlWidgetToggle` hands you the destination state via `SetValueIntent`, which a flipping toggle cannot express. |

Internal-only twins get `isDiscoverable = false` and stay out of App Shortcuts.

### Merge intents that differ only by a value

Prefer a parameter over a new type: `ShowTodosIntent(filter: TodoFilterType)` beats four `ShowXTodosIntent` types, and it protects the 10-slot App Shortcut budget ([02](02-multi-surface-mapping.md)).

## Entity surface

`AppEntity` is **not** the persistence model. Keep it to:

1. `id` — stable across launches and devices. (Stability is what makes `SyncableEntity` free later; see [10](10-advanced-entity-apis.md).)
2. `displayRepresentation` — title, optional subtitle, optional image.
3. The few `@Property` members the system actually consumes.

**Only `@Property` members are visible to the system.** A plain `var` is invisible to Shortcuts filters, Siri and Spotlight — and to `AnyAppEntity` dynamic lookup in tests. Verify with `scripts/inspect_appintents_metadata.py`, which prints the property list the build actually emitted; an entity showing `0 props` is a display-only shell.

```swift
public struct TodoAppEntity: AppEntity, Identifiable {
    public var id: String

    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    @Property(title: "Due date") public var dueDate: Date?

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    public static let defaultQuery = TodoEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: isCompleted ? "Done" : "Open")
    }
}
```

`id` itself is normally *not* a `@Property`. That is fine at runtime, but in AppIntentsTesting the type-erased `entity.id` then fails with `castingFailed(elementType: "NSNull")` — use `entity.identifier.instanceIdentifier` there ([09](09-verification.md)).

### Check for a system shape before writing your own

The framework already models several common entity shapes, and using one tells the system more than a hand-rolled equivalent: `UniqueAppEntity` for a value that only ever has one instance (global settings — no fake query over one row), `FileEntity` when the entity *is* a document, `TransientAppEntity` for a computed snapshot nobody queries back ([10](10-advanced-entity-apis.md)). The full list is in [12](12-surface-catalog.md).

### `AppEnum` before `AppEntity`

For closed sets (filters, sort orders, screen targets), use `AppEnum`: cheaper to reason about, and the system renders a fixed picker. Reach for `AppEntity` only when the set is dynamic, stored, or large.

Two hard rules:

- **Raw values are persisted by string.** A shortcut a user built keeps the old string; renaming or renumbering a case silently breaks their automation. [Apple]
- **Every case needs a `caseDisplayRepresentations` entry** — a missing one is a runtime `fatalError`, not a compile error. [Apple]

```swift
public enum TodoFilterType: String, AppEnum {
    case all, incomplete, completed, favorites

    public static var typeDisplayRepresentation: TypeDisplayRepresentation { "Filter" }
    public static var caseDisplayRepresentations: [TodoFilterType: DisplayRepresentation] {
        [.all: "All", .incomplete: "Incomplete", .completed: "Completed", .favorites: "Favorites"]
    }
}
```

> Adding a case to a navigation-target enum does nothing on its own: the `switch` in `perform()` must write the matching state, or the new case silently falls through to "just open the app" ([05](05-ui-integration.md)).

## Queries: pick the narrowest one that works

| Protocol | Gives you | Cost |
|---|---|---|
| `EntityQuery` | `entities(for:)` — id resolution. The minimum. | none |
| `EntityStringQuery` | `entities(matching:)` — free-text lookup from Siri/Shortcuts | you filter; the framework does **not** filter for you [Apple] |
| `EnumerableEntityQuery` | `allEntities()` — the full list in the Shortcuts picker | loads everything; wrong for large stores |
| `EntityPropertyQuery` | "Find X where…" with `properties` / `sortingOptions` / `comparators` | you execute the predicate; the framework only parses it [Apple] |
| `IndexedEntityQuery` | system-driven Spotlight reindex | see [10](10-advanced-entity-apis.md) |
| `IntentValueQuery` | Visual Intelligence input; **may return a `@UnionValue`**, and *can* use `@Dependency` | see [11](11-interaction-and-scale.md) |

`suggestedEntities()` is what fills parameter pickers. Returning an empty default means "no suggestions" — users see an empty picker and assume the app is broken. If it is cheap, implement it.

**`entities(for:)` is batched** — resolve the whole `[ID]` in one fetch, not in a loop.

Queries *can* use `@Dependency`; entities cannot ([04](04-process-and-dependencies.md)).

## Naming

- Intents: imperative verb + object + `Intent` — `AddTodoIntent`, `ToggleFavoriteIntent`, `SnoozeTodoIntent`.
- Entities: noun + `AppEntity` — `TodoAppEntity`, `CategoryAppEntity`.
- Enums: domain noun — `TodoSortOrder`, `AppScreenTarget`.
- Non-interactive twins: name the behaviour, not the caller — `QuickSnoozeTodoIntent`, `DeleteTodoImmediatelyIntent`. Never `…FromWidgetIntent`; the caller is not the difference.

Consistent naming makes the Shortcuts gallery and Siri training data legible without extra annotation.
