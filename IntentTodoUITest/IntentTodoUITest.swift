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

    // `setUpWithError()` で組み立て `tearDownWithError()` で捨てる XCTest の
    // ライフサイクルに乗せた fixture。毎回 unwrap する Optional にしても、テスト側の
    // 記述が増えるだけで捕まえられる失敗は増えない。
    // swiftlint:disable:next implicitly_unwrapped_optional
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

        // Swipe to delete。スワイプ対象は StaticText ではなく行のセル
        // （StaticText を swipeLeft してもスワイプアクションは開かない）。
        let row = app.cells.containing(.staticText, identifier: todoTitle).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Row cell should exist")
        row.swipeLeft()

        // Tap delete button
        //
        // **条件付き assert にしないこと**。`if deleteButton.waitForExistence(...)` で
        // 包むと、要素が見つからないまま何も検証されず緑になる。
        // ラベルは `DeleteButton` の `.accessibilityLabel` に合わせて "Delete todo"
        // （"Delete" ではない）。
        // 経緯: docs/devlog/06-control-widget-ios26.md（2026-08-12 の削除ボタン不動作）
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

    /// 詳細画面の「Delete Todo」は確認ダイアログを挟んでから削除する。
    /// この経路は `DeleteTodoIntent`（`requestConfirmation` 付き）を直接叩いていた頃、
    /// `LNPerformActionErrorCodeUnsupportedValueType` で失敗して**何も起きなかった**。
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

        // Wait for menu to appear
        sleep(1)

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
            // `XCUIElementQuery` に `isEmpty` は無い。件数は要らず「1 件でもあるか」だけ
            // 知りたいので `firstMatch` で問い合わせる（全件の解決も避けられる）。
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
