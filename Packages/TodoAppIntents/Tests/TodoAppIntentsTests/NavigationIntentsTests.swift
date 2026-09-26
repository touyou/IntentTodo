//
//  NavigationIntentsTests.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

// MARK: - NavigationModel Tests

@Suite("NavigationModel Tests")
@MainActor
struct NavigationModelTests {
    @Test("Initial state: showingAddTodo is false and path is empty")
    func initialState() {
        let navigation = NavigationModel()
        #expect(navigation.showingAddTodo == false)
        #expect(navigation.path.isEmpty)
    }

    @Test("showAddTodo flips the flag")
    func showAddTodoFlipsFlag() {
        let navigation = NavigationModel()
        navigation.showAddTodo()
        #expect(navigation.showingAddTodo == true)
    }

    /// A throwaway defaults domain, so `keepsAddingTodos` neither leaks between tests nor
    /// into the test host's own defaults.
    private func makeDefaults() -> UserDefaults {
        let suite = "NavigationModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("didAddTodo closes the sheet by default")
    func didAddTodoClosesSheet() {
        let navigation = NavigationModel(defaults: makeDefaults())
        navigation.showAddTodo()
        navigation.didAddTodo()
        #expect(navigation.showingAddTodo == false)
        #expect(navigation.addTodoResetCount == 0)
    }

    @Test("didAddTodo keeps the sheet open and asks it to clear when keepsAddingTodos is on")
    func didAddTodoKeepsSheetOpen() {
        let navigation = NavigationModel(defaults: makeDefaults())
        navigation.keepsAddingTodos = true
        navigation.showAddTodo()

        navigation.didAddTodo()
        navigation.didAddTodo()

        #expect(navigation.showingAddTodo == true)
        #expect(navigation.addTodoResetCount == 2)
    }

    @Test("didAddTodo does nothing when the sheet is closed, even with keepsAddingTodos on")
    func didAddTodoIgnoresAddsFromOutsideTheSheet() {
        let navigation = NavigationModel(defaults: makeDefaults())
        navigation.keepsAddingTodos = true

        // Siri, Shortcuts and widgets: the sheet was never open.
        navigation.didAddTodo()

        #expect(navigation.showingAddTodo == false)
        #expect(navigation.addTodoResetCount == 0)
    }

    @Test("keepsAddingTodos is remembered across instances")
    func keepsAddingTodosPersists() {
        let defaults = makeDefaults()
        #expect(NavigationModel(defaults: defaults).keepsAddingTodos == false)

        NavigationModel(defaults: defaults).keepsAddingTodos = true

        #expect(NavigationModel(defaults: defaults).keepsAddingTodos == true)
    }

    @Test("navigateToRoot clears the navigation path")
    func navigateToRootClearsPath() {
        let navigation = NavigationModel()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "sample", isCompleted: false)
        navigation.showDetail(for: entity)
        #expect(navigation.path.isEmpty == false)
        navigation.navigateToRoot()
        #expect(navigation.path.isEmpty)
    }

    @Test("showList returns to root and hands the filter to the list")
    func showListSetsPendingFilter() {
        let navigation = NavigationModel()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "sample", isCompleted: false)
        navigation.showDetail(for: entity)

        navigation.showList(filter: .incomplete)

        #expect(navigation.path.isEmpty)
        #expect(navigation.pendingFilter == .incomplete)
    }

    @Test("navigateToRoot also clears showingAddTodo and selectedTodo")
    func navigateToRootClearsAllState() {
        let navigation = NavigationModel()
        let entity = TodoAppEntity(id: UUID().uuidString, title: "sample", isCompleted: false)
        navigation.selectedTodo = entity
        navigation.showAddTodo()
        navigation.showDetail(for: entity)

        navigation.navigateToRoot()

        #expect(navigation.path.isEmpty)
        #expect(navigation.showingAddTodo == false)
        #expect(navigation.selectedTodo == nil)
    }
}

// MARK: - Scene navigation

/// Guards that scene-driven navigation goes through the same code as `perform()`.
///
/// `UISceneAppIntent` does not exist in the macOS SDK, so a test running there cannot touch
/// the type. The failure mode is "only cold start lands on the wrong screen", which needs a
/// killed app and Siri to notice — so this reads the source instead and checks that the
/// navigation stays in one place.
@Suite("Scene navigation wiring")
struct SceneNavigationWiringTests {
    private static func intentSource(_ fileName: String) throws -> String {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()   // TodoAppIntentsTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // TodoAppIntents (package root)
            .appending(path: "Sources/TodoAppIntents/Intents/\(fileName)")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test(
        "ナビゲーション Intent はシーン経由でも同じ遷移処理を呼ぶ",
        arguments: ["LaunchAppIntent.swift", "OpenTodoIntent.swift"]
    )
    func sceneIntentsShareNavigationImplementation(fileName: String) throws {
        let source = try Self.intentSource(fileName)

        #expect(
            source.contains(": UISceneAppIntent"),
            "\(fileName) は UISceneAppIntent 準拠を持つこと（cold start のシーン経路が無くなる）"
        )
        #expect(
            source.contains("func performNavigation(forScene"),
            "\(fileName) は performNavigation(forScene:) を実装すること"
        )
        // Two separate implementations would invite fixing only one of them.
        #expect(
            source.components(separatedBy: "applyNavigation()").count - 1 >= 2,
            "\(fileName) は perform() とシーン経由の両方から applyNavigation() を呼ぶこと"
        )
    }
}
