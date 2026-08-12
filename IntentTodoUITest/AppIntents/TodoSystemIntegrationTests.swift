//
//  TodoSystemIntegrationTests.swift
//  IntentTodoUITest
//
//  アプリの外側まで届く統合部分。壊れても「アプリ内では正常に見える」ため
//  手で Siri / 他アプリを触るまで気づけない種類の経路をここで押さえる。
//

import AppIntents
import AppIntentsTesting
import XCTest

final class TodoSystemIntegrationTests: AppIntentsTestCase {
    // MARK: - Onscreen entity（view annotation）

    /// `userActivity` + `appEntityIdentifier` で「いま画面に出ている entity」を
    /// システムへ知らせている経路。落ちると Siri が「これ」を解決できなくなる。
    func testDetailViewAnnotatesItsEntity() async throws {
        let title = uniqueTitle("AITest Onscreen")
        let entity = try await addTodo(title: title)

        // OpenIntent で詳細画面へ遷移させる（.foreground(.immediate)）。
        try await intent("OpenTodoIntent").makeIntent(target: entity).run()

        // 画面が実際に切り替わってから annotation を読む。
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

    // MARK: - Navigation（@Dependency + perform()）

    /// `LaunchAppIntent` は `@Dependency var navigationModel` へ書き込むことで画面遷移する。
    /// `onAppIntentExecution` を使わない代わりの経路なので、遷移が起きることを押さえる。
    /// 経緯: docs/insights/04-ui-integration.md
    func testLaunchIntentNavigatesToAddSheet() async throws {
        try await intent("LaunchAppIntent").makeIntent(target: "addTodo").run()

        let titleField = app.textFields["todoTitleField"]
        XCTAssertTrue(
            titleField.waitForExistence(timeout: 10),
            "LaunchAppIntent(.addTodo) should present the add sheet, not just open the app"
        )

        app.buttons["cancelButton"].tap()
    }

    // MARK: - ValueRepresentation（他アプリ / システム型への受け渡し）

    /// `Transferable` の `ValueRepresentation` で担当者を `IntentPerson` として出す経路。
    /// アプリ内の表示は担当者名の String のままなので、ここが壊れても画面上は正常に見える。
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

    /// 担当者が居ない todo は `IntentPerson` の flavor を提供しない（空の値を出さない）。
    func testExportThrowsWhenAssigneeIsMissing() async throws {
        let title = uniqueTitle("AITest ExportEmpty")
        let entity = try await addTodo(title: title)

        do {
            _ = try await entity.exported(as: IntentPerson.self)
            XCTFail("A todo without an assignee should not export as IntentPerson")
        } catch {
            // 期待どおり。export 側が throw して flavor ごと提供されない。
        }

        try await deleteTodos(matching: title)
    }

    // MARK: - Helpers

    /// 詳細画面を開いたままだと次のテストの起点がずれるので、一覧へ戻す。
    private func returnToList() async throws {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
}
