//
//  TodoAppEntity.swift
//  IntentTodo
//

import AppIntents
import CoreTransferable
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Domain
import GeoToolbox
import Repository
import SwiftData

/// An App Intents entity representing a todo item.
///
/// This entity is used in Siri, Shortcuts, and Spotlight to reference todo items.
///
/// Conforms to `SyncableEntity` (WWDC 2026 #345): `id` is the `TodoItem`'s UUID
/// stringified, which is identical across a person's devices (SwiftData + CloudKit
/// replicate the same record id). That stability lets the system refer to a todo
/// consistently across devices — e.g. transferring a Siri conversation. No extra
/// `SyncableEntityIdentifier` is needed because there is no separate local id.
public struct TodoAppEntity: AppEntity, Hashable, SyncableEntity {
    // MARK: - Properties

    /// The unique identifier for this entity.
    public var id: String

    // `indexingKey:` (WWDC 2026 #240) maps the property onto the Spotlight
    // semantic index via a `CSSearchableItemAttributeSet` key, so semantic search
    // / Q&A can reason over the text. The overload is only vended where Spotlight
    // indexing exists (iOS / macOS) — matching the `IndexedEntity` extension below —
    // so other platforms fall back to a plain `@Property`.
    #if os(iOS) || os(macOS)
    /// The title of the todo item (semantically indexed via `.title`).
    @Property(title: "Title", indexingKey: \.title)
    public var title: String

    /// A longer free-text description of the todo, if any (semantically indexed
    /// via `.contentDescription` — the field most likely to carry natural-language
    /// content that semantic search / Q&A benefits from).
    @Property(title: "Description", indexingKey: \.contentDescription)
    public var todoDescription: String?
    #else
    /// The title of the todo item.
    @Property(title: "Title")
    public var title: String

    /// A longer free-text description of the todo, if any.
    @Property(title: "Description")
    public var todoDescription: String?
    #endif

    /// Whether the todo item is completed.
    @Property(title: "Completed")
    public var isCompleted: Bool

    /// Whether the todo item is marked as favorite.
    @Property(title: "Favorite")
    public var isFavorite: Bool

    /// The due date of the todo item, if any.
    @Property(title: "Due Date")
    public var dueDate: Date?

    /// The creation date of the todo item.
    public var createdAt: Date

    /// User-defined manual ordering index, mirrored from the model. Not exposed to
    /// Siri / Shortcuts (no `@Property`); it only drives the UI's `.manual` sort and
    /// drag-to-reorder. Included in `==` so a reorder invalidates the list.
    public var sortIndex: Int

    /// The category this todo belongs to, if any. Exposed as a related entity so
    /// Siri / Shortcuts can filter or navigate todos by category.
    @Property(title: "Category")
    public var category: CategoryAppEntity?

    /// Estimated time to complete, exposed as the App Intents native `Duration`
    /// type (WWDC 2026). Bridged from the stored `TimeInterval` on the model.
    @Property(title: "Estimated Duration")
    public var estimatedDuration: Duration?

    /// Display name of the assignee, if any.
    @Property(title: "Assignee")
    public var assigneeName: String?

    /// Associated location name.
    ///
    /// NOTE: App Intents ネイティブの `PlaceDescriptor` (GeoToolbox) を使いたいが、Xcode 27 beta 3 の
    /// AppIntentsSSUTraining が `GeoToolbox.PlaceDescriptorEntity` をそのまま SSU の variable 名に使い、
    /// ドットが regex `^[a-zA-Z_][a-zA-Z_$0-9]*$` に落ちてビルドエラーになる（SDK バグの可能性大）。
    /// 暫定で場所名の String に退避。SDK 修正後に `PlaceDescriptor?` へ戻す。
    @Property(title: "Location")
    public var location: String?

    // MARK: - Derived Properties (WWDC 2026 property macros)

    /// Whether the todo is past its due date and still incomplete.
    ///
    /// Uses `@ComputedProperty` (iOS 26+) so the value is derived live from the
    /// entity's snapshot fields and exposed to Shortcuts / Siri without being
    /// stored. Cheap and synchronous — no external source access.
    @ComputedProperty(title: "Is Overdue")
    public var isOverdue: Bool {
        guard !isCompleted, let dueDate else { return false }
        return dueDate < Date()
    }

