//
//  TodoFocusFilterStore.swift
//  TodoAppIntents
//
//  アプリプロセス内で現在の集中モード絞り込みを保持する観測可能なストア。
//  View はここを見て絞り込みとインジケータを描く。
//

import Foundation

/// 現在の `TodoFocusFilter` を保持し、View に変更を通知する。
///
/// 書き手は 2 つある:
/// - `TodoFocusFilterIntent.perform()`（集中モードの切り替わりをシステムが届けたとき）
/// - `syncFromSystem()`（起動 / 復帰時。アプリが動いていない間の遷移は `perform()` が
///   呼ばれないため、`SetFocusFilterIntent.current` で現在値を取り直す）
@MainActor
@Observable
public final class TodoFocusFilterStore {
    public static let shared = TodoFocusFilterStore()

    /// システムが設定している絞り込み。
    public private(set) var filter: TodoFocusFilter

    /// 一時的に絞り込みを無視するか。
    ///
    /// 標準アプリ（カレンダー）が「Focus で絞り込み中」の表示と一緒に解除手段を
    /// 出しているのと同じ扱い（wwdc2022-10121 2:04）。ユーザーが今見たいものを
    /// 見られなくなるのを防ぐためのもので、永続化はしない。
    public var isSuspended = false

    /// 実際に一覧へ適用する設定。
    public var effectiveFilter: TodoFocusFilter {
        isSuspended ? .inactive : filter
    }

    private init() {
        filter = TodoFocusFilter.loadFromSharedDefaults()
    }

    /// 新しい設定を反映し、他プロセス（ウィジェット）向けに共有ストレージへ書く。
    public func apply(_ newFilter: TodoFocusFilter) {
        // 絞り込みが変わったら一時解除も畳む。前の Focus に対する解除を
        // 次の Focus へ持ち越すと、絞り込みが効かない理由が説明できなくなる。
        if newFilter != filter {
            isSuspended = false
        }
        filter = newFilter
        newFilter.saveToSharedDefaults()
    }

    /// 共有ストレージから読み直す。
    public func reloadFromSharedDefaults() {
        filter = TodoFocusFilter.loadFromSharedDefaults()
    }

    /// システムが持っている現在の Focus filter を取り直す。
    ///
    /// アプリ未起動中の Focus 遷移では `perform()` が呼ばれない（AppIntents
    /// Extension を持っていないため。wwdc2022-10121 9:29）。起動時とフォアグラウンド
    /// 復帰時にここを通すことで、その取りこぼしを埋める。
    /// Focus filter が未設定なら `notFound` が飛ぶので、その場合は `.inactive`。
    public func syncFromSystem() async {
        do {
            let current = try await TodoFocusFilterIntent.current
            apply(current.resolvedFilter)
        } catch {
            apply(.inactive)
        }
    }
}
