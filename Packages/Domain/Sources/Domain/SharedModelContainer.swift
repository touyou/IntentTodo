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
import os.log
import SwiftData

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "SharedModelContainer")

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
    ///
    /// `cloudKitDatabase: .automatic` pulls the container identifier from the
    /// target's `com.apple.developer.icloud-container-identifiers` entitlement
    /// (`iCloud.dev.touyou.IntentTodo`). All targets that open this store must
    /// carry that entitlement plus `aps-environment` for silent remote push.
    public static var configuration: ModelConfiguration? {
        if let containerURL = sharedContainerURL {
            let storeURL = containerURL.appendingPathComponent(databaseFilename)
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
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
        logger.info("createContainer() called")
        logger.info("App Group identifier: \(appGroupIdentifier)")
        logger.info("Shared container URL: \(sharedContainerURL?.absoluteString ?? "nil")")

        if let config = configuration {
            logger.info("Using shared configuration with URL")
            return try ModelContainer(for: schema, configurations: [config])
        } else {
            logger.info("Using fallback configuration (no App Group)")
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
