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

/// Siri / Shortcuts に出る（読み上げられる）文言を、`errorDescription` とは別に決める。
///
/// `errorDescription` は開発者向けに種別のプレフィックス（"Validation error: …"）を
/// 付けているが、それを Siri に読ませたくない。公式: *"When you throw a conforming error
/// from a method such as `perform()` […] the framework reads the `appIntentError`
/// property and uses it directly."* — つまり throw 側で `AppIntentError(wrapping:)` を
/// 明示的に呼ぶ必要はなく、この準拠だけで変換される。
///
/// `.notFound` は既定義の `entityNotFound` に載せる。文言だけでなく「参照先の entity が
/// 無い」という種別がシステムに伝わるため、`AppIntentError(description:)` で自前の文を
/// 渡すより情報量が多い。
///
/// 文字列は必ず `"\(message)"` の補間形式で渡す（`LocalizedStringResource` に
/// ランタイム文字列をリテラルとして渡すとローカライズキー扱いになる）。
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
