//
//  WatchTodoAppEntity.swift
//  IntentTodo
//
//  watchOS 版の `TodoAppEntity`。**型名を分けている理由は `TodoAppEntity.swift` の
//  冒頭コメント**（App Schema が watchOS に無く、同じ mangled name にスキーマ有無の
//  2 形があると iOS の出荷メタデータからスキーマが消えるため）。
//
//  `Transferable` / `URLRepresentableEntity` をここに（`typealias` ではなく具象名で）
//  書いているのも実測による制約: const 抽出は typealias 越しに型へ結び付かず、
//  `extension TodoAppEntity: Transferable` と書くと watchOS スライスの抽出が
//  `The property 'transferRepresentation' must be static, have a compile-time constant
//  value, and cannot be computed or dynamic` で落ちる。
//

import AppIntents
import CoreTransferable
import Domain
import Foundation
import GeoToolbox
import Repository
import SwiftData

#if os(watchOS)

/// An App Intents entity representing a todo item (watchOS).
///
/// スキーマ適合が無いので、スキーマだけが要求するプロパティ（`note` / `creationDate` /
/// `isFlagged` / `list` / `dueDate`(DateComponents) / `completionDate` / `tags` / `urls` /
/// `recurrence` / `locationTrigger`）は持たない。watch の UI と Intent が使うのは
/// ここにある分だけ。
public struct WatchTodoAppEntity: AppEntity, Hashable, SyncableEntity {
    // MARK: - Properties

    /// The unique identifier for this entity.
    public var id: String

    /// The title of the todo item.
    @Property(title: "Title")
    public var title: String

    /// A longer free-text description of the todo, if any.
    @Property(title: "Description")
    public var todoDescription: String?

    /// Whether the todo item is completed.
    @Property(title: "Completed")
    public var isCompleted: Bool

    /// Whether the todo item is marked as favorite.
    @Property(title: "Favorite")
    public var isFavorite: Bool

    /// The due date, for the app's own use (comparisons, formatting).
    ///
    /// 名前が `dueDateValue` なのはスキーマ側の系統と揃えるため（あちらは `dueDate` を
    /// `DateComponents?` の射影に使っている）。共有 extension が両方から読む。
    public var dueDateValue: Date?

    /// The creation date of the todo item.
    public var createdAt: Date

    /// User-defined manual ordering index, mirrored from the model.
    public var sortIndex: Int

    /// The category this todo belongs to, if any.
    @Property(title: "Category")
    public var category: CategoryAppEntity?

    /// Estimated time to complete.
    @Property(title: "Estimated Duration")
    public var estimatedDuration: Duration?

    /// Display name of the assignee, if any.
    @Property(title: "Assignee")
    public var assigneeName: String?

    /// Associated location.
    @Property(title: "Location")
    public var location: PlaceDescriptor?

    /// Whether the todo is past its due date and still incomplete.
    @ComputedProperty(title: "Is Overdue")
    public var isOverdue: Bool {
        Self.isOverdue(isCompleted: isCompleted, dueDate: dueDateValue)
    }

    /// A short human-readable summary of subtask completion (e.g. "2/5 completed").
    @DeferredProperty(title: "Subtask Progress")
    public var subtaskProgress: String {
        get async throws {
            try await Self.loadSubtaskProgress(forID: id)
        }
    }

    // MARK: - Initialization

    /// Creates a new entity from a `TodoItem`.
    @MainActor
    public init(from todoItem: TodoItem) {
        self.id = todoItem.id.uuidString
        self.createdAt = todoItem.createdAt
        self.sortIndex = todoItem.sortIndex
        self.title = todoItem.title
        self.todoDescription = todoItem.todoDescription
        self.isCompleted = todoItem.isCompleted
        self.isFavorite = todoItem.isFavorite
        self.dueDateValue = todoItem.dueDate
        self.category = todoItem.category.map(CategoryAppEntity.init(from:))
        self.estimatedDuration = todoItem.estimatedDuration.map { Duration.seconds($0) }
        self.assigneeName = todoItem.assigneeName
        self.location = TodoPlace.descriptor(
            name: todoItem.locationName,
            latitude: todoItem.locationLatitude,
            longitude: todoItem.locationLongitude
        )
    }

    /// Creates a new entity with the given properties.
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
        location: PlaceDescriptor? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.title = title
        self.todoDescription = todoDescription
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDateValue = dueDate
        self.category = category
        self.estimatedDuration = estimatedDuration
        self.assigneeName = assigneeName
        self.location = location
    }
}

/// Call sites use the shared name on every platform, so nothing outside this file
/// needs a `#if`. Only the metadata sees the two names apart.
public typealias TodoAppEntity = WatchTodoAppEntity

// MARK: - const 抽出される適合
//
// `Transferable` / `URLRepresentableEntity` の宣言は **const 抽出**（swiftconstvalues）で
// 読まれるため、型宣言と別ファイルに置くと
// `The property 'transferRepresentation' must be static, have a compile-time constant
// value, and cannot be computed or dynamic` でメタデータ抽出が落ちる（実測）。
// 他の共通実装は `WatchTodoAppEntity+Shared.swift` にある。

// MARK: - Transferable (structured value export, WWDC 2026 #240/#345)

/// Lets a todo be shared / dragged / copied out of the app as structured values
/// that other apps and the system understand.
///
/// - A plain-text proxy (the title) so any text target can accept it.
/// - `ValueRepresentation` (`AppEntity.ValueRepresentation` = `IntentValueRepresentation`)
///   bridges to the system intent value types `IntentPerson` (assignee) and
///   `PlaceDescriptor` (location). The export closures throw when the underlying value
///   is absent, so a todo with no assignee / location simply doesn't offer those flavors
///   instead of exporting empty values.
extension WatchTodoAppEntity: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.title)

        // `exporting:` は Transferable DSL で表現の向きを選ぶラベルで（`importing:` /
        // `exporting:importing:` の兄弟がある）、外すと向きの決定がクロージャの型推論に
        // 委ねられる。上の `ProxyRepresentation(exporting:)` とも綴りを揃える。
        // swiftlint:disable:next trailing_closure
        ValueRepresentation(exporting: { (todo: WatchTodoAppEntity) -> IntentPerson in
            guard let name = todo.assigneeName, !name.isEmpty else {
                throw IntentError.notFound("Todo has no assignee to export")
            }
            return IntentPerson(
                identifier: .applicationDefined(todo.id),
                name: .displayName(name),
                handle: nil
            )
        })

        // swiftlint:disable:next trailing_closure
        ValueRepresentation(exporting: { (todo: WatchTodoAppEntity) -> PlaceDescriptor in
            guard let descriptor = todo.location else {
                throw IntentError.notFound("Todo has no location to export")
            }
            return descriptor
        })
    }
}

// MARK: - URLRepresentableEntity

/// Todo を URL で指し示せるようにする。
///
/// これがあると `OpenTodoIntent` が `URLRepresentableIntent` を無償で満たせて、
/// ウィジェットの `Link(destination:)` からも同じ宛先を作れる。
///
/// リテラルの綴りは `TodoDeepLink.todo(id:)` と一致していなければならない
/// （こちらは DSL なので関数を呼べず、同じ形を 2 回書くしかない）。
/// 食い違いは `TodoDeepLinkTests` が検出する。
/// 詳細: docs/insights/03-app-intents-core.md（URL 表現）
extension WatchTodoAppEntity: URLRepresentableEntity {
    public static var urlRepresentation: URLRepresentation {
        "intenttodo://todo/\(.id)"
    }
}

#endif
