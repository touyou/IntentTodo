//
//  WatchScreenshotTests.swift
//  IntentTodoWatchAppUITest
//
//  Captures the watchOS App Store submission screenshots. The iOS-side counterpart and the
//  extraction script are `IntentTodoUITest/ScreenshotTests.swift` and
//  `scripts/capture_screenshots.sh`.
//

import XCTest

final class WatchScreenshotTests: XCTestCase {
    // XCTest fixture, as in `IntentTodoWatchAppUITest`.
    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        // The language comes from `xcodebuild -testLanguage`; see the iOS counterpart.
        app.launchArguments = [
            "--uitesting",
            "-uitest-ephemeral-store",
            "-uitest-screenshot-fixture"
        ]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testCaptureScreenshots() throws {
        // Rows are `button`s on watchOS — they are `NavigationLink` labels, not static text.
        let firstRow = app.cells.element(boundBy: 0)
        XCTAssertTrue(firstRow.waitForExistence(timeout: 60), "Screenshot fixture should have seeded rows")
        capture("01-list")

        // A row holds two buttons: the navigation link and the completion checkbox, whose
        // identifier is the SF Symbol name. Picking by index taps the checkbox instead —
        // the todo gets completed, drops out of the list, and no push ever happens.
        let link = firstRow.buttons
            .matching(NSPredicate(format: "identifier != 'circle'"))
            .firstMatch
        XCTAssertTrue(link.waitForExistence(timeout: 10), "Row should offer a navigation link")
        link.tap()
        // The detail screen carries no identifier of its own, and every label on it is
        // localized. The add button belongs to the list's toolbar, so it disappearing is the
        // locale-independent signal that the push completed.
        XCTAssertTrue(
            app.buttons["addTodoButton"].firstMatch.waitForNonExistence(timeout: 15),
            "Tapping a row should push the detail screen over the list"
        )
        capture("02-detail")
    }
}
