//
//  TodoDeepLinkTests.swift
//  TodoAppIntents
//
//  URL スキームの作る側と読む側が一致していることを守る。
//
//  作る側はウィジェットの `Link` と `TodoAppEntity.urlRepresentation`、読む側は
//  アプリの `onOpenURL`。別ターゲットに分かれているのでビルドでは食い違いを検出できず、
//  「ウィジェットをタップしても何も起きない」という形でしか出ない。
//

import AppIntents
import Foundation
import Testing
@testable import TodoAppIntents

@Suite("Todo deep link")
struct TodoDeepLinkTests {
    private static let todoID = "1E7D9F2A-0000-4000-8000-00000000ABCD"

    @Test("作った URL は同じリンクとして読み戻せる", arguments: [
        TodoDeepLink.addTodo,
        TodoDeepLink.todo(id: TodoDeepLinkTests.todoID)
    ])
    func roundTrips(link: TodoDeepLink) {
        #expect(TodoDeepLink(url: link.url) == link)
    }

    @Test("スキームが違う URL は解釈しない")
    func rejectsForeignScheme() throws {
        let url = try #require(URL(string: "https://example.com/todo/\(Self.todoID)"))
        #expect(TodoDeepLink(url: url) == nil)
    }

    @Test("知らないホストは解釈しない")
    func rejectsUnknownHost() throws {
        let url = try #require(URL(string: "intenttodo://unknown"))
        #expect(TodoDeepLink(url: url) == nil)
    }

    @Test("id の無い todo リンクは解釈しない")
    func rejectsTodoLinkWithoutID() throws {
        let url = try #require(URL(string: "intenttodo://todo"))
        #expect(TodoDeepLink(url: url) == nil)
    }

    /// `TodoAppEntity.urlRepresentation` は DSL リテラルなので `TodoDeepLink` を
    /// 呼べず、同じ形を 2 回書いている。ここがその 2 つを繋ぎ止める唯一の場所。
    @Test("entity の URL 表現は TodoDeepLink と同じ URL になる")
    func entityURLRepresentationMatchesDeepLink() async {
        let entity = TodoAppEntity(id: Self.todoID, title: "Deep link target")

        let representation = await entity.urlRepresentation

        #expect(representation == TodoDeepLink.todo(id: Self.todoID).url)
    }
}
