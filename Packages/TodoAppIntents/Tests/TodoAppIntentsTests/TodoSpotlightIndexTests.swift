//
//  TodoSpotlightIndexTests.swift
//  TodoAppIntents
//
//  Properties of the client-state digest. Getting it wrong means either a full reindex on
//  every launch or changes that never reach Spotlight, and neither is visible at build time.
//

#if os(iOS) || os(macOS) || os(visionOS)
import Foundation
import Testing
@testable import TodoAppIntents

@Suite("TodoSpotlightIndex client state")
struct TodoSpotlightIndexTests {
    @Test("Digest fits well under the 250-byte client state limit")
    func digestIsSmall() {
        let state = TodoSpotlightIndex.clientState(for: (0..<10_000).map { "todo-\($0)@\($0)" })

        #expect(state.count == 32)
    }

    @Test("Digest ignores input order")
    func digestIsOrderIndependent() {
        let ascending = TodoSpotlightIndex.clientState(for: ["a@1", "b@2", "c@3"])
        let shuffled = TodoSpotlightIndex.clientState(for: ["c@3", "a@1", "b@2"])

        #expect(ascending == shuffled)
    }

    @Test("Digest changes when an item's fingerprint changes")
    func digestTracksContent() {
        let before = TodoSpotlightIndex.clientState(for: ["a@1", "b@2"])
        let afterEdit = TodoSpotlightIndex.clientState(for: ["a@1", "b@3"])
        let afterAdd = TodoSpotlightIndex.clientState(for: ["a@1", "b@2", "c@1"])

        #expect(before != afterEdit)
        #expect(before != afterAdd)
    }

    @Test("Empty input yields a digest distinct from any populated store")
    func digestOfNothing() {
        let empty = TodoSpotlightIndex.clientState(for: [])

        #expect(empty.count == 32)
        #expect(empty != TodoSpotlightIndex.clientState(for: ["a@1"]))
    }
}

/// Recovery after repeated incremental failures. Without it a broken index never heals, and
/// the app looks perfectly fine while search finds nothing.
@Suite("TodoSpotlightIndex self-healing")
struct TodoSpotlightIndexSelfHealingTests {
    /// A private suite per test, so `.standard` is left alone.
    private func makeDefaults() -> UserDefaults {
        let suite = "TodoSpotlightIndexSelfHealingTests.\(UUID().uuidString)"
        // A suite-named `UserDefaults` always initialises for a valid name.
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("A clean install does not ask for a full reindex")
    func noRequestByDefault() {
        #expect(TodoSpotlightIndex.needsFullReindex(makeDefaults()) == false)
    }

    @Test("Failures below the threshold do not ask for a full reindex")
    func belowThreshold() {
        let defaults = makeDefaults()

        for _ in 1..<TodoSpotlightIndex.failureThreshold {
            TodoSpotlightIndex.recordFailure(defaults)
        }

        #expect(TodoSpotlightIndex.needsFullReindex(defaults) == false)
    }

    @Test("Reaching the threshold asks for a full reindex on the next launch")
    func reachingThreshold() {
        let defaults = makeDefaults()

        for _ in 0..<TodoSpotlightIndex.failureThreshold {
            TodoSpotlightIndex.recordFailure(defaults)
        }

        #expect(TodoSpotlightIndex.needsFullReindex(defaults))
    }

    @Test("A success in between resets the streak")
    func successResetsStreak() {
        let defaults = makeDefaults()

        for _ in 1..<TodoSpotlightIndex.failureThreshold {
            TodoSpotlightIndex.recordFailure(defaults)
        }
        TodoSpotlightIndex.recordSuccess(defaults)
        TodoSpotlightIndex.recordFailure(defaults)

        #expect(TodoSpotlightIndex.needsFullReindex(defaults) == false)
    }

    @Test("A completed full reindex clears the request and the streak")
    func clearingTheRequest() {
        let defaults = makeDefaults()
        for _ in 0..<TodoSpotlightIndex.failureThreshold {
            TodoSpotlightIndex.recordFailure(defaults)
        }

        TodoSpotlightIndex.clearFullReindexRequest(defaults)

        #expect(TodoSpotlightIndex.needsFullReindex(defaults) == false)
        // A single failure right afterwards must not re-raise the request.
        TodoSpotlightIndex.recordFailure(defaults)
        #expect(TodoSpotlightIndex.needsFullReindex(defaults) == false)
    }
}
#endif
