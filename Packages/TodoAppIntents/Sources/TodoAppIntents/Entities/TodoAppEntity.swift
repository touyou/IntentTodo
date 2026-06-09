//
//  TodoAppEntity.swift
//  IntentTodo
//

import AppIntents
#if canImport(CoreSpotlight)
import CoreSpotlight
#endif
import Domain
import Repository
import SwiftData

/// An App Intents entity representing a todo item.
///
/// This entity is used in Siri, Shortcuts, and Spotlight to reference todo items.
public struct TodoAppEntity: AppEntity, Hashable {
    // MARK: - Properties

    /// The unique identifier for this entity.
    public var id: String

    /// The title of the todo item.
    @Property(title: "Title")
    public var title: String

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

    /// The category this todo belongs to, if any. Exposed as a related entity so
    /// Siri / Shortcuts can filter or navigate todos by category.
    @Property(title: "Category")
    public var category: CategoryAppEntity?

    /// Estimated time to complete, exposed as the App Intents native `Duration`
    /// type (WWDC 2026). Bridged from the stored `TimeInterval` on the model.
    @Property(title: "Estimated Duration")
    public var estimatedDuration: Duration?

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
        DisplayRepresentation(
            title: LocalizedStringResource(stringLiteral: title),
            subtitle: subtitle,
            image: displayImage
        )
    }

    private var subtitle: LocalizedStringResource {
        if isCompleted {
            return LocalizedStringResource("Completed", comment: "Todo completed status")
        }
        if let dueDate {
            return LocalizedStringResource(stringLiteral: "Due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
        }
        return LocalizedStringResource("", comment: "Empty")
    }

    private var displayImage: DisplayRepresentation.Image {
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
        self.title = todoItem.title
        self.isCompleted = todoItem.isCompleted
        self.isFavorite = todoItem.isFavorite
        self.dueDate = todoItem.dueDate
        self.category = todoItem.category.map(CategoryAppEntity.init(from:))
        self.estimatedDuration = todoItem.estimatedDuration.map { Duration.seconds($0) }
    }

    /// Creates a new TodoAppEntity with the given properties.
    public init(
        id: String,
        title: String,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        category: CategoryAppEntity? = nil,
        estimatedDuration: Duration? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.category = category
        self.estimatedDuration = estimatedDuration
    }

    // MARK: - Hashable / Equatable

    // The `@ComputedProperty` / `@DeferredProperty` macros add non-`Hashable`
    // `EntityProperty` backing storage, so synthesis is unavailable. Equality
    // compares the value snapshot fields; the hash uses the stable id.
    public static func == (lhs: TodoAppEntity, rhs: TodoAppEntity) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.isCompleted == rhs.isCompleted
            && lhs.isFavorite == rhs.isFavorite
            && lhs.dueDate == rhs.dueDate
            && lhs.createdAt == rhs.createdAt
            && lhs.category == rhs.category
            && lhs.estimatedDuration == rhs.estimatedDuration
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - IndexedEntity (Spotlight Integration)

#if os(iOS) || os(macOS)
/// Spotlight integration for todo items.
/// Allows users to search for todos via Spotlight with enhanced attributes.
extension TodoAppEntity: IndexedEntity {
    public var attributeSet: CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet()
        attributes.displayName = title
        attributes.contentDescription = isCompleted ? "Completed" : "Incomplete"
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
