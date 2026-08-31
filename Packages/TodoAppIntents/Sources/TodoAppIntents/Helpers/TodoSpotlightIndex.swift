//
//  TodoSpotlightIndex.swift
//  IntentTodo
//
//  Single entry point for the Spotlight index.
//

#if os(iOS) || os(macOS) || os(visionOS)
import CoreSpotlight
import CryptoKit
import Foundation
import os.log

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "TodoSpotlightIndex")

/// The Spotlight index todos are donated to.
///
/// **Named, not the default index.** Apple:
/// Note: "When indexing your app's content, use a named `CSSearchableIndex` type and not
/// the default index. Use the default index only for prototyping and testing your code
/// during development."
///
enum TodoSpotlightIndex {
    /// Prefixed with the bundle id so it cannot collide with another app's index.
    static let name = "dev.touyou.IntentTodo.Todos"

    static func index() -> CSSearchableIndex {
        CSSearchableIndex(name: name)
    }

    // MARK: - Client State

    /// A 32-byte digest of what is currently indexed, handed to
    /// `endBatch(withClientState:)` and compared with `fetchLastClientState()` on the next
    /// launch to decide whether a full reindex can be skipped.
    ///
    /// Two constraints shape it:
    /// - client state is capped at **250 bytes**, which a list of ids exceeds immediately,
    ///   hence SHA-256
    /// - the input is **sorted before hashing**: depending on fetch order would make the
    ///   digest wobble for identical content and force a full reindex every time
    ///
    /// Callers mix modification times into `fingerprints`, not just ids: the same set of
    /// ids can have different contents after a CloudKit merge.
    static func clientState(for fingerprints: [String]) -> Data {
        var hasher = SHA256()
        for fingerprint in fingerprints.sorted() {
            hasher.update(data: Data(fingerprint.utf8))
        }
        return Data(hasher.finalize())
    }

    /// The last committed client state, or `nil` — which falls back to a full reindex.
    static func lastClientState(of index: CSSearchableIndex) async -> Data? {
        do {
            return try await index.fetchLastClientState()
        } catch {
            logger.error("fetchLastClientState failed: \(String(reflecting: error))")
            return nil
        }
    }

    // MARK: - Self-Healing

    /// Consecutive failures needed before the next launch reindexes everything. Not one:
    /// transient failures like `quotaExceeded` are not fixed by a full reindex.
    static let failureThreshold = 3

    private static let failureCountKey = "spotlight.consecutiveFailureCount"
    private static let needsFullReindexKey = "spotlight.needsFullReindex"

    /// Counts a failed incremental update.
    ///
    /// These failures are deliberately not reported to the intent caller — a Spotlight
    /// problem should not fail the todo operation — so without counting them a broken index
    /// never recovers. Everything looks fine inside the app while search finds nothing.
    static func recordFailure(_ defaults: UserDefaults = .standard) {
        let count = defaults.integer(forKey: failureCountKey) + 1
        defaults.set(count, forKey: failureCountKey)
        guard count >= failureThreshold else { return }
        defaults.set(true, forKey: needsFullReindexKey)
        logger.error("spotlight failed \(count) times in a row; requesting a full reindex on next launch")
    }

    /// Resets the consecutive failure count.
    static func recordSuccess(_ defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: failureCountKey) != 0 else { return }
        defaults.set(0, forKey: failureCountKey)
    }

    /// While `true`, launch-time indexing ignores a matching client state — otherwise
    /// "index broken, state current" has no exit.
    static func needsFullReindex(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: needsFullReindexKey)
    }

    /// Clears the request. Only called after a successful full reindex.
    static func clearFullReindexRequest(_ defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: needsFullReindexKey)
        defaults.set(0, forKey: failureCountKey)
    }

    // MARK: - Legacy Default Index

    private static let purgeFlagKey = "spotlight.legacyDefaultIndexPurged"

    /// Clears items left in `CSSearchableIndex.default()` once.
    ///
    /// Devices updating from a build that used the default index would otherwise show every
    /// todo twice. Deleting everything is safe because only this app's todos were ever put
    /// there. The flag is not set on failure, so a failed attempt retries next launch.
    static func purgeLegacyDefaultIndexIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: purgeFlagKey) else { return }
        do {
            try await CSSearchableIndex.default().deleteAllSearchableItems()
            defaults.set(true, forKey: purgeFlagKey)
            logger.info("purged legacy default Spotlight index")
        } catch {
            logger.error("purging legacy default index failed: \(String(reflecting: error))")
        }
    }
}
#endif
