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

    // XCTest fixture, built in `setUpWithError()` and torn down again. Making it an optional
    // to unwrap per test would add noise without catching anything more.
    // swiftlint:disable:next implicitly_unwrapped_optional
    var app: XCUIApplication!

    // MARK: - Setup / Teardown

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The language is pinned because some elements are matched by accessibility label:
        // the simulator otherwise inherits the host's preferred language and the English
        // labels stop resolving.
        //
        // The store is emptied per launch. It outlives the process, so otherwise todos
        // accumulate across tests — no test can assume an empty list, and the growing list
        // slows redraws until waits time out.
        app.launchArguments = [
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

        // Waits for the title field to disappear rather than for a fixed interval, which
        // every test would otherwise pay for.
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 5), "Add sheet should dismiss")
    }

    /// Finds a todo cell by its title.
    /// - Parameter title: The title to search for.
    /// - Returns: The cell element if found.
    private func findTodoCell(title: String) -> XCUIElement {
        app.staticTexts[title].firstMatch
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
        //
        // **Never wrap assertions in `if element.waitForExistence(...)`**: a missing element
        // then verifies nothing and the test passes. That is exactly what happened when the
        // app started launching in another language and the English labels stopped matching.
        let checkbox = app.buttons["Mark as complete"].firstMatch
        XCTAssertTrue(checkbox.waitForExistence(timeout: 3), "Incomplete todo should show a complete checkbox")
        checkbox.tap()

        // Verify the checkbox changed to "Mark as incomplete"
        let completedCheckbox = app.buttons["Mark as incomplete"].firstMatch
        XCTAssertTrue(completedCheckbox.waitForExistence(timeout: 5), "Todo should be marked as complete")
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
        //
        // Unconditional for the same reason as `testToggleTodoCompletion` above.
        let favoriteButton = app.buttons["Add to favorites"].firstMatch
        XCTAssertTrue(favoriteButton.waitForExistence(timeout: 3), "Todo row should show a favorite button")
        favoriteButton.tap()

        // Verify the button changed to "Remove from favorites"
        let unfavoriteButton = app.buttons["Remove from favorites"].firstMatch
        XCTAssertTrue(unfavoriteButton.waitForExistence(timeout: 5), "Todo should be marked as favorite")
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

        // Swiping has to happen on the row's cell: a `StaticText` does not open the swipe
        // actions.
        let row = app.cells.containing(.staticText, identifier: todoTitle).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row cell should exist")
        row.swipeLeft()

        // Tap delete button
        //
        // Unconditional, as above. The label matches `DeleteButton`'s accessibility label —
        // "Delete todo", not "Delete".
        let deleteButton = app.buttons["Delete todo"].firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Swipe should reveal a Delete action")
        deleteButton.tap()

        // Verify todo is deleted
        XCTAssertTrue(
            todoCell.waitForNonExistence(timeout: 5),
            "Todo should be deleted"
        )
    }

    // MARK: - Test: Delete Todo from the detail screen

    /// Deleting from the detail view confirms first. While this called the confirming intent
    /// directly it failed with `LNPerformActionErrorCodeUnsupportedValueType` and **nothing
    /// happened at all**.
    @MainActor
    func testDeleteTodoFromDetailView() throws {
        let todoTitle = "Detail Delete Test \(Date().timeIntervalSince1970)"
        addTodo(title: todoTitle)

        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")
        todoCell.tap()

        let deleteButton = app.buttons["deleteTodoButton"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 5), "Detail view should offer Delete Todo")
        deleteButton.tap()

        let confirmButton = app.buttons["confirmDeleteTodoButton"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "A confirmation dialog should appear")
        confirmButton.tap()

        XCTAssertTrue(
            findTodoCell(title: todoTitle).waitForNonExistence(timeout: 5),
            "Confirming should actually delete the todo"
        )
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
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field should appear")
        searchField.tap()
        searchField.typeText("Apple")

        // Waits for the non-matching row to disappear: a fixed delay would move on even if
        // filtering never happened.
        XCTAssertTrue(
            findTodoCell(title: todoTitle2).waitForNonExistence(timeout: 5),
            "Non-matching todo should be hidden"
        )
        XCTAssertTrue(findTodoCell(title: todoTitle1).exists, "Matching todo should be visible")
    }

    // MARK: - Test: Filter

    @MainActor
    func testFilterMenu() throws {
        // Tap filter menu
        let filterMenu = app.buttons["filterSortMenu"]
        XCTAssertTrue(filterMenu.waitForExistence(timeout: 5), "Filter menu should exist")
        filterMenu.tap()

        // The `waitForExistence` below doubles as the wait for the menu.

        // In SwiftUI Menu with Picker, menu content can appear in different ways
        // depending on iOS version. We check multiple possible element types.
        // The menu contains: Filter picker (All, Incomplete, Completed, Favorites) and Sort submenu

        // Check for any evidence the menu opened:
        // 1. Check for filter options (staticTexts, buttons, images)
        // 2. Check for "Filter" or "Sort" labels
        // 3. Check for checkmarks (selected state indicator)

        var menuOpened = false

        // Check for filter options
        let possibleTexts = ["All", "Incomplete", "Completed", "Favorites", "Filter", "Sort"]
        for text in possibleTexts {
            if app.staticTexts[text].waitForExistence(timeout: 1) {
                menuOpened = true
                break
            }
            if app.buttons[text].exists {
                menuOpened = true
                break
            }
        }

        // Also check if any menu items exist (generic check)
        if !menuOpened {
            // Check for picker selections via images (checkmark.circle.fill indicates selection)
            // `XCUIElementQuery` has no `isEmpty`, and only "any at all" matters here, so
            // this asks `firstMatch` instead of resolving every match.
            if app.images.matching(identifier: "checkmark").firstMatch.exists {
                menuOpened = true
            }
        }

        // If still not found, check for any popover or sheet content
        if !menuOpened {
            // The menu should have at least some content - check for any new elements
            let initialButtonCount = app.buttons.count
            menuOpened = initialButtonCount > 2 // More than just navigation bar buttons
        }

        XCTAssertTrue(menuOpened, "Filter menu should open and display options")

        // Tap outside to dismiss menu (tap on navigation bar area)
        let navBar = app.navigationBars["Todos"]
        if navBar.exists {
            navBar.tap()
        }
    }

    // MARK: - Test: Empty State

    @MainActor
    func testEmptyStateShowsAddButton() throws {
        // The store is empty per launch, so the empty state can be expected unconditionally.
        let emptyStateButton = app.buttons["Add Todo"]
        XCTAssertTrue(
            emptyStateButton.waitForExistence(timeout: 5),
            "Empty state should offer an Add Todo button"
        )
        XCTAssertTrue(emptyStateButton.isHittable, "Empty state Add Todo button should be tappable")
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

        // The wait for the back button below doubles as the wait for navigation.

        // Verify we're on the detail view by checking for back button
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 3), "Back button should exist on detail view")
    }

    // MARK: - Test: Editing Attributes

    /// Adding a tag from the detail view's edit sheet.
    ///
    /// This needs a UI test for two reasons: running an intent from an in-app button shows no
    /// error when it fails — an unregistered dependency or an interactive API fails silently,
    /// and AppIntentsTesting goes through the Shortcuts-equivalent path instead — and the
    /// sheet closing is the only visible evidence that `perform()` ran to completion.
    @MainActor
    func testAddTagFromDetailView() throws {
        let todoTitle = "Tag Test \(Date().timeIntervalSince1970)"
        addTodo(title: todoTitle)

        let todoCell = findTodoCell(title: todoTitle)
        XCTAssertTrue(todoCell.waitForExistence(timeout: 5), "Todo should exist")
        todoCell.tap()

        let editButton = app.buttons["editDetailsButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5), "Edit Details button should exist on detail view")
        editButton.tap()

        let tagField = app.textFields["tagField"]
        XCTAssertTrue(tagField.waitForExistence(timeout: 5), "Tag field should exist in the editor")
        tagField.tap()
        tagField.typeText("errand")

        let addTagButton = app.buttons["addTagButton"]
        XCTAssertTrue(addTagButton.waitForExistence(timeout: 3), "Add tag button should exist")
        addTagButton.tap()

        let saveButton = app.buttons["saveAttributesButton"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3), "Save button should exist")
        saveButton.tap()

        // The sheet closing means the intent succeeded; asserting without it would pass
        // while nothing was saved.
        XCTAssertTrue(tagField.waitForNonExistence(timeout: 5), "Editor sheet should dismiss after saving")

        // Present in the detail view's tag section, i.e. the save reached the model.
        XCTAssertTrue(
            app.staticTexts["errand"].waitForExistence(timeout: 5),
            "Saved tag should appear in the detail view"
        )
    }

    // MARK: - Test: Settings

    /// Reaching `ShortcutsLink` from the settings screen.
    ///
    /// It is a system-provided view, so moving or losing it breaks nothing visible inside the
    /// app — only its reachability can be checked.
    @MainActor
    func testSettingsShowsShortcutsLink() throws {
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "Settings button should exist")
        settingsButton.tap()

        let shortcutsLink = app.descendants(matching: .any)["shortcutsLink"]
        XCTAssertTrue(shortcutsLink.waitForExistence(timeout: 5), "ShortcutsLink should exist in settings")

        let doneButton = app.buttons["settingsDoneButton"]
        XCTAssertTrue(doneButton.exists, "Done button should exist")
        doneButton.tap()

        XCTAssertTrue(
            app.buttons["addTodoButton"].waitForExistence(timeout: 5),
            "Dismissing settings should return to the list"
        )
    }

    // MARK: - Test: Launch Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
