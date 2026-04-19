//
//  DueDateStatus.swift
//  Domain
//

import Foundation

/// 期限日に対する状態を表す共有ドメイン値。各プラットフォームの UI は
/// 同じ閾値ロジックに基づき見た目（アイコン/色/レイアウト）を決定する。
public enum DueDateStatus: Sendable, Equatable {
    case normal
    case dueSoon
    case overdue

    /// "Due soon" 判定の閾値 (1 時間以内)。
    public static let dueSoonThreshold: TimeInterval = 3600

    /// 指定日時と完了フラグから状態を評価する。完了済みは常に `.normal`。
    public static func evaluate(date: Date, isCompleted: Bool, now: Date = Date()) -> DueDateStatus {
        guard !isCompleted else { return .normal }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return .overdue }
        if interval <= dueSoonThreshold { return .dueSoon }
        return .normal
    }
}
