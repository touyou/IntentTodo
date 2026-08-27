//
//  TodoDeepLink.swift
//  TodoAppIntents
//
//  アプリの URL スキームを 1 か所で定義する。
//
//  作る側（ウィジェットの `Link(destination:)`、`TodoAppEntity` の
//  `URLRepresentableEntity`）と読む側（アプリの `onOpenURL`）が別ターゲットに
//  分かれているため、文字列を各所に散らすと片方だけ直して黙って壊れる。
//
//  詳細: docs/insights/03-app-intents-core.md（URL 表現）
//

import Foundation

/// アプリが受け付けるディープリンク。
public enum TodoDeepLink: Equatable, Sendable {
    /// 新規作成シートを開く。
    case addTodo
    /// 指定 Todo の詳細を開く。
    case todo(id: String)

    /// URL スキーム。Info.plist の `CFBundleURLSchemes` と一致していること。
    public static let scheme = "intenttodo"

    private static let addTodoHost = "addTodo"
    private static let todoHost = "todo"

    /// このリンクを表す URL。
    ///
    /// `URLComponents` で組むのは、id に URL で特別な意味を持つ文字が入っても
    /// パーセントエンコードが効くようにするため（文字列補間だと素通しになる）。
    public var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme
        switch self {
        case .addTodo:
            components.host = Self.addTodoHost
        case .todo(let id):
            components.host = Self.todoHost
            components.path = "/\(id)"
        }
        guard let url = components.url else {
            // scheme / host / path はすべてここで組み立てているので到達しない。
            preconditionFailure("Failed to build a deep link URL for \(self)")
        }
        return url
    }

    /// 受け取った URL を解釈する。スキームや形が違えば `nil`。
    public init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case Self.addTodoHost:
            self = .addTodo
        case Self.todoHost:
            // "intenttodo://todo/<id>" の id 部分。空なら解釈しない。
            guard let id = url.pathComponents.first(where: { $0 != "/" }), !id.isEmpty else {
                return nil
            }
            self = .todo(id: id)
        default:
            return nil
        }
    }
}
