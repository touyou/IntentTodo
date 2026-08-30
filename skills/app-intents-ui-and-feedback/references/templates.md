# Templates — UI and feedback

## Navigation intent (cold-start safe)

```swift
public struct LaunchAppIntent: AppIntent {
    public static var title: LocalizedStringResource { "Open App" }
    public static let supportedModes: IntentModes = [.foreground(.immediate)]
    public static var parameterSummary: some ParameterSummary { Summary("Open \(\.$target)") }

    @Parameter(title: "Target") public var target: AppScreenTarget
    @Dependency var navigationModel: NavigationModel

    public init() {}
    public init(target: AppScreenTarget) { self.target = target }

    // Call-site sugar so widgets/controls read well.
    public static func incompleteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .incompleteTodos) }

    @MainActor
    public func perform() async throws -> some IntentResult {
        switch target {                       // EVERY case must write state, or it just opens the app
        case .addTodo:         navigationModel.showAddTodo()
        case .todoList:        navigationModel.navigateToRoot()
        case .incompleteTodos: navigationModel.pendingFilter = .incomplete
        case .favoriteTodos:   navigationModel.pendingFilter = .favorites
        }
        return .result()
    }
}

#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}   // unavailable on macOS / watchOS
#endif
```

```swift
// Receiving side — both hooks, or cold start drops the value.
.onChange(of: navigationModel.pendingFilter) { _, new in applyPendingFilter(new) }
.onAppear { applyPendingFilter(navigationModel.pendingFilter) }

private func applyPendingFilter(_ filter: TodoFilterType?) {
    guard let filter else { return }
    viewModel.filter = TodoFilter(filter)
    navigationModel.pendingFilter = nil      // always clear, or it reapplies
}
```

## Confirmation pair (Siri asks / UI asks)

```swift
public struct DeleteTodoIntent: AppIntent {                 // Siri & Shortcuts
    public static var title: LocalizedStringResource { "Delete Todo" }
    public static var supportedModes: IntentModes { .background }
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }
    public static var parameterSummary: some ParameterSummary { Summary("Delete \(\.$todo)") }

    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService
    public init() {}
    public init(todo: TodoAppEntity) { self.todo = todo }

    @MainActor
    public func perform() async throws -> some IntentResult {
        // Ask BEFORE the irreversible work: perform() is retriable.
        try await requestConfirmation(dialog: IntentDialog("Delete “\(todo.title)”?"))
        try todoService.delete(todoId: todo.id)
        _ = try? await IntentDonationManager.shared.deleteDonations(
            matching: .entityIdentifiers([EntityIdentifier(for: todo)])
        )
        return .result()
    }
}

public struct DeleteTodoImmediatelyIntent: AppIntent {      // UI, after .confirmationDialog
    public static var title: LocalizedStringResource { "Delete Todo Immediately" }
    public static let isDiscoverable = false
    public static var supportedModes: IntentModes { .background }
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService
    public init() {}
    public init(todo: TodoAppEntity) { self.todo = todo }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.delete(todoId: todo.id)
        return .result()
    }
}
```

```swift
// UI side — SwiftUI asks, the non-interactive twin acts.
.confirmationDialog("Delete this todo?", isPresented: $confirmingDelete) {
    Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) { Text("Delete") }
}
```

## Snippet + host intent

```swift
public struct ShowTodoCountIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show Todo Count" }
    public static var supportedModes: IntentModes { .background }
    @Dependency var todoService: TodoService
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog & ShowsSnippetView {
        let pending = try todoService.pendingCount()
        return .result(
            value: pending,
            dialog: IntentDialog(
                full: "You have ^[\(pending) pending todo](inflect: true).",
                supporting: "^[\(pending) pending todo](inflect: true)."
            ),
            snippetIntent: TodoSummarySnippetIntent()
        )
    }
}

public struct TodoSummarySnippetIntent: SnippetIntent {
    public static var title: LocalizedStringResource { "Todo Summary" }
    public static let isDiscoverable = false
    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ShowsSnippetView {
        // Re-read: every button press inside the snippet re-runs this whole intent.
        let summary = try TodoEntityStore.summary()
        return .result(view: TodoSummaryView(summary: summary))
    }
}
```

## Error notification with entity context

Keep the entry point **synchronous**. It is called from the `catch` in a `perform()` that is about to rethrow, so there is nothing useful to await — and an `async` signature forces every call site to be `await`ed inside error handling, which is where a forgotten `await` is least likely to be noticed.

```swift
public enum ControlNotificationHelper {
    /// Synchronous on purpose: called from a `catch` that is about to rethrow.
    public static func sendErrorNotification(message: LocalizedStringResource, todoId: String) {
        Task { await send(message: message, todoId: todoId) }
    }

    private static func send(message: LocalizedStringResource, todoId: String) async {
        let center = UNUserNotificationCenter.current()

        // `add` does not fail when notifications are denied — check first, and record
        // the miss so the app can offer a route to Settings.
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            MissedFeedback.record(.notificationsDenied)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = String(localized: message)
        content.appEntityIdentifiers = [
            EntityIdentifier(for: TodoAppEntity.self, identifier: todoId)
        ]
        try? await center.add(UNNotificationRequest(identifier: UUID().uuidString,
                                                    content: content, trigger: nil))
    }
}
```
