//
//  SearchEverythingIntent.swift
//  TodoAppIntents
//
//  Returns a heterogeneous list of matches (todos and categories) using the
//  @UnionValue type `TodoOrCategory` (WWDC 2026 #345).
//

import AppIntents

/// Searches todos and categories by name, returning both kinds in one result list.
public struct SearchEverythingIntent: AppIntent {
    public static var title: LocalizedStringResource { "Search Todos and Categories" }

    public static var description: IntentDescription {
        IntentDescription(
            "Finds todos and categories matching a search term",
            categoryName: "Todos",
            searchKeywords: ["search", "find", "lookup"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    public static var parameterSummary: some ParameterSummary {
        Summary("Search for \(\.$query)")
    }

    @Parameter(title: "Query", description: "Text to match against todo and category names")
    public var query: String

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(query: String) {
        self.query = query
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[TodoOrCategory]> {
        // 突き合わせは `localizedStandardContains(_:)`（`TodoEntityQuery` と同じ）。
        // 小文字化して `contains` するとロケール非依存になり、かな/カナやダイアクリ
        // ティカルマークを別物として扱ってしまう。
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return .result(value: []) }

        let todos = try todoService.listTodos(filter: .all)

        let matchedTodos = todos
            .filter { $0.title.localizedStandardContains(needle) }
            .map { TodoOrCategory.todo($0) }

        // Categories are derived from the todos' relationships — dedupe by id and
        // match on name. (No separate category store is needed for this search.)
        var seenCategoryIDs = Set<String>()
        let matchedCategories = todos
            .compactMap(\.category)
            .filter { category in
                category.name.localizedStandardContains(needle) && seenCategoryIDs.insert(category.id).inserted
            }
            .map { TodoOrCategory.category($0) }

        return .result(value: matchedTodos + matchedCategories)
    }
}
