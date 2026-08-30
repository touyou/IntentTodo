# UI integration

## Intent → UI navigation

Two patterns, opposite directions of knowledge. Both are valid.

| Pattern | Who knows whom | Notes |
|---|---|---|
| `@Dependency var navigationModel` written in `perform()` | the intent knows app state | works everywhere including macOS/watchOS, survives cold start |
| `.onAppIntentExecution(MyIntent.self)` on a `Scene` | the app knows the intent | declarative, iOS/visionOS only |

Prefer the first when cold-start reliability matters, which for a widget or control launch it always does.

### `@Dependency` + a navigation model (the default)

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

#### Dismissal belongs to `perform()` too

A sheet whose submit button runs `AddTodoIntent` should be closed by the intent (`navigationModel.dismissAddSheet()`), not by a `dismiss()` in the button's action. A `dismiss()` alongside `Button(intent:)` runs whether the intent succeeded or not, so a validation failure closes the sheet and looks like a successful save.

One rule to keep: **intent completion is what closes the sheet**, one-to-one.

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
- **macOS and watchOS cannot use it.** `TargetContentProvidingIntent` is `@available(macOS, unavailable)` / `@available(watchOS, unavailable)` [measured, Xcode 27 beta 5–6]. Guard conformance with `#if os(iOS) || os(visionOS)`.
- **`canImport` is the wrong test.** `_AppIntents_SwiftUI.framework` *does* exist in the macOS SDK, so `canImport` is true there; only the `onAppIntentExecution` declaration is missing from the macOS slice. Guard on `os()`. [measured 2026-08-12]
- **Cold start is still shaky.** Even with the "fixed in iOS 26.4" note in Apple's workshop material, cold-start navigation through this path did not complete reliably on device [measured].

```swift
#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}
#endif
```

`AppIntentSceneDelegate` gives the same hook at scene level, which is the right place when you need to pick *which window* handles the intent.

### `UISceneAppIntent` (multi-window)

`UISceneAppIntent` lives in `_AppIntents_UIKit` and **works fine inside a Swift package** — verified by building a probe for iOS simulator, My Mac and visionOS simulator [measured 2026-08-12]. The guard is the subtle part: watchOS *has* the framework (so `canImport` is true) but not the type.

```swift
#if canImport(_AppIntents_UIKit) && !os(watchOS)
```

## Telling the person the shortcuts exist

Two system views, and neither belongs everywhere:

- **`SiriTipView`** — a dismissible tip for one shortcut. Show it contextually and let it stay dismissed; a permanently mounted tip is chrome the person cannot remove.
- **`ShortcutsLink`** — sends the person to your shortcuts in the Shortcuts app. This belongs in settings or an "about" area, not in the main flow.

## View structure

- Extract sections into `private struct: View`, not computed `some View` properties. A computed property is not a diffing unit, so the parent `body` re-evaluates wholesale.
- `@Observable` classes are `@MainActor`; never `ObservableObject`.
- Business logic (CRUD, search execution) belongs to intents/service. View models hold **UI** state only: filter, sort order, search text.
- Share derived domain logic (a "due soon / overdue" rule, say) as a `Domain` value type rather than reimplementing thresholds per platform.
- **Do not read a SwiftData `@Model`'s array attribute from `body`** — it traps on a deleted object. Snapshot it in `@State`, refreshed via a scalar trigger (`app-intents-centric-design`).
- UI copy in a Swift package needs the package's own catalog and accessor, or it is never extracted (`app-intents-localization`).
