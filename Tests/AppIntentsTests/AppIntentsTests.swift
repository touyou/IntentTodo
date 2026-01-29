//
//  AppIntentsTests.swift
//  IntentTodo
//

import Testing
@testable import TodoAppIntents

@Suite("AppIntents Tests")
struct AppIntentsTests {
    @Test("TodoIntentsPackage is accessible")
    func packageAccessible() {
        let package = TodoIntentsPackage()
        #expect(package != nil)
    }
}
