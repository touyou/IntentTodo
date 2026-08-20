//
//  TodoSpotlightIndex.swift
//  IntentTodo
//
//  Spotlight index の入口を 1 箇所に集約する。
//

#if os(iOS) || os(macOS)
import CoreSpotlight
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
