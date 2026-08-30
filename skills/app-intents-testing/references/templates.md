# Templates — tests

## AppIntentsTesting base class

```swift
import AppIntentsTesting
import XCTest

class AppIntentsTestCase: XCTestCase {
    var app: XCUIApplication!
    var definitions: IntentDefinitions!

    @MainActor override func setUp() async throws {         // @MainActor: XCUIApplication isolation
        app = XCUIApplication()
        // No -uitest-ephemeral-store here: these tests want the REAL shared store, so
        // entity resolution and Spotlight behave as they do in production.
        if app.state == .runningForeground || app.state == .runningBackground {
            app.activate()          // launch() restarts the app and destabilises long suites
        } else {
            app.launch()
        }
        definitions = IntentDefinitions(bundleIdentifier: "com.example.MyApp")
        try await waitForMetadata()
    }

    /// The first test after a clean install fails with
    /// `AppIntentsServicesMetadataErrorDomain Code=400 "… is not present"`.
    private func waitForMetadata(timeout: TimeInterval = 20) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? await definitions.entities["TodoAppEntity"].suggestedEntities()) != nil { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTFail("App Intents metadata never became available")
    }
}
```

## A representative case

```swift
final class TodoIntentExecutionTests: AppIntentsTestCase {
    func testToggleCompletion() async throws {
        let created = try await definitions.intents["AddTodoIntent"]
            .makeIntent(title: "probe-\(UUID().uuidString)").run()
        let id: String = try created.value.identifier.instanceIdentifier   // NOT .id

        let entity = try await definitions.entities["TodoAppEntity"].entities(identifiers: [id]).first!
        let toggled = try await definitions.intents["ToggleTodoCompletionIntent"]
            .makeIntent(todo: entity).run()
        let isCompleted: Bool = try toggled.value.isCompleted
        XCTAssertTrue(isCompleted)

        // explicit clear needs a TYPED nil; plain nil means "unset"
        let explicitNull: any IntentValueExpressing = String?.none
        _ = try await definitions.intents["UpdateTodoIntent"]
            .makeIntent(todo: entity, todoDescription: explicitNull).run()

        _ = try await definitions.intents["DeleteTodoImmediatelyIntent"]
            .makeIntent(todo: entity).run()          // self-cleaning
    }
}
```

## Polling an asynchronous index

```swift
func testSpotlightIndexing() async throws {
    let title = "probe-\(UUID().uuidString)"
    let created = try await definitions.intents["AddTodoIntent"].makeIntent(title: title).run()
    let id: String = try created.value.identifier.instanceIdentifier
    defer { Task { _ = try? await deleteTodo(id: id) } }

    // Indexing is asynchronous: poll, never assert immediately after run().
    let found = try await poll(timeout: 15) {
        try await definitions.entities["TodoAppEntity"].spotlightQuery(title).isEmpty == false
    }
    XCTAssertTrue(found, "Todo never appeared in the Spotlight index")
}

private func poll(timeout: TimeInterval, _ predicate: () async throws -> Bool) async throws -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if try await predicate() { return true }
        try await Task.sleep(for: .milliseconds(500))
    }
    return false
}
```

## Onscreen annotations, one test per screen

```swift
func testTodoListAnnotations() async throws {
    let annotations = try await definitions.entities["TodoAppEntity"].viewAnnotations()
    XCTAssertFalse(annotations.isEmpty, "The list screen exposes no onscreen entities")
}
```

Each annotated screen uses a different annotation form (`List` selection type, single row, `Canvas` bounds) and each fails independently. One case per screen, not one for the app.

## Enforcing the execution-target rule

```swift
/// Mutating intents must pin the process, or a widget extension can become a second
/// writer to the shared store when the app is not running. No linter knows this rule.
func testMutatingIntentsPinExecutionTarget() {
    let mutating: [any AppIntent.Type] = [
        AddTodoIntent.self, ToggleTodoCompletionIntent.self, DeleteTodoImmediatelyIntent.self,
        SetTodoCompletionIntent.self, UpdateTodoIntent.self,
    ]
    for intent in mutating {
        XCTAssertEqual(intent.allowedExecutionTargets, [.main], "\(intent) does not pin [.main]")
    }
}
```

## UI test that catches what intent tests cannot

```swift
final class DeleteFlowUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [
            "-uitest-ephemeral-store",              // empty store: assertions about absence work
            "-AppleLanguages", "(en)",              // host language must not decide the labels
            "-AppleLocale", "en_US",
        ]
        app.launch()
        self.app = app
    }
    var app: XCUIApplication!

    /// An interactive intent invoked from Button(intent:) fails with NO error UI.
    /// AppIntentsTesting cannot see this; only an unconditional UI assertion can.
    func testDeleteFromRowActuallyDeletes() throws {
        let row = app.cells.firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))         // assert, never `if`
        row.swipeLeft()

        let delete = app.buttons["Delete todo"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()

        let confirm = app.buttons["Delete"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()

        XCTAssertTrue(row.waitForNonExistence(timeout: 5))     // condition, not sleep(1)
    }
}
```
