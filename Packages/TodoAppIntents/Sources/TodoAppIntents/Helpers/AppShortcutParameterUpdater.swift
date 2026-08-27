//
//  AppShortcutParameterUpdater.swift
//  IntentTodo
//
//  Bridges "todo データが変わった" (パッケージ側) と
//  `TodoAppShortcuts.updateAppShortcutParameters()` (アプリターゲット側) をつなぐ。
//

import Foundation

/// App Shortcut のパラメータ候補をシステムに再取得させるための間接層。
///
/// `updateAppShortcutParameters()` は `AppShortcutsProvider` の**具体型**に対する
/// static メソッドで、その具体型 (`TodoAppShortcuts`) はアプリターゲットにしか置けない
/// (パッケージに置くと統合メタデータから落ちる。`TodoAppShortcuts.swift` 冒頭参照)。
/// パッケージ側からは型を参照できないので、アプリ起動時にクロージャを登録してもらう。
///
/// 呼ぶべきタイミング:
/// - entity の追加 / 削除 / `displayRepresentation` の変化 (リネーム等)
/// - **アプリの初回起動時**。一度もフェッチされていないとパラメータ付きフレーズが機能しない
///
/// 詳細: docs/insights/03-app-intents-core.md
@MainActor
public enum AppShortcutParameterUpdater {
    private static var updateHandler: (@MainActor () -> Void)?

    /// アプリ起動時に `{ TodoAppShortcuts.updateAppShortcutParameters() }` を渡す。
    public static func register(_ handler: @escaping @MainActor () -> Void) {
        updateHandler = handler
    }

    /// entity の集合か表示内容が変わったことをシステムに伝える。
    ///
    /// 未登録のプロセス (Widget Extension など) では何もしない。App Shortcut の
    /// パラメータはアプリターゲットの provider が持つものなので、それで正しい。
    public static func notifyEntitiesChanged() {
        updateHandler?()
    }
}
