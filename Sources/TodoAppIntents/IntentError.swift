//
//  IntentError.swift
//  IntentTodo
//

import Foundation

/// Errors that can occur during Intent execution.
public enum IntentError: Error, LocalizedError {
    /// A validation error occurred.
    case validation(String)

    /// The requested item was not found.
    case notFound(String)

    /// A general error occurred.
    case general(String)

    public var errorDescription: String? {
        switch self {
        case .validation(let message):
            return "Validation error: \(message)"
        case .notFound(let message):
            return "Not found: \(message)"
        case .general(let message):
            return message
        }
    }
}
