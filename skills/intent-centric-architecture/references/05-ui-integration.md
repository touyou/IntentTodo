# 05 — UI integration: routing intents back into the scene

Most apps need *some* intents to drive the visible UI — open a detail, switch a tab, focus a list. iOS 26 provides three layered tools for this; pick the simplest one that works.

## The three tools

| API | Granularity | When to use |
|---|---|---|
| `onAppIntentExecution(_:perform:)` (iOS 26+) | Per-Intent, per-Scene | The cleanest option when targeting iOS 26.4+ on Scene-based apps |
| `AppIntentSceneDelegate` (iOS 26+) | Per-Scene | When you need lifecycle hooks beyond a single intent (e.g. opening a new window per invocation) |
| `AppDependencyManager` + `@Dependency` writes inside `perform()` | App-wide | Cold-start fallback; or when intent UI side effects need to survive Scene transitions |

## `onAppIntentExecution` — the iOS 26+ default

Attach a handler to a SwiftUI `Scene` for a specific Intent type. The closure runs whenever that Intent is invoked while the Scene is alive.

```swift
struct MyApp: App {
    @State private var navigation = NavigationModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
        }
        .onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
            navigation.path.append(.todo(intent.todo.id))
        }
        .onAppIntentExecution(OpenSectionIntent.self) { intent in
            navigation.selectedTab = intent.section.toTab
        }
    }
}
```

The Intent itself can be minimal:

```swift
struct ShowTodoDetailIntent: TargetContentProvidingIntent {
    @Parameter(title: "Todo") var todo: TodoAppEntity

    func perform() async throws -> some IntentResult { .result() }
}
```

`TargetContentProvidingIntent` inherits from `AppIntent`, so you don't write `: AppIntent` separately.

### Double-execution gotcha

If the Intent's `perform()` *also* mutates navigation state, the closure runs **after** `perform()`, and the user may see two transitions. Pick one place:

- **In the Scene closure** (`onAppIntentExecution`) for iOS 26.4+ — keeps `perform()` empty.
- **In `perform()` via `@Dependency var navigationModel`** — works on iOS 26.0–26.3 too.

Don't do both.

## `AppIntentSceneDelegate` — when Scene lifecycle matters

When you need intent execution to also influence Scene creation (multi-window apps, opening a new window per Intent), conform to `AppIntentSceneDelegate`. This is heavier than `onAppIntentExecution` and not needed for most cases.

## Cold-start fallback for early iOS 26

`onAppIntentExecution` works reliably on iOS 26.4+. On 26.0–26.3, cold-start invocations sometimes time out before the Scene's handler is registered, and the navigation appears to silently fail.

The robust fallback is to write navigation state into a shared `@Dependency` model from inside `perform()`, and let the Scene observe it on appearance:

```swift
@MainActor @Observable
public final class NavigationModel {
    public var pendingTodoId: String?
    public init() {}
}

struct ShowTodoDetailIntent: AppIntent {
    static var supportedModes: IntentModes { .foreground(.immediate) }
    @Parameter(title: "Todo") var todo: TodoAppEntity
    @Dependency var navigation: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigation.pendingTodoId = todo.id
        return .result()
    }
}

struct RootView: View {
    @Environment(NavigationModel.self) private var navigation

    var body: some View {
        @Bindable var navigation = navigation
        NavigationStack(path: $navigation.path) {
            TodoListView()
        }
        .onChange(of: navigation.pendingTodoId, initial: true) { _, id in
            guard let id else { return }
            navigation.path.append(.todo(id))
            navigation.pendingTodoId = nil
        }
    }
}
```

This pattern survives Scene re-creation because the `NavigationModel` instance lives in `AppDependencyManager`, not in the Scene. It also unit-tests cleanly because you can read/write `pendingTodoId` from a test without a Scene.

## Choosing between `.background` and `.foreground(.immediate)` for UI intents

If the Intent is meant to *open* the app (e.g. show a detail), use `.foreground(.immediate)` so the system brings the app forward before `perform()` runs. If you only want to update background data and let the user discover changes the next time they open the app, use `.background` and skip the navigation write.

Mixing the two is fine: `[.background, .foreground(.dynamic)]` lets the same Intent decide at runtime based on user context (see `03-supported-modes.md`).

## Reference

- <https://developer.apple.com/documentation/appintents/targetcontentprovidingintent>
- <https://developer.apple.com/documentation/swiftui/scene/onappintentexecution(_:perform:)>
- <https://developer.apple.com/documentation/appintents/appintentscenedelegate>
