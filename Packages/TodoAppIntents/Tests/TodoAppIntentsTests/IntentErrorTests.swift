//
//  IntentErrorTests.swift
//  IntentTodo
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

@Suite("IntentError Tests")
struct IntentErrorTests {
    // MARK: - Error Description Tests

    @Test("Validation error has correct description")
    func validationError() {
        let error = IntentError.validation("Title cannot be empty")

        #expect(error.errorDescription == "Validation error: Title cannot be empty")
    }

    @Test("NotFound error has correct description")
    func notFoundError() {
        let error = IntentError.notFound("Todo with ID 123")

        #expect(error.errorDescription == "Not found: Todo with ID 123")
    }

    @Test("General error has correct description")
    func generalError() {
        let error = IntentError.general("Something went wrong")

        #expect(error.errorDescription == "Something went wrong")
    }

    // MARK: - Error Conformance Tests

    @Test("IntentError conforms to LocalizedError")
    func localizedErrorConformance() {
        let error: any LocalizedError = IntentError.general("Test")

        #expect(error.errorDescription != nil)
    }

    @Test("IntentError conforms to Error")
    func errorConformance() {
        let error: any Error = IntentError.validation("Test")

        #expect(error.localizedDescription.contains("Validation error"))
    }

    // MARK: - CustomAppIntentErrorConvertible

    /// `AppIntentError(predefinedError:description:)` は受け付けない値を渡すと
    /// **実行時に `fatalError()`** で落ちる（公式ドキュメント明記）。ビルドでは
    /// 検出できないので、全ケースを 1 度組み立てて経路を踏む。
    @Test("Every IntentError case builds an AppIntentError", arguments: [
        IntentError.validation("Title cannot be empty"),
        IntentError.notFound("Todo with ID 123"),
        IntentError.general("Something went wrong")
    ])
    func appIntentErrorConversion(error: IntentError) {
        let converted = error.appIntentError

        // Siri に読ませる文言は種別プレフィックス無しの生メッセージ。
        #expect(!converted.description.isEmpty)
        #expect(!converted.description.contains("Validation error:"))
        #expect(!converted.description.contains("Not found:"))
    }

    // MARK: - Edge Cases

    @Test("Validation error with empty message")
    func validationEmptyMessage() {
        let error = IntentError.validation("")

        #expect(error.errorDescription == "Validation error: ")
    }

    @Test("NotFound error with empty message")
    func notFoundEmptyMessage() {
        let error = IntentError.notFound("")

        #expect(error.errorDescription == "Not found: ")
    }

    @Test("General error with empty message")
    func generalEmptyMessage() {
        let error = IntentError.general("")

        #expect(error.errorDescription == "")
    }
}
