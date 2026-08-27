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

    @Test("dismissAddTodo resets the flag")
    func dismissAddTodoResetsFlag() {
        let navigation = NavigationModel()
        navigation.showAddTodo()
        navigation.dismissAddTodo()
        #expect(navigation.showingAddTodo == false)
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

/// シーン経由のナビゲーション経路が `perform()` と同じ処理を通ることを守る。
///
/// `UISceneAppIntent` は iOS / visionOS 専用（macOS では SDK に無い）なので、
/// macOS で走る SPM テストからは型として触れない。壊れ方は「cold start のときだけ
/// 目的の画面に行かない」で、アプリを kill してから Siri を叩かないと気づけない。
/// そこでソースを真として、遷移処理が 1 か所に集約されたままかを確かめる。
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
        // `perform()` 側とシーン側で別々に遷移を書くと、片方だけ直す事故が起きる。
        #expect(
            source.components(separatedBy: "applyNavigation()").count - 1 >= 2,
            "\(fileName) は perform() とシーン経由の両方から applyNavigation() を呼ぶこと"
        )
    }
}
