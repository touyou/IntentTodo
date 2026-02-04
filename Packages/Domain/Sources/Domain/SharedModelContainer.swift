//
//  SharedModelContainer.swift
//  Domain
//
//  Provides a shared ModelContainer configuration for use across
//  the main app and all extensions (Widget, Control, Watch, etc.).
//
//  ## App Group Setup Required
//  To share data between app and extensions, you must:
//  1. Enable App Groups capability in Xcode for all targets
//  2. Use the same App Group identifier for all targets
//  3. The identifier should match `appGroupIdentifier` below
//

import Foundation
import SwiftData

/// Provides shared SwiftData configuration for data sharing between app and extensions.
public enum SharedModelContainer {
    // MARK: - App Group Configuration

    /// The App Group identifier for shared data.
    /// Must be configured in Xcode for all targets that need data access.
    public static let appGroupIdentifier = "group.com.touyou.IntentTodo"

    /// The URL for the shared container directory.
    /// Falls back to default location if App Group is not available.
    public static var sharedContainerURL: URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )
    }

    // MARK: - Schema Configuration

    /// The SwiftData schema including all domain models.
    public static let schema = Schema([
        TodoItem.self,
        SubTask.self,
        Category.self
    ])

    /// The database filename for SwiftData storage.
    public static let databaseFilename = "IntentTodo.store"

    // MARK: - Model Configuration

    /// Creates a ModelConfiguration for shared data storage.
    /// Uses App Group container if available, otherwise falls back to default.
    public static var configuration: ModelConfiguration? {
        if let containerURL = sharedContainerURL {
            let storeURL = containerURL.appendingPathComponent(databaseFilename)
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .none  // Disable CloudKit for shared container
            )
        } else {
            // Fallback for when App Group is not available (e.g., previews, tests)
            return ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
        }
    }

    // MARK: - Container Creation

    /// Creates a ModelContainer using the shared configuration.
    /// - Returns: A configured ModelContainer for shared data access.
    /// - Throws: Error if container creation fails.
    public static func createContainer() throws -> ModelContainer {
        if let config = configuration {
            return try ModelContainer(for: schema, configurations: [config])
        } else {
            // Minimal fallback
            return try ModelContainer(for: schema)
        }
    }

    /// Creates a ModelContainer for in-memory use (testing/previews).
    /// - Returns: An in-memory ModelContainer.
    /// - Throws: Error if container creation fails.
    public static func createInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
