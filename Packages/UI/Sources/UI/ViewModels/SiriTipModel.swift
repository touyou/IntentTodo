//
//  SiriTipModel.swift
//  UI
//
//  App Shortcut のフレーズを教える Siri Tip を「いつ出すか」だけを持つ。
//

import Foundation
import Observation

/// `SiriTipView` の表示ポリシー。
///
/// Apple の設計ガイダンスは Siri Tip を**常設せず、文脈のある瞬間に出す**ことを求めて
/// いる（wwdc2022-10169 18:58: "carefully select moments within your app to surface
/// these tips, at a time when people are likely to benefit from the education, such as
/// immediately before or after completing an action that they may want to repeat" /
/// wwdc2023-10102 11:14: "Siri Tips are best placed contextually"）。
/// ここでの「文脈のある瞬間」は **アプリの追加シートで Todo を追加した直後**
/// （= `AddTodoIntent` のフレーズを覚えると次から短縮できる瞬間）。
///
/// ポリシーは 3 つ:
/// - `presentationThreshold` 回目のアプリ内追加から出す（1 回目の追加でいきなり教えない）
/// - 出すのは通算 `maxPresentations` 回まで。前面から外れたら引っ込め、次の追加で出し直す
/// - 閉じるボタンを押されたら以後出さない（ガイダンスの "make your tip dismissible"）
///
/// 詳細: docs/insights/04-ui-integration.md
@MainActor
@Observable
public final class SiriTipModel {
    // MARK: - Policy

    /// 何回目のアプリ内追加から出すか。
    private static let presentationThreshold = 3

    /// 通算で何回まで出すか。
    private static let maxPresentations = 2

    // MARK: - Storage keys

    private enum Key {
        static let addCount = "siriTip.addTodo.inAppAddCount"
        static let presentationCount = "siriTip.addTodo.presentationCount"
        static let isDismissed = "siriTip.addTodo.isDismissed"
        /// リスト先頭に常設していた頃の `@AppStorage` キー（`false` = 閉じられた）。
        static let legacyIsVisible = "siriTip.addTodo.isVisible"
    }

    // MARK: - State

    /// 今 tip を出しているか。View はこれだけを見る。
    public private(set) var isPresented = false

    private let defaults: UserDefaults

    /// テストから差し替えるための注入口。`nil` なら `UserDefaults.standard`。
    ///
    /// App Group ではなくアプリローカルの既定ストアを使う。これは「このアプリの UI で
    /// 手作業している人への教育をもう済ませたか」という**アプリ UI だけの状態**で、
    /// Extension から読み書きする必要がない。
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? .standard
    }

    // MARK: - Events

    /// アプリ UI 起点の追加が起きたことを伝える。
    ///
    /// 呼び出し元は `NavigationModel.inAppAddCount` の変化。回数は永続化するので、
    /// 起動をまたいで 3 回目でも出る。
    public func recordInAppAdd() {
        guard !isFinished else { return }

        let count = defaults.integer(forKey: Key.addCount) + 1
        defaults.set(count, forKey: Key.addCount)

        // 出している間に次を追加した = 教育の役目は済んでいる。引っ込めるだけで、
        // 表示回数は消費済みなので数えない。
        if isPresented {
            isPresented = false
            return
        }

        guard count >= Self.presentationThreshold else { return }
        defaults.set(defaults.integer(forKey: Key.presentationCount) + 1, forKey: Key.presentationCount)
        isPresented = true
    }

    /// 閉じるボタン。以後出さない。
    public func dismiss() {
        isPresented = false
        defaults.set(true, forKey: Key.isDismissed)
    }

    /// 前面から外れた等で引っ込める。閉じたことにはしないので、次の追加で出し直す
    /// （表示回数の上限に達していなければ）。
    public func hide() {
        isPresented = false
    }

    // MARK: - Private

    /// もう出さない状態か。
    private var isFinished: Bool {
        if defaults.bool(forKey: Key.isDismissed) { return true }
        // 常設していた頃に閉じた人を再教育しない。旧キーは「表示中か」ではなく
        // 「まだ閉じていないか」として使われていたので false = 閉じ済み。
        if defaults.object(forKey: Key.legacyIsVisible) != nil,
           !defaults.bool(forKey: Key.legacyIsVisible) {
            return true
        }
        return defaults.integer(forKey: Key.presentationCount) >= Self.maxPresentations
    }
}
