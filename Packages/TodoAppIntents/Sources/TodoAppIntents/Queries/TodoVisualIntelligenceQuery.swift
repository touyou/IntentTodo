//
//  TodoVisualIntelligenceQuery.swift
//  TodoAppIntents
//
//  Visual Intelligence integration (WWDC 2026 #297). The system calls this query
//  when a person performs a visual search (camera / screenshot); we return matching
//  todos and categories so they appear in the visual search results.
//
//  Guarded by `canImport(VisualIntelligence)` — the framework is iOS-only, while
//  this package also builds for macOS / watchOS / visionOS / widget extensions.
//

#if canImport(VisualIntelligence)
import AppIntents
import VisualIntelligence

/// Provides todos / categories that match the on-screen or in-camera content.
///
/// `IntentValueQuery` (unlike `AppEntity`) supports `@Dependency`, so the shared
/// `TodoService` is injected directly. Results use the `TodoOrCategory`
/// `@UnionValue` so a single query can surface both entity kinds.
public struct TodoVisualIntelligenceQuery: IntentValueQuery {
    @Dependency
    var todoService: TodoService

    public init() {}

    public func values(for input: SemanticContentDescriptor) async throws -> [TodoOrCategory] {
        // Visual Intelligence labels are general English terms (e.g. "book",
        // "plant"). Match them against todo titles and category names. The pixel
        // buffer (`input.pixelBuffer`) is available too but image matching needs
        // an ML model, so we use the labels here.
        let labels = input.labels.map { $0.lowercased() }
        guard !labels.isEmpty else { return [] }

        // TodoService is MainActor-isolated; hop to fetch the snapshot, then filter
        // off-actor on the Sendable entity values.
        let todos = try await MainActor.run { try todoService.listTodos(filter: .all) }

        func matches(_ text: String) -> Bool {
            let haystack = text.lowercased()
            return labels.contains { haystack.contains($0) }
        }

        let matchedTodos = todos
            .filter { matches($0.title) }
            .map { TodoOrCategory.todo($0) }

        var seenCategoryIDs = Set<String>()
        let matchedCategories = todos
            .compactMap(\.category)
            .filter { matches($0.name) && seenCategoryIDs.insert($0.id).inserted }
            .map { TodoOrCategory.category($0) }

        return matchedTodos + matchedCategories
    }
}
#endif
