//
//  TodoFilingTests.swift
//  TodoAppIntentsTests
//
//  Covers filing a todo under a list and a section. The rules the service applies to the
//  values Siri / Shortcuts send (a section carries its own list, moving list drops a
//  section that no longer belongs) are only visible in the stored relationships, which a
//  green build says nothing about.
//

import Domain
import Foundation
import Repository
import Testing
@testable import TodoAppIntents

@Suite("Todo の list / section 配属")
@MainActor
struct TodoFilingTests {
    private func makeService(
        categories: [Domain.Category] = [],
        sections: [TodoSection] = []
    ) -> (TodoService, MockTodoRepository) {
        let repo = MockTodoRepository()
        for category in categories { repo.register(category) }
        for section in sections { repo.register(section) }
        return (TodoService(repository: repo), repo)
    }

    private func makeSection(name: String, in category: Domain.Category) -> TodoSection {
        let section = TodoSection(name: name)
        section.category = category
        category.sections = (category.sections ?? []) + [section]
        return section
    }

    private func stored(in repo: MockTodoRepository) throws -> TodoItem {
        guard let item = try repo.fetchAll().first else {
            throw IntentError.notFound("no todo stored")
        }
        return item
    }

    // MARK: - create

    @Test("create が list を保存する")
    func createFilesUnderList() throws {
        let work = Domain.Category(name: "Work")
        let (service, repo) = makeService(categories: [work])

        _ = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            listId: work.id.uuidString
        )

        #expect(try stored(in: repo).category?.id == work.id)
    }

    @Test("section を指定すると、その section の list も一緒に付く")
    func sectionCarriesItsList() throws {
        let work = Domain.Category(name: "Work")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work], sections: [today])

        _ = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            sectionId: today.id.uuidString
        )

        let item = try stored(in: repo)
        #expect(item.section?.id == today.id)
        #expect(item.category?.id == work.id)
    }

    @Test("list と section が食い違うときは section が勝つ")
    func sectionWinsOverList() throws {
        let work = Domain.Category(name: "Work")
        let home = Domain.Category(name: "Home")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work, home], sections: [today])

        _ = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            listId: home.id.uuidString,
            sectionId: today.id.uuidString
        )

        #expect(try stored(in: repo).category?.id == work.id)
    }

    @Test("存在しない list / section は throw する")
    func unknownFilingThrows() throws {
        let (service, _) = makeService()

        #expect(throws: IntentError.self) {
            _ = try service.create(
                title: "write the deck",
                todoDescription: nil,
                dueDate: nil,
                isFavorite: false,
                listId: UUID().uuidString
            )
        }
        #expect(throws: IntentError.self) {
            _ = try service.create(
                title: "write the deck",
                todoDescription: nil,
                dueDate: nil,
                isFavorite: false,
                sectionId: UUID().uuidString
            )
        }
    }

    // MARK: - update

    @Test("別の list へ移すと、その list に属さない section は外れる")
    func movingListDropsForeignSection() throws {
        let work = Domain.Category(name: "Work")
        let home = Domain.Category(name: "Home")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work, home], sections: [today])

        let entity = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            sectionId: today.id.uuidString
        )

        _ = try service.update(todoId: entity.id, listId: .set(home.id.uuidString))

        let item = try stored(in: repo)
        #expect(item.category?.id == home.id)
        #expect(item.section == nil)
    }

    @Test("list に触らない更新は section を保つ")
    func unrelatedUpdateKeepsFiling() throws {
        let work = Domain.Category(name: "Work")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work], sections: [today])

        let entity = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            sectionId: today.id.uuidString
        )

        _ = try service.update(todoId: entity.id, title: .set("write the deck v2"))

        let item = try stored(in: repo)
        #expect(item.section?.id == today.id)
        #expect(item.category?.id == work.id)
    }

    @Test("list を明示的に nil にすると section も外れる")
    func clearingListUnfiles() throws {
        let work = Domain.Category(name: "Work")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work], sections: [today])

        let entity = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            sectionId: today.id.uuidString
        )

        _ = try service.update(todoId: entity.id, listId: .set(nil))

        let item = try stored(in: repo)
        #expect(item.category == nil)
        #expect(item.section == nil)
    }

    // MARK: - createSection

    @Test("createSection が list 配下に作り、sortIndex を詰める")
    func createSectionAppends() throws {
        let work = Domain.Category(name: "Work")
        let (service, _) = makeService(categories: [work])

        let first = try service.createSection(name: "Today", listId: work.id.uuidString)
        let second = try service.createSection(name: "Later", listId: work.id.uuidString)

        #expect(first.list.id == work.id.uuidString)
        #expect(second.name == "Later")
        let sections = (work.sections ?? []).sorted { $0.sortIndex < $1.sortIndex }
        #expect(sections.map(\.name) == ["Today", "Later"])
        #expect(sections.map(\.sortIndex) == [0, 1])
    }

    @Test("section は合成の未分類リストには作れない")
    func createSectionRejectsUncategorized() throws {
        let (service, _) = makeService()

        #expect(throws: IntentError.self) {
            _ = try service.createSection(
                name: "Today",
                listId: CategoryAppEntity.uncategorizedID
            )
        }
    }

    @Test("空名の section は作れない")
    func createSectionRejectsBlankName() throws {
        let work = Domain.Category(name: "Work")
        let (service, _) = makeService(categories: [work])

        #expect(throws: IntentError.self) {
            _ = try service.createSection(name: "   ", listId: work.id.uuidString)
        }
    }

    // MARK: - undo

    @Test("スナップショット復元が section まで戻す")
    func restoreBringsBackSection() throws {
        let work = Domain.Category(name: "Work")
        let today = makeSection(name: "Today", in: work)
        let (service, repo) = makeService(categories: [work], sections: [today])

        let entity = try service.create(
            title: "write the deck",
            todoDescription: nil,
            dueDate: nil,
            isFavorite: false,
            sectionId: today.id.uuidString
        )
        let snapshot = try service.snapshot(todoId: entity.id)
        try service.delete(todoId: entity.id)
        _ = try service.restore(snapshot)

        let item = try stored(in: repo)
        #expect(item.section?.id == today.id)
        #expect(item.category?.id == work.id)
    }
}
