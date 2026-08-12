# Code templates

Copy and adapt. All templates assume intents live in a Swift package with `public` types, and dependencies are registered at every executing process's entry point ([04](04-process-and-dependencies.md)).

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
        defer { WidgetReloader.reloadAllWidgets() }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw IntentError.validation("Title cannot be empty") }
        let item = try repository.create(TodoItem(title: trimmed, dueDate: dueDate))
        return TodoAppEntity(from: item)
    }

    public func setCompletion(todoId: String, isCompleted: Bool) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        // absolute setter — required by ControlWidgetToggle, and idempotent
    }

    public func delete(todoId: String) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        do { try repository.delete(id: todoId) }
        catch RepositoryError.notFound { return }        // idempotent
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
    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$title)")
    }

    @Parameter(title: "Title") public var title: String
    @Parameter(title: "Due date") public var dueDate: Date?

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

## Confirmation pair (Siri asks / UI asks)

```swift
public struct DeleteTodoIntent: AppIntent {                 // Siri & Shortcuts
    public static var title: LocalizedStringResource { "Delete Todo" }
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency var todoService: TodoService
    public init() {}
    public init(todo: TodoAppEntity) { self.todo = todo }

    @MainActor
    public func perform() async throws -> some IntentResult {
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
// UI side
.confirmationDialog("Delete this todo?", isPresented: $confirmingDelete) {
    Button(role: .destructive, intent: DeleteTodoImmediatelyIntent(todo: entity)) { Text("Delete") }
}
```

## Entity + query

```swift
public struct TodoAppEntity: AppEntity, Identifiable, Hashable {
    public var id: String

    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    @Property(title: "Due date") public var dueDate: Date?

    @ComputedProperty(title: "Is overdue")
    public var isOverdue: Bool { !isCompleted && (dueDate.map { $0 < .now } ?? false) }

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    public static var defaultQuery: TodoEntityQuery { TodoEntityQuery() }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)",
                              image: .init(systemName: isCompleted ? "checkmark.circle.fill" : "circle"))
    }

    // Property macros break synthesised Hashable/Equatable.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.title == rhs.title && lhs.isCompleted == rhs.isCompleted
    }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

public struct TodoEntityQuery: EntityQuery {
    @Dependency var todoService: TodoService      // queries CAN use @Dependency; entities cannot
    public init() {}

    @MainActor public func entities(for ids: [String]) async throws -> [TodoAppEntity] {
        try todoService.entities(matching: ids)   // batched — one fetch, not a loop
    }

    @MainActor public func suggestedEntities() async throws -> [TodoAppEntity] {
        try todoService.incompleteEntities(limit: 8)
    }
}

extension TodoEntityQuery: EntityStringQuery {
    @MainActor public func entities(matching string: String) async throws -> [TodoAppEntity] {
        // The framework does NOT filter for you.
        try todoService.entities(titleContains: string)
    }
}
```

## App entry point

```swift
@main
struct MyApp: App {
    #if os(iOS) || os(visionOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    let modelContainer: ModelContainer
    @State private var navigationModel: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        // Entities can't use @Dependency — ambient store, registered per process.
        MainActor.assumeIsolated { TodoEntityStore.register(container: container) }

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        Task(priority: .utility) { await todoService.indexAllForSpotlight() }

        let navigation = NavigationModel()
        self.navigationModel = navigation
        AppDependencyManager.shared.add(dependency: navigation)   // intents
        #if os(iOS) || os(visionOS) || os(macOS)
        MainActor.assumeIsolated { NotificationHandler.shared.navigationModel = navigation }
        #endif
    }

    var body: some Scene {
        WindowGroup { RootView().environment(navigationModel) }
            .modelContainer(modelContainer)
    }
}
```

## Widget bundle entry point

