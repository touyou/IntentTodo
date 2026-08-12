# 09 — Verification

App Intents fail quietly. The build is green, the IDE is clean, and the feature simply never appears. This is the order Apple prescribes for finding that out, and what each rung can and cannot prove.

## The ladder

[Apple: wwdc2026-240 24:13–25:57, "progressive validation"]

| Rung | Tool | Proves |
|---|---|---|
| 1 | **AppIntentsTesting** | business logic, in isolation — "entirely in isolation. **No Siri involved.**" |
| 2 | **Shortcuts app** | the shape of the intent: parameters, parameter summary, action list |
| 3 | **Spotlight** | that content is indexed and findable |
| 4 | **Siri** | natural language, entity resolution, onscreen references, cross-app — end to end |

**Rung 4 cannot be automated.** "Be sure to test your intents **manually** with Siri and the Shortcuts app" [Apple: wwdc2026-295 24:46]. AppIntentsTesting's public API contains no phrase / utterance / shortcut symbol at all, and it looks intents up by **type name** — the `AppShortcutsProvider` phrase path is structurally out of reach.

Before doing anything by hand, ask what could be a test instead. Manual checks do not catch regressions; tests do.

Below the ladder sit two static rungs that cost nothing:

```bash
python3 scripts/audit_intents.py .                       # architectural rules
python3 scripts/inspect_appintents_metadata.py --find MyProject   # what the system will read
```

## Rung 0: the metadata

App Intents are not the Swift types you wrote — they are the `Metadata.appintents` bundle the build produced. Reading it directly catches things nothing else reports:

- `autoShortcuts: 0` → the `AppShortcutsProvider` registered nothing (usually: it is in a package). [see [04](04-process-and-dependencies.md)]
- An entity with `0 props` → nothing about it is visible to Shortcuts filters, Siri or Spotlight.
- No `assistantDefinedSchemas` entry on a type you annotated with `@AppEntity(schema:)` → the schema conformance did not land, even though `displayTypeName` shows the macro ran.
- An action present in the package bundle but missing from the app bundle → target membership or `includedPackages` problem.

```bash
python3 scripts/inspect_appintents_metadata.py --find MyProject -v
# or, by hand:
python3 -c "import json;d=json.load(open('<...>/MyApp.app/Metadata.appintents/extract.actionsdata'));\
print({k:len(v) for k,v in d.items() if isinstance(v,(list,dict))})"
```

## Rung 1: AppIntentsTesting

### It must be a UI test bundle

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

### The API is string-keyed

`IntentDefinitions(bundleIdentifier:)` discovers intents, entities, enums and queries; subscripts key on **type name**:

```swift
let entity = try await definitions.entities["TodoAppEntity"].suggestedEntities().first!
let result = try await definitions.intents["ToggleTodoCompletionIntent"]
    .makeIntent(todo: entity)
    .run()
let title: String = try result.value.title      // dynamic member lookup
```

Because the app target is never imported, **most mistakes surface at runtime, not compile time**. Design tests to create with a unique title, act, then delete — self-cleaning.

### Pitfalls, all measured 2026-08-12 across 22 tests

| Symptom | Cause / fix |
|---|---|
| `entity.id` → `castingFailed(elementType: "NSNull", targetType: "String")` | Dynamic lookup only sees `@Property` members, and `id` usually isn't one. Use `entity.identifier.instanceIdentifier`. |
| Simulator dies intermittently as the suite grows | `app.launch()` in `setUp`. Use `activate()`. |
| First test after a clean build fails with `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"` | The metadata service hasn't seen the new app yet. Poll a cheap query (`suggestedEntities()`) until it succeeds, then start. |
| `makeIntent(x: nil)` doesn't clear the value | `nil` becomes `.unset` (parameter not supplied), not `.set(nil)`. Pass a **typed** nil: `let explicitNull: any IntentValueExpressing = String?.none`. Misreading this looks exactly like an app bug — it was misdiagnosed as one once. |
| `valueQueries["…"]` not found | `VisualIntelligence.framework` is absent from the **iOS simulator** SDK, so the query isn't compiled in. Test on device or macOS. |
| `spotlightQuery()` returns empty right after `run()` | Indexing is asynchronous. Poll with a timeout. |
| An intent using `requestChoice` / `requestConfirmation` can't be run | Nothing can answer. Keep a non-interactive twin and test that ([01](01-actions-and-entities.md)). |

### What to cover here

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

If your UI test target is a synchronized folder in the Xcode project, adding files (including subfolders) is enough — no target-membership dance. `setUp` must be `@MainActor override func setUp() async` or `XCUIApplication`'s isolation trips Swift 6.

## Tests that lie

**Never write a conditional assertion.**

```swift
// ❌ green when the element never appears
if deleteButton.waitForExistence(timeout: 3) {
    deleteButton.tap()
    XCTAssertFalse(row.exists)
}

// ✅
XCTAssertTrue(deleteButton.waitForExistence(timeout: 3))
deleteButton.tap()
XCTAssertFalse(row.exists)
```

This exact shape concealed a **completely non-functional delete path** for months: the confirmation-based intent was failing silently from `Button(intent:)` ([05](05-ui-integration.md)), and the test never entered the branch. `scripts/audit_intents.py` flags it (`conditional-assert`).

The related lesson: an intent that works through Siri and AppIntentsTesting can still be broken from the UI, because the caller changes the behaviour. **UI tests are not redundant with intent tests.**

## What stays manual

After all of the above, exactly three things need a human:

1. **App Shortcut phrase routing** — say one phrase to Siri.
2. **How system UI actually looks** — dialog read aloud, snippet rendering, control appearance.
3. **Anything the simulator lacks** (Visual Intelligence).

Keep that list short and explicit. Everything else belongs on a rung below.

## Method for settling "does surface X do Y?"

1. Build the smallest probe that isolates **one** variable.
2. Run the *same* intent from two callers, changing nothing else.
3. Record the result with date, OS and Xcode version, and label it `[measured]`.
4. If you cannot run it, label the claim `[inferred]` and do not design around it.

Positive lists in documentation do not imply exclusion, and demos can be ambiguous. Both traps have produced wrong designs here ([06](06-feedback-channels.md)).
