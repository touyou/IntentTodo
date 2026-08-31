//
//  DueDateStatus.swift
//  Domain
//

import Foundation

/// Shared domain value for a due date's state, so every platform's UI derives its icon,
/// colour and layout from the same threshold.
public enum DueDateStatus: Sendable, Equatable {
    case normal
    case dueSoon
    case overdue

    /// Threshold for "due soon".
    public static let dueSoonThreshold: TimeInterval = 3600

    /// Completed todos are always `.normal`.
    public static func evaluate(date: Date, isCompleted: Bool, now: Date = Date()) -> DueDateStatus {
        guard !isCompleted else { return .normal }
        let interval = date.timeIntervalSince(now)
        if interval <= 0 { return .overdue }
        if interval <= dueSoonThreshold { return .dueSoon }
        return .normal
    }
}
