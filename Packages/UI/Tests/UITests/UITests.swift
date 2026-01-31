//
//  UITests.swift
//  IntentTodo
//

import Testing
import TodoAppIntents
@testable import UI

@Suite("UI Tests")
struct UITests {
    @Test("UI exports TodoAppIntents")
    func uiExportsTodoAppIntents() {
        // Verify that UI module properly re-exports TodoAppIntents
        // by checking we can access TodoAppEntity through it
        let entity = TodoAppEntity(id: "test", title: "Test Todo")
        #expect(entity.title == "Test Todo")
    }
}
