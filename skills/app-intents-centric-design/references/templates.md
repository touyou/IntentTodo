# Templates — service and core intents

Copy and adapt. These assume intents live in a Swift package with `public` types (a level-1-or-above project). **Starting from nothing?** Take the single-file version in [adoption-levels](adoption-levels.md) first.

Templates for other jobs live with their skill: entry points and packaging in `app-intents-execution-and-processes`, controls in `app-intents-system-surfaces`, navigation and confirmation UI in `app-intents-ui-and-feedback`, entities and queries in `app-intents-entities-and-search`, test cases in `app-intents-testing`.

## Service (the only place with persistence)

```swift
@MainActor
public final class TodoService {
    private let repository: any TodoRepositoryProtocol

    public init(repository: any TodoRepositoryProtocol) { self.repository = repository }

    public static func swiftDataBacked(container: ModelContainer) -> TodoService {
        // mainContext, not a fresh ModelContext: a new context won't see unsaved state.
        TodoService(repository: SwiftDataTodoRepository(modelContext: container.mainContext))
    }

    public func create(title: String, dueDate: Date?) throws -> TodoAppEntity {
        defer { Self.dataDidChange() }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntentError.validation("Title cannot be empty") }
        let item = try repository.create(TodoItem(title: trimmed, dueDate: dueDate))
        return TodoAppEntity(from: item)
    }

    public func setCompletion(todoId: String, isCompleted: Bool) throws {
        defer { Self.dataDidChange() }
        // absolute setter — required by ControlWidgetToggle, and idempotent
    }

    public func delete(todoId: String) throws {
        defer { Self.dataDidChange() }
        do { try repository.delete(id: todoId) }
        catch RepositoryError.notFound { return }        // idempotent
    }

    /// Everything that must happen after any mutation, in one place so no intent can forget.
    static func dataDidChange() {
        WidgetReloader.reloadAllWidgets()
        AppShortcutParameterUpdater.notifyEntitiesChanged()   // parameterised phrases
    }
}
```

## Surface reload helper

```swift
public enum WidgetReloader {
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #if !os(visionOS)
        ControlCenter.shared.reloadAllControls()   // separate API — required
        #endif
        #endif
    }
}
```

## Background action intent

```swift
import AppIntents

public struct AddTodoIntent: AppIntent {
    public static var title: LocalizedStringResource { "Add Todo" }
    public static var description: IntentDescription {
        IntentDescription("Creates a new todo item",
                          categoryName: "Todos",
                          searchKeywords: ["create", "new", "add", "task"])
    }
    public static var supportedModes: IntentModes { .background }

    // Writes to the store ⇒ pin the process, or an extension can become the writer.
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    // The Shortcuts editor shows ONLY what appears here. Interpolated parameters become
    // the sentence; everything else settable goes in the trailing block.
    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$title)") {
            \.$dueDate
            \.$isFavorite
        }
    }

    @Parameter(title: "Title") public var title: String
    @Parameter(title: "Due date") public var dueDate: Date?
    @Parameter(title: "Favorite") public var isFavorite: Bool

    @Dependency var todoService: TodoService

    public init() {}
    public init(title: String, dueDate: Date? = nil) {
        self.title = title
        self.dueDate = dueDate
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog {
        let entity = try todoService.create(title: title, dueDate: dueDate)
        return .result(value: entity, dialog: "Added \(title).")
    }
}
```

## One intent, all callers (including Live Activity)

```swift
public struct ToggleTodoCompletionIntent: AppIntent {
    public static var title: LocalizedStringResource { "Toggle Todo Completion" }
    public static var supportedModes: IntentModes { .background }
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService

    public init() {}
    public init(todo: TodoAppEntity) { self.todo = todo }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let result = try todoService.toggleCompletion(todoId: todo.id)
        #if os(iOS)
        if result.isNowCompleted { await endMatchingLiveActivity(for: todo.id) }
        #endif
        return .result(value: result.entity)
    }
}

// Touching Activity state ⇒ LiveActivityIntent (app-process execution, background start).
#if os(iOS)
extension ToggleTodoCompletionIntent: LiveActivityIntent {}
#endif
```

```swift
// Live Activity view: build a partial entity; the system re-resolves it from the id.
let entity = TodoAppEntity(id: context.attributes.todoId, title: context.state.title)
Button(intent: ToggleTodoCompletionIntent(todo: entity)) {
    Label("Complete", systemImage: "checkmark.circle.fill")
}
```

## Undoable delete

```swift
public struct DeleteTodoImmediatelyIntent: AppIntent, UndoableIntent {
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
        // Snapshot first: after the delete the @Model is unreadable, and it is not Sendable.
        let snapshot = try todoService.snapshot(todoId: todo.id)
        try todoService.delete(todoId: todo.id)

        // Registration lives in one registrar so every delete path gets it.
        TodoUndoRegistrar.registerRestore(snapshot, in: undoManager, service: todoService)

        _ = try? await IntentDonationManager.shared.deleteDonations(
            matching: .entityIdentifiers([EntityIdentifier(for: todo)])
        )
        return .result()
    }
}
```
