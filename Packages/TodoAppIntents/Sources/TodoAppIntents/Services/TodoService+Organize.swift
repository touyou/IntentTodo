//
//  TodoService+Organize.swift
//  TodoAppIntents
//
//  Business logic for the two things a todo is filed by: its list and its tags.
//
//  Kept out of `TodoService.swift` for file length; the rules are the same — every mutating
//  method exits through `Self.dataDidChange()`, and the todos it touches are reindexed so
//  Spotlight does not keep serving the old list name.
//

import Domain
import Foundation

// MARK: - Lists

extension TodoService {
    /// Creates a list, or returns the one that already carries that name.
    ///
    /// Folding a repeated name into the existing list rather than inserting a second row is
    /// deliberate: a list is identified by its name everywhere a person meets it — the
    /// filing picker, Siri ("add it to the Work list"), the Shortcuts editor — so two lists
    /// called *Work* are indistinguishable in every one of those places while quietly
    /// splitting the todos between them. `isSameTag` is the comparison, so case and
    /// diacritics do not create a near-duplicate either.
    @discardableResult
    public func createList(name: String, colorHex: String? = nil) throws -> CategoryAppEntity {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntentError.validation("List name cannot be empty")
        }
        if let existing = try repository.fetchCategories()
            .first(where: { TodoAttributes.isSameTag($0.name, trimmed) }) {
            return CategoryAppEntity(from: existing)
        }
        defer { Self.dataDidChange() }
        let category = Domain.Category(name: trimmed, colorHex: colorHex)
        try repository.create(category)
        return CategoryAppEntity(from: category)
    }

    /// Renames and/or recolours a list.
    ///
    /// Renaming into a name another list already has is rejected rather than silently
    /// merged: merging throws todos together, which is `mergeLists(sourceIDs:into:)`'s job
    /// and needs to be the caller's explicit choice.
    @discardableResult
    public func updateList(
        listId: String,
        name: FieldUpdate<String> = .unchanged,
        colorHex: FieldUpdate<String?> = .unchanged
    ) throws -> CategoryAppEntity {
        let category = try requireCategory(id: listId)
        if case .set(let value) = name {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw IntentError.validation("List name cannot be empty")
            }
            let clash = try repository.fetchCategories().contains {
                $0.id != category.id && TodoAttributes.isSameTag($0.name, trimmed)
            }
            guard !clash else {
                throw IntentError.validation("Another list is already called “\(trimmed)”")
            }
            category.name = trimmed
        }
        if case .set(let value) = colorHex {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
            category.colorHex = (trimmed?.isEmpty ?? true) ? nil : trimmed
        }
        defer { Self.dataDidChange() }
        try repository.update(category)
        let entity = CategoryAppEntity(from: category)
        // The list name is part of every filed todo's Spotlight record, so a rename that
        // stopped here would leave search answering with the old name.
        reindexTodos(filedUnder: category)
        return entity
    }

    /// Deletes a list. The todos filed under it stay, unfiled.
    ///
    /// No `requestConfirmation`: nothing is lost that cannot be put back by filing the
    /// todos again, which is why this single intent is safe to run from the app's own
    /// buttons as well as from Siri.
    public func deleteList(listId: String) throws {
        let category = try requireCategory(id: listId)
        let affected = (category.todos ?? []).map { TodoAppEntity(from: $0) }
        defer { Self.dataDidChange() }
        try repository.delete(category)
        // Built before the delete, but re-read after it: the entities above still carry the
        // old list, and the store has nullified the relation by now.
        for entity in affected {
            guard let refreshed = todo(id: entity.id) else { continue }
            reindexSpotlight(refreshed)
        }
    }

    /// Moves every todo out of `sourceIDs` into `listId`, then deletes the emptied lists.
    ///
    /// The fix for lists that have drifted into duplicates. Sections are not carried over —
    /// a section belongs to exactly one list, so the merged todos lose theirs rather than
    /// landing in a section of a list they are no longer in (the same rule
    /// `applyFiling(to:listId:sectionId:)` applies to a list change).
    @discardableResult
    public func mergeLists(sourceIDs: [String], into listId: String) throws -> CategoryAppEntity {
        let destination = try requireCategory(id: listId)
        let sources = try sourceIDs
            .filter { $0 != listId }
            .map { try requireCategory(id: $0) }
        guard !sources.isEmpty else {
            throw IntentError.validation("Pick at least one other list to merge")
        }
        defer { Self.dataDidChange() }

        var moved: [TodoItem] = []
        let now = Date()
        for source in sources {
            // Snapshotted, because assigning `category` below removes the todo from the
            // relationship being iterated.
            let filed = source.todos ?? []
            for item in filed {
                item.category = destination
                item.section = nil
                item.modifiedAt = now
                try repository.update(item)
                moved.append(item)
            }
        }
        for source in sources {
            try repository.delete(source)
        }
        for item in moved {
            reindexSpotlight(TodoAppEntity(from: item))
        }
        return CategoryAppEntity(from: destination)
    }

    // MARK: - Private

    /// Resolves a list id that has to name a real, stored list.
    ///
    /// `resolveCategory(id:)` answers `nil` for the synthetic "uncategorized" list, which is
    /// the right answer when *filing* a todo and the wrong one here: there is no stored row
    /// to rename, recolour or delete.
    private func requireCategory(id: String) throws -> Domain.Category {
        guard let category = try resolveCategory(id: id) else {
            throw IntentError.validation("“Uncategorized” is not a list that can be edited")
        }
        return category
    }

    /// Reindexes the todos filed under a list, for changes to the list itself.
    private func reindexTodos(filedUnder category: Domain.Category) {
        for item in category.todos ?? [] {
            reindexSpotlight(TodoAppEntity(from: item))
        }
    }
}

