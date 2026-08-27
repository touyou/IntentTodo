//
//  MissedFeedbackModel.swift
//  UI
//
//  伝達手段が塞がれていて届かなかったフィードバックを、一覧の設定誘導バナーへ流す。
//

import Foundation
import Observation
import TodoAppIntents

/// `MissedFeedback` の記録を View に見せるストア。
///
/// 記録を書くのは Control / Widget の Extension プロセスにもなるため、値の変化を
/// 購読する手段が無い。前面に戻ったタイミングで `refresh()` を呼んで読み直す。
@MainActor
@Observable
public final class MissedFeedbackModel {
    /// 表示すべき channel（`MissedFeedback.Channel.allCases` の順）。
    public private(set) var channels: [MissedFeedback.Channel] = []

    /// テストから差し替えるための注入口。`nil` なら App Group の既定ストア。
    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
    }

    /// 記録を読み直す。
    public func refresh() {
        channels = MissedFeedback.pending(defaults)
    }

    /// バナーを閉じる。記録を消すので、次に取りこぼすまで再表示されない。
    public func dismiss(_ channel: MissedFeedback.Channel) {
        MissedFeedback.clear(channel, defaults: defaults)
        refresh()
    }
}
