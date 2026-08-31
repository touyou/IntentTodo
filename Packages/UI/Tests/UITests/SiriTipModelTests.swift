//
//  SiriTipModelTests.swift
//  UI
//
//  Presentation policy for the Siri tip, and that it has not become permanent again.
//

import Foundation
import Testing
@testable import UI

@MainActor
@Suite("SiriTipModel Tests")
struct SiriTipModelTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "SiriTipModelTests.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Not shown until the third in-app add")
    func waitsForThirdAdd() {
        let model = SiriTipModel(defaults: makeDefaults())

        #expect(!model.isPresented)
        model.recordInAppAdd()
        #expect(!model.isPresented)
        model.recordInAppAdd()
        #expect(!model.isPresented)
        model.recordInAppAdd()
        #expect(model.isPresented)
    }

    @Test("The add count survives relaunches")
    func countPersists() {
        let defaults = makeDefaults()
        let first = SiriTipModel(defaults: defaults)
        first.recordInAppAdd()
        first.recordInAppAdd()

        // Relaunching does not restart the count.
        let second = SiriTipModel(defaults: defaults)
        #expect(!second.isPresented)
        second.recordInAppAdd()

        #expect(second.isPresented)
    }

    @Test("Adding again while shown puts it away")
    func nextAddHidesIt() {
        let model = SiriTipModel(defaults: makeDefaults())
        for _ in 0..<3 { model.recordInAppAdd() }
        #expect(model.isPresented)

        model.recordInAppAdd()

        #expect(!model.isPresented)
    }

    @Test("Dismissing means it never comes back")
    func dismissIsPermanent() {
        let defaults = makeDefaults()
        let model = SiriTipModel(defaults: defaults)
        for _ in 0..<3 { model.recordInAppAdd() }
        #expect(model.isPresented)

        model.dismiss()

        #expect(!model.isPresented)
        model.recordInAppAdd()
        #expect(!model.isPresented)
        // Relaunching does not bring it back.
        let relaunched = SiriTipModel(defaults: defaults)
        relaunched.recordInAppAdd()
        #expect(!relaunched.isPresented)
    }

    @Test("hide() only puts it away for now — the next add brings it back")
    func hideIsTemporary() {
        let model = SiriTipModel(defaults: makeDefaults())
        for _ in 0..<3 { model.recordInAppAdd() }

        model.hide()
        #expect(!model.isPresented)

        model.recordInAppAdd()

        #expect(model.isPresented)
    }

    @Test("Shown at most twice, even if it is only ever hidden")
    func stopsAfterTwoPresentations() {
        let model = SiriTipModel(defaults: makeDefaults())
        for _ in 0..<3 { model.recordInAppAdd() }
        #expect(model.isPresented)
        model.hide()

        model.recordInAppAdd()
        #expect(model.isPresented)
        model.hide()

        // No third presentation: the total is capped.
        model.recordInAppAdd()
        #expect(!model.isPresented)
    }

    @Test("Someone who dismissed the old always-on row is not re-taught")
    func honorsLegacyDismissal() {
        let defaults = makeDefaults()
        // Key from when the tip was permanent; `false` meant dismissed.
        defaults.set(false, forKey: "siriTip.addTodo.isVisible")
        let model = SiriTipModel(defaults: defaults)

        for _ in 0..<3 { model.recordInAppAdd() }

        #expect(!model.isPresented)
    }
}
