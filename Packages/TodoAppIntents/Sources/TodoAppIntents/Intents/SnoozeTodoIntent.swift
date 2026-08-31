//
//  SnoozeTodoIntent.swift
//  TodoAppIntents
//
//

import AppIntents
import Foundation

public struct SnoozeTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Snooze Todo"
    public static let description = IntentDescription("Pushes back the due date by a duration you choose")
    public static let supportedModes: IntentModes = [.background]

    /// Writes SwiftData, so it is pinned to the app process. [Apple: wwdc2026-345 16:30]
    public static let allowedExecutionTargets: IntentExecutionTargets = [.main]

    public static var parameterSummary: some ParameterSummary {
        Summary("Snooze \(\.$todo)")
    }

    @Parameter(title: "Todo", description: "The todo to snooze")
    public var todo: TodoAppEntity

    @Dependency
    var todoService: TodoService

    public init() {}

    public init(todo: TodoAppEntity) {
        self.todo = todo
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog {
        // WWDC 2026 (#343): pause the intent and let the person pick how long to
        // snooze. requestChoice surfaces in Siri / Shortcuts; the chosen option
        // is returned so we can map it back to an interval. Selecting `.cancel`
        // throws a cancellation error and aborts the snooze.
        let choice = try await requestChoice(
            between: SnoozeDuration.choiceOptions,
            dialog: IntentDialog("Snooze “\(todo.title)” for how long?")
        )
        let duration = SnoozeDuration(matching: choice)

        let result = try todoService.snooze(todoId: todo.id, by: duration.interval)
        return .result(
            value: result.entity,
            dialog: IntentDialog("Snoozed “\(result.title)” by \(duration.spokenLabel).")
        )
    }
}

// MARK: - Snooze Duration Options

/// The snooze intervals offered through `requestChoice`. Kept as a single source
/// of truth so the option list and the reverse mapping can never drift apart.
private enum SnoozeDuration: CaseIterable {
    case thirtyMinutes
    case oneHour
    case oneDay

    var interval: TimeInterval {
        switch self {
        case .thirtyMinutes: return 30 * 60   // matches TodoService.defaultSnoozeInterval
        case .oneHour: return 60 * 60
        case .oneDay: return 24 * 60 * 60
        }
    }

    var optionTitle: LocalizedStringResource {
        switch self {
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .oneDay: return "1 day"
        }
    }

    var spokenLabel: LocalizedStringResource { optionTitle }

    /// The options shown in the prompt, in display order.
    static var choiceOptions: [IntentChoiceOption] {
        allCases.map { IntentChoiceOption(title: $0.optionTitle) }
    }

    /// Maps a chosen option back to a duration. `IntentChoiceOption` carries no
    /// stable identifier, so we match on the localized title — falling back to
    /// the 30-minute default if a future option list ever desynchronizes.
    init(matching choice: IntentChoiceOption) {
        self = Self.allCases.first { IntentChoiceOption(title: $0.optionTitle) == choice } ?? .thirtyMinutes
    }
}
