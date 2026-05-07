# Code templates

Copy-and-adapt templates for the patterns this skill recommends. All templates assume:

- Intents live in a SPM package, types are `public`.
- A single `AppIntentsPackage` is declared inside that package.
- Dependencies are registered in `AppDependencyManager.shared` at the entry point of every executing process.

## Service-backed action intent (`.background`)

```swift
import AppIntents

public struct AddTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add todo"
    public static let description = IntentDescription("Adds a new todo without opening the app")
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Title") public var title: String
    @Parameter(title: "Due date") public var dueDate: Date?

    @Dependency public var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws
        -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog
    {
        let entity = try todoService.create(title: title, dueDate: dueDate)
        return .result(value: entity, dialog: "Added \(title).")
    }
}
```

## Open-app intent with scene-side handling (iOS 26.4+)

```swift
import AppIntents

public struct ShowTodoDetailIntent: TargetContentProvidingIntent {
    public static let title: LocalizedStringResource = "Show todo"
    public static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Todo") public var todo: TodoAppEntity

    public init() {}

    public func perform() async throws -> some IntentResult { .result() }
}
```

```swift
// In your @main App
WindowGroup { RootView() }
    .onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
        navigation.path.append(.todo(intent.todo.id))
    }
```

## Open-app intent with cold-start fallback (iOS 26.0–26.3 safe)

```swift
public struct ShowTodoDetailIntent: AppIntent {
    public static let title: LocalizedStringResource = "Show todo"
    public static var supportedModes: IntentModes { .foreground(.immediate) }

    @Parameter(title: "Todo") public var todo: TodoAppEntity

    @Dependency public var navigation: NavigationModel

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        navigation.pendingTodoId = todo.id
        return .result()
    }
}
```

```swift
// In RootView
.onChange(of: navigation.pendingTodoId, initial: true) { _, id in
    guard let id else { return }
    navigation.path.append(.todo(id))
    navigation.pendingTodoId = nil
}
```

## Primary + FromExtension pair

```swift
public struct ToggleTodoCompletionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle todo"
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Todo") public var todo: TodoAppEntity
    @Dependency public var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.toggleCompletion(id: todo.id)
        return .result()
    }
}

public struct ToggleTodoCompletionFromExtensionIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle todo (extension)"
    public static let isDiscoverable = false
    public static var supportedModes: IntentModes { .background }

    @Parameter(title: "Todo ID") public var todoId: String
    @Dependency public var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try todoService.toggleCompletion(id: todoId)
        return .result()
    }
}

#if os(iOS)
extension ToggleTodoCompletionFromExtensionIntent: LiveActivityIntent {}
#endif
```

## App entity + query

```swift
public struct TodoAppEntity: AppEntity, IndexedEntity, Identifiable {
    public var id: String

    @Property(title: "Title") public var title: String
    @Property(title: "Is completed") public var isCompleted: Bool
    @Property(title: "Due date") public var dueDate: Date?

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Todo"
    public static let defaultQuery = TodoEntityQuery()

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: isCompleted ? "Done" : "Open"
        )
    }
}

public struct TodoEntityQuery: EntityQuery {
    @Dependency public var todoService: TodoService

    public init() {}

    public func entities(for identifiers: [TodoAppEntity.ID]) async throws -> [TodoAppEntity] {
        try await todoService.entities(matching: identifiers)
    }

    public func suggestedEntities() async throws -> [TodoAppEntity] {
        try await todoService.recentEntities(limit: 8)
    }

    public func defaultResult() async -> TodoAppEntity? {
        try? await todoService.recentEntities(limit: 1).first
    }
}
```

## Widget configuration intent (with dependent parameters)

