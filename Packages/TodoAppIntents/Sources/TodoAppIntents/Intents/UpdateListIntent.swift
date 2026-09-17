//
//  UpdateListIntent.swift
//  TodoAppIntents
//
//  Renames or recolours a list. No reminders schema covers this, so it is an app action.
//

#if !os(watchOS)
import AppIntents
import Foundation

/// Renames and/or recolours a list.
///
/// Each parameter is read through its `valueState` (WWDC 2026 #344), so a field the caller
/// left alone stays as it is, and `colorHex` explicitly set to no value clears the colour.
public struct UpdateListIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource { "Update List" }

    public static var description: IntentDescription {
        IntentDescription(
            "Renames a list or changes its colour. Fields you leave blank are kept as-is.",
            categoryName: "Todos",
            searchKeywords: ["list", "rename", "colour", "color", "edit"]
        )
    }

    public static var supportedModes: IntentModes { .background }

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$list)") {
            \.$name
            \.$colorHex
        }
    }

    // MARK: - Parameters

    @Parameter(title: "List", description: "The list to update")
    public var list: CategoryAppEntity

    @Parameter(title: "Name", description: "The new name for the list")
    public var name: String?

    /// A hex string rather than a colour picker or an `AppEnum` of presets.
    ///
    /// The model stores `Category.colorHex`, and introducing an `AppEnum` for the presets
    /// would need a second, differently named declaration for the watchOS slice (the same
    /// metadata merge that `CategoryAppEntity` documents) for a value the watch never sets.
    @Parameter(title: "Color", description: "Hex colour for the list, e.g. #FF5733")
    public var colorHex: String?

    // MARK: - Dependencies

    @Dependency
    var todoService: TodoService

    // MARK: - Initialization

    public init() {}

    public init(list: CategoryAppEntity, name: String? = nil, colorHex: String? = nil) {
        self.list = list
        self.name = name
        self.colorHex = colorHex
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<CategoryAppEntity> {
        let nameUpdate: FieldUpdate<String>
        if case .set(let value?) = $name.valueState {
            nameUpdate = .set(value)
        } else {
            // A required field cannot be cleared, so `.set(nil)` also means "leave it".
            nameUpdate = .unchanged
        }

        let colorUpdate: FieldUpdate<String?>
        if case .set(let value) = $colorHex.valueState {
            colorUpdate = .set(value)
        } else {
            colorUpdate = .unchanged
        }

        return .result(
            value: try todoService.updateList(
                listId: list.id,
                name: nameUpdate,
                colorHex: colorUpdate
            )
        )
    }
}
#endif
