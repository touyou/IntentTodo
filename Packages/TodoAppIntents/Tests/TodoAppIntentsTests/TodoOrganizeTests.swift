//
//  TodoOrganizeTests.swift
//  TodoAppIntentsTests
//
//  Covers creating, editing, merging and deleting lists, and renaming / removing tags.
//
//  These rules only show up in the stored relationships and arrays — a list whose todos
//  quietly vanished with it, or a rename that folded two tags into one, both build green.
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("リストとタグの整理")
@MainActor
struct TodoOrganizeTests {
    private func makeService(
        categories: [Domain.Category] = [],
        sections: [TodoSection] = []
    ) -> (TodoService, MockTodoRepository) {
        let repo = MockTodoRepository()
        for category in categories { repo.register(category) }
        for section in sections { repo.register(section) }
        return (TodoService(repository: repo), repo)
    }

    private func makeTodo(
        _ title: String,
        in category: Domain.Category? = nil,
        tags: [String] = [],
        repo: MockTodoRepository
    ) throws -> TodoItem {
        let item = TodoItem(title: title)
        item.tags = tags
        item.category = category
        if let category {
            category.todos = (category.todos ?? []) + [item]
        }
        try repo.create(item)
        return item
    }

    // MARK: - Creating lists

    @Test("createList が新しいリストを保存する")
    func createListStores() throws {
        let (service, repo) = makeService()

        let entity = try service.createList(name: "  Work  ")

        #expect(entity.name == "Work")
        #expect(try repo.fetchCategories().count == 1)
    }

    @Test("同名のリストは増やさず既存を返す")
    func createListFoldsDuplicateNames() throws {
        let work = Domain.Category(name: "Work")
        let (service, repo) = makeService(categories: [work])

        // Differs only in case, which is what `isSameTag` treats as the same name.
        let entity = try service.createList(name: "work")

        #expect(entity.id == work.id.uuidString)
        #expect(try repo.fetchCategories().count == 1)
    }

