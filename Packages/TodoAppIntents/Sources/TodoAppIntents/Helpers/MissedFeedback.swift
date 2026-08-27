//
//  MissedFeedback.swift
//  TodoAppIntents
//
//  「ユーザーに伝えられなかった」フィードバックを記録し、アプリが設定誘導を出せるようにする。
//

import Domain
import Foundation

/// 伝達手段（通知 / ライブアクティビティ）がシステム設定で塞がれていて、
/// フィードバックを届けられなかったことの記録。
///
/// **なぜ要るか**: Control / Widget から実行した Intent の失敗は、ローカル通知が唯一の
/// 伝達手段（dialog も snippet も表示されない。`AGENTS.md` の Dialog 表）。通知が拒否
/// されているとこの経路が無言で死に、コントロールは前の状態のまま再描画されるので
/// 「何も起きなかった」と区別できない。ライブアクティビティも同じで、設定で無効なら
/// 「期限が近い todo が出てこない」理由にユーザーが到達できない。
///
/// 記録は App Group の `UserDefaults` に置く。書き手は Widget / Control の Extension
/// プロセスにもなるため、プロセスをまたいで読める場所である必要がある。
/// 読み手はアプリの一覧画面で、設定誘導のバナーを出してから記録を消す。
public enum MissedFeedback {
    /// 塞がれ得る伝達手段。
    public enum Channel: String, CaseIterable, Sendable {
        /// ローカル通知。Control / Widget からの失敗報告の唯一の経路。
        case notification
        /// ライブアクティビティ（ロック画面 / Dynamic Island）。
        case liveActivity
    }

    static let sharedDefaultsKey = "missedFeedbackChannels"

    /// App Group の `UserDefaults`。取得できない構成では `nil`（記録は諦める）。
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    /// 伝えられなかったことを記録する。同じ channel の重複は畳む。
    public static func record(_ channel: Channel, defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        var stored = storedRawValues(defaults)
        guard !stored.contains(channel.rawValue) else { return }
        stored.append(channel.rawValue)
        defaults.set(stored, forKey: sharedDefaultsKey)
    }

    /// 未通知の記録。`Channel.allCases` の順に返す（表示順を安定させるため）。
    public static func pending(_ defaults: UserDefaults? = nil) -> [Channel] {
        guard let defaults = defaults ?? sharedDefaults() else { return [] }
        let stored = Set(storedRawValues(defaults))
        return Channel.allCases.filter { stored.contains($0.rawValue) }
    }

    /// 記録を消す。
    ///
    /// 呼ぶのは 2 つの場面:
    /// - ユーザーがバナーを閉じた / 設定へ送ったあと
    /// - その経路が**また使えるようになった**と分かったとき（通知が許可された /
    ///   ライブアクティビティが有効に戻った）。古い記録でバナーを出し続けないため
    public static func clear(_ channel: Channel, defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        let stored = storedRawValues(defaults)
        guard stored.contains(channel.rawValue) else { return }
        let remaining = stored.filter { $0 != channel.rawValue }
        if remaining.isEmpty {
            defaults.removeObject(forKey: sharedDefaultsKey)
        } else {
            defaults.set(remaining, forKey: sharedDefaultsKey)
        }
    }

    private static func storedRawValues(_ defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: sharedDefaultsKey) ?? []
    }
}
