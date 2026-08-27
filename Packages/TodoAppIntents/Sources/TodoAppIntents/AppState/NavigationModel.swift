//
//  NavigationModel.swift
//  TodoAppIntents
//
//  Single source of truth for app navigation state. Lives in this package so
//  Intents can reach it via @Dependency.
//
//  Register in App.init():
//    let nav = NavigationModel()
//    self.navigationModel = nav
//    AppDependencyManager.shared.add(dependency: nav)
//

import AppIntents
import Observation

/// Shared navigation state for the entire app.
///
/// Registered via `AppDependencyManager` so intents can write to it from `perform()`.
/// Passed to views via `.environment(navigationModel)` so they can observe and bind to it.
@MainActor
@Observable
public final class NavigationModel {
    // MARK: - State

    /// Navigation stack path for detail views.
    public var path: [NavigationDestination] = []

    /// Whether the add todo sheet is presented.
    public var showingAddTodo: Bool = false

    /// Currently selected todo in NavigationSplitView layouts (visionOS, macOS).
    /// Stack-based platforms (iOS/iPadOS/watchOS) use `path` instead and leave this nil.
    public var selectedTodo: TodoAppEntity?

    /// A search term an intent wants the list to apply. The list view observes
    /// this, copies it into its `.searchable` field, then clears it back to nil.
    /// Drives `ShowTodoSearchResultsIntent` (`.system.searchInApp`, WWDC 2026 #343/#47).
    public var pendingSearchText: String?

    /// A list filter an intent wants the list to apply. Same handshake as
    /// ``pendingSearchText``: the list view copies it into its own filter state,
    /// then clears it back to nil.
    ///
    /// Drives `LaunchAppIntent`'s list targets, so opening the app from the Todo
    /// Count control lands on exactly the todos the number referred to — rather
    /// than just opening the app.
    public var pendingFilter: TodoFilterType?

    /// 追加シートが開いている状態で `AddTodoIntent` が成功した回数（起動中のみ）。
    ///
    /// 「アプリの UI で手作業している人」だけを数えるためのカウンタ。シートが開いて
    /// いないときの追加（Siri / Shortcuts / ウィジェット / コントロール）は数に入らない
    /// ので、**既にフレーズを使えている人に App Shortcut の教育を出さずに済む**
    /// （UI タップ起点に限る、という donation の判断と同じ理屈）。
    ///
    /// 表示ポリシー（何回目で出すか・何回まで出すか）は持たない。読み手は UI 側の
    /// `SiriTipModel`。詳細: docs/insights/04-ui-integration.md
    public private(set) var inAppAddCount = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Navigation Methods

    /// Navigates to the detail view for a todo.
    /// 同時に selectedTodo にも書き込むので macOS NavigationSplitView の detail も追従する。
    public func showDetail(for todo: TodoAppEntity) {
        path.append(.todoDetail(todo))
        selectedTodo = todo
    }

    /// Pops to the root view.
    public func popToRoot() {
        path.removeAll()
        selectedTodo = nil
    }

    /// Pops the last view from the stack.
    public func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Resets all navigation state to root — call this before programmatic navigation
    /// from intents to ensure a clean slate regardless of current app state.
    public func navigateToRoot() {
        path.removeAll()
        showingAddTodo = false
        selectedTodo = nil
    }

    /// Shows the add todo sheet.
    public func showAddTodo() {
        showingAddTodo = true
    }

    /// Navigates to the root list and asks it to run an in-app search for `term`.
    public func showSearch(matching term: String) {
        navigateToRoot()
        pendingSearchText = term
    }

    /// Navigates to the root list and asks it to show only todos matching `filter`.
    public func showList(filter: TodoFilterType) {
        navigateToRoot()
        pendingFilter = filter
    }

    /// Dismisses the add todo sheet.
    ///
    /// `AddTodoIntent.perform()` の成功時だけ呼ばれる（Cancel ボタンは
    /// `@Environment(\.dismiss)` を通るのでここには来ない）。シートが開いていた場合は
    /// アプリ UI 起点の追加なので ``inAppAddCount`` を進める。
    public func dismissAddTodo() {
        if showingAddTodo {
            inAppAddCount += 1
        }
        showingAddTodo = false
    }
}
