//
//  TodoAttributesLinkTests.swift
//  TodoAppIntentsTests
//

import Foundation
import Testing
import TodoAppIntents

@Suite("添付リンクを開いてよいかの判定")
struct TodoAttributesLinkTests {
    @Test("http / https は開ける", arguments: ["https://example.com/a", "http://example.com", "HTTPS://EXAMPLE.COM"])
    func webLinksAreOpenable(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(TodoAttributes.isOpenable(url))
    }

    @Test(
        "それ以外のスキームは開かない",
        arguments: ["tel:0312345678", "mailto:a@example.com", "intenttodo://todo/1", "file:///etc/hosts", "example.com/path"]
    )
    func otherSchemesAreNotOpenable(string: String) throws {
        let url = try #require(URL(string: string))
        #expect(!TodoAttributes.isOpenable(url))
    }
}
