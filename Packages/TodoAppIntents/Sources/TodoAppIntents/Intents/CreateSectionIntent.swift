//
//  CreateSectionIntent.swift
//  TodoAppIntents
//
//  Conforms to the reminders `createSection` schema, so Siri can add a subdivision to a
//  list ("add a Today section to my Work list"). The schema domain does not exist on
//  watchOS, and neither does `TodoSectionAppEntity`, so the whole file is excluded there.
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Creates a new section inside a list.
@AppIntent(schema: .reminders.createSection)
struct CreateSectionIntent {
    var name: String
    var list: CategoryAppEntity

    @Dependency
    var todoService: TodoService

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @MainActor
    func perform() async throws -> some ReturnsValue<TodoSectionAppEntity> {
        .result(value: try todoService.createSection(name: name, listId: list.id))
    }
}
#endif
