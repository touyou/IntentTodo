//
//  TodoFocusFilterStore.swift
//  TodoAppIntents
//
//  Observable store holding the current Focus filter inside the app process. Views read it
//  to filter the list and to draw the indicator.
//

import Foundation

/// Holds the current `TodoFocusFilter` and publishes changes to views.
///
/// Two writers: `TodoFocusFilterIntent.perform()` when the system delivers a Focus change,
/// and `syncFromSystem()` at launch or foregrounding, which covers transitions that
/// happened while the app was not running.
@MainActor
@Observable
public final class TodoFocusFilterStore {
    public static let shared = TodoFocusFilterStore()

    /// The filter the system has configured.
    public private(set) var filter: TodoFocusFilter

    /// Whether filtering is temporarily ignored.
    ///
    /// Showing "filtered by Focus" together with a way to lift it is what Calendar does
    /// [Apple: wwdc2022-10121 2:04]. Not persisted: the next Focus change folds it away.
    public var isSuspended = false

    /// What the list actually applies.
    public var effectiveFilter: TodoFocusFilter {
        isSuspended ? .inactive : filter
    }

    private init() {
        filter = TodoFocusFilter.loadFromSharedDefaults()
    }

    /// Applies a new filter and writes it to shared storage for the widget process.
    public func apply(_ newFilter: TodoFocusFilter) {
        // A new filter clears the suspension: carrying one Focus's override into the next
        // leaves no explanation for why filtering appears not to work.
        if newFilter != filter {
            isSuspended = false
        }
        filter = newFilter
        newFilter.saveToSharedDefaults()
    }

    /// Re-reads the filter from shared storage.
    public func reloadFromSharedDefaults() {
        filter = TodoFocusFilter.loadFromSharedDefaults()
    }

    /// Asks the system for the Focus filter currently in effect.
    ///
    /// Without an AppIntents extension, `perform()` is not called for Focus changes that
    /// happen while the app is not running [Apple: wwdc2022-10121 9:29]; calling this at
    /// launch and on foregrounding fills that gap. An unset filter throws, which maps to
    /// `.inactive`.
    public func syncFromSystem() async {
        do {
            let current = try await TodoFocusFilterIntent.current
            apply(current.resolvedFilter)
        } catch {
            apply(.inactive)
        }
    }
}
