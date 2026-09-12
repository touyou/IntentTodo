//
//  QueryCallLog.swift
//  TodoAppIntents
//
//  Records the query calls the system makes, so "nothing happened" can be told apart
//  from "asked and got nothing".
//

import Domain
import Foundation

/// One recorded call into an `EntityQuery` (or `IntentValueQuery`).
public struct QueryCallLogEntry: Codable, Sendable, Identifiable {
    public let id: UUID
    public let date: Date
    /// The query type, e.g. `TodoEntityQuery`.
    public let query: String
    /// The method, from `#function` at the call site.
    public let caller: String
    /// How many values the system asked for, or `nil` where the call has no input count
    /// (`suggestedEntities()`, `allEntities()`).
    public let requested: Int?
    /// How many were returned. `requested` > 0 with `returned` == 0 is the shape of a
    /// resolution failure.
    public let returned: Int
    /// Which process answered, from `ProcessInfo.processName` — the app, the widget
    /// extension or the Live Activity extension.
    public let process: String

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        query: String,
        caller: String,
        requested: Int?,
        returned: Int,
        process: String
    ) {
        self.id = id
        self.date = date
        self.query = query
        self.caller = caller
        self.requested = requested
        self.returned = returned
        self.process = process
    }
}

/// Records which query methods the system actually called.
///
/// Nothing else observes this. Entity resolution runs inside whichever process the system
/// chooses, driven by Siri, Spotlight, Shortcuts or Apple Intelligence, and a query that is
/// never called looks exactly like one that returned nothing: the surface is empty either
/// way. `os_log` shows the calls live but keeps no history a later run can read, and the
/// donation stream only records intent *execution*.
///
/// Written to the App Group `UserDefaults` because the caller may be an extension process,
/// which also makes it readable from outside the app (see
/// `skills/app-intents-testing/scripts/dump_query_call_log.py`).
///
/// DEBUG only: ``record(query:caller:requested:returned:defaults:)`` does nothing in a
/// release build, so call sites need no `#if` of their own.
public enum QueryCallLog {
    static let sharedDefaultsKey = "queryCallLog"

    /// Kept small enough that the whole log can be re-encoded on every call. Oldest entries
    /// are dropped first.
    static let entryLimit = 200

    /// `nil` when the App Group is unavailable, in which case recording is given up on.
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    /// Appends one call. Never throws and never blocks on anything but its own lock: a
    /// diagnostic must not be able to change the behaviour it is diagnosing.
    public static func record(
        query: String,
        caller: String,
        requested: Int? = nil,
        returned: Int,
        defaults: UserDefaults? = nil
    ) {
        #if DEBUG
        guard let defaults = defaults ?? sharedDefaults() else { return }
        let entry = QueryCallLogEntry(
            query: query,
            caller: caller,
            requested: requested,
            returned: returned,
            process: ProcessInfo.processInfo.processName
        )

        // Read-modify-write, so concurrent queries in one process would otherwise lose
        // entries. Two *processes* racing still can — what matters here is whether a call
        // happened at all, not an exact count.
        lock.lock()
        defer { lock.unlock() }
        var stored = decode(defaults)
        stored.append(entry)
        if stored.count > entryLimit {
            stored.removeFirst(stored.count - entryLimit)
        }
        guard let data = try? encoder.encode(stored) else { return }
        defaults.set(data, forKey: sharedDefaultsKey)
        #endif
    }

    /// Recorded calls, oldest first.
    public static func entries(_ defaults: UserDefaults? = nil) -> [QueryCallLogEntry] {
        guard let defaults = defaults ?? sharedDefaults() else { return [] }
        return decode(defaults)
    }

    public static func clear(_ defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        defaults.removeObject(forKey: sharedDefaultsKey)
    }

    // MARK: - Private

    private static let lock = NSLock()

    /// ISO 8601 dates so the plist stays readable from `plutil` and from Python, which is
    /// how this log is read on the platforms that have no debug screen.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func decode(_ defaults: UserDefaults) -> [QueryCallLogEntry] {
        guard let data = defaults.data(forKey: sharedDefaultsKey) else { return [] }
        return (try? decoder.decode([QueryCallLogEntry].self, from: data)) ?? []
    }
}