```swift
public struct TodoWidgetConfiguration: WidgetConfigurationIntent {
    public static let title: LocalizedStringResource = "Todo widget"
    public static let description = IntentDescription("Pick which list to show.")

    @Parameter(title: "Category") public var category: CategoryAppEntity?
    @Parameter(title: "Show completed") public var showCompleted: Bool = false

    public init() {}
}

public struct CategoryQuery: EntityQuery {
    @IntentParameterDependency<TodoWidgetConfiguration>(\.$category)
    var category

    @Dependency var categoryService: CategoryService

    public init() {}

    public func entities(for identifiers: [CategoryAppEntity.ID]) async throws -> [CategoryAppEntity] {
        try await categoryService.entities(matching: identifiers)
    }

    public func suggestedEntities() async throws -> [CategoryAppEntity] {
        try await categoryService.allCategories()
    }
}
```

## App shortcuts provider

```swift
public struct TodoAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "Add a todo with \(.applicationName)",
                "New task in \(.applicationName)",
            ],
            shortTitle: "Add todo",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: ShowTodosIntent(),
            phrases: [
                "Show my todos in \(.applicationName)",
                "What's on my list in \(.applicationName)",
            ],
            shortTitle: "Show todos",
            systemImageName: "list.bullet"
        )
    }
}
```

## Service template

```swift
@MainActor
public final class TodoService {
    private let repository: any TodoRepository

    public init(repository: any TodoRepository) {
        self.repository = repository
    }

    public static func swiftDataBacked(container: ModelContainer) -> TodoService {
        TodoService(repository: SwiftDataTodoRepository(container: container))
    }

    public func create(title: String, dueDate: Date?) throws -> TodoAppEntity {
        defer { WidgetReloader.reloadAllWidgets() }
        let item = try repository.insert(TodoItem(title: title, dueDate: dueDate))
        return TodoAppEntity(item: item)
    }

    public func toggleCompletion(id: String) throws {
        defer { WidgetReloader.reloadAllWidgets() }
        try repository.toggleCompletion(id: id)
    }

    public func entities(matching ids: [String]) async throws -> [TodoAppEntity] {
        try repository.fetch(ids: ids).map(TodoAppEntity.init)
    }

    public func recentEntities(limit: Int) async throws -> [TodoAppEntity] {
        try repository.fetchRecent(limit: limit).map(TodoAppEntity.init)
    }
}
```

## App entry point

```swift
@main
struct MyApp: App {
    let modelContainer: ModelContainer
    @State private var navigation: NavigationModel

    init() {
        let container = try! SharedModelContainer.createContainer()
        self.modelContainer = container
        AppDependencyManager.shared.add(dependency: container)

        let todoService = TodoService.swiftDataBacked(container: container)
        AppDependencyManager.shared.add(dependency: todoService)

        let navigation = NavigationModel()
        self.navigation = navigation
        AppDependencyManager.shared.add(dependency: navigation)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(navigation)
                .modelContainer(modelContainer)
        }
        .onAppIntentExecution(ShowTodoDetailIntent.self) { intent in
            navigation.path.append(.todo(intent.todo.id))
        }
    }
}
```

## Widget bundle entry point

```swift
@main
struct MyAppWidgetBundle: WidgetBundle {
    init() {
        let container = sharedWidgetModelContainer
        AppDependencyManager.shared.add(dependency: container)
        MainActor.assumeIsolated {
            let todoService = TodoService.swiftDataBacked(container: container)
            AppDependencyManager.shared.add(dependency: todoService)
        }
    }

    var body: some Widget {
        TodoWidget()
        UrgentTodoControlWidget()
    }
}
```

## Control widget with notification feedback

```swift
struct UrgentTodoControlWidget: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MarkUrgentDone") {
            ControlWidgetButton(action: ToggleUrgentTodoIntent()) {
                Label("Urgent done", systemImage: "checkmark.circle.fill")
            }
        }
    }
}

public struct ToggleUrgentTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle urgent"
    public static var supportedModes: IntentModes { .background }

    @Dependency public var todoService: TodoService

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        if let title = try todoService.toggleNextUrgent() {
            IntentFeedback.notify(title: "Marked done", body: title)
        }
        return .result()
    }
}
```

## `AppIntentsPackage` declaration (SPM only)

```swift
// In your intents package, e.g. Sources/MyAppIntents/Package.swift
public struct MyAppIntentsPackage: AppIntentsPackage {}
```

Do **not** declare another conformance in the main app target.
