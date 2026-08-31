//
//  TodoSystemIntegrationTests.swift
//  IntentTodoUITest
//
//  The integrations that reach outside the app. They keep looking fine from inside it, so
//  without these tests breakage is only noticeable by hand with Siri or another app.
//

import AppIntents
import AppIntentsTesting
import XCTest

/// The `XCUIApplication` APIs are `@MainActor`, so the whole class is isolated to it;
/// otherwise Swift 6 language mode rejects the calls.
@MainActor
final class TodoSystemIntegrationTests: AppIntentsTestCase {
    // MARK: - Onscreen entity（view annotation）

    /// Publishing the on-screen entity through `userActivity` + `appEntityIdentifier`.
    /// Without it, Siri cannot resolve "this one".
    func testDetailViewAnnotatesItsEntity() async throws {
        let title = uniqueTitle("AITest Onscreen")
        let entity = try await addTodo(title: title)

        // Navigates to the detail view through the `OpenIntent`.
        try await intent("OpenTodoIntent").makeIntent(target: entity).run()

        // Read after the screen has actually changed.
        let titleText = app.staticTexts[title]
        XCTAssertTrue(titleText.waitForExistence(timeout: 10), "Detail view should show the todo title")

        let annotations = try await pollUntil(timeout: 10) {
            try await self.todoEntity.viewAnnotations()
        } until: { !$0.isEmpty }

        XCTAssertEqual(annotations.count, 1, "Detail view should annotate exactly one entity")
        XCTAssertEqual(
            annotations[0].entity.identifier.instanceIdentifier,
            identifier(of: entity),
            "The annotated entity must be the one on screen (a wrong identifier here is invisible in-app)"
        )

        try await returnToList()
        try await deleteTodos(matching: title)
    }

    /// The collection annotation on the list.
    ///
    /// A separate path from the detail view's single annotation, and the one that lets Siri
    /// resolve "the third one". `forSelectionType:` is only honoured on a `List`, so a
    /// layout change can disable it with no visible effect inside the app.
    func testListAnnotatesEveryVisibleRow() async throws {
        let firstTitle = uniqueTitle("AITest ListOnscreen A")
        let secondTitle = uniqueTitle("AITest ListOnscreen B")
        let first = try await addTodo(title: firstTitle)
        let second = try await addTodo(title: secondTitle)
        let expected = Set([identifier(of: first), identifier(of: second)])

        // Read with the list in front; from the detail view only one row is annotated.
        XCTAssertTrue(
            app.staticTexts[secondTitle].waitForExistence(timeout: 10),
            "The list should be on screen with the newly added todos"
        )

        let annotated = try await pollUntil(timeout: 10) {
            Set(try await self.todoEntity.viewAnnotations().map(\.entity.identifier.instanceIdentifier))
        } until: { $0.isSuperset(of: expected) }

        XCTAssertTrue(
            annotated.isSuperset(of: expected),
            "The list must annotate every visible row; got \(annotated.count) annotation(s) missing \(expected.subtracting(annotated))"
        )

        try await deleteTodos(matching: firstTitle)
        try await deleteTodos(matching: secondTitle)
    }

    // MARK: - Navigation（@Dependency + perform()）

    /// `LaunchAppIntent` navigates by writing to `NavigationModel`, which is the alternative
    /// to `onAppIntentExecution` — so the navigation itself is what gets checked.
    func testLaunchIntentNavigatesToAddSheet() async throws {
        try await intent("LaunchAppIntent").makeIntent(target: "addTodo").run()

        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(
            titleField.waitForExistence(timeout: 10),
            "LaunchAppIntent(.addTodo) should present the add sheet, not just open the app"
        )

        app.buttons["cancelButton"].tap()
    }

    // MARK: - ValueRepresentation

    /// Exporting the assignee as an `IntentPerson`. The app itself only ever shows the name
    /// as a string, so breakage here is invisible on screen.
    func testAssigneeExportsAsIntentPerson() async throws {
        let title = uniqueTitle("AITest Export")
        let entity = try await addTodo(title: title)

        try await intent("UpdateTodoIntent")
            .makeIntent(todo: entity, assigneeName: "Ada Lovelace")
            .run()

        let refreshed = try await todoEntity.entities(identifiers: [identifier(of: entity)])
        let person = try await refreshed[0].exported(as: IntentPerson.self)
        XCTAssertEqual(person.name, .displayName("Ada Lovelace"))

        try await deleteTodos(matching: title)
    }

    /// A todo with no assignee offers no `IntentPerson` at all, rather than an empty one.
    func testExportThrowsWhenAssigneeIsMissing() async throws {
        let title = uniqueTitle("AITest ExportEmpty")
        let entity = try await addTodo(title: title)

        do {
            _ = try await entity.exported(as: IntentPerson.self)
            XCTFail("A todo without an assignee should not export as IntentPerson")
        } catch {
            // As expected: the export throws and the representation is simply absent.
        }

        try await deleteTodos(matching: title)
    }

    // MARK: - Helpers

    /// Returns to the list so the next test starts from a known screen.
    private func returnToList() async throws {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
}
