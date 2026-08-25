//
//  TodoServiceFactory.swift
//  TodoAppIntents
//
//  `TodoService` の生成口。SwiftData / Repository への依存をここに閉じ込める。
//

import Repository
import SwiftData

// MARK: - Factory

public extension TodoService {
    /// Convenience factory for a SwiftData-backed service. Lets callers avoid
    /// importing `Repository` directly — handy for targets (watchOS app,
    /// Widget Extension) that don't link the Repository product.
    @MainActor
    static func swiftDataBacked(container: ModelContainer) -> TodoService {
        TodoService(repository: SwiftDataTodoRepository(modelContext: container.mainContext))
    }
}
