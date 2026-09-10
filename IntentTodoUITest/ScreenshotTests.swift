//
//  ScreenshotTests.swift
//  IntentTodoUITest
//
//  Captures the App Store submission screenshots. Not a behaviour test: it drives the app
//  to each screen and attaches an image. `scripts/capture_screenshots.sh` runs it per
//  destination and locale and extracts the attachments.
//

import XCTest

final class ScreenshotTests: XCTestCase {
    // XCTest fixture, built in `setUpWithError()`. Same reasoning as `IntentTodoUITest`.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    /// Arguments every launch needs, whichever screen is being captured.
    ///
    /// The language comes from `xcodebuild -testLanguage`, not from `-AppleLanguages`. The
    /// other UI tests pin English that way because they match on English accessibility
    /// labels; here the whole point is to run the app in each locale, and `-testLanguage` is
    /// the switch that also moves `Locale.current` inside the app — which is what picks the
    /// fixture's language.
    private let baseArguments = [
        "-uitest-ephemeral-store",
        "-uitest-screenshot-fixture",
        // macOS restores the previous session's windows. If the app was last quit with its
        // window closed it comes back with **no window at all** — the accessibility tree is
        // a menu bar and nothing else, and every element lookup times out. Ignored on the
        // other platforms.
        "-ApplePersistenceIgnoreState", "YES"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = baseArguments
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Capture

    /// Attaches a capture under a name the extraction script can order by.
    private func capture(_ name: String) {
        #if os(macOS)
        // The window, not `app.screenshot()` and not `XCUIScreen.main`: both of those come
        // back as the whole display, with the desktop and every other app in the shot.
        let screenshot = app.windows.firstMatch.screenshot()
        #else
        // The device's framebuffer, at exactly the pixel size App Store Connect asks for.
        let screenshot = XCUIScreen.main.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        // Attachments are discarded on success by default, and every screenshot run
        // succeeds — without this the run produces nothing.
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Screens

    @MainActor
    func testCaptureScreenshots() throws {
        #if os(macOS)
        try captureByRelaunching()
        #else
        try captureByNavigating()
        #endif
    }

    /// Walks the app the way a person would, capturing on the way.
    ///
    /// Only for the touch platforms. On macOS a whole sidebar row collapses into one
    /// accessibility element, so there is nothing to tap that opens the detail screen.
    @MainActor
    private func captureByNavigating() throws {
        // 1. The seeded list.
        //
        // Waiting on the add button rather than a title: it is the one control present on
        // every platform's list screen, and its absence means the fixture never loaded.
        let addButton = app.buttons["addTodoButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 30), "List screen should show the add button")
        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 10), "Screenshot fixture should have seeded rows")
        capture("01-list")

        // 2. Detail of the first todo.
        firstRow.tap()
        let editButton = app.buttons["editDetailsButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 10), "Tapping a row should open the detail screen")
        capture("02-detail")
        returnToList()

        // 3. The add sheet.
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Add button should be back on screen")
        addButton.tap()
        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10), "Add sheet should present a title field")
        capture("03-add")
        app.buttons["cancelButton"].tap()
        XCTAssertTrue(titleField.waitForNonExistence(timeout: 10), "Add sheet should dismiss")

        // 4. Settings, which is where the Shortcuts entry point lives.
        //
        // iOS only, mirroring the app: `SettingsView` is built around `ShortcutsLink`, which
        // does not exist on macOS, so `TodoListToolbar` omits the button there.
        #if os(iOS)
        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10), "Settings button should exist")
        settingsButton.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["shortcutsLink"].waitForExistence(timeout: 10),
            "Settings should show the Shortcuts link"
        )
        capture("04-settings")
        app.buttons["settingsDoneButton"].tap()
        #endif
    }

    /// Relaunches once per screen, asking the app to open each one directly.
    ///
    /// The same launch argument the visionOS capture uses. On macOS this sidesteps the fact
    /// that a row is a single `checkbox_<uuid>-favorite_<uuid>` button with no separate
    /// navigation link to activate.
    @MainActor
    private func captureByRelaunching() throws {
        for (name, screen) in [("01-list", "list"), ("02-detail", "detail"), ("03-add", "add")] {
            app.terminate()
            app.launchArguments = baseArguments + ["-uitest-screenshot-screen", screen]
            app.launch()

            XCTAssertTrue(
                app.buttons["addTodoButton"].waitForExistence(timeout: 30),
                "List screen should show the add button before capturing \(name)"
            )
            XCTAssertTrue(
                app.cells.element(boundBy: 0).waitForExistence(timeout: 10),
                "Screenshot fixture should have seeded rows before capturing \(name)"
            )
            capture(name)
        }
    }

    /// Returns from the detail screen to the list.
    ///
    /// The split-view platforms keep the list on screen, so there is nothing to pop there —
    /// the add button never went away.
    @MainActor
    private func returnToList() {
        guard !app.buttons["addTodoButton"].exists else { return }
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 10), "Detail screen should offer a back button")
        backButton.tap()
    }
}
