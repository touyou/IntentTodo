//
//  ShowTodoCountIntent.swift
//  TodoAppIntents
//
//  Sends a notification with the current incomplete todo count.
//  Designed for Control Center.
//

import AppIntents
import Domain
import Repository
import SwiftData

public struct ShowTodoCountIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show Todo Count"
    public static let description = IntentDescription("Shows the current incomplete todo count as a notification")
    public static let supportedModes: IntentModes = [.background]

    @Dependency
    var modelContainer: ModelContainer

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<TodoItem>(
            predicate: #Predicate { !$0.isCompleted }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0

        ControlNotificationHelper.sendTodoCountNotification(count: count)
        return .result()
    }
}
