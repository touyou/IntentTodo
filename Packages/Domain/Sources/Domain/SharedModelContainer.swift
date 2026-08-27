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

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "SharedModelContainer")

/// Provides shared SwiftData configuration for data sharing between app and extensions.
public enum SharedModelContainer {
    // MARK: - App Group Configuration

    /// The App Group identifier for shared data.
    /// Must be configured in Xcode for all targets that need data access.
    public static let appGroupIdentifier = "group.com.touyou.IntentTodo"

    /// The URL for the shared container directory.
    ///
    /// **nil は「App Group が使えない」の信頼できる指標ではない**。iOS では
    /// entitlement が無ければ nil が返るが、**macOS では entitlement の無い
    /// プロセスでもパスが返る**（`~/Library/Group Containers/<id>`。ただし
    /// 書き込み不可）。SPM テストがここで nil を期待できないのはそのため。
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
    ///
    /// `cloudKitDatabase: .automatic` pulls the container identifier from the
    /// target's `com.apple.developer.icloud-container-identifiers` entitlement
    /// (`iCloud.dev.touyou.IntentTodo`). All targets that open this store must
    /// carry that entitlement plus `aps-environment` for silent remote push.
    ///
    /// **Production behaviour**: if the App Group container is unavailable
    /// (entitlement misconfig, provisioning profile issue, MDM block) the app
    /// would silently fall back to a per-process default store, leaving the
    /// main app and Extensions on different stores with no sync. We trip
    /// `fatalError` instead so the misconfig surfaces in TestFlight / App Store
    /// review rather than at unhappy users.
    ///
    /// In `DEBUG` builds (previews, iOS の SPM テスト) the same path returns a
    /// default non-shared store so unit tests can still construct a container.
    ///
    /// **macOS の SPM テストではこのフォールバックに入らない**。上記のとおり
    /// `sharedContainerURL` がパスを返してしまうため、開けない共有ストアを掴んで
    /// `createContainer()` が throw する。テスト側はそれを前提に組む
    /// （`SharedModelContainerTests` / `createInMemoryContainer()`）。
    ///
    /// 詳細: docs/insights/05-extensions-and-data-sharing.md
    /// 経緯: docs/devlog/05-extensions-and-data-sharing.md（2026-08-26）
    public static var configuration: ModelConfiguration {
        if let containerURL = sharedContainerURL {
            let storeURL = containerURL.appendingPathComponent(databaseFilename)
            return ModelConfiguration(
                schema: schema,
                url: storeURL,
                cloudKitDatabase: .automatic
            )
        }
        #if DEBUG
        logger.warning("App Group container unavailable — using non-shared fallback (DEBUG only)")
        return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        #else
        logger.critical("App Group container unavailable in production build — entitlement misconfig")
        fatalError("App Group missing in production build — check entitlements for \(appGroupIdentifier)")
        #endif
    }

    // MARK: - Container Creation

    /// Creates a ModelContainer using the shared configuration.
    /// - Returns: A configured ModelContainer for shared data access.
    /// - Throws: Error if container creation fails.
    public static func createContainer() throws -> ModelContainer {
        logger.info("createContainer() called")
        logger.info("App Group identifier: \(appGroupIdentifier)")
        logger.info("Shared container URL: \(sharedContainerURL?.absoluteString ?? "nil — DEBUG fallback")")

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            logger.error("ModelContainer creation failed: \(String(reflecting: error))")
            if let nsError = error as NSError? {
                logger.error("NSError domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
            }
            throw error
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
