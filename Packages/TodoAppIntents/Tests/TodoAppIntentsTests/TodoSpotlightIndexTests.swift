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

    @Test("Empty input yields a digest distinct from any populated store")
    func digestOfNothing() {
        let empty = TodoSpotlightIndex.clientState(for: [])

        #expect(empty.count == 32)
        #expect(empty != TodoSpotlightIndex.clientState(for: ["a@1"]))
    }
}

/// 差分 index が失敗し続けたときの自己修復。ここが効かないと index が壊れたまま
/// 復旧せず、Spotlight / Siri から todo を引けない状態が続く（アプリ内では正常に見える）。
@Suite("TodoSpotlightIndex self-healing")
struct TodoSpotlightIndexSelfHealingTests {
    /// テストごとに独立した UserDefaults を使う（`.standard` を汚さない）。
    private func makeDefaults() -> UserDefaults {
        let suite = "TodoSpotlightIndexSelfHealingTests.\(UUID().uuidString)"
        // suiteName 付きの UserDefaults は必ず生成できる（不正な名前でない限り）。
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
        // 直後の 1 回の失敗で再び要求が立たない（カウントも 0 に戻っている）。
        TodoSpotlightIndex.recordFailure(defaults)
        #expect(TodoSpotlightIndex.needsFullReindex(defaults) == false)
    }
}
#endif
