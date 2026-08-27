//
//  TodoEntityStore.swift
//  IntentTodo
//

import SwiftData

/// Process-wide accessor for the shared SwiftData container, used by
/// ``TodoAppEntity`` deferred properties that fetch data on demand.
///
/// App entities can't use `@Dependency` (Apple: "you can only use dependency
/// injection to pass data objects from your main app to its intents"), so the
/// app registers its container here at launch — mirroring the ambient
/// `modelData` accessor pattern in Apple's App Intents sample code.
///
/// Deferred properties are only ever fetched in the main app process
/// (Siri / Shortcuts / Spotlight follow-ups), so registering at the app's
/// `init()` is sufficient. When unset (previews, SPM tests) deferred fetches
/// degrade gracefully to an empty result.
@MainActor
public enum TodoEntityStore {
    /// The shared container used for on-demand entity property fetches.
    public static var container: ModelContainer?

    /// Registers the shared container. Call once, as early as possible at launch.
    public static func register(container: ModelContainer) {
        self.container = container
    }
}
