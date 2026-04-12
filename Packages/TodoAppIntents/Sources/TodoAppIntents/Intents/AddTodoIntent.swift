import AppIntents
import Domain
import os.log
import Repository
import SwiftData

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "AddTodoIntent")

public struct AddTodoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Add Todo"
    public static let description = IntentDescription("Creates a new todo item")
    public static let supportedModes: IntentModes = .foreground

    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$todoTitle)")
    }

    @Dependency
    private var modelContainer: ModelContainer

    @Parameter(title: "Title")
    public var todoTitle: String

    @Parameter(title: "Description")
    public var todoDescription: String?

    @Parameter(title: "Due Date")
    public var dueDate: Date?

    @Parameter(title: "Mark as Favorite", default: false)
    public var isFavorite: Bool

    public init() {}
    
    public init(
        todoTitle: String,
        todoDescription: String? = nil,
        dueDate: Date? = nil,
        isFavorite: Bool = false
    ) {
        self.todoTitle = todoTitle
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> {
        logger.info("[1] perform() entered, todoTitle='\(todoTitle)'")

        let trimmedTitle = todoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw IntentError.validation("Todo title cannot be empty")
        }
        logger.info("[2] title validated")

        let repository = SwiftDataTodoRepository(modelContext: ModelContext(modelContainer))
        logger.info("[3] Repository created from @Dependency modelContainer")

        let todoItem = TodoItem(
            title: trimmedTitle,
            todoDescription: todoDescription,
            isFavorite: isFavorite,
            dueDate: dueDate
        )

        try repository.create(todoItem)
        logger.info("[4] TodoItem saved")

        WidgetReloader.reloadAllWidgets()
        logger.info("[5] Returning result")

        return .result(value: TodoAppEntity(from: todoItem))
    }
}
