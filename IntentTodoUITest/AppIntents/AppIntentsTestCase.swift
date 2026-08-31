//
//  AppIntentsTestCase.swift
//  IntentTodoUITest
//
//  Shared base for the AppIntentsTesting cases.
//
//  These run the app in its own process, through the same App Intents stack Siri,
//  Shortcuts and Spotlight use — which is why Apple requires them to live in a UI test
//  bundle rather than a unit test target.
//
//  Each test creates todos with a unique title and deletes them again: they share the
//  app's real store, so anything left behind leaks into the next test.
//

import AppIntents
import AppIntentsTesting
import XCTest

/// Base class with no tests of its own.
class AppIntentsTestCase: XCTestCase {
    /// Must match the app target's `PRODUCT_BUNDLE_IDENTIFIER`.
    static let appBundleID = "dev.touyou.IntentTodo"

    // XCTest fixtures. `definitions` in particular has to be built inside `setUp`, after
    // the app has been activated, so it cannot become a property initialiser.
    // swiftlint:disable implicitly_unwrapped_optional
    var app: XCUIApplication!
    var definitions: IntentDefinitions!
    // swiftlint:enable implicitly_unwrapped_optional

    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // `activate()`, not `launch()`: the latter terminates and relaunches a running app,
        // which makes the simulator fail intermittently with "did not return a process
        // handle nor launch error" once there are enough tests.
        app.activate()
        // Discovers the intents, entities, enums and queries the app registered.
        definitions = IntentDefinitions(bundleIdentifier: Self.appBundleID)
        try await waitUntilIntentsAreDiscoverable()
    }

    /// Right after the app is reinstalled the App Intents metadata service does not know
    /// about it yet and calls through `IntentDefinitions` fail — which surfaces as "only the
    /// `AppIntentsServicesMetadataErrorDomain Code=400 "<bundle id> is not present"`
    /// first test after a clean build fails". Waiting for recognition avoids that.
    private func waitUntilIntentsAreDiscoverable(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?
        while Date() < deadline {
            do {
                _ = try await todoEntity.suggestedEntities()
                return
            } catch {
                lastError = error
                try await Task.sleep(for: .milliseconds(500))
            }
        }
        throw XCTSkip("App Intents metadata never became available: \(String(describing: lastError))")
    }

    override func tearDown() {
        app = nil
        definitions = nil
    }

    // MARK: - Definition Shortcuts

    var todoEntity: AppEntityDefinition { definitions.entities["TodoAppEntity"] }
    var categoryEntity: AppEntityDefinition { definitions.entities["CategoryAppEntity"] }

    func intent(_ typeName: String) -> AppIntentDefinition { definitions.intents[typeName] }

    // MARK: - Helpers

    func uniqueTitle(_ prefix: String) -> String {
        "\(prefix) \(UUID().uuidString)"
    }

    /// Creates one todo and returns its entity.
    @discardableResult
    func addTodo(title: String) async throws -> AnyAppEntity {
        try await intent("AddTodoIntent").makeIntent(title: title).run().value
    }

    /// The id of an `AnyAppEntity`. Not a `@Property`, so dynamic member lookup
    /// (`entity.id`) cannot reach it; it comes from the type-erased `identifier`.
    func identifier(of entity: AnyAppEntity) -> String {
        entity.identifier.instanceIdentifier
    }

    /// Deletes every todo with a matching title, restoring the store.
    func deleteTodos(matching title: String) async throws {
        let matches = try await todoEntity.entities(matching: title)
        for match in matches {
            try await intent("DeleteTodoIntent").makeIntent(todo: match).run()
        }
    }

    /// Waits for results that land asynchronously, such as the Spotlight index.
    func pollUntil<T>(
        timeout: TimeInterval,
        interval: TimeInterval = 0.5,
        _ produce: () async throws -> T,
        until isSatisfied: (T) -> Bool
    ) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        var latest = try await produce()
        while !isSatisfied(latest), Date() < deadline {
            try await Task.sleep(for: .seconds(interval))
            latest = try await produce()
        }
        return latest
    }
}
