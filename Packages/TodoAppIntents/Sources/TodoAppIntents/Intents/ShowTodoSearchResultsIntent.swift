//
//  ShowTodoSearchResultsIntent.swift
//  TodoAppIntents
//
//  Conforms to the system in-app search schema (`@AppIntent(schema: .system.searchInApp)`
//  / `ShowInAppSearchResultsIntent`, WWDC 2026 #343 / #47). Adopting this schema
//  lets Siri / Apple Intelligence route a search request into the app's own search
//  UI and show results there, instead of returning data out-of-band.
//
//  This is distinct from `SearchEverythingIntent`, which *returns* matching values
//  as a `@UnionValue` list (`[TodoOrCategory]`). The schema intent here *navigates*:
//  it pushes the term into the list's `.searchable` field via `NavigationModel`.
//
//  The `.system.searchInApp` schema is unavailable on watchOS (Xcode 27 beta 2/3), and the
//  watch app has no in-app search surface to route into, so the intent is excluded
//  there entirely.
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Takes the person to the app's in-app search results for a term.
@AppIntent(schema: .system.searchInApp)
struct ShowTodoSearchResultsIntent: ShowInAppSearchResultsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @Dependency
    var navigationModel: NavigationModel

    @MainActor
    func perform() async throws -> some IntentResult {
        navigationModel.showSearch(matching: criteria.term)
        return .result()
    }
}
#endif
