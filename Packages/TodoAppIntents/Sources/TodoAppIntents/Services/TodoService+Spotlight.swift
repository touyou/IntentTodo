//
//  TodoService+Spotlight.swift
//  TodoAppIntents
//
//  Keeps Spotlight — the index Siri and Apple Intelligence read — in step with the store.
//
//  `IndexedEntity` conformance alone does not put anything in Spotlight, so this holds the
//  launch-time bulk index and the per-mutation deltas. Delta failures are never surfaced to
//  the intent caller; they are counted instead, and enough of them force a full reindex on
//  the next launch.
//
//  Members are internal rather than private because the callers (create / update / delete)
//  live in `TodoService.swift`.
//

#if os(iOS) || os(macOS) || os(visionOS)
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
    /// Reindex requests coming *from* Spotlight are answered by `TodoEntityQuery`
    /// (`IndexedEntityQuery`); this is only the launch-time seed.
    ///
    /// Skipped entirely when the content digest matches the last committed client state,
    /// since `reindexSpotlight` already tracks individual changes — unless deltas have been
    /// failing repeatedly, in which case skipping would leave "index broken, state current"
    /// with no way out.
    public func indexAllForSpotlight() async {
        #if os(iOS) || os(macOS) || os(visionOS)
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
                // Ending an empty batch does not persist the state, so do not open one.
                // Nothing to repair either, so drop any outstanding request.
                spotlightLogger.info("indexAllForSpotlight nothing to index")
                TodoSpotlightIndex.clearFullReindexRequest()
                return
            }
            spotlightLogger.info("indexAllForSpotlight start count=\(items.count) repairing=\(isRepairing)")
            // The batch has to be opened *before* the index calls.
            index.beginBatch()
            try await index.indexAppEntities(items.map { TodoAppEntity(from: $0) })
            // Committed only when every entity made it, so a launch that threw halfway
            // keeps the previous state and reindexes fully next time.
            try await index.endBatch(withClientState: state)
            TodoSpotlightIndex.clearFullReindexRequest()
            spotlightLogger.info("indexAllForSpotlight done count=\(items.count)")
        } catch {
            spotlightLogger.error("indexAllForSpotlight failed: \(String(reflecting: error))")
            TodoSpotlightIndex.recordFailure()
        }
        #endif
    }

    // MARK: - Incremental Updates

    /// Add / update a single todo in Spotlight. Fire-and-forget; Spotlight
    /// failures must not surface to the Intent caller.
    ///
    /// Cancels any in-flight task for the same id first, so rapid toggling cannot let an
    /// older state land after a newer one.
    func reindexSpotlight(_ entity: TodoAppEntity) {
        #if os(iOS) || os(macOS) || os(visionOS)
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

    /// Remove a deleted todo from Spotlight. Same in-flight cancellation as
    /// `reindexSpotlight`.
    func deindexSpotlight(id: String) {
        #if os(iOS) || os(macOS) || os(visionOS)
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

    #if os(iOS) || os(macOS) || os(visionOS)
    /// `CSSearchableIndexErrorDomain` codes distinguish quotaExceeded(1),
    /// invalidIndexState(2), userInteractionRequired(3) and indexUnavailable(4), so the code
    /// is logged rather than flattened into one error.
    ///
    /// Failures are also counted: nothing else would ever notice a broken index, since they
    /// are deliberately not reported to the caller.
    static func logSpotlight(_ error: Error, action: String, id: String) {
        let nsError = error as NSError
        spotlightLogger.error(
            "spotlight \(action) failed id=\(id, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code): \(String(reflecting: error))"
        )
        TodoSpotlightIndex.recordFailure()
    }
    #endif
}
