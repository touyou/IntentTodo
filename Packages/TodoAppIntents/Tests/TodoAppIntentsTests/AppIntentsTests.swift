//
//  AppIntentsTests.swift
//  IntentTodo
//

import AppIntents
import Testing
@testable import TodoAppIntents

@Suite("AppIntents Tests")
struct AppIntentsTests {
    @Test("TodoIntentsPackage pulls in no further packages")
    func packageIncludesNothingFurther() {
        // Typed as the protocol so conformance is enforced at compile time. What can
        // regress at runtime is `includedPackages`: this package is a leaf, and anything
        // appearing here would mean another module's intents are being pulled in
        // implicitly rather than by an explicit registration.
        let package: any AppIntentsPackage.Type = TodoIntentsPackage.self

        #expect(package.includedPackages.isEmpty)
    }
}
