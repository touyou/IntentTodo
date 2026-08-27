//
//  TodoSpotlightIndex.swift
//  IntentTodo
//
//  Spotlight index の入口を 1 箇所に集約する。
//

#if os(iOS) || os(macOS)
import CoreSpotlight
import CryptoKit
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoSpotlightIndex")

/// Todo を donate する Spotlight index。
///
/// **名前付き index を使う**。Apple 公式 (Making app entities available in Spotlight) の
/// Note: "When indexing your app's content, use a named `CSSearchableIndex` type and not
/// the default index. Use the default index only for prototyping and testing your code
/// during development."
///
/// 経緯: docs/devlog/03-app-intents-core.md（2026-08-21 の default index からの移行）
enum TodoSpotlightIndex {
    /// アプリ固有の index 名。bundle id を前置してぶつからないようにする。
    static let name = "dev.touyou.IntentTodo.Todos"

    static func index() -> CSSearchableIndex {
        CSSearchableIndex(name: name)
    }

    // MARK: - client state（起動時フル再インデックスの省略）

    /// 索引済みの内容を表す 32 バイトのダイジェスト。
    ///
    /// `endIndexBatch(withClientState:)` に渡して index 側へ永続化し、次回起動時に
    /// `fetchLastClientState()` と突き合わせる。一致すれば全件再インデックスを省ける。
    ///
    /// 実装上の制約が 2 つある:
    /// - client state は **250 バイト上限**（公式ヘッダ）。id を並べると簡単に超えるので
    ///   SHA-256 で畳む
    /// - 入力は必ず**ソートしてから**hash する。fetch 順に依存すると、同じ内容でも
    ///   ダイジェストがぶれて毎回フル再インデックスになる
    ///
    /// `fingerprints` には id だけでなく更新時刻も混ぜる（呼出側の責務）。id の集合が
    /// 同じでも中身が変わることがある（アプリ未起動中に他デバイスの編集が CloudKit で
    /// 届いた場合など）。
    static func clientState(for fingerprints: [String]) -> Data {
        var hasher = SHA256()
        for fingerprint in fingerprints.sorted() {
            hasher.update(data: Data(fingerprint.utf8))
        }
        return Data(hasher.finalize())
    }

    /// 前回コミットされた client state。取得に失敗したら `nil`（＝フル再インデックスへ倒す）。
    static func lastClientState(of index: CSSearchableIndex) async -> Data? {
        do {
            return try await index.fetchLastClientState()
        } catch {
            logger.error("fetchLastClientState failed: \(String(reflecting: error))")
            return nil
        }
    }

    // MARK: - 失敗からの自己修復

    /// 連続失敗がこの回数に達したら、次の起動でフル再インデックスをやり直す。
    ///
    /// 1 回の失敗で倒さないのは、`quotaExceeded` / 一時的な `indexUnavailable` のような
    /// その場限りの失敗でフル再インデックスを走らせても直らないため。
    static let failureThreshold = 3

    private static let failureCountKey = "spotlight.consecutiveFailureCount"
    private static let needsFullReindexKey = "spotlight.needsFullReindex"

    /// 差分 index（`reindex` / `deindex`）の失敗を記録する。
    ///
    /// 差分の失敗は Intent の呼出側には伝えない（Spotlight の不調で todo の操作自体を
    /// 失敗させるべきではない）ので、放っておくと **index が壊れたまま復旧しない**。
    /// アプリ内では正常に見え、Spotlight / Siri から引けないことにユーザーは気付けない。
    /// 閾値に達したら「次回起動でフル再インデックス」の要求を立てる。
    static func recordFailure(_ defaults: UserDefaults = .standard) {
        let count = defaults.integer(forKey: failureCountKey) + 1
        defaults.set(count, forKey: failureCountKey)
        guard count >= failureThreshold else { return }
        defaults.set(true, forKey: needsFullReindexKey)
        logger.error("spotlight failed \(count) times in a row; requesting a full reindex on next launch")
    }

    /// 差分 index の成功を記録する（連続失敗のカウントを畳む）。
    static func recordSuccess(_ defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: failureCountKey) != 0 else { return }
        defaults.set(0, forKey: failureCountKey)
    }

    /// フル再インデックスが要求されているか。
    ///
    /// `true` の間は起動時の client state 一致による省略を**行わない**。省略してしまうと
    /// 「index は壊れているが state は最新」の状態から抜け出せない。
    static func needsFullReindex(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: needsFullReindexKey)
    }

    /// フル再インデックスの要求を降ろす。成功したときだけ呼ぶ。
    static func clearFullReindexRequest(_ defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: needsFullReindexKey)
        defaults.set(0, forKey: failureCountKey)
    }

    // MARK: - 旧 default index からの移行

    private static let purgeFlagKey = "spotlight.legacyDefaultIndexPurged"

    /// `CSSearchableIndex.default()` に残っているアイテムを 1 度だけ消す。
    ///
    /// 名前付き index へ移す前のバージョンから更新した端末では、消さないと同じ todo が
    /// Spotlight に二重で出る。default index にはこのアプリの todo しか入れていないので
    /// 全消しで問題ない。失敗してもフラグを立てないので次回起動で再試行する。
    static func purgeLegacyDefaultIndexIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: purgeFlagKey) else { return }
        do {
            try await CSSearchableIndex.default().deleteAllSearchableItems()
            defaults.set(true, forKey: purgeFlagKey)
            logger.info("purged legacy default Spotlight index")
        } catch {
            logger.error("purging legacy default index failed: \(String(reflecting: error))")
        }
    }
}
#endif
