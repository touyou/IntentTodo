//
//  MissedFeedbackTests.swift
//  TodoAppIntents
//
//  「伝えられなかった」記録の読み書き。ここが壊れると設定誘導が出ず、
//  Control の失敗もライブアクティビティ不在も無音のままになる。
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("MissedFeedback")
struct MissedFeedbackTests {
    /// テストごとに独立した UserDefaults を使う（App Group の実ストアを汚さない）。
    private func makeDefaults() -> UserDefaults {
        let suite = "MissedFeedbackTests.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Nothing pending on a clean store")
    func emptyByDefault() {
        #expect(MissedFeedback.pending(makeDefaults()).isEmpty)
    }

    @Test("A recorded channel becomes pending")
    func recordThenPending() {
        let defaults = makeDefaults()

        MissedFeedback.record(.notification, defaults: defaults)

        #expect(MissedFeedback.pending(defaults) == [.notification])
    }

    @Test("Recording the same channel twice does not duplicate it")
    func recordIsIdempotent() {
        let defaults = makeDefaults()

        MissedFeedback.record(.liveActivity, defaults: defaults)
        MissedFeedback.record(.liveActivity, defaults: defaults)

        #expect(MissedFeedback.pending(defaults) == [.liveActivity])
    }

    @Test("Pending channels come back in a stable order")
    func stableOrder() {
        let defaults = makeDefaults()

        MissedFeedback.record(.liveActivity, defaults: defaults)
        MissedFeedback.record(.notification, defaults: defaults)

        #expect(MissedFeedback.pending(defaults) == [.notification, .liveActivity])
    }

    @Test("Clearing one channel leaves the other pending")
    func clearOne() {
        let defaults = makeDefaults()
        MissedFeedback.record(.notification, defaults: defaults)
        MissedFeedback.record(.liveActivity, defaults: defaults)

        MissedFeedback.clear(.notification, defaults: defaults)

        #expect(MissedFeedback.pending(defaults) == [.liveActivity])
    }

    @Test("Clearing the last channel removes the key entirely")
    func clearLast() {
        let defaults = makeDefaults()
        MissedFeedback.record(.notification, defaults: defaults)

        MissedFeedback.clear(.notification, defaults: defaults)

        #expect(MissedFeedback.pending(defaults).isEmpty)
        #expect(defaults.object(forKey: MissedFeedback.sharedDefaultsKey) == nil)
    }

    @Test("Unknown raw values stored by an older build are ignored")
    func ignoresUnknownRawValues() {
        let defaults = makeDefaults()
        defaults.set(["notification", "carrierPigeon"], forKey: MissedFeedback.sharedDefaultsKey)

        #expect(MissedFeedback.pending(defaults) == [.notification])
    }
}
