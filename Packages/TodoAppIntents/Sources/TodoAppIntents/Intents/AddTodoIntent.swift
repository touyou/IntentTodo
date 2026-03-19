//
//  AddTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Repository

/// An intent that creates a new todo item.
///
/// This intent can be triggered via:
/// - Siri: "Add a todo called 'Buy groceries' in IntentTodo"
/// - Shortcuts: Add Todo action
/// - UI: `Button(intent: AddTodoIntent(title: "..."))`
///
/// ## Execution Modes
///
/// Supports both background and deferred foreground modes:
/// - **Background**: Creates the todo immediately without opening the app (default).
/// - **Foreground (deferred)**: Creates the todo, then opens the app for detail editing
///   when `openInApp` is `true`.
public struct AddTodoIntent: AppIntent {
    // MARK: - Metadata

    public static var title: LocalizedStringResource {
        "Add Todo"
    }

    public static var description: IntentDescription {
        IntentDescription(
            "Creates a new todo item",
            categoryName: "Todos",
            searchKeywords: ["create", "new", "add", "task", "todo"]
        )
    }

    /// Supports background execution by default, with optional deferred foreground
    /// for cases where the user wants to edit details after creation.
    public static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }

    // MARK: - Parameters

    @Parameter(title: "Title", description: "The title of the new todo")
    public var title: String

    @Parameter(title: "Description", description: "Optional description for the todo")
    public var todoDescription: String?

    @Parameter(title: "Due Date", description: "Optional due date for the todo")
    public var dueDate: Date?

    @Parameter(title: "Mark as Favorite", description: "Whether to mark as favorite", default: false)
    public var isFavorite: Bool

    @Parameter(title: "Open in App", description: "Whether to open the app after creation", default: false)
    public var openInApp: Bool

    // MARK: - Initialization

    public init() {}

    /// Creates an intent with the specified parameters.
    public init(
        title: String,
        todoDescription: String? = nil,
        dueDate: Date? = nil,
        isFavorite: Bool = false,
        openInApp: Bool = false
    ) {
        self.title = title
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
        self.openInApp = openInApp
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        // Validate title is not empty
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }

        // Get repository
        let repository = try IntentDependencies.shared.createRepository()

        // Create the todo item
        let todoItem = TodoItem(
            title: trimmedTitle,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate
        )

        // Save to repository
        try repository.create(todoItem)

        // Reload widgets to show the new todo
        WidgetReloader.reloadAllWidgets()

        // If user wants to open the app for detail editing, request foreground
        if openInApp {
            try await continueInForeground()
        }

        // Return the created entity
        let entity = TodoAppEntity(from: todoItem)
        return .result(value: entity)
    }
}

