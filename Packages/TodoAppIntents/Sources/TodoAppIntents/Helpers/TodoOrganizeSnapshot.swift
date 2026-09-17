//
//  TodoOrganizeSnapshot.swift
//  TodoAppIntents
//
//  One read of the store, shaped for the screens and menus that organise by list and tag.
//

import Foundation

/// Counts and memberships for every list and tag currently in use.
///
/// Built from a single `fetchAll()` so the management screens and the list's filter menu
/// agree on what exists, and so **no caller has to read `TodoItem.tags` itself**. Reading a
/// collection attribute off a deleted `@Model` traps, and a `@Query` result can hold a
/// deleted object for one frame — a fetch never returns one, which is why the tag
/// membership is resolved here instead of in a view body.
@MainActor
public struct TodoOrganizeSnapshot {
    /// Every stored list, sorted by name, with the synthetic "uncategorized" list left out
    /// (it is not a row anybody can rename or delete).
    public let lists: [CategoryAppEntity]

    /// Todo ids per list id. `CategoryAppEntity.uncategorizedID` holds the unfiled ones.
    public let todoIDsByListID: [String: Set<String>]

    /// Todo ids per tag, keyed by the tag's stored spelling.
    public let todoIDsByTag: [String: Set<String>]

    /// Section count per list id.
    public let sectionCountByListID: [String: Int]

    public init(
        lists: [CategoryAppEntity],
        todoIDsByListID: [String: Set<String>],
        todoIDsByTag: [String: Set<String>],
        sectionCountByListID: [String: Int]
    ) {
        self.lists = lists
        self.todoIDsByListID = todoIDsByListID
        self.todoIDsByTag = todoIDsByTag
        self.sectionCountByListID = sectionCountByListID
    }

    /// An empty snapshot, for the moment before the first read completes.
    public static var empty: TodoOrganizeSnapshot {
        TodoOrganizeSnapshot(
            lists: [],
            todoIDsByListID: [:],
            todoIDsByTag: [:],
            sectionCountByListID: [:]
        )
    }

    // MARK: - Reading

    /// Tags in collation order. `Set` keys have no order of their own, so one is chosen
    /// here rather than left to hashing.
    public var tags: [String] {
        todoIDsByTag.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    public func todoCount(inList listID: String) -> Int {
        todoIDsByListID[listID]?.count ?? 0
    }

    public func sectionCount(inList listID: String) -> Int {
        sectionCountByListID[listID] ?? 0
    }

    public func todoCount(withTag tag: String) -> Int {
        todoIDsByTag[tag]?.count ?? 0
    }

    public func todoIDs(withTag tag: String) -> Set<String> {
        todoIDsByTag[tag] ?? []
    }

    /// Lists whose names differ only in case or diacritics, grouped together.
    ///
    /// Surfaced so the management screen can point at the duplicates rather than leaving
    /// them to be spotted by eye: `CreateListIntent` folds a repeated name into the
    /// existing list, but lists created before that rule existed are still here.
    public var duplicateNameGroups: [[CategoryAppEntity]] {
        var groups: [[CategoryAppEntity]] = []
        for list in lists {
            if let index = groups.firstIndex(where: {
                guard let first = $0.first else { return false }
                return TodoAttributes.isSameTag(first.name, list.name)
            }) {
                groups[index].append(list)
            } else {
                groups.append([list])
            }
        }
        return groups.filter { $0.count > 1 }
    }
}
