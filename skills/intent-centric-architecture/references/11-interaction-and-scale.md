# 11 — Interaction, scale and system integration

Intents that ask questions, render UI, process hundreds of items, or answer the camera.

## Asking the user mid-`perform()`

### `requestConfirmation`

```swift
try await requestConfirmation(dialog: IntentDialog("Delete “\(todo.title)”?"))
try todoService.delete(todoId: todo.id)
```

Throws (cancelling the intent) when declined. Put it before any irreversible work — `perform()` is retriable ([07](07-data-and-side-effects.md)).

### `requestChoice`

The multi-way version [Apple: wwdc2026-343]:

```swift
let choice = try await requestChoice(
    between: [
        IntentChoiceOption(title: "30 minutes"),
        IntentChoiceOption(title: "1 hour"),
        .cancel,
    ],
    dialog: IntentDialog("Snooze “\(todo.title)” for how long?")
)
```

- Returns the chosen `IntentChoiceOption`. It is `Equatable` but has no stable identifier, so keep options and their meanings in **one** enum and match with `IntentChoiceOption(title:) == choice` — otherwise the option list and the mapping drift apart.
- Including `.cancel` means selecting it throws a cancellation error.
- `style` is `.default` / `.destructive` / `.cancel`. `requestChoice(between:dialog:view:)` also exists.
- Callable from a `.background` intent: it surfaces in the Siri / Shortcuts UI.

### ⚠️ Both are Siri/Shortcuts-only

From an in-app button, widget button or control, they fail with `LNPerformActionErrorCodeUnsupportedValueType` and **nothing visible happens** [measured 2026-08-12]. Keep a non-interactive twin for those callers ([01](01-actions-and-entities.md), [05](05-ui-integration.md)). Note they also cannot be exercised by AppIntentsTesting ([09](09-verification.md)).

## Interactive snippets

A `SnippetIntent` returns SwiftUI; the host intent attaches it.

```swift
public struct TodoSummarySnippetIntent: SnippetIntent {
    public static let isDiscoverable = false     // presented via snippetIntent:, not Shortcuts

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        let summary = try TodoEntityStore.summary()      // re-read every time
        return .result(view: SummaryView(summary: summary))
    }
}

// host intent
return .result(value: count, dialog: dialog, snippetIntent: TodoSummarySnippetIntent())
```

- Buttons inside a snippet run intents with `Button(intent:)`, exactly like a widget.
- **Every button press re-runs the whole `SnippetIntent`**, so `perform()` must re-fetch current state rather than close over a stale snapshot.
- Snippets render in Siri, Spotlight and Shortcuts — **not in Control Center** ([06](06-feedback-channels.md)).
- Snippet bodies cannot use `@Dependency` on the entity side; read the ambient store ([04](04-process-and-dependencies.md)) — and register that store in the widget extension too, or the snippet renders empty when resolved there [measured 2026-08-12].

## System intents

Conform to the protocol directly; no schema macro needed. The system then understands the action semantically (tap a Spotlight result → open; delete from a list → delete).

| Protocol | Requirement | Notes |
|---|---|---|
| `OpenIntent` | `var target: Target` where `Target: AppEntity` | associated type inferred from `target`; use `.foreground(.immediate)` |
| `DeleteIntent` (`: SystemIntent`) | `var entities: [Entity]` — an **array** | a single-entity delete intent cannot conform; make a separate bulk intent |

Neither needs an App Shortcut slot — they are understood without one, which protects the 10-slot budget ([02](02-multi-surface-mapping.md)). The wider catalogue of semantic conformances (media, camera, search, Focus, prediction) is in [12](12-surface-catalog.md).

### `UndoableIntent`

For a destructive or surprising action, conforming buys the gesture people already know: "swipe left with three fingers to trigger undo". Register your undo actions with the `undoManager` the protocol hands you — the system supplies "the most relevant undo manager through this property, even when those intents are run in your extensions", which keeps UI and intent undo in one stack. [Apple: wwdc2025-275 15:19–16:06]

Combines naturally with `requestChoice`: offer "Archive" as an alternative before deleting, and undo as the safety net after. Not exercised here [inferred for behaviour details] — verify the stack ordering before promising it.

### `DeprecatedAppIntent`

The retirement path. A shortcut someone built keeps a reference to your intent type, so deleting the type breaks their automation silently. `DeprecatedAppIntent` marks the action as retired and names its `ReplacementIntent`, so the system can tell them what to use instead. [Apple: app-intent-types] Same discipline as `AppEnum` raw values ([01](01-actions-and-entities.md)): the public surface is a contract with the user's automations, not just with the compiler.

**Every entity a Visual Intelligence value query can return must be openable** — "This `OpenIntent` must exist, otherwise your app won't show up" [Apple: wwdc2025-275 9:19]. The requirement is cross-platform, but it is only **enforced at compile time on the macOS destination**: `result type 'X' that is not openable … must be associated with an OpenIntent`. If a union type returns two entity kinds, both need one — even if one of them has no dedicated screen and its `perform()` just opens the app.

## Partial updates: `IntentParameter.valueState`

An update intent must distinguish "new value" / "clear it" / "leave it alone". A plain `nil` check collapses the last two.

