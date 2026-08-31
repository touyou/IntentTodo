//
//  MissedFeedbackModelTests.swift
//  UI
//
//  The banner's source of truth: re-reading, and clearing on dismissal.
//

import Foundation
import Testing
import TodoAppIntents
@testable import UI

@MainActor
@Suite("MissedFeedbackModel Tests")
struct MissedFeedbackModelTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "MissedFeedbackModelTests.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Starts empty and stays empty without records")
    func emptyByDefault() {
        let model = MissedFeedbackModel(defaults: makeDefaults())

        #expect(model.channels.isEmpty)
        model.refresh()
        #expect(model.channels.isEmpty)
    }

    @Test("refresh() picks up a record written by another process")
    func refreshReadsRecords() {
        let defaults = makeDefaults()
        let model = MissedFeedbackModel(defaults: defaults)

        // Reproduces a record written by an extension process.
        MissedFeedback.record(.notification, defaults: defaults)
        // Nothing to subscribe to, so it stays invisible until `refresh()`.
        #expect(model.channels.isEmpty)

        model.refresh()

        #expect(model.channels == [.notification])
    }

    @Test("dismiss() clears the record so it does not come back")
    func dismissClearsRecord() {
        let defaults = makeDefaults()
        MissedFeedback.record(.liveActivity, defaults: defaults)
        let model = MissedFeedbackModel(defaults: defaults)
        model.refresh()

        model.dismiss(.liveActivity)

        #expect(model.channels.isEmpty)
        model.refresh()
        #expect(model.channels.isEmpty)
    }
}
