//
//  OpenCategoryIntent.swift
//  TodoAppIntents
//
//  Adopts the system `OpenIntent` protocol (WWDC 2026 #344) for categories.
//
//  Beyond the usual "open this entity" semantics, this is what makes
//  `CategoryAppEntity` usable in Visual Intelligence results: Xcode 27 beta 2
//  requires every entity a visual-search `IntentValueQuery` returns to be openable
//  (associated with an `OpenIntent`). `TodoVisualIntelligenceQuery` returns a
//  `TodoOrCategory` union, so both `TodoAppEntity` (via `OpenTodoIntent`) and
//  `CategoryAppEntity` (via this intent) must be openable. Adding it lets Visual
//  Intelligence build on every platform where the framework now exists (iOS and,
//  as of beta 2, Mac), instead of scoping the feature to iOS.
//

import AppIntents

/// Opens the app for a specific category.
///
/// The app has no dedicated category screen yet, so `perform()` opens to the list
/// root. Conforming to `OpenIntent` is the important part — it declares the
/// category as an openable entity so Siri / Spotlight / Visual Intelligence can
/// route to it. A category-scoped list screen can refine `perform()` later.
public struct OpenCategoryIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Category"
    public static let description = IntentDescription("Opens the app for a specific category")
    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    public static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$target)")
    }

    @Parameter(title: "Category", description: "The category to open")
    public var target: CategoryAppEntity

    @Dependency
    var navigationModel: NavigationModel

    public init() {}

    public init(target: CategoryAppEntity) {
        self.target = target
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        navigationModel.navigateToRoot()
        return .result()
    }
}
