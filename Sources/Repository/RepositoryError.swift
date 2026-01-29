//
//  RepositoryError.swift
//  IntentTodo
//

import Foundation

/// Errors that can occur during repository operations.
public enum RepositoryError: Error, LocalizedError, Sendable {
    /// The requested item was not found.
    case notFound(id: UUID)

    /// The operation failed due to a persistence error.
    case persistenceError(underlying: Error)

    /// The operation was cancelled.
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Item with ID \(id) was not found."
        case .persistenceError(let underlying):
            return "Persistence error: \(underlying.localizedDescription)"
        case .cancelled:
            return "The operation was cancelled."
        }
    }
}
