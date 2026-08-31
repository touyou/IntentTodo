//
//  IntentError.swift
//  IntentTodo
//

import AppIntents
import Foundation

/// Errors that can occur during Intent execution.
public enum IntentError: Error, LocalizedError, Sendable {
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

// MARK: - CustomAppIntentErrorConvertible

/// Decides what Siri says, separately from `errorDescription`.
///
/// `errorDescription` carries a developer-facing prefix ("Validation error: …") that should
/// never be read aloud. Apple: "When you throw a conforming error from a method such as
/// `perform()` […] the framework reads the `appIntentError` property and uses it directly"
/// — so the throwing side never has to call `AppIntentError(wrapping:)` itself.
///
/// `.notFound` maps onto the predefined `entityNotFound`, which tells the system *what kind*
/// of failure it was rather than only what to say.
///
/// Messages go through `"\(message)"` interpolation: a runtime string passed as a
/// `LocalizedStringResource` literal would be treated as a localization key.
extension IntentError: CustomAppIntentErrorConvertible {
    public var appIntentError: AppIntentError {
        switch self {
        case .validation(let message):
            AppIntentError(description: "\(message)")
        case .notFound(let message):
            AppIntentError(predefinedError: .Unrecoverable.entityNotFound, description: "\(message)")
        case .general(let message):
            AppIntentError(description: "\(message)")
        }
    }
}