    /// A short human-readable summary of subtask completion (e.g. "2/5 completed").
    ///
    /// Uses `@DeferredProperty` (iOS 26+): subtasks are a SwiftData relationship
    /// that isn't carried in the lightweight entity snapshot, so the value is
    /// fetched on demand only when Shortcuts / Siri actually request it. It is
    /// deliberately excluded from Spotlight indexing per the deferred-property
    /// contract.
    @DeferredProperty(title: "Subtask Progress")
    public var subtaskProgress: String {
        get async throws {
            try await Self.loadSubtaskProgress(forID: id)
        }
    }

    /// Fetches subtask completion counts on the MainActor and formats a summary.
    ///
    /// Entities can't use `@Dependency` (that is intents-only), so the shared
    /// container is read from `TodoEntityStore`, which the app registers at launch.
    private static func loadSubtaskProgress(forID id: String) async throws -> String {
        try await MainActor.run {
            guard let container = TodoEntityStore.container else {
                return String(localized: "No subtasks")
            }
            let repository = SwiftDataTodoRepository(modelContext: container.mainContext)
            guard let uuid = UUID(uuidString: id),
                  let item = try repository.fetch(by: uuid) else {
                return String(localized: "No subtasks")
            }
            let subTasks = item.subTasks ?? []
            guard !subTasks.isEmpty else {
                return String(localized: "No subtasks")
            }
            let completed = subTasks.filter(\.isCompleted).count
            return "\(completed)/\(subTasks.count) completed"
        }
    }

    // MARK: - AppEntity Requirements

