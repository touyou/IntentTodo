//
//  IntentDependencies.swift
//  IntentTodo
//

import Foundation
import os.log
import Repository
import SwiftData

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "IntentDependencies")

/// Configuration for Intent dependencies.
///
/// Due to Sendable constraints with SwiftData, we use a shared ModelContainer
/// that Intents can access to create their own ModelContext.
@MainActor
public final class IntentDependencies {
    /// Shared instance for accessing dependencies.
    public static let shared = IntentDependencies()

    /// The model container for SwiftData.
    public private(set) var modelContainer: ModelContainer?

    /// Override repository for testing purposes.
    /// When set, `createRepository()` returns this instead of creating a new one.
    public var testRepository: (any TodoRepositoryProtocol)?

    private init() {}

    /// Configures the dependencies with the given model container.
    /// - Parameter modelContainer: The SwiftData model container to use.
    ///
    /// Call this at app launch:
    /// ```swift
    /// @main
    /// struct IntentTodoApp: App {
    ///     let modelContainer: ModelContainer
    ///
    ///     init() {
    ///         let container = try! ModelContainer(for: TodoItem.self)
    ///         modelContainer = container
    ///         IntentDependencies.shared.configure(modelContainer: container)
    ///     }
    /// }
    /// ```
    public func configure(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    /// Creates a new TodoRepository using the configured ModelContainer.
    /// - Returns: A TodoRepository instance (or test repository if configured).
    /// - Throws: If the ModelContainer cannot be created.
    ///
    /// When running in the main app, uses the configured ModelContainer.
    /// When running in extensions (Shortcuts, Siri, Control Center), falls back
    /// to SharedModelContainer for automatic App Group data access.
    public func createRepository() throws -> any TodoRepositoryProtocol {
        logger.info("createRepository() called")

        // Return test repository if configured (for testing)
        if let testRepo = testRepository {
            logger.info("Using test repository")
            return testRepo
        }

        // Use configured container if available (main app process)
        // Otherwise, create from SharedModelContainer (extension processes)
        let container: ModelContainer
        if let configuredContainer = modelContainer {
            logger.info("Using configured modelContainer (main app process)")
            container = configuredContainer
        } else {
            logger.info("modelContainer is nil, falling back to SharedModelContainer")
            do {
                container = try SharedModelContainer.createContainer()
                logger.info("SharedModelContainer created successfully")
            } catch {
                logger.error("Failed to create SharedModelContainer: \(error.localizedDescription)")
                throw error
            }
        }

        return SwiftDataTodoRepository(modelContext: container.mainContext)
    }

    /// Resets the dependencies to their initial state.
    /// Primarily used for testing cleanup.
    public func reset() {
        modelContainer = nil
        testRepository = nil
    }
}

/// Errors related to Intent dependencies.
public enum IntentDependenciesError: Error, LocalizedError {
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "IntentDependencies not configured. Call IntentDependencies.shared.configure(modelContainer:) at app launch."
        }
    }
}
