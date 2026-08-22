//
//  TodoSpotlightIndexTests.swift
//  TodoAppIntents
//
//  client state ダイジェストの性質を押さえる。ここが崩れると「毎起動フル再インデックス」
//  か「変更が Spotlight に反映されない」のどちらかに倒れ、どちらもビルドでは分からない。
//

#if os(iOS) || os(macOS)
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

    @Test("Empty input still yields a stable digest")
    func digestOfNothing() {
        #expect(TodoSpotlightIndex.clientState(for: []) == TodoSpotlightIndex.clientState(for: []))
    }
}
#endif
