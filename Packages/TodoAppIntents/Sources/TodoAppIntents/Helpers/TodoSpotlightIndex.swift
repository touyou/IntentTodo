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
