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

import Foundation

/// アプリが受け付けるディープリンク。
public enum TodoDeepLink: Equatable, Sendable {
    /// 新規作成シートを開く。
    case addTodo
    /// 指定 Todo の詳細を開く。
    case todo(id: String)

    /// URL スキーム。Info.plist の `CFBundleURLSchemes` と一致していること。
    public static let scheme = "intenttodo"

    /// このリンクを表す URL。
    public var url: URL {
        switch self {
        case .addTodo:
            return URL(string: "\(Self.scheme)://addTodo")!
        case .todo(let id):
            return URL(string: "\(Self.scheme)://todo/\(id)")!
        }
    }

    /// 受け取った URL を解釈する。スキームや形が違えば `nil`。
    public init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case "addTodo":
            self = .addTodo
        case "todo":
            // "intenttodo://todo/<id>" の id 部分。空なら解釈しない。
            let id = url.pathComponents.filter { $0 != "/" }.first ?? ""
            guard !id.isEmpty else { return nil }
            self = .todo(id: id)
        default:
            return nil
        }
    }
}
