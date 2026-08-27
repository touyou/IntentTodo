//
//  TodoSemanticContentSearchIntent.swift
//  TodoAppIntents
//
//  The "see more results" action for Visual Intelligence (WWDC 2026 #297).
//  When a person taps "More results" in visual search, the system runs this
//  intent so the app can open its full results for the recognized content.
//
//  Conforms to the `.visualIntelligence.semanticContentSearch` assistant schema;
//  guarded by `canImport(VisualIntelligence)`. Originally iOS-only; Xcode 27 beta 2
//  makes the framework importable on Mac too, so this builds wherever it exists
//  (see TodoVisualIntelligenceQuery for the openability requirement that enables it).
//

#if canImport(VisualIntelligence) && !os(visionOS)
import AppIntents
import VisualIntelligence

@AppIntent(schema: .visualIntelligence.semanticContentSearch)
public struct TodoSemanticContentSearchIntent: AppIntent {
    /// The recognized content the person is searching for. Supplied by the system.
    @Parameter(title: "Semantic Content")
    public var semanticContent: SemanticContentDescriptor

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Open the app to the todo list so the person can browse the matches.
        // (A dedicated label-scoped results screen could consume
        // `semanticContent.labels`; the list root is sufficient for now.)
        navigationModel.navigateToRoot()
        return .result()
    }
}
#endif