// MARK: - Tags

extension TodoService {
    /// Renames a tag across every todo carrying it, and reports how many changed.
    ///
    /// Renaming onto an existing tag merges the two, because that is what the stored value
    /// can express: `TodoAttributes.normalized(tags:)` folds the duplicate away, so a todo
    /// that had both ends up with one. That makes this the tag equivalent of merging lists,
    /// and there is no separate merge operation.
    @discardableResult
    public func renameTag(_ current: String, to newName: String) throws -> Int {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntentError.validation("Tag cannot be empty")
        }
        defer { Self.dataDidChange() }
        return try rewriteTags(matching: current) { tags in
            tags.map { TodoAttributes.isSameTag($0, current) ? trimmed : $0 }
        }
    }

    /// Removes a tag from every todo carrying it, and reports how many changed.
    ///
    /// The todos themselves are untouched, so this needs no confirmation of its own for the
    /// same reason `deleteList(listId:)` does not.
    @discardableResult
    public func deleteTag(_ tag: String) throws -> Int {
        defer { Self.dataDidChange() }
        return try rewriteTags(matching: tag) { tags in
            tags.filter { !TodoAttributes.isSameTag($0, tag) }
        }
    }

    /// One read of the store, shaped for the screens that organise by list and tag.
    ///
    /// Reads through a fetch rather than a `@Query`, which is what makes touching
    /// `TodoItem.tags` safe here: a fetch never hands back a deleted object, and reading a
    /// collection attribute off one traps.
    public func organizeSnapshot() throws -> TodoOrganizeSnapshot {
        let items = try repository.fetchAll()
        let categories = try repository.fetchCategories()

        var todoIDsByListID: [String: Set<String>] = [:]
        var todoIDsByTag: [String: Set<String>] = [:]
        for item in items {
            let id = item.id.uuidString
            let listID = item.category?.id.uuidString ?? CategoryAppEntity.uncategorizedID
            todoIDsByListID[listID, default: []].insert(id)
            for tag in item.tags {
                todoIDsByTag[tag, default: []].insert(id)
            }
        }

        var sectionCountByListID: [String: Int] = [:]
        for section in try repository.fetchSections() {
            guard let listID = section.category?.id.uuidString else { continue }
            sectionCountByListID[listID, default: 0] += 1
        }

        return TodoOrganizeSnapshot(
            lists: categories.map { CategoryAppEntity(from: $0) },
            todoIDsByListID: todoIDsByListID,
            todoIDsByTag: todoIDsByTag,
            sectionCountByListID: sectionCountByListID
        )
    }

    // MARK: - Private

    /// Applies `transform` to the tags of every todo that carries `tag`, saving only the
    /// ones whose tags actually changed.
    private func rewriteTags(
        matching tag: String,
        _ transform: ([String]) -> [String]
    ) throws -> Int {
        let now = Date()
        var changed = 0
        for item in try repository.fetchAll() {
            guard item.tags.contains(where: { TodoAttributes.isSameTag($0, tag) }) else { continue }
            let rewritten = TodoAttributes.normalized(tags: transform(item.tags))
            guard rewritten != item.tags else { continue }
            item.tags = rewritten
            item.modifiedAt = now
            try repository.update(item)
            reindexSpotlight(TodoAppEntity(from: item))
            changed += 1
        }
        return changed
    }
}
