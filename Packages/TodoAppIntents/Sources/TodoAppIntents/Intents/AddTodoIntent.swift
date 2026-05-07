//
//  AddTodoIntent.swift
//  IntentTodo
//

import AppIntents
import Foundation

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

    /// バックグラウンド実行のみ。perform() は OpensIntent / requestForeground を
    /// 使わず .result(value:) を返すだけなので、`.foreground(.deferred)` を入れても
    /// 実際にフォアグラウンド化される経路がない。Siri 経由の追加 UI が必要になったら
    /// その時点で `.foreground(.dynamic)` を足す。
    public static var supportedModes: IntentModes { .background }

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
    var todoService: TodoService

    @Dependency
    var navigationModel: NavigationModel

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
        let entity = try todoService.create(
            title: title,
            todoDescription: todoDescription,
            dueDate: dueDate,
            isFavorite: isFavorite
        )
        // UI から呼ばれた場合は Add シートを閉じる。Siri / Shortcuts / Widget から
        // 呼ばれた場合は元から閉じているので no-op。@Query の件数差分でシートを
        // 閉じていた旧実装は他デバイス / Widget からの追加で誤クローズしたため、
        // Intent 完了 = シート閉じるという 1 対 1 対応に集約した。
        navigationModel.dismissAddTodo()
        return .result(value: entity)
    }
}
