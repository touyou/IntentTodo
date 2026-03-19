//
//  TodoWidgetConfiguration.swift
//  IntentTodoWidget
//
//  Configuration intent and filter for the todo widget.
//

import AppIntents

// MARK: - Configuration Intent

/// Configuration intent for the todo widget.
struct TodoWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Todo Widget"
    static var description: IntentDescription = "Configure your todo widget"

    @Parameter(title: "Filter", default: .incomplete)
    var filter: TodoFilter

    init() {}

    init(filter: TodoFilter) {
        self.filter = filter
    }
}

// MARK: - Filter Enum

/// Filter options for the todo widget.
enum TodoFilter: String, AppEnum {
    case all
    case incomplete
    case favorites
    case dueToday

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Filter")
    }

    static var caseDisplayRepresentations: [TodoFilter: DisplayRepresentation] {
        [
            .all: DisplayRepresentation(title: "All"),
            .incomplete: DisplayRepresentation(title: "Incomplete"),
            .favorites: DisplayRepresentation(title: "Favorites"),
            .dueToday: DisplayRepresentation(title: "Due Today")
        ]
    }
}