    public static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(
            name: LocalizedStringResource("Todo", comment: "Todo item type name"),
            numericFormat: LocalizedStringResource("\(placeholder: .int) todos", comment: "Number of todos")
        )
    }

    public var displayRepresentation: DisplayRepresentation {
        Self.makeDisplayRepresentation(
            title: title,
            isCompleted: isCompleted,
            isFavorite: isFavorite,
            dueDate: dueDate
        )
    }

    /// Builds a todo's display representation from raw field values.
    ///
    /// Static so `TodoEntityQuery.displayRepresentations(for:)` can build the same
    /// representation straight from a `TodoItem`, without constructing the entity
    /// (and its `CategoryAppEntity` relation) only to discard it.
    ///
    /// The image is passed as a closure so the system can skip materializing it in
    /// text-only contexts (`DisplayRepresentation.Components.text`).
    static func makeDisplayRepresentation(
        title: String,
        isCompleted: Bool,
        isFavorite: Bool,
        dueDate: Date?
    ) -> DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: subtitle(isCompleted: isCompleted, dueDate: dueDate),
            synonyms: ["\(title) todo", "\(title) task"]
        ) {
            image(isCompleted: isCompleted, isFavorite: isFavorite)
        }
    }

    /// Siri はこの subtitle を読み上げるので、時刻は位置指定表記（"14:30"）ではなく
    /// 自然文表記で渡す。出す情報が無いときは空文字ではなく `nil`。
    /// 詳細: docs/insights/03-app-intents-core.md
    private static func subtitle(isCompleted: Bool, dueDate: Date?) -> LocalizedStringResource? {
        if isCompleted {
            return LocalizedStringResource("Completed", comment: "Todo completed status")
        }
        if let dueDate {
            return "Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return nil
    }

    private static func image(isCompleted: Bool, isFavorite: Bool) -> DisplayRepresentation.Image {
        if isCompleted {
            return .init(systemName: "checkmark.circle.fill")
        }
        if isFavorite {
            return .init(systemName: "star.fill")
        }
        return .init(systemName: "circle")
    }

    public static var defaultQuery: TodoEntityQuery {
        TodoEntityQuery()
    }

    // MARK: - Initialization

    /// Creates a new TodoAppEntity from a TodoItem.
    /// - Parameter todoItem: The domain model to convert.
    @MainActor
    public init(from todoItem: TodoItem) {
        self.id = todoItem.id.uuidString
        self.createdAt = todoItem.createdAt
        self.sortIndex = todoItem.sortIndex
        self.title = todoItem.title
        self.todoDescription = todoItem.todoDescription
        self.isCompleted = todoItem.isCompleted
        self.isFavorite = todoItem.isFavorite
        self.dueDate = todoItem.dueDate
        self.category = todoItem.category.map(CategoryAppEntity.init(from:))
        self.estimatedDuration = todoItem.estimatedDuration.map { Duration.seconds($0) }
        self.assigneeName = todoItem.assigneeName
        self.location = todoItem.locationName
    }

    /// Creates a new TodoAppEntity with the given properties.
    public init(
        id: String,
        title: String,
        todoDescription: String? = nil,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        sortIndex: Int = 0,
        category: CategoryAppEntity? = nil,
        estimatedDuration: Duration? = nil,
        assigneeName: String? = nil,
        location: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.location = location
    }

    // MARK: - Hashable / Equatable

    // The `@ComputedProperty` / `@DeferredProperty` macros add non-`Hashable`
    // `EntityProperty` backing storage, so synthesis is unavailable. Equality
    // compares the value snapshot fields; the hash uses the stable id.
    // `location` (PlaceDescriptor) is excluded as it isn't guaranteed `Equatable`;
    // the underlying stored name/coordinate are reflected via the model anyway.
    public static func == (lhs: TodoAppEntity, rhs: TodoAppEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.todoDescription == rhs.todoDescription
            && lhs.isCompleted == rhs.isCompleted
            && lhs.isFavorite == rhs.isFavorite
            && lhs.dueDate == rhs.dueDate
            && lhs.createdAt == rhs.createdAt
            && lhs.sortIndex == rhs.sortIndex
            && lhs.category == rhs.category
            && lhs.estimatedDuration == rhs.estimatedDuration
            && lhs.assigneeName == rhs.assigneeName
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Transferable (structured value export, WWDC 2026 #240/#345)

/// Lets a todo be shared / dragged / copied out of the app as structured values
/// that other apps and the system understand.
///
/// - A plain-text proxy (the title) so any text target can accept it.
/// - `ValueRepresentation` (`AppEntity.ValueRepresentation` = `IntentValueRepresentation`)
///   bridges to the system intent value types `IntentPerson` (assignee) and
///   `PlaceDescriptor` (location). This is the same machinery the issue tracks as
///   "ValueRepresentation(→IntentPerson)". The export closures throw when the
///   underlying value is absent, so a todo with no assignee / location simply
///   doesn't offer those flavors instead of exporting empty values.
extension TodoAppEntity: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.title)

        ValueRepresentation(exporting: { (todo: TodoAppEntity) -> IntentPerson in
            guard let name = todo.assigneeName, !name.isEmpty else {
                throw IntentError.notFound("Todo has no assignee to export")
            }
            return IntentPerson(
                identifier: .applicationDefined(todo.id),
                name: .displayName(name),
                handle: nil
            )
        })

        ValueRepresentation(exporting: { (todo: TodoAppEntity) -> PlaceDescriptor in
            // `location` は SSU バグ回避のため String（場所名）に退避している。
            // Transferable 経由の export はここで `PlaceDescriptor` に復元して従来どおり提供する。
            guard let descriptor = TodoPlace.descriptor(
                name: todo.location,
                latitude: nil,
                longitude: nil
            ) else {
                throw IntentError.notFound("Todo has no location to export")
            }
            return descriptor
        })
    }
}

// MARK: - IndexedEntity (Spotlight Integration)

#if os(iOS) || os(macOS)
/// Spotlight integration for todo items.
/// Allows users to search for todos via Spotlight with enhanced attributes.
extension TodoAppEntity: IndexedEntity {
    /// `@Property(indexingKey:)` が使っているキーはここで埋めない（どちらが勝つかは
    /// 公式に未定義）。`contentDescription` は `todoDescription` のマップ先なので、
    /// 完了状態は `keywords` 側で表現する。`displayName` は `.title` とは別キーで衝突しない。
    /// 詳細: docs/insights/03-app-intents-core.md
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        if let dueDate {
            attributes.dueDate = dueDate
        }
        attributes.keywords = buildKeywords()
        return attributes
    }

    /// Builds keyword list for Spotlight search.
    private func buildKeywords() -> [String] {
        var keywords = ["todo", title]
        if isFavorite {
            keywords.append(contentsOf: ["favorite", "starred", "important"])
        }
        if isCompleted {
            keywords.append("completed")
        } else {
            keywords.append(contentsOf: ["incomplete", "pending"])
        }
        return keywords
    }
}
#endif
