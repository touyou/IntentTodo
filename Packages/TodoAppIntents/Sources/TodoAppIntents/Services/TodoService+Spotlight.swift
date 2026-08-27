//
//  TodoService+Spotlight.swift
//  TodoAppIntents
//
//  Spotlight（= Apple Intelligence / Siri が引く索引）への反映。
//
//  `IndexedEntity` 準拠だけでは Spotlight に載らないため、起動時の全件投入と
//  mutation ごとの差分反映をここで持つ。差分の失敗は Intent の呼出側に伝えない
//  代わりに連続失敗を数え、閾値を超えたら次回起動でフル再インデックスをやり直す
//  （`TodoSpotlightIndex` の「失敗からの自己修復」）。
//
//  メンバーが private ではなく internal なのは、呼び手（create / update / delete）が
//  `TodoService.swift` 側に居るため。
//

#if os(iOS) || os(macOS)
import CoreSpotlight
#endif
import Domain
import Foundation
import os.log

let spotlightLogger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoService.Spotlight")

extension TodoService {
    /// Populate Spotlight with every todo currently in the store. Call once on
    /// app launch — `IndexedEntity` conformance alone is not enough for
    /// Spotlight to discover entities (it covers Apple Intelligence surfaces).
    ///
    /// Spotlight 側からの再インデックス要求には `TodoEntityQuery`
    /// (`IndexedEntityQuery`) が応答する。こちらは起動時の初期投入専用。
    ///
    /// 前回コミットした client state と内容ダイジェストが一致していれば**丸ごと省く**。
    /// 逐次の変更は `reindexSpotlight` が拾っているので、ここが毎起動走る必要はない。
    /// ダイジェストの作り方と 250 バイト制約は `TodoSpotlightIndex.clientState(for:)`。
    ///
    /// ただし差分 index が連続で失敗している（`TodoSpotlightIndex.needsFullReindex()`）
    /// ときは省略しない。省略すると「index は壊れているが state は最新」から抜け出せず、
    /// Spotlight / Siri から todo を引けない状態が続く。
    public func indexAllForSpotlight() async {
        #if os(iOS) || os(macOS)
        await TodoSpotlightIndex.purgeLegacyDefaultIndexIfNeeded()
        let isRepairing = TodoSpotlightIndex.needsFullReindex()
        do {
            let items = try repository.fetchAll()
            let state = TodoSpotlightIndex.clientState(
                for: items.map { "\($0.id.uuidString)@\($0.modifiedAt.timeIntervalSinceReferenceDate)" }
            )
            let index = TodoSpotlightIndex.index()
            if !isRepairing, await TodoSpotlightIndex.lastClientState(of: index) == state {
                spotlightLogger.info("indexAllForSpotlight skipped (unchanged) count=\(items.count)")
                return
            }
            guard !items.isEmpty else {
                // 空のバッチを endIndexBatch しても state は永続化されない。開かずに抜ける。
                // 直す対象が無いので修復要求も降ろす。
                spotlightLogger.info("indexAllForSpotlight nothing to index")
                TodoSpotlightIndex.clearFullReindexRequest()
                return
            }
            spotlightLogger.info("indexAllForSpotlight start count=\(items.count) repairing=\(isRepairing)")
            // batch は index 呼び出しの**前**に開く。
            index.beginBatch()
            try await index.indexAppEntities(items.map { TodoAppEntity(from: $0) })
            // 全件成功したときだけコミットする。途中で throw した起動は前回の state を
            // 残したままなので、次回起動でフル再インデックスをやり直す。
            try await index.endBatch(withClientState: state)
            TodoSpotlightIndex.clearFullReindexRequest()
            spotlightLogger.info("indexAllForSpotlight done count=\(items.count)")
        } catch {
            spotlightLogger.error("indexAllForSpotlight failed: \(String(reflecting: error))")
            TodoSpotlightIndex.recordFailure()
        }
        #endif
    }

    // MARK: - 差分反映

    /// Add / update a single todo in Spotlight. Fire-and-forget; Spotlight
    /// failures must not surface to the Intent caller.
    ///
    /// 同じ id に対して前回の reindex/deindex Task が残っていればキャンセルしてから
    /// 新しい Task を走らせる。これで連続トグル時に古い状態が後から上書きする
    /// race condition を避ける。
    func reindexSpotlight(_ entity: TodoAppEntity) {
        #if os(iOS) || os(macOS)
        let id = entity.id
        inflightSpotlightTasks[id]?.cancel()
        inflightSpotlightTasks[id] = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in self?.inflightSpotlightTasks.removeValue(forKey: id) }
            }
            do {
                try await TodoSpotlightIndex.index().indexAppEntities([entity])
                if Task.isCancelled { return }
                TodoSpotlightIndex.recordSuccess()
                spotlightLogger.debug("reindex ok id=\(id)")
            } catch is CancellationError {
                return
            } catch {
                Self.logSpotlight(error, action: "reindex", id: id)
            }
        }
        #endif
    }

    /// Remove a deleted todo from Spotlight. race 対策は `reindexSpotlight` と同じ。
    func deindexSpotlight(id: String) {
        #if os(iOS) || os(macOS)
        inflightSpotlightTasks[id]?.cancel()
        inflightSpotlightTasks[id] = Task { [weak self] in
            defer {
                Task { @MainActor [weak self] in self?.inflightSpotlightTasks.removeValue(forKey: id) }
            }
            do {
                try await TodoSpotlightIndex.index().deleteAppEntities(
                    identifiedBy: [id],
                    ofType: TodoAppEntity.self
                )
                if Task.isCancelled { return }
                TodoSpotlightIndex.recordSuccess()
                spotlightLogger.debug("deindex ok id=\(id)")
            } catch is CancellationError {
                return
            } catch {
                Self.logSpotlight(error, action: "deindex", id: id)
            }
        }
        #endif
    }

    #if os(iOS) || os(macOS)
    /// CSSearchableIndex のエラーは `NSError(domain: CSSearchableIndexErrorDomain)`
    /// で `code` を見れば quotaExceeded(1) / invalidIndexState(2) /
    /// userInteractionRequired(3) / indexUnavailable(4) を区別できる。
    /// 一律 `error` で潰さず、判別できるようにログに出しておくと運用で原因切り分けがしやすい。
    ///
    /// あわせて連続失敗を数える。差分 index の失敗は呼出側に伝えない設計なので、
    /// 数えておかないと index が壊れたまま復旧する契機が無い
    /// （`TodoSpotlightIndex.recordFailure` → 次回起動でフル再インデックス）。
    static func logSpotlight(_ error: Error, action: String, id: String) {
        let nsError = error as NSError
        spotlightLogger.error(
            "spotlight \(action) failed id=\(id, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code): \(String(reflecting: error))"
        )
        TodoSpotlightIndex.recordFailure()
    }
    #endif
}
