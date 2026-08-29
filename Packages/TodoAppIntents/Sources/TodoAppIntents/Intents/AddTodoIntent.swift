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

    /// 書き込み系。Extension プロセスが SwiftData を書かないようアプリ本体に固定（WWDC 2026 #345）。
    public static var allowedExecutionTargets: IntentExecutionTargets { [.main] }

    /// **The summary is the allowlist for the Shortcuts editor**: a `@Parameter` that
    /// appears neither in the sentence nor in the trailing block still resolves but is
    /// never offered as an editable row. Listing every parameter is what makes them
    /// settable from Shortcuts.
    /// 詳細: docs/insights/03-app-intents-core.md
    public static var parameterSummary: some ParameterSummary {
        Summary("Add todo titled \(\.$title)") {
            \.$todoDescription
            \.$dueDate
            \.$isFavorite
            \.$estimatedDuration
            \.$assignee
            \.$location
            \.$tags
            \.$urls
            \.$recurrenceFrequency
            \.$recurrenceInterval
            \.$locationTriggerEvent
        }
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
    /// 本来は `PlaceDescriptor?`（GeoToolbox）にしたいが、**App Shortcut に登録した Intent の
    /// `@Parameter`** に system value 型を置くと `AppIntentsSSUTraining` が
    /// `GeoToolbox.PlaceDescriptorEntity` をそのまま SSU の variable 名に使い、ドットが
    /// 正規表現 `^[a-zA-Z_][a-zA-Z_$0-9]*$` に落ちて `Metadata.appintents/nlu/` が
    /// 丸ごと生成されなくなる（ローカルは exit 0、Xcode Cloud は失敗扱い）。この Intent は
    /// `TodoAppShortcuts` に登録済みなので該当する。SDK バグ、Apple 報告済み（FB24548956 / #57）。
    /// 場所名を String で受け、緯度経度と合わせて `TodoPlace` が `PlaceDescriptor` を組み直す。
    /// 詳細: docs/insights/03-app-intents-core.md
    /// 経緯: docs/devlog/2026-08-28-ssu-system-value-type-bug.md
    @Parameter(title: "Location", description: "Place associated with the todo")
    public var location: String?

    // MARK: - reminders スキーマ属性

    /// Free-form tags to attach to the new todo.
    @Parameter(title: "Tags", description: "Tags to attach to the todo")
    public var tags: [String]?

    /// Links to attach to the new todo.
    @Parameter(title: "URLs", description: "Links to attach to the todo")
    public var urls: [URL]?

    /// How often the todo should repeat.
    @Parameter(title: "Recurrence", description: "How often the todo repeats")
    public var recurrenceFrequency: TodoRecurrenceFrequency?

    /// How many frequency units sit between occurrences.
    @Parameter(title: "Repeat Every", description: "Number of frequency units between occurrences")
    public var recurrenceInterval: Int?

    /// Whether arriving at or leaving `location` should surface the todo. Inert until
    /// the todo has a location — both halves are needed to form a trigger.
    @Parameter(title: "Location Trigger Event", description: "Surface the todo on arrival or departure")
    public var locationTriggerEvent: TodoLocationTriggerEvent?

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
        location: String? = nil,
        tags: [String]? = nil,
        urls: [URL]? = nil,
        recurrenceFrequency: TodoRecurrenceFrequency? = nil,
        recurrenceInterval: Int? = nil,
        locationTriggerEvent: TodoLocationTriggerEvent? = nil
    ) {
        self.title = title
        self.todoDescription = todoDescription
        self.dueDate = dueDate
        self.isFavorite = isFavorite
        self.estimatedDuration = estimatedDuration
        self.assignee = assignee
        self.location = location
        self.tags = tags
        self.urls = urls
        self.recurrenceFrequency = recurrenceFrequency
        self.recurrenceInterval = recurrenceInterval
        self.locationTriggerEvent = locationTriggerEvent
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
            locationLongitude: nil,
            tags: tags ?? [],
            urls: urls ?? [],
            recurrenceFrequency: recurrenceFrequency,
            recurrenceInterval: recurrenceInterval ?? TodoRecurrence.minimumInterval,
            locationTriggerEvent: locationTriggerEvent
        )
        // UI から呼ばれた場合は Add シートを閉じる。Siri / Shortcuts / Widget から
        // 呼ばれた場合は元から閉じているので no-op。@Query の件数差分でシートを
        // 閉じていた旧実装は他デバイス / Widget からの追加で誤クローズしたため、
        // Intent 完了 = シート閉じるという 1 対 1 対応に集約した。
        navigationModel.dismissAddTodo()

        // ここで donate しない。公式 (Donations and discovery): "Restrict your donations to
        // direct interactions with your app's interface, and not to interactions started by
        // Siri or the Shortcuts app". `perform()` は呼出元を判別できないため、ここでの donate は
        // Siri / Shortcuts 経由でも必ず走ってしまう。
        // 詳細: docs/insights/03-app-intents-core.md

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
