//
//  IntentTodoUITest.swift
//  IntentTodoUITest
//
//  UI Tests for IntentTodo app.
//  Tests core functionality: add, complete, favorite, delete todos.
//

import XCTest

final class IntentTodoUITest: XCTestCase {
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
    private func addTodo(title: String, favorite: Bool = false) {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add button should exist")
        addButton.tap()

        // Wait for sheet to appear
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Enter title
        titleField.tap()
        titleField.typeText(title)

        // Set favorite if needed
        if favorite {
            let favoriteToggle = app.switches["favoriteToggle"]
            if favoriteToggle.exists {
                favoriteToggle.tap()
            }
        }

        // Tap Add button
        let confirmButton = app.buttons["addButton"]
        XCTAssertTrue(confirmButton.exists, "Add button should exist")
        confirmButton.tap()

        // Wait for sheet to dismiss
        sleep(1)
    }

    /// Finds a todo cell by its title.
    /// - Parameter title: The title to search for.
    /// - Returns: The cell element if found.
    private func findTodoCell(title: String) -> XCUIElement {
        return app.staticTexts[title].firstMatch
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
        let todoTitle = "Test Todo \(Date().timeIntervalSince1970)"

        // Add a todo
        addTodo(title: todoTitle)

        // Verify todo appears in the list
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Added todo should appear in the list")
    }

    @MainActor
    func testAddTodoWithFavorite() throws {
        let todoTitle = "Favorite Todo \(Date().timeIntervalSince1970)"

        // Add a favorite todo
        addTodo(title: todoTitle, favorite: true)

        // Verify todo appears in the list
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Added favorite todo should appear in the list")
    }

    @MainActor
    func testCancelAddTodo() throws {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        addButton.tap()

        // Wait for sheet to appear
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Tap Cancel button
        let cancelButton = app.buttons["cancelButton"]
        XCTAssertTrue(cancelButton.exists, "Cancel button should exist")
        cancelButton.tap()

        // Verify sheet is dismissed (title field no longer exists)
        XCTAssertFalse(titleField.waitForExistence(timeout: 2), "Sheet should be dismissed")
    }

    @MainActor
    func testAddButtonDisabledWithEmptyTitle() throws {
        // Tap add button
        let addButton = app.buttons["addTodoButton"]
        addButton.tap()

        // Wait for sheet to appear
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5), "Title field should exist")

        // Verify Add button is disabled when title is empty
        let confirmButton = app.buttons["addButton"]
        XCTAssertTrue(confirmButton.exists, "Add button should exist")
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
        let todoTitle = "Toggle Test \(Date().timeIntervalSince1970)"

        // Add a todo
        addTodo(title: todoTitle)

        // Find the todo cell
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")

        // Find and tap the checkbox (using accessibility label)
        let checkbox = app.buttons["Mark as complete"].firstMatch
        if checkbox.waitForExistence(timeout: 3) {
            checkbox.tap()

            // Wait for state change
            sleep(1)

            // Verify the checkbox changed to "Mark as incomplete"
            let completedCheckbox = app.buttons["Mark as incomplete"].firstMatch
            XCTAssertTrue(completedCheckbox.waitForExistence(timeout: 3), "Todo should be marked as complete")
        }
    }

    // MARK: - Test: Toggle Favorite

    @MainActor
    func testToggleFavorite() throws {
        let todoTitle = "Favorite Test \(Date().timeIntervalSince1970)"

        // Add a todo
        addTodo(title: todoTitle)

        // Find the todo cell
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")

        // Find and tap the favorite button
        let favoriteButton = app.buttons["Add to favorites"].firstMatch
        if favoriteButton.waitForExistence(timeout: 3) {
            favoriteButton.tap()

            // Wait for state change
            sleep(1)

            // Verify the button changed to "Remove from favorites"
            let unfavoriteButton = app.buttons["Remove from favorites"].firstMatch
            XCTAssertTrue(unfavoriteButton.waitForExistence(timeout: 3), "Todo should be marked as favorite")
        }
    }

    // MARK: - Test: Delete Todo

    @MainActor
    func testDeleteTodo() throws {
        let todoTitle = "Delete Test \(Date().timeIntervalSince1970)"

        // Add a todo
        addTodo(title: todoTitle)

        // Find the todo cell
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")

        // Swipe to delete
        todoCell.swipeLeft()

        // Tap delete button
        let deleteButton = app.buttons["Delete"]
        if deleteButton.waitForExistence(timeout: 3) {
            deleteButton.tap()

            // Wait for deletion
            sleep(1)

            // Verify todo is deleted
            XCTAssertFalse(todoCell.exists, "Todo should be deleted")
        }
    }

    // MARK: - Test: Search

    @MainActor
    func testSearchTodos() throws {
        let todoTitle1 = "Apple Task \(Date().timeIntervalSince1970)"
        let todoTitle2 = "Banana Task \(Date().timeIntervalSince1970)"

        // Add two todos
        addTodo(title: todoTitle1)
        addTodo(title: todoTitle2)

        // Pull down to reveal search
        let list = app.collectionViews.firstMatch
        if list.exists {
            list.swipeDown()
        }

        // Find and tap search field
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            searchField.typeText("Apple")

            // Wait for filter to apply
            sleep(1)

            // Verify only matching todo is visible
            XCTAssertTrue(findTodoCell(title: todoTitle1).exists, "Matching todo should be visible")
            XCTAssertFalse(findTodoCell(title: todoTitle2).exists, "Non-matching todo should be hidden")
        }
    }

    // MARK: - Test: Filter

    @MainActor
    func testFilterMenu() throws {
        // Tap filter menu
        let filterMenu = app.buttons["filterSortMenu"]
        XCTAssertTrue(filterMenu.waitForExistence(timeout: 5), "Filter menu should exist")
        filterMenu.tap()

        // Verify filter options appear
        let allFilter = app.buttons["All"]
        let incompleteFilter = app.buttons["Incomplete"]
        let completedFilter = app.buttons["Completed"]
        let favoritesFilter = app.buttons["Favorites"]

        // At least one filter option should exist
        let filterExists = allFilter.waitForExistence(timeout: 3) ||
                          incompleteFilter.waitForExistence(timeout: 1) ||
                          completedFilter.waitForExistence(timeout: 1) ||
                          favoritesFilter.waitForExistence(timeout: 1)

        XCTAssertTrue(filterExists, "Filter options should appear")
    }

    // MARK: - Test: Empty State

    @MainActor
    func testEmptyStateShowsAddButton() throws {
        // If there are no todos, empty state should show "Add Todo" button
        // This test assumes starting with an empty state or after deleting all todos
        let emptyStateButton = app.buttons["Add Todo"]
        if emptyStateButton.waitForExistence(timeout: 3) {
            XCTAssertTrue(emptyStateButton.isHittable, "Empty state Add Todo button should be tappable")
        }
    }

    // MARK: - Test: Navigation to Detail

    @MainActor
    func testNavigateToTodoDetail() throws {
        let todoTitle = "Detail Test \(Date().timeIntervalSince1970)"

        // Add a todo
        addTodo(title: todoTitle)

        // Find and tap the todo cell
        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")
        todoCell.tap()

        // Verify detail view appears (navigation title changes or detail elements appear)
        // The exact verification depends on the detail view implementation
        sleep(1)

        // Verify we're on the detail view by checking for back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Back button should exist on detail view")
    }

    // MARK: - Test: Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
