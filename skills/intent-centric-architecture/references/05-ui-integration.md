# 05 — UI integration

How the app's own UI triggers intents, and how intents drive the app's navigation.

## `Button(intent:)` is the execution path

```swift
import AppIntents   // required for Button(intent:)

Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark.circle")
}

Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
    Label("Delete", systemImage: "trash")
}
```

Same execution path as Siri and Shortcuts, no boilerplate, no duplicated logic.

**Argument order: `role` comes first.** `Button(intent:role:)` resolves to a different init and fails with `"extraneous argument label 'intent:'"`. [measured — hit on a visionOS build] Note that `Button(role:intent:)` does not exist on watchOS; drop `role:` there, plain `Button(intent:)` works everywhere.

### Never call `perform()` yourself

```swift
// ❌ crashes: @Dependency is zero-initialised, the ModelContainer access traps
Button { Task { try? await AddTodoIntent(title: t).perform() } } label: { … }

// ✅ system dispatch resolves dependencies
Button(intent: AddTodoIntent(title: t)) { … }
```

`@Dependency` is injected by the system when it dispatches the intent. A manual call skips that entirely. `scripts/audit_intents.py` flags this (`manual-perform`).

### ⚠️ Interactive intents cannot be called from a button

An intent that calls `requestConfirmation` or `requestChoice` **fails when invoked from an in-app or widget button** — there is no surface to answer on. It fails with `LNPerformActionErrorCodeUnsupportedValueType`, **shows no error, and nothing happens**. [measured 2026-08-12]

This is nasty for three reasons: it looks like a dead button, the same intent succeeds through Siri / Shortcuts / AppIntentsTesting, and therefore **AppIntentsTesting cannot catch it** — only a UI test can, and only one that asserts unconditionally ([09](09-verification.md)).

The pattern:

```swift
// Siri / Shortcuts: the intent asks.
public struct DeleteTodoIntent: AppIntent {
    public func perform() async throws -> some IntentResult {
        try await requestConfirmation(dialog: IntentDialog("Delete “\(todo.title)”?"))
        try todoService.delete(todoId: todo.id)
        return .result()
    }
}

// UI: SwiftUI asks, then runs the non-interactive twin (isDiscoverable = false).
.confirmationDialog("Delete this todo?", isPresented: $showingDelete) {
    Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) {
        Text("Delete")
    }
}
```

## Intent → UI navigation

Two patterns, opposite directions of knowledge. Both are valid.

| Pattern | Who knows whom | Notes |
|---|---|---|
| `@Dependency var navigationModel` written in `perform()` | the intent knows app state | works everywhere including macOS/watchOS, survives cold start |
| `.onAppIntentExecution(MyIntent.self)` on a `Scene` | the app knows the intent | declarative, iOS/visionOS only |

### `@Dependency` + `NavigationModel` (the default here)

```swift
@MainActor @Observable
public final class NavigationModel {
    public var showingAddTodo = false
    public var pendingFilter: TodoFilterType?
    public var pendingSearchText: String?
    public init() {}
}

struct LaunchAppIntent: AppIntent {
    static let supportedModes: IntentModes = [.foreground(.immediate)]
    @Dependency var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showAddTodo()
        return .result()
    }
}
```

`perform()` runs in the intent's own context, so it can write before any scene exists; the `@Observable` change is picked up when the scene appears. Register the *same* instance in `AppDependencyManager` and pass it to views via `.environment()`.

#### Pending-value handshake

For "open **in this state**", write a `pending…` value, let the view transfer it into its own state, then clear it. Handling both `.onChange` and `.onAppear` is what makes cold start reliable — the intent may run before the view exists.

```swift
.onChange(of: navigationModel.pendingFilter) { _, new in applyPendingFilter(new) }
.onAppear { applyPendingFilter(navigationModel.pendingFilter) }

private func applyPendingFilter(_ filter: TodoFilterType?) {
    guard let filter else { return }
    viewModel.filter = TodoFilter(filter)
    navigationModel.pendingFilter = nil      // always clear, or it reapplies
}
```

> Adding a case to the target enum is only half the work. If `perform()`'s `switch` has no branch writing the state, the intent just opens the app — "show my favourites" from Siri and a count control both land on an unfiltered list, with nothing failing anywhere. [measured 2026-08-12]

### `onAppIntentExecution` — iOS/visionOS only

```swift
struct ShowTodoDetailIntent: TargetContentProvidingIntent {   // already an AppIntent
    @Parameter(title: "Todo") var todo: TodoAppEntity
    func perform() async throws -> some IntentResult { .result() }
}

WindowGroup { RootView() }
    .onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
        navigation.path.append(.todo(intent.todo.id))
    }
```

Constraints worth knowing before choosing it:

- **The closure runs *before* `perform()`.** "If the app intent implements a `perform()` method, it will be called after the action closure." [Apple] Navigating in both places double-navigates — pick one.
- **macOS and watchOS cannot use it.** `TargetContentProvidingIntent` is `@available(macOS, unavailable)` / `@available(watchOS, unavailable)` [measured, Xcode 27 beta 5]. Guard conformance with `#if os(iOS) || os(visionOS)`.
- **`canImport` is the wrong test.** `_AppIntents_SwiftUI.framework` *does* exist in the macOS SDK, so `canImport` is true there; only the `onAppIntentExecution` declaration is missing from the macOS slice. Guard on `os()`. [measured 2026-08-12]
- **Cold start is still shaky.** Even with the "fixed in iOS 26.4" note in Apple's workshop material, cold-start navigation through this path did not complete reliably on device [measured]. This project uses the `@Dependency` pattern as the primary route for that reason.

```swift
#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif
```

### `UISceneAppIntent` (multi-window)

`UISceneAppIntent` lives in `_AppIntents_UIKit` and **works fine inside a Swift package** — verified by building a probe for iOS simulator, My Mac and visionOS simulator [measured 2026-08-12]. The guard is the subtle part: watchOS *has* the framework (so `canImport` is true) but not the type.

```swift
#if canImport(_AppIntents_UIKit) && !os(watchOS)
```

## View structure

- Extract sections into `private struct: View`, not computed `some View` properties. A computed property is not a diffing unit, so the parent `body` re-evaluates wholesale.
- `@Observable` classes are `@MainActor`; never `ObservableObject`.
- Business logic (CRUD, search execution) belongs to intents/Service. View models hold **UI** state only: filter, sort order, search text.
- Share derived domain logic (a "due soon / overdue" rule, say) as a `Domain` value type rather than reimplementing thresholds per platform.
