//
//  MissedFeedbackModel.swift
//  UI
//
//  Surfaces undelivered feedback as a banner in the list that points at Settings.
//

import Foundation
import Observation
import TodoAppIntents

/// Exposes `MissedFeedback` records to views.
///
/// The writer can be an extension process, so there is nothing to observe: callers invoke
/// `refresh()` when the app comes forward.
@MainActor
@Observable
public final class MissedFeedbackModel {
    /// Channels to report, in `MissedFeedback.Channel.allCases` order.
    public private(set) var channels: [MissedFeedback.Channel] = []

    /// Injectable for tests; `nil` uses the App Group store.
    private let defaults: UserDefaults?

    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
    }

    /// Re-reads the records.
    public func refresh() {
        channels = MissedFeedback.pending(defaults)
    }

    /// Clears the record, so the banner returns only if feedback is lost again.
    public func dismiss(_ channel: MissedFeedback.Channel) {
        MissedFeedback.clear(channel, defaults: defaults)
        refresh()
    }
}
