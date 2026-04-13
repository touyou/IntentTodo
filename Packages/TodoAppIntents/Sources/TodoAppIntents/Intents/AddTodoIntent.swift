//
//  AddTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Repository
import SwiftData

/// An intent that creates a new todo item.
///
/// This intent can be triggered via:
/// - Siri: "Add a todo called 'Buy groceries' in IntentTodo"
/// - Shortcuts: Add Todo action
/// - UI: `Button(intent: AddTodoIntent(title: "..."))`
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

    public static var supportedModes: IntentModes { [.background, .foreground(.deferred)] }

    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$title)")
    }

    // MARK: - Parameters

    @Parameter(title: "Title", description: "The title of the new todo")
    public var title: String

    @Parameter(title: "Description", description: "Optional description for the todo")
    public var todoDescription: String?

    @Parameter(title: "Due Date", description: "Optional due date for the todo")
    public var dueDate: Date?

    @Parameter(title: "Mark as Favorite", description: "Whether to mark as favorite", default: false)
    public var isFavorite: Bool

    // MARK: - Dependencies

    @Dependency
    var modelContainer: ModelContainer

    // MARK: - Initialization

    public init() {}

    /// Creates an intent with the specified parameters.
    public init(
        title: String,
        todoDescription: String? = nil,
        dueDate: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.title = title
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }

        let repository = SwiftDataTodoRepository(modelContext: modelContainer.mainContext)

        let todoItem = TodoItem(
            title: trimmedTitle,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate
        )

        try repository.create(todoItem)
        WidgetReloader.reloadAllWidgets()

        return .result(value: TodoAppEntity(from: todoItem))
    }
}
