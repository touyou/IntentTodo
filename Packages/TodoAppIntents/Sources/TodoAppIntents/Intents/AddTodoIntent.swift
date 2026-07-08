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

    /// Estimated time to complete. Uses the App Intents native `Duration` type
    /// (WWDC 2026) so Siri / Shortcuts present a proper duration picker.
    @Parameter(title: "Estimated Duration", description: "Estimated time to complete")
    public var estimatedDuration: Duration?

    /// Person to assign the todo to. Uses the App Intents native
    /// `PersonNameComponents` type (WWDC 2026) so Siri can resolve a name.
    @Parameter(title: "Assignee", description: "Person responsible for the todo")
    public var assignee: PersonNameComponents?

    /// Location associated with the todo.
    ///
    /// NOTE: Xcode 27 beta 3 の AppIntentsSSUTraining（"Generate SSU asset files"）は、
    /// `PlaceDescriptor` を @Parameter にすると裏側のシステム Entity 型名
    /// `GeoToolbox.PlaceDescriptorEntity` をそのまま SSU の variable 名に使い、ドットを
    /// 含むため正規表現 `^[a-zA-Z_][a-zA-Z_$0-9]*$` に落ちてエラーを emit する
    /// (ローカルは exit 0 だが Xcode Cloud は失敗扱い)。SDK 側バグの可能性が高いため、
    /// 暫定で場所名の String に退避している。SDK 修正後にこのコミットを revert して
    /// `PlaceDescriptor?` へ戻す。
    @Parameter(title: "Location", description: "Place associated with the todo")
    public var location: String?

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
        isFavorite: Bool = false,
        estimatedDuration: Duration? = nil,
        assignee: PersonNameComponents? = nil,
        location: String? = nil
    ) {
        self.title = title
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
        self.estimatedDuration = estimatedDuration
        self.assignee = assignee
        self.location = location
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<TodoAppEntity> & ProvidesDialog & ShowsSnippetIntent {
        let entity = try todoService.create(
            title: title,
            todoDescription: todoDescription,
            dueDate: dueDate,
            isFavorite: isFavorite,
            estimatedDuration: estimatedDuration.map { Double($0.components.seconds) },
            assigneeName: assignee.map { PersonNameComponentsFormatter().string(from: $0) },
            locationName: location.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .flatMap { $0.isEmpty ? nil : $0 },
            locationLatitude: nil,
            locationLongitude: nil
        )
        // UI から呼ばれた場合は Add シートを閉じる。Siri / Shortcuts / Widget から
        // 呼ばれた場合は元から閉じているので no-op。@Query の件数差分でシートを
        // 閉じていた旧実装は他デバイス / Widget からの追加で誤クローズしたため、
        // Intent 完了 = シート閉じるという 1 対 1 対応に集約した。
        navigationModel.dismissAddTodo()

        // Donate the action so the system can predict / proactively suggest it
        // (IntentDonationManager). Failures are non-fatal.
        _ = try? await donate()

        // WWDC 2026: Siri / Shortcuts から呼ばれた場合は作成した Todo を
        // インタラクティブスニペットで提示し、その場で完了 / お気に入り操作を
        // 可能にする。UI Button(intent:) 経由ではスニペット / dialog は表示されない。
        return .result(
            value: entity,
            dialog: IntentDialog("Added \"\(entity.title)\"."),
            snippetIntent: TodoSnippetIntent(todoId: entity.id)
        )
    }
}