    @Test("空の名前は拒否される")
    func createListRejectsEmptyName() throws {
        let (service, _) = makeService()

        #expect(throws: IntentError.self) {
            _ = try service.createList(name: "   ")
        }
    }

    // MARK: - Editing lists

    @Test("updateList が名前と色を書き換える")
    func updateListRenamesAndRecolours() throws {
        let work = Domain.Category(name: "Work")
        let (service, _) = makeService(categories: [work])

        let entity = try service.updateList(
            listId: work.id.uuidString,
            name: .set("Office"),
            colorHex: .set("#FF3B30")
        )

        #expect(entity.name == "Office")
        #expect(work.name == "Office")
        #expect(work.colorHex == "#FF3B30")
    }

    @Test("触っていないフィールドは残る")
    func updateListLeavesUnchangedFields() throws {
        let work = Domain.Category(name: "Work", colorHex: "#007AFF")
        let (service, _) = makeService(categories: [work])

        _ = try service.updateList(listId: work.id.uuidString, name: .set("Office"))

        #expect(work.colorHex == "#007AFF")
    }

    @Test("色は明示的に消せる")
    func updateListClearsColour() throws {
        let work = Domain.Category(name: "Work", colorHex: "#007AFF")
        let (service, _) = makeService(categories: [work])

        _ = try service.updateList(listId: work.id.uuidString, colorHex: .set(nil))

        #expect(work.colorHex == nil)
    }

    @Test("他のリストと同名にする改名は拒否される")
    func updateListRejectsNameClash() throws {
        let work = Domain.Category(name: "Work")
        let home = Domain.Category(name: "Home")
        let (service, _) = makeService(categories: [work, home])

        #expect(throws: IntentError.self) {
            _ = try service.updateList(listId: home.id.uuidString, name: .set("work"))
        }
        #expect(home.name == "Home")
    }

    @Test("Uncategorized は編集対象にならない")
    func updateListRejectsSyntheticList() throws {
        let (service, _) = makeService()

        #expect(throws: IntentError.self) {
            _ = try service.updateList(
                listId: CategoryAppEntity.uncategorizedID,
                name: .set("Anything")
            )
        }
    }

    // MARK: - Deleting lists

    @Test("リストを消しても todo は残り、未分類になる")
    func deleteListKeepsTodos() throws {
        let work = Domain.Category(name: "Work")
        let (service, repo) = makeService(categories: [work])
        let item = try makeTodo("write the deck", in: work, repo: repo)

        try service.deleteList(listId: work.id.uuidString)

        #expect(try repo.fetchCategories().isEmpty)
        #expect(try repo.fetchAll().count == 1)
        #expect(item.category == nil)
    }

    // MARK: - Merging lists

    @Test("mergeLists が todo を移して空のリストを消す")
    func mergeListsMovesTodos() throws {
        let keep = Domain.Category(name: "Work")
        let duplicate = Domain.Category(name: "work")
        let (service, repo) = makeService(categories: [keep, duplicate])
        let moved = try makeTodo("write the deck", in: duplicate, repo: repo)

        let entity = try service.mergeLists(
            sourceIDs: [duplicate.id.uuidString],
            into: keep.id.uuidString
        )

        #expect(entity.id == keep.id.uuidString)
        #expect(moved.category?.id == keep.id)
        #expect(try repo.fetchCategories().map(\.id) == [keep.id])
    }

    @Test("移した todo は section を持ち越さない")
    func mergeListsDropsSection() throws {
        let keep = Domain.Category(name: "Work")
        let duplicate = Domain.Category(name: "Work Copy")
        let section = TodoSection(name: "Today")
        section.category = duplicate
        duplicate.sections = [section]
        let (service, repo) = makeService(categories: [keep, duplicate], sections: [section])
        let moved = try makeTodo("write the deck", in: duplicate, repo: repo)
        moved.section = section

        _ = try service.mergeLists(
            sourceIDs: [duplicate.id.uuidString],
            into: keep.id.uuidString
        )

        #expect(moved.section == nil)
    }

    @Test("行き先しか指定していない merge は拒否される")
    func mergeListsRejectsNoSource() throws {
        let keep = Domain.Category(name: "Work")
        let (service, _) = makeService(categories: [keep])

        #expect(throws: IntentError.self) {
            _ = try service.mergeLists(
                sourceIDs: [keep.id.uuidString],
                into: keep.id.uuidString
            )
        }
    }

    // MARK: - Tags

    @Test("renameTag が持っている todo すべてを書き換える")
    func renameTagRewritesEveryTodo() throws {
        let (service, repo) = makeService()
        let first = try makeTodo("a", tags: ["work", "urgent"], repo: repo)
        let second = try makeTodo("b", tags: ["Work"], repo: repo)
        let untouched = try makeTodo("c", tags: ["home"], repo: repo)

        let changed = try service.renameTag("work", to: "office")

        #expect(changed == 2)
        #expect(first.tags == ["office", "urgent"])
        #expect(second.tags == ["office"])
        #expect(untouched.tags == ["home"])
    }

    @Test("既にあるタグへの改名は 2 つを 1 つに畳む")
    func renameTagMergesIntoExisting() throws {
        let (service, repo) = makeService()
        let item = try makeTodo("a", tags: ["work", "office"], repo: repo)

        _ = try service.renameTag("work", to: "office")

        #expect(item.tags == ["office"])
    }

    @Test("deleteTag は todo を残してタグだけ外す")
    func deleteTagKeepsTodos() throws {
        let (service, repo) = makeService()
        let item = try makeTodo("a", tags: ["work", "urgent"], repo: repo)

        let changed = try service.deleteTag("URGENT")

        #expect(changed == 1)
        #expect(item.tags == ["work"])
        #expect(try repo.fetchAll().count == 1)
    }

    // MARK: - Snapshot

    @Test("organizeSnapshot がリストとタグの所属を返す")
    func snapshotReportsMemberships() throws {
        let work = Domain.Category(name: "Work")
        let (service, repo) = makeService(categories: [work])
        let filed = try makeTodo("a", in: work, tags: ["urgent"], repo: repo)
        let unfiled = try makeTodo("b", tags: ["urgent", "later"], repo: repo)

        let snapshot = try service.organizeSnapshot()

        #expect(snapshot.lists.map(\.id) == [work.id.uuidString])
        #expect(snapshot.todoCount(inList: work.id.uuidString) == 1)
        #expect(snapshot.todoCount(inList: CategoryAppEntity.uncategorizedID) == 1)
        #expect(snapshot.tags == ["later", "urgent"])
        #expect(snapshot.todoIDs(withTag: "urgent") == Set([filed.id.uuidString, unfiled.id.uuidString]))
    }

    @Test("大文字小文字だけ違うリスト名は重複として挙がる")
    func snapshotFindsDuplicateNames() throws {
        let work = Domain.Category(name: "Work")
        let duplicate = Domain.Category(name: "work")
        let home = Domain.Category(name: "Home")
        let (service, _) = makeService(categories: [work, duplicate, home])

        let groups = try service.organizeSnapshot().duplicateNameGroups

        #expect(groups.count == 1)
        #expect(groups.first?.count == 2)
    }
}
