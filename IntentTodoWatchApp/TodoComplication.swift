//
//  TodoComplication.swift
//  IntentTodoWatchApp
//
//  watchOS complication widget for IntentTodo.
//

import SwiftUI
import WidgetKit

// MARK: - Complication Widget

/// Widget that displays todo information on the watch face.
struct TodoComplicationWidget: Widget {
    let kind = "TodoComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodoComplicationProvider()) { entry in
            TodoComplicationEntryView(entry: entry)
        }
        .configurationDisplayName("Todos")
        .description("Track your incomplete todos.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Corner", as: .accessoryCorner) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Rectangular", as: .accessoryRectangular) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}

#Preview("Inline", as: .accessoryInline) {
    TodoComplicationWidget()
} timeline: {
    TodoComplicationEntry.placeholder
}
