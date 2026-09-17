//
//  SearchMatch.swift
//  UI
//
//  Shows *why* a row is in the search results.
//

import Foundation
import SwiftUI
import TodoAppIntents

/// What a todo matched a search term on.
///
/// The search looks at four things (title, description, list name, tags), so a result can be
/// on screen for a reason the row does not otherwise show — a todo whose *tag* matched looks
/// identical to one that matched nothing. This carries the answer to the row.
struct TodoSearchMatch: Equatable {
    /// The term being searched for. Empty means "no search is running".
    let term: String

    /// Tags on this todo that contain the term.
    let tags: [String]

    /// Whether the term is in the description rather than anywhere visible on the row.
    let matchesDescription: Bool

    /// Whether the term is in the name of the list the todo is filed under.
    let matchesList: Bool

    static let none = TodoSearchMatch(term: "", tags: [], matchesDescription: false, matchesList: false)

    var isSearching: Bool { !term.isEmpty }

    /// Whether anything beyond the title matched, i.e. whether the row needs to explain itself.
    var hasHiddenReason: Bool {
        isSearching && (!tags.isEmpty || matchesDescription || matchesList)
    }

    /// Builds the match for one todo.
    ///
    /// Uses `localizedStandardContains(_:)`, the same relation the search itself uses — a row
    /// must not claim a reason the filter did not act on.
    @MainActor
    static func make(
        for todo: TodoAppEntity,
        term: String,
        organize: TodoOrganizeSnapshot?
    ) -> TodoSearchMatch {
        guard !term.isEmpty else { return .none }
        let tags = (organize?.todoIDsByTag ?? [:])
            .filter { $0.key.localizedStandardContains(term) && $0.value.contains(todo.id) }
            .keys
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        return TodoSearchMatch(
            term: term,
            tags: tags,
            matchesDescription: todo.todoDescription?.localizedStandardContains(term) == true,
            matchesList: todo.category?.name.localizedStandardContains(term) == true
        )
    }
}

// MARK: - Highlighting

extension AttributedString {
    /// `text` with every occurrence of `term` emphasised.
    ///
    /// Bold rather than a coloured background: the row already carries colour (due date,
    /// favourite), and a highlight block behind part of a title competes with the row's
    /// selection state.
    static func highlighting(_ term: String, in text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard !term.isEmpty else { return attributed }
        var searchRange = attributed.startIndex..<attributed.endIndex
        while let found = attributed[searchRange].range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) {
            attributed[found].inlinePresentationIntent = .stronglyEmphasized
            guard found.upperBound < searchRange.upperBound else { break }
            searchRange = found.upperBound..<searchRange.upperBound
        }
        return attributed
    }
}

// MARK: - Reason row

/// The caption under a search result saying what it matched on.
///
/// Only rendered when the reason is *not* the title — a title match is already visible
/// because the matching words are emphasised in place.
struct TodoSearchReason: View {
    let match: TodoSearchMatch
    /// The list the todo is filed under, for the "matched the list name" case.
    let listName: String?

    /// Kept short: the point is "this is why you are seeing this row", not a full inventory.
    private static let tagLimit = 2

    var body: some View {
        if match.hasHiddenReason {
            HStack(spacing: 6) {
                ForEach(match.tags.prefix(Self.tagLimit), id: \.self) { tag in
                    chip(tag, systemImage: "number")
                }
                if match.tags.count > Self.tagLimit {
                    Text(.copy("+\(match.tags.count - Self.tagLimit)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if match.matchesList, let listName {
                    chip(listName, systemImage: "folder")
                }
                if match.matchesDescription {
                    Label(.copy("in notes"), systemImage: "text.alignleft")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func chip(_ text: String, systemImage: String) -> some View {
        Label {
            Text(AttributedString.highlighting(match.term, in: text))
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())
    }
}
