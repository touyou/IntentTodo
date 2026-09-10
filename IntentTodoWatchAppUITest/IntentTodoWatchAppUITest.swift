//
//  IntentTodoWatchAppUITest.swift
//  IntentTodoWatchAppUITest
//
//  UI Tests for IntentTodo watchOS app.
//  Tests core functionality: view list, add todo, toggle completion.
//

import XCTest

final class IntentTodoWatchAppUITest: XCTestCase {
    // MARK: - Properties

    // XCTest fixture, as in `IntentTodoUITest`.
    // swiftlint:disable:next implicitly_unwrapped_optional
    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // Pinned for the same two reasons as `IntentTodoUITest`: elements matched by
        // accessibility label need the English strings to resolve (the simulator otherwise
        // inherits the host's preferred language), and the shared store outlives the process,
        // so without an empty store every test has to branch on leftover todos.
        app.launchArguments = [
            "--uitesting",
            "-uitest-ephemeral-store",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Title of the todo the app seeds under `-uitest-seed-todo`.
    /// Must match `IntentTodoWatchApp.seededTodoTitle`.
    static let seededTodoTitle = "Seeded Todo"

    /// Relaunches the app with one known incomplete todo already in the store.
    ///
    /// `setUpWithError` launches with an empty store because most tests want the empty
    /// state; the tests that need a row ask for it here rather than making every other
    /// test start from a populated list.
    @MainActor
    private func relaunchWithSeededTodo() {
        app.terminate()
        app.launchArguments.append("-uitest-seed-todo")
        app.launch()
    }

    /// Adds a todo with the given title.
    /// - Parameter title: The title for the new todo.
    /// - Note: On watchOS simulator, text input via typeText can be unreliable.
    ///         This helper waits for keyboard activation before typing.
    private func addTodo(title: String) {
        // Tap add button (use firstMatch to handle potential duplicates from complication)
        let addButton = app.buttons["addTodoButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Wait for add view to appear
        let titleField = app.textFields["todoTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // On watchOS, tap the text field and wait for it to become active
        titleField.tap()

        // Wait for keyboard/input system to activate
        sleep(2)

        // Try to type - if this fails, the test will catch it
        titleField.typeText(title)

        // Wait for typing to complete
        sleep(1)

        // Tap Add button
        let confirmButton = app.buttons["addButton"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Add button should exist")
        confirmButton.tap()

        // Wait for view to dismiss
        sleep(1)
    }

    // MARK: - Test: App Launch

    @MainActor
    func testAppLaunches() throws {
        // Verify app launches and shows navigation title
        let navTitle = app.navigationBars["Todos"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 5), "Navigation title should be 'Todos'")
    }

    @MainActor
    func testAddButtonExists() throws {
        let addButton = app.buttons["addTodoButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
    }

    // MARK: - Test: Add Todo

    @MainActor
    func testAddTodo() throws {
        // Note: Text input via typeText is not reliably supported on watchOS simulator.
        // This test verifies navigation to add view and back instead.
        let addButton = app.buttons["addTodoButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Verify add view appears
        let titleField = app.textFields["todoTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should appear")

        // Verify Add button exists (even if disabled)
        let confirmButton = app.buttons["addButton"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Add button should exist on add view")
    }

    @MainActor
    func testAddButtonDisabledWithEmptyTitle() throws {
        // Tap add button (use firstMatch to handle potential duplicates from complication)
        let addButton = app.buttons["addTodoButton"].firstMatch
        addButton.tap()

        // Wait for add view to appear
        let titleField = app.textFields["todoTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Verify Add button is disabled when title is empty
        let confirmButton = app.buttons["addButton"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Add button should exist")
        XCTAssertFalse(confirmButton.isEnabled, "Add button should be disabled with empty title")

        // Note: Text input verification skipped on watchOS simulator
        // as typeText is not reliably supported
    }

    // MARK: - Test: Toggle Completion

    @MainActor
    func testToggleTodoCompletion() throws {
        // `typeText` is not reliable on the watchOS simulator, so the todo comes from a
        // launch-argument fixture instead of the add sheet.
        relaunchWithSeededTodo()

        // The row's title is the label of the `NavigationLink`, so it resolves as a button
        // rather than a static text.
        let todoCell = app.buttons[Self.seededTodoTitle].firstMatch
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Seeded todo should appear in the list")

        let checkbox = app.buttons["Mark as complete"].firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 5), "Incomplete todo should show a complete checkbox")
        checkbox.tap()

        // The watch list queries `!isCompleted`, so completing the only todo empties it —
        // there is no "Mark as incomplete" row to look for here as there is on iOS.
        XCTAssertTrue(todoCell.waitForNonExistence(timeout: 5), "Completed todo should leave the list")
        XCTAssertTrue(
            app.staticTexts["All Done!"].waitForExistence(timeout: 5),
            "Completing the only todo should show the empty state"
        )
    }

    // MARK: - Test: Empty State

    @MainActor
    func testEmptyStateMessage() throws {
        // The store is empty per launch, so the empty state is expected unconditionally.
        let allDoneText = app.staticTexts["All Done!"]
        XCTAssertTrue(
            allDoneText.waitForExistence(timeout: 5),
            "Empty state should show 'All Done!' message"
        )
    }

    // MARK: - Test: Sections

    @MainActor
    func testListHasSections() throws {
        // "Sections exist OR the empty state is shown" was true either way, so the section
        // header was never actually verified. The fixture makes the expected branch
        // deterministic: one todo with no due date lands in "Upcoming".
        relaunchWithSeededTodo()

        let upcomingSection = app.staticTexts["Upcoming"]
        XCTAssertTrue(
            upcomingSection.waitForExistence(timeout: 5),
            "A todo with no due date should appear under 'Upcoming'"
        )
    }

    // MARK: - Test: Navigation

    @MainActor
    func testNavigateToAddView() throws {
        // Tap add button (use firstMatch to handle potential duplicates from complication)
        let addButton = app.buttons["addTodoButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Verify we're on the add view by checking for title field
        let titleField = app.textFields["todoTitleField"].firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Should navigate to add view")

        // Verify navigation title
        let navTitle = app.navigationBars["New Todo"]
        XCTAssertTrue(navTitle.waitForExistence(timeout: 3), "Navigation title should be 'New Todo'")
    }

    // MARK: - Test: Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