```swift
@main
struct MyWidgetBundle: WidgetBundle {
    init() {
        AppDependencyManager.shared.add(dependency: sharedWidgetModelContainer)
        MainActor.assumeIsolated {
            AppDependencyManager.shared.add(
                dependency: TodoService.swiftDataBacked(container: sharedWidgetModelContainer))
            TodoEntityStore.register(container: sharedWidgetModelContainer)
        }
    }

    var body: some Widget {
        MyHomeWidget()
        #if !os(visionOS)
        QuickAddControl()
        TodoCountControl()
        ToggleTodoControl()
        #endif
    }
}
```

## `AppIntentsPackage` set

```swift
// In the package that owns the intents
public struct TodoIntentsPackage: AppIntentsPackage {
    public init() {}
}
```

```swift
// One per consuming target: app, widget extension, Live Activity extension, watch app
import AppIntents
import TodoAppIntents

struct MyAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [TodoIntentsPackage.self] }
}
```

## `AppShortcutsProvider` — app target only

```swift
// MyApp/MyAppShortcuts.swift  ← NOT in a package: autoShortcuts is not aggregated
import AppIntents
import TodoAppIntents

struct MyAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: ["Add a todo in \(.applicationName)",
                      "Create a new todo in \(.applicationName)"],
            shortTitle: "Add Todo",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: ["Show my todos in \(.applicationName)",
                      "Show \(\.$filter) todos in \(.applicationName)"],   // AppEnum only
            shortTitle: "Show Todos",
            systemImageName: "list.bullet"
        )
    }
}
```

## Control: toggle over a configured target

```swift
struct ToggleTodoControl: ControlWidget {
    static let kind = "com.example.MyApp.MyWidget.ToggleTodoControl"

    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(kind: Self.kind, provider: Provider()) { snapshot in
            ControlWidgetToggle(
                snapshot.title,
                isOn: snapshot.isCompleted,
                action: SetTodoCompletionIntent(todoId: snapshot.todoId ?? "")
            ) { isOn in
                Label(isOn ? "Completed" : "To Do",
                      systemImage: isOn ? "checkmark.circle.fill" : "circle")
                    .controlWidgetActionHint(isOn ? "Complete Todo" : "Reopen Todo")
            }
        }
        .promptsForUserConfiguration()
        .displayName("Complete Todo")
        .description("Complete or reopen a todo you choose.")
    }
}

extension ToggleTodoControl {
    struct Provider: AppIntentControlValueProvider {
        // Gallery preview: per Apple's guidance, return the off state.
        func previewValue(configuration: SelectTodoConfigurationIntent) -> Snapshot { .placeholder }

        // The configuration's entity snapshot is stale — re-read by id every time,
        // and fall back to "unconfigured" if the target was deleted meanwhile.
        func currentValue(configuration: SelectTodoConfigurationIntent) async throws -> Snapshot { … }
    }
}

public struct SetTodoCompletionIntent: SetValueIntent {
    public static let title: LocalizedStringResource = "Set Todo Completion"
    public static let supportedModes: IntentModes = [.background]
    public static let isDiscoverable = false          // control-only

    @Parameter(title: "Todo ID") public var todoId: String

    /// The system fills this with the toggle's destination state. Never set it yourself.
    @Parameter(title: "Completed") public var value: Bool

    @Dependency var todoService: TodoService
    public init() {}
    public init(todoId: String) { self.todoId = todoId }

    @MainActor
    public func perform() async throws -> some IntentResult {
        do {
            try todoService.setCompletion(todoId: todoId, isCompleted: value)   // absolute, not a flip
        } catch {
            // Success is conveyed by the control's own redraw; only failure needs a notification.
            ControlNotificationHelper.sendErrorNotification(
                message: "Couldn't update the todo. Open the app to retry.", todoId: todoId)
            throw error
        }
        return .result()
    }
}
```

## Control: value display

