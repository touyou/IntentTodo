//
//  TodoDeepLink.swift
//  TodoAppIntents
//
//  The app's URL scheme, defined once.
//
//  The side that builds URLs (widget `Link(destination:)`, `URLRepresentableEntity`) and the
//  side that reads them (`onOpenURL`) are in different targets, so spelling the strings out
//  in both places breaks silently when only one is changed.
//
//

import Foundation

/// Deep links the app accepts.
public enum TodoDeepLink: Equatable, Sendable {
    /// Opens the add sheet.
    case addTodo
    /// Opens a specific todo's detail view.
    case todo(id: String)

    /// Must match `CFBundleURLSchemes` in the Info.plist.
    public static let scheme = "intenttodo"

    private static let addTodoHost = "addTodo"
    private static let todoHost = "todo"

    /// Built with `URLComponents` so ids containing URL-significant characters get
    /// percent-encoded; string interpolation would pass them through untouched.
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
            // Unreachable: scheme, host and path are all set above.
            preconditionFailure("Failed to build a deep link URL for \(self)")
        }
        return url
    }

    /// Parses an incoming URL, returning `nil` for a foreign scheme or shape.
    public init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host {
        case Self.addTodoHost:
            self = .addTodo
        case Self.todoHost:
            // The `<id>` in "intenttodo://todo/<id>"; an empty one is not a link.
            guard let id = url.pathComponents.first(where: { $0 != "/" }), !id.isEmpty else {
                return nil
            }
            self = .todo(id: id)
        default:
            return nil
        }
    }
}
