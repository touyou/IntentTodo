//
//  QueryCallLogTests.swift
//  TodoAppIntents
//
//  The debug record of what the system asked the queries for. Broken, a query that was
//  never called is indistinguishable from one that returned nothing.
//
//  `record` is a no-op outside DEBUG, which is also the only configuration these run in.
//

import Foundation
import Testing
@testable import TodoAppIntents

@Suite("QueryCallLog")
struct QueryCallLogTests {
    /// A private suite per test, so the real App Group store is left alone.
    private func makeDefaults() -> UserDefaults {
        let suite = "QueryCallLogTests.\(UUID().uuidString)"
        // swiftlint:disable:next force_unwrapping
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test("Nothing recorded on a clean store")
    func emptyByDefault() {
        #expect(QueryCallLog.entries(makeDefaults()).isEmpty)
    }

    @Test("A recorded call keeps every field")
    func recordRoundTrips() {
        let defaults = makeDefaults()

        QueryCallLog.record(
            query: "TodoEntityQuery",
            caller: "entities(for:)",
            requested: 3,
            returned: 0,
            defaults: defaults
        )

        let entries = QueryCallLog.entries(defaults)
        #expect(entries.count == 1)
        #expect(entries.first?.query == "TodoEntityQuery")
        #expect(entries.first?.caller == "entities(for:)")
        #expect(entries.first?.requested == 3)
        #expect(entries.first?.returned == 0)
        // Which process answered is the point of the field; anything non-empty proves it
        // was captured rather than left blank.
        #expect(entries.first?.process.isEmpty == false)
    }

    @Test("Calls without an input count record nil rather than zero")
    func requestedIsOptional() {
        let defaults = makeDefaults()

        QueryCallLog.record(
            query: "TodoEntityQuery",
            caller: "suggestedEntities()",
            returned: 4,
            defaults: defaults
        )

        #expect(QueryCallLog.entries(defaults).first?.requested == nil)
    }

    @Test("Entries come back oldest first")
    func preservesOrder() {
        let defaults = makeDefaults()

        for index in 0..<3 {
            QueryCallLog.record(
                query: "TodoEntityQuery",
                caller: "call\(index)",
                returned: index,
                defaults: defaults
            )
        }

        #expect(QueryCallLog.entries(defaults).map(\.caller) == ["call0", "call1", "call2"])
    }

    @Test("The log is capped, dropping the oldest entries")
    func dropsOldestPastTheLimit() {
        let defaults = makeDefaults()
        let overflow = 5

        for index in 0..<(QueryCallLog.entryLimit + overflow) {
            QueryCallLog.record(
                query: "TodoEntityQuery",
                caller: "call\(index)",
                returned: 0,
                defaults: defaults
            )
        }

        let entries = QueryCallLog.entries(defaults)
        #expect(entries.count == QueryCallLog.entryLimit)
        #expect(entries.first?.caller == "call\(overflow)")
        #expect(entries.last?.caller == "call\(QueryCallLog.entryLimit + overflow - 1)")
    }

    @Test("Clearing removes the key entirely")
    func clearRemovesEverything() {
        let defaults = makeDefaults()
        QueryCallLog.record(query: "TodoEntityQuery", caller: "allEntities()", returned: 1, defaults: defaults)

        QueryCallLog.clear(defaults)

        #expect(QueryCallLog.entries(defaults).isEmpty)
        #expect(defaults.object(forKey: QueryCallLog.sharedDefaultsKey) == nil)
    }

    @Test("Unreadable stored data is ignored rather than crashing")
    func ignoresGarbage() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: QueryCallLog.sharedDefaultsKey)

        #expect(QueryCallLog.entries(defaults).isEmpty)
    }

    /// The log is written from whichever process answers the query, so the dates have to
    /// survive as text a plist reader outside the app can parse.
    @Test("Dates are stored as ISO 8601 text")
    func storesISO8601Dates() throws {
        let defaults = makeDefaults()
        QueryCallLog.record(query: "TodoEntityQuery", caller: "allEntities()", returned: 1, defaults: defaults)

        let data = try #require(defaults.data(forKey: QueryCallLog.sharedDefaultsKey))
        let raw = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let date = try #require(raw.first?["date"] as? String)
        #expect(ISO8601DateFormatter().date(from: date) != nil)
    }
}
