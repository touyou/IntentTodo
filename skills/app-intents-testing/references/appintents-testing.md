# AppIntentsTesting

## It must be a UI test bundle

"App Intents Testing runs your intents in a **live app process**, so put the tests in a UI testing bundle rather than a unit test bundle" [Apple]. An SPM test target cannot work: the tests need a running app with a populated `AppDependencyManager`.

**The test runner and the app must be signed with the same development team** [Apple: wwdc2026-295 2:54]. On CI or with multiple Apple IDs this is the first thing to check when everything fails for no visible reason.

```swift
import AppIntentsTesting

@MainActor override func setUp() async throws {
    app = XCUIApplication()
    // activate(), never launch(): launch() terminates and restarts a running app,
    // and with ~10 tests the simulator starts failing with
    // "did not return a process handle nor launch error".
    if app.state == .runningForeground || app.state == .runningBackground {
        app.activate()
    } else {
        app.launch()
    }
    definitions = IntentDefinitions(bundleIdentifier: "com.example.MyApp")
    try await waitUntilMetadataIsReady()      // see below
}
```

`setUp` must be `@MainActor override func setUp() async` or `XCUIApplication`'s isolation trips Swift 6.

If your UI test target is a synchronized folder in the Xcode project, adding files (including subfolders) is enough — no target-membership dance. **The target itself still has to be in the scheme's `TestAction`** ([tests-that-lie](tests-that-lie.md)).

## The API is string-keyed

`IntentDefinitions(bundleIdentifier:)` discovers intents, entities, enums and queries; subscripts key on **type name**:

```swift
let entity = try await definitions.entities["TodoAppEntity"].suggestedEntities().first!
let result = try await definitions.intents["ToggleTodoCompletionIntent"]
    .makeIntent(todo: entity)
    .run()
let title: String = try result.value.title      // dynamic member lookup
```

Because the app target is never imported, **most mistakes surface at runtime, not compile time**. Design tests to create with a unique title, act, then delete — self-cleaning.

## Pitfalls, all measured

| Symptom | Cause / fix |
|---|---|
| `entity.id` → `castingFailed(elementType: "NSNull", targetType: "String")` | Dynamic lookup only sees `@Property` members, and `id` usually isn't one. Use `entity.identifier.instanceIdentifier`. |
| Simulator dies intermittently as the suite grows | `app.launch()` in `setUp`. Use `activate()`. |
| First test after a clean build fails with `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"` | The metadata service hasn't seen the new app yet. Poll a cheap query (`suggestedEntities()`) until it succeeds, then start. |
| `makeIntent(x: nil)` doesn't clear the value | `nil` becomes `.unset` (parameter not supplied), not `.set(nil)`. Pass a **typed** nil: `let explicitNull: any IntentValueExpressing = String?.none`. The symptom is indistinguishable from an app-side bug, so suspect the test first. |
| `castingFailed(elementType: "DateComponents", targetType: "Date")` after a model change | Dynamic member lookup **compiles fine** against the wrong type. The entity exposes whatever the property actually is; assert at that granularity. |
| A stored property is unreadable from `AnyAppEntity` | It is not a `@Property`. Only the projected surface exists here. |
| `valueQueries["…"]` not found | `VisualIntelligence.framework` is absent from the **iOS simulator** SDK, so the query isn't compiled in. Test on device or macOS. |
| `spotlightQuery()` returns empty right after `run()` | Indexing is asynchronous. Poll with a timeout. |
| An intent using `requestChoice` / `requestConfirmation` can't be run | Nothing can answer. Keep a non-interactive twin and test that (`app-intents-parameters-and-prompts`). |
| Everything fails on watchOS | `run()` does not work there — see below. |

## Platform limits

- **watchOS: `run()` fails** (error 4025), so intent execution cannot be exercised at all. Cover the watch by testing the shared service and entity layer with unit tests, plus a UI test for the watch app's own flow — do not write watch AppIntentsTesting cases that can only ever be skipped.
- **iOS simulator: no `VisualIntelligence`**, so `IntentValueQuery` cases must run on device or macOS.
- Live Activity and Control Center invocation paths are not reachable; both stay manual.

## What to cover

Prioritise paths that **fail invisibly** — where nothing else goes red:

| Aspect | API | Symptom when broken |
|---|---|---|
| entity id resolution | `entities(identifiers:)` | Live Activity / widget buttons do nothing |
| enumerable query | `allEntities()` | Shortcuts list is empty |
| suggestions | `suggestedEntities()` | parameter picker is blank |
| Spotlight index | `spotlightQuery(_:)` | disappears from search and Siri only |
| transient entity | `run()` → `result.value.<prop>` | Shortcuts conditionals break |
| value representation | `AnyAppEntity.exported(as:)` | hand-off to other apps breaks |
| onscreen entity | `viewAnnotations()` | Siri stops recognising what's on screen |
| partial update tri-state | `valueState`, typed nil | fields can't be cleared from Shortcuts |
| navigation | `run()` then assert with `XCUIApplication` | intent "just opens the app" |
| value query | `valueQueries["…"].values(for:)` | Visual Intelligence returns nothing (**device/macOS only**) |

Cover `viewAnnotations()` **per annotated screen**, not once. Apple's own samples carry one test per surface (detail sheet, each list segment, a `Canvas`, a card stack) because each uses a different annotation form and each fails independently (`app-intents-system-surfaces`).

Two more that are worth a test each because no linter knows them:

- **`allowedExecutionTargets = [.main]` on every mutating intent.** Enumerate the intents whose `perform()` reaches a mutating service method and assert the declaration. A forgotten one has no symptom (`app-intents-execution-and-processes`).
- **Parameter reachability.** Compare each intent's `@Parameter` set with its parameter summary. Cheaper as a metadata check than a test, but it belongs in CI either way (`app-intents-parameters-and-prompts`).

## Getting to a known state

Two approaches, and the trade is explicit:

| | Ship-nothing (self-cleanup) | Seed intents |
|---|---|---|
| How | each test creates uniquely-titled fixtures and deletes them in teardown | `#if DEBUG` + `isDiscoverable = false` intents (`ResetTestDataIntent`, `SeedSampleEventsIntent`, `ClearSpotlightIntent`) run from `setUp()` [Apple: sample code] |
| Adds to the shipping binary | nothing | nothing in release; the intents exist in debug builds |
| Test independence | weaker — tests share whatever the store already holds | strong — every test starts from the same catalogue |
| Enables | — | asserting on *absence* and on exact counts, and testing the reindex path by clearing Spotlight first |

Seed intents are the only way to assert "exactly one result" reliably. Reach for them once assertions start needing `XCTAssertFalse(...isEmpty)` because a count would be flaky.

**AppIntentsTesting should use the real shared store**, not an ephemeral one: the point is to exercise entity resolution and Spotlight indexing as they actually behave. That is the opposite of plain UI tests ([tests-that-lie](tests-that-lie.md)), which want an empty store — so the two need different launch arguments.
