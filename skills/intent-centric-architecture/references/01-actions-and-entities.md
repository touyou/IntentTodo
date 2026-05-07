# 01 — Actions and entities

How to pick the smallest useful set of `AppIntent` and `AppEntity` types.

## The verb–noun rule

For every use case, write a sentence: **"*\<who\>* can *\<verb\>* *\<noun\>*"**.

- The verb is an `AppIntent` candidate.
- The noun is an `AppEntity` candidate.
- "*who*" is rarely a system-facing entity — it is usually implicit (the signed-in user).

Examples:

| Use-case sentence | Intent | Entity |
|---|---|---|
| User can **add** a **todo**. | `AddTodoIntent` | (input is `String`, no entity needed for input) |
| User can **toggle completion** on a **todo**. | `ToggleTodoCompletionIntent` | `TodoAppEntity` |
| User can **filter** todos by **category**. | `FilterTodosIntent` | `CategoryAppEntity` |

If a sentence has no clear verb or noun, it is probably a screen, not an action — drop it from the first pass.

## Entity surface rules

`AppEntity` is **not** your persistence model. Strip it down to:

1. `id` — stable identifier the system can route on.
2. `displayRepresentation` — title, optional subtitle, optional image.
3. The few extra fields the system actually consumes (e.g. for widget configuration or Spotlight ranking).

Anything else (timestamps, internal flags, foreign keys) stays in your domain model and never reaches the entity boundary.

```swift
struct TodoAppEntity: AppEntity, IndexedEntity {
    var id: String
    @Property(title: "Title") var title: String
    @Property(title: "Is completed") var isCompleted: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: isCompleted ? "Done" : "Open")
    }

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    static let defaultQuery = TodoEntityQuery()
}
```

### `AppEnum` before `AppEntity`

For closed sets (tabs, modes, sort orders, visibility levels), use `AppEnum`. It is cheaper to reason about and the system displays it as a fixed picker.

Reach for `AppEntity` only when the set is dynamic, fetched from a store, or large.

### `IndexedEntity` for Spotlight

If users should be able to search your entities from Spotlight, conform to `IndexedEntity` and call your indexing pipeline (e.g. `CSSearchableIndex`) at the right moments — typically on app launch (low priority `Task(priority: .utility)`) and after mutations.

## EntityQuery — only when it earns its keep

Add `EntityQuery` when you need at least one of:

- **Disambiguation** — Siri or Shortcuts asks "which one?" and the system needs to fetch candidates.
- **Suggested entities** — picker UX in Shortcuts editor or Widget configuration.
- **Dependent parameters** — one parameter narrows the choices for another (`@IntentParameterDependency`).

If your Intent only ever runs on an entity the *caller already has* (e.g. a widget passing through the todo it is rendering), `EntityQuery` is optional — and avoiding it sidesteps a whole class of cross-process bugs (see Primary vs FromExtension below).

## Primary vs FromExtension intent split

The single most important pattern in this skill.

**Problem.** When an intent declares `@Parameter var todo: TodoAppEntity`, App Intents resolves the entity **before** `perform()` runs by calling `TodoEntityQuery.entities(for:)`. If the intent is invoked from a **Live Activity** or **Widget Extension** process, that resolution happens in the extension process — and Apple's frameworks (notably SwiftData) can trap with internal assertions when fetched from the wrong process.

**Solution.** Split the same logical action into two Intent types:

| Variant | Caller | Parameter type | `isDiscoverable` | `AppShortcuts` |
|---|---|---|---|---|
| **Primary** | Siri / Shortcuts / UI `Button(intent:)` | `MyAppEntity` (via `@Parameter`) | `true` (default) | ✅ |
| **FromExtension** | Live Activity / Widget that already holds the id | `String` (the UUID) | `false` | ❌ |

Both forward to a single `Service` method, so behavior stays identical.

```swift
public struct ToggleTodoCompletionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle todo"
    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency public var todoService: TodoService

    public func perform() async throws -> some IntentResult {
        try todoService.toggleCompletion(id: todo.id)
        return .result()
    }
}

public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle todo (extension)"
    public static let isDiscoverable = false

    @Parameter(title: "Todo ID") public var todoId: String
    @Dependency public var todoService: TodoService

    public func perform() async throws -> some IntentResult {
        try todoService.toggleCompletion(id: todoId)
        return .result()
    }
}

#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
```

Mark Live Activity buttons with `LiveActivityIntent` to force execution into the **app process** (see `04-process-and-dependencies.md`). Widget `Button(intent:)` with `.background` still runs in the widget extension, so the extension must register the same `@Dependency` graph.

## Naming conventions

- Intents: imperative verb + object + `Intent`. e.g. `AddTodoIntent`, `ToggleFavoriteIntent`, `SnoozeTodoIntent`.
- Entities: noun + `AppEntity` (or `Entity`). e.g. `TodoAppEntity`, `CategoryAppEntity`.
- Enums: noun + `IntentValue` or domain noun. e.g. `TodoSortOrder`, `SectionIntentValue`.
- FromExtension variants: append `FromExtensionIntent`. e.g. `ToggleTodoCompletionFromExtensionIntent`.

Consistent naming makes the Shortcuts gallery and Siri training data legible without extra annotation.
