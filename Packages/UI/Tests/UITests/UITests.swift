//
//  UITests.swift
//  IntentTodo
//

import Testing
@testable import UI

@Suite("UI Tests")
struct UITests {
    @Test("UI module is accessible")
    func uiModuleAccessible() {
        #expect(UI.version == "1.0.0")
    }
}