```swift
struct TodoCountControl: ControlWidget {
    static let kind = "com.example.MyApp.MyWidget.TodoCountControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: Provider()) { count in
            ControlWidgetButton(action: LaunchAppIntent.incompleteTodos()) {
                Label { Text("\(count)") } icon: { Image(systemName: "checklist") }
                    .controlWidgetActionHint("Show Incomplete Todos")
            }
        }
        .displayName("Todo Count")
    }
}

extension TodoCountControl {
    struct Provider: ControlValueProvider {
        var previewValue: Int { 3 }
        func currentValue() async throws -> Int {
            // Throw on failure — `try? … ?? 0` would render a confident lie ("all done").
            try await MainActor.run {
                let descriptor = FetchDescriptor<TodoItem>(predicate: #Predicate { !$0.isCompleted })
                return try sharedWidgetModelContainer.mainContext.fetchCount(descriptor)
            }
        }
    }
}
```

## Navigation intent (cold-start safe)

```swift
public struct LaunchAppIntent: AppIntent {
    public static var title: LocalizedStringResource { "Open App" }
    public static let supportedModes: IntentModes = [.foreground(.immediate)]

    @Parameter(title: "Target") public var target: AppScreenTarget
    @Dependency var navigationModel: NavigationModel

    public init() {}
    public init(target: AppScreenTarget) { self.target = target }

    // Call-site sugar so widgets/controls read well.
    public static func incompleteTodos() -> LaunchAppIntent { LaunchAppIntent(target: .incompleteTodos) }

    @MainActor
    public func perform() async throws -> some IntentResult {
        switch target {                       // EVERY case must write state, or it just opens the app
        case .addTodo:        navigationModel.showAddTodo()
        case .todoList:       navigationModel.navigateToRoot()
        case .incompleteTodos: navigationModel.pendingFilter = .incomplete
        case .favoriteTodos:  navigationModel.pendingFilter = .favorites
        }
        return .result()
    }
}

#if os(iOS) || os(visionOS)
extension LaunchAppIntent: TargetContentProvidingIntent {}   // unavailable on macOS / watchOS
#endif
```

## AppIntentsTesting case

```swift
import AppIntentsTesting
import XCTest

class AppIntentsTestCase: XCTestCase {
    var app: XCUIApplication!
    var definitions: IntentDefinitions!

    @MainActor override func setUp() async throws {         // @MainActor: XCUIApplication isolation
        app = XCUIApplication()
        if app.state == .runningForeground || app.state == .runningBackground {
            app.activate()          // launch() restarts the app and destabilises long suites
        } else {
            app.launch()
        }
        definitions = IntentDefinitions(bundleIdentifier: "com.example.MyApp")
        try await waitForMetadata()
    }

    /// The first test after a clean install fails with
    /// `AppIntentsServicesMetadataErrorDomain Code=400 "… is not present"`.
    private func waitForMetadata(timeout: TimeInterval = 20) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if (try? await definitions.entities["TodoAppEntity"].suggestedEntities()) != nil { return }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTFail("App Intents metadata never became available")
    }
}

final class TodoIntentExecutionTests: AppIntentsTestCase {
    func testToggleCompletion() async throws {
        let created = try await definitions.intents["AddTodoIntent"]
            .makeIntent(title: "probe-\(UUID().uuidString)").run()
        let id: String = try created.value.identifier.instanceIdentifier   // NOT .id

        let entity = try await definitions.entities["TodoAppEntity"].entities(identifiers: [id]).first!
        let toggled = try await definitions.intents["ToggleTodoCompletionIntent"]
            .makeIntent(todo: entity).run()
        let isCompleted: Bool = try toggled.value.isCompleted
        XCTAssertTrue(isCompleted)

        // explicit clear needs a TYPED nil; plain nil means "unset"
        let explicitNull: any IntentValueExpressing = String?.none
        _ = try await definitions.intents["UpdateTodoIntent"]
            .makeIntent(todo: entity, todoDescription: explicitNull).run()

        _ = try await definitions.intents["DeleteTodoImmediatelyIntent"]
            .makeIntent(todo: entity).run()          // self-cleaning
    }
}
```