```swift
// $param.valueState is IntentParameter<Value>.ValueState: .set(Value) | .unset
// For an optional parameter: .set(nil) == explicit clear, .unset == not supplied
```

[Apple: wwdc2026-344 20:17]

Mirror it in the Service with `enum FieldUpdate<Value> { case unchanged, set(Value) }`:

- optional model column: `if case .set(let v) = state { .set(v) } else { .unchanged }` — passes `.set(nil)` through.
- required model column exposed as optional: `if case .set(let v?) = state { .set(v) } else { .unchanged }` — `.set(nil)` means leave alone, since the column cannot be emptied.

Testing this needs a **typed nil** ([09](09-verification.md)); plain `nil` is `.unset`.

## Scale: hundreds of entities

`CompleteTodosIntent` combines three APIs [Apple: wwdc2026-345]:

```swift
public struct CompleteTodosIntent: AppIntent, LongRunningIntent, CancellableIntent {
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Todos") public var todos: EntityCollection<TodoAppEntity>
    @Dependency var todoService: TodoService

    public func perform() async throws -> some IntentResult {
        let ids = todos.identifiers            // no full entity resolution
        progress.totalUnitCount = Int64(ids.count)

        try await performBackgroundTask(operation: { [progress] in
            for (i, id) in ids.enumerated() {
                try Task.checkCancellation()
                try await todoService.markCompleted(id)   // hops to MainActor
                progress.completedUnitCount = Int64(i + 1)
            }
        }, onCancel: { reason in /* clean up */ })

        return .result()
    }
}
```

- **`EntityCollection<T>`** skips per-id entity resolution at parameter time — a large saving in memory and latency [Apple: wwdc2026-345 8:09]. Use `.identifiers` when ids suffice; `resolvedEntities()` only when you need the whole entity.
- **`LongRunningIntent`** (`: ProgressReportingIntent`) extends the background window via `performBackgroundTask` — but **you must keep updating `progress` or the system cuts the extension short** [Apple: wwdc2026-345 13:55].
- **`CancellableIntent`** supplies `onCancel: (IntentCancellationReason) -> Void`; check `Task.checkCancellation()` in the loop.
- Concurrency: the operation closure is nonisolated `async`, so `try await service.method()` hops to `@MainActor` safely — `perform()` itself does not need `@MainActor`.
- Pinning `allowedExecutionTargets` to `[.main]` is reasonable for bulk persistence work ([04](04-process-and-dependencies.md)).

## Visual Intelligence

```swift
#if canImport(VisualIntelligence) && !os(visionOS)
import VisualIntelligence

public struct TodoVisualIntelligenceQuery: IntentValueQuery {
    @Dependency var todoService: TodoService        // value queries CAN use @Dependency

    public func values(for input: SemanticContentDescriptor) async throws -> [TodoOrCategory] {
        let labels = input.labels                   // generic English labels, en_US, no synonyms
        let todos = try await MainActor.run { try todoService.listTodos(filter: .all) }
        return todos.filter { t in labels.contains { t.title.localizedCaseInsensitiveContains($0) } }
                    .map(TodoOrCategory.todo)
    }
}
#endif
```

- `SemanticContentDescriptor` carries `labels: [String]` and `pixelBuffer: CVReadOnlyPixelBuffer?`. Labels are generic — no proper nouns, English only, no synonyms or translations.
- Returning a `@UnionValue` array is the value query's advantage over `EntityQuery`: results are not confined to one entity type.
- `values(for:)` is nonisolated — hop to `@MainActor` for the fetch, then filter off-actor on `Sendable` values.
- **One `SemanticContentDescriptor`-taking `IntentValueQuery` per app** [Apple: wwdc2026-297 11:39]. To span more types, widen the union — you cannot add a second query.
- No registration needed; the system discovers it. No App Shortcut needed.
- `@AppIntent(schema: .visualIntelligence.semanticContentSearch)` handles "More results" — it only requires a `semanticContent` parameter, so it avoids the entity-property pitfalls of the richer schemas ([10](10-advanced-entity-apis.md)).
- Reuse rather than invent: results tapping through uses your existing `OpenIntent`, multiple result types use your existing union.

## Onscreen entities

Tell Siri what the person is looking at.

```swift
// single entity (detail screen)
.userActivity("com.example.MyApp.ViewingTodo") { activity in
    activity.title = String(localized: "Viewing \(todo.title)")
    activity.appEntityIdentifier = EntityIdentifier(for: entity)
}

// a collection (list) — ids are mapped lazily
List(todos) { … }
    .appEntityIdentifier(forSelectionType: TodoAppEntity.self) {
        EntityIdentifier(for: TodoAppEntity.self, identifier: $0.id)
    }
```

- The activity type string must also be listed in `Info.plist` under `NSUserActivityTypes`, matching exactly.
- `appEntityIdentifier` / `EntityIdentifier` come from `AppIntents` — `import AppIntents` in the view file.
- The `forSelectionType:` form is what makes "the third one" work on long lists without mapping every id upfront.
- Cover this with `viewAnnotations()` in AppIntentsTesting ([09](09-verification.md)).
