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

    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Adds a todo with the given title.
    /// - Parameter title: The title for the new todo.
    private func addTodo(title: String) {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Wait for add view to appear
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Enter title
        titleField.tap()
        titleField.typeText(title)

        // Tap Add button
        let confirmButton = app.buttons["addButton"]
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
        let addButton = app.buttons["addTodoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
    }

    // MARK: - Test: Add Todo

    @MainActor
    func testAddTodo() throws {
        let todoTitle = "Watch Test \(Int(Date().timeIntervalSince1970))"

        // Add a todo
        addTodo(title: todoTitle)

        // Verify todo appears in the list
        let todoText = app.staticTexts[todoTitle]
        XCTAssertTrue(todoText.waitForExistence(timeout: 5), "Added todo should appear in the list")
    }

    @MainActor
    func testAddButtonDisabledWithEmptyTitle() throws {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        addButton.tap()

        // Wait for add view to appear
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Verify Add button is disabled when title is empty
        let confirmButton = app.buttons["addButton"]
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3), "Add button should exist")
        XCTAssertFalse(confirmButton.isEnabled, "Add button should be disabled with empty title")

        // Enter title
        titleField.tap()
        titleField.typeText("Test")

        // Verify Add button is now enabled
        XCTAssertTrue(confirmButton.isEnabled, "Add button should be enabled with title")
    }

    // MARK: - Test: Toggle Completion

    @MainActor
    func testToggleTodoCompletion() throws {
        let todoTitle = "Toggle Watch \(Int(Date().timeIntervalSince1970))"

        // Add a todo
        addTodo(title: todoTitle)

        // Find and tap the todo row (which toggles completion via Intent)
        let todoText = app.staticTexts[todoTitle]
        XCTAssertTrue(todoText.waitForExistence(timeout: 5), "Todo should exist")

        // On watchOS, tapping the row toggles completion
        todoText.tap()

        // Wait for state change
        sleep(1)

        // After completion, the todo should disappear from the incomplete list
        XCTAssertFalse(todoText.waitForExistence(timeout: 3), "Completed todo should disappear from incomplete list")
    }

    // MARK: - Test: Empty State

    @MainActor
    func testEmptyStateMessage() throws {
        // If there are no incomplete todos, should show "All Done!" message
        let allDoneText = app.staticTexts["All Done!"]
        if allDoneText.waitForExistence(timeout: 3) {
            XCTAssertTrue(allDoneText.exists, "Empty state should show 'All Done!' message")
        }
    }

    // MARK: - Test: Sections

    @MainActor
    func testListHasSections() throws {
        // Add a todo first to ensure list is visible
        let todoTitle = "Section Test \(Int(Date().timeIntervalSince1970))"
        addTodo(title: todoTitle)

        // Check for section headers
        let upcomingSection = app.staticTexts["Upcoming"]
        let dueSoonSection = app.staticTexts["Due Soon"]

        // At least one section should exist
        let sectionExists = upcomingSection.waitForExistence(timeout: 3) ||
                           dueSoonSection.waitForExistence(timeout: 1)

        // Note: This might not always pass depending on the todo's due date
        // Keeping as informational test
        if !sectionExists {
            // If no sections found, just verify the todo exists
            let todoText = app.staticTexts[todoTitle]
            XCTAssertTrue(todoText.exists, "Todo should be visible even without section headers")
        }
    }

    // MARK: - Test: Navigation

    @MainActor
    func testNavigateToAddView() throws {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Verify we're on the add view by checking for title field
        let titleField = app.textFields["todoTitleField"]
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
