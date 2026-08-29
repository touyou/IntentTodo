//
//  TodoAppEntity.swift
//  IntentTodo
//
//  非 watchOS 版（reminders スキーマ適合あり）の宣言と、const 抽出される適合
//  （`Transferable` / `URLRepresentableEntity`）。watchOS 版は `WatchTodoAppEntity.swift`、
//  両系統で共有する表示・クエリ・等価性は `TodoAppEntity+Shared.swift`。
//

import AppIntents
import CoreTransferable
import Domain
import Foundation
import GeoToolbox
import Repository
import SwiftData

// MARK: - なぜ 2 系統なのか
//
// `AppSchema` の**全 20 ドメインが watchOS / tvOS で `@available(..., unavailable)`**。
// reminders 固有の制限ではなく、App Schema が「Apple Intelligence の新しい Siri に語彙を
// 渡す」仕組みで、その Siri が iPhone / iPad / Mac / visionOS にしか無いため
// （WWDC 2026 Apple Intelligence Group Lab 35:34 "The new Siri AI is available on iPhone,
// iPad, Mac, and visionOS."）。ドメインを変えても回避できない。
//
// 一方 iOS アプリの `appintentsmetadataprocessor` には **watchOS スライスのメタデータが
// 入力として渡る**（Xcode が自動生成する `IntentTodo.DependencyMetadataFileList` に
// `Debug-watchsimulator/...` が並ぶ）。同じ mangled name にスキーマ有り / 無しの 2 形が
// あると**スキーマ無し側が勝ち、iOS の出荷メタデータからスキーマが静かに消える**（実測）。
//
// したがって watchOS には**別の型名**を与えるしかない。`__appSchemaEntity` を手書きして
// watchOS でも適合を宣言する手もあるが、これは
//   ① `AssistantSchemaEntity` のプロトコル要求ですらない非公開シンボル（マクロと
//      メタデータ抽出器の間の申し合わせ）で、Apple のガイダンスが使用を禁じている
//   ② スキーマという機能自体が無いプラットフォームに「この型は reminders.ReminderEntity
//      です」と主張するメタデータを出すことになり、内容としても誤り
// の 2 点で採らない。
//
// 経緯: docs/devlog/2026-08-29-schema-vs-watch-target.md

#if !os(watchOS)

/// An App Intents entity representing a todo item.
///
/// Conforms to the reminders `reminder` assistant schema so Siri / Apple Intelligence
/// treat a todo as a reminder. The macro supplies the schema conformance; we supply the
/// schema-required properties plus the app's own extras.
///
/// Conforms to `SyncableEntity` (WWDC 2026 #345): `id` is the `TodoItem`'s UUID
/// stringified, which is identical across a person's devices (SwiftData + CloudKit
/// replicate the same record id). That stability lets the system refer to a todo
/// consistently across devices — e.g. transferring a Siri conversation. No extra
/// `SyncableEntityIdentifier` is needed because there is no separate local id.
@AppEntity(schema: .reminders.reminder)
public struct TodoAppEntity: Hashable, SyncableEntity {
    // MARK: - Properties

    /// The unique identifier for this entity.
    public var id: String

    // `indexingKey:` (WWDC 2026 #240) maps the property onto the Spotlight
    // semantic index via a `CSSearchableItemAttributeSet` key, so semantic search
    // / Q&A can reason over the text.
    // 経緯: docs/devlog/2026-08-28-xcode27-beta6-recheck.md（visionOS を除外していたのは誤りだった件）

    /// The title of the todo item (semantically indexed via `.title`).
    @Property(title: "Title", indexingKey: \.title)
    public var title: String

    /// A longer free-text description of the todo, if any (semantically indexed
    /// via `.contentDescription` — the field most likely to carry natural-language
    /// content that semantic search / Q&A benefits from).
    @Property(title: "Description", indexingKey: \.contentDescription)
    public var todoDescription: String?

    /// Whether the todo item is completed.
    @Property(title: "Completed")
    public var isCompleted: Bool

    /// Whether the todo item is marked as favorite.
    @Property(title: "Favorite")
    public var isFavorite: Bool

    /// The due date as a `Date`, for the app's own use (comparisons, formatting,
    /// Live Activity scheduling).
    ///
    /// Deliberately **not** a `@Property`: the schema-visible spelling of the due
    /// date is `dueDate` below, and exposing the same value twice would give Siri
    /// two competing properties for one concept.
    public var dueDateValue: Date?

    /// The due date of the todo item, if any (schema-required).
    ///
    /// `.reminders.reminder` requires `DateComponents?` here, not `Date?` — the
    /// schema can express "a day with no time of day", which a `Date` can't. The
    /// stored value stays a `Date` (`dueDateValue`) and this projects it.
    @ComputedProperty(title: "Due Date")
    public var dueDate: DateComponents? {
        dueDateValue.map {
            Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: $0)
        }
    }

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

    /// Associated location.
    ///
    /// App Intents ネイティブの `PlaceDescriptor`（GeoToolbox）で持つ。モデル側は CloudKit 互換の
    /// primitive（名前 + 緯度経度）なので `TodoPlace` が相互変換する。
    ///
    /// SSU training バグ（FB24548956）が発火するのは **App Shortcut に登録した Intent の
    /// `@Parameter`** だけで、entity の `@Property` は SSU の variable にならないため、ここは
    /// ネイティブ型のままで問題ない。
    /// 詳細: docs/insights/03-app-intents-core.md
    /// 経緯: docs/devlog/2026-08-28-ssu-system-value-type-bug.md
    @Property(title: "Location")
    public var location: PlaceDescriptor?

    // MARK: - reminders スキーマ要求プロパティ

    /// When the todo was completed, if it has been (schema-required).
    @Property(title: "Completion Date")
    public var completionDate: Date?

    /// Free-form tags (schema-required).
    ///
    /// `@DeferredProperty` にしているのは `subtaskProgress` と同じ理由 + もう 1 つ:
    /// **SwiftData は削除済みオブジェクトの配列属性を読むと trap する**（scalar は最後の値を
    /// 返すので耐える）。`@Query` の結果は削除直後の 1 フレームだけ削除済みオブジェクトを
    /// 含みうるので、`init(from:)` の中で配列を読むと詳細画面の再描画でクラッシュする（実測）。
    /// id から引き直す形にすると、消えた todo は「見つからない」に落ちるだけで済む。
    ///
    /// スキーマは `Set<String>` を要求する。モデル側は CloudKit 互換のため `[String]`。
    /// 経緯: docs/devlog/2026-08-29-reminder-schema-conformance.md
    @DeferredProperty(title: "Tags")
    public var tags: Set<String> {
        get async throws {
            try await Self.loadTags(forID: id)
        }
    }

    /// Links attached to the todo (schema-required). `tags` と同じ理由で deferred。
    @DeferredProperty(title: "URLs")
    public var urls: [URL] {
        get async throws {
            try await Self.loadURLs(forID: id)
        }
    }

    /// Recurrence rule, if the todo repeats (schema-required).
    @Property(title: "Recurrence")
    public var recurrence: Calendar.RecurrenceRule?

    /// Place-plus-event pair that surfaces the todo (schema-required).
    @Property(title: "Location Trigger")
    public var locationTrigger: TodoLocationTriggerAppEntity?

    // MARK: - スキーマ名エイリアス
    //
    // `.reminders.reminder` はプロパティ名まで一致を要求する（`note` / `creationDate` /
    // `isFlagged` / `list`）。アプリ側の既存名（`todoDescription` / `createdAt` /
    // `isFavorite` / `category`）を変えずに済ませるため、`@ComputedProperty` で
    // スキーマ側の綴りを足している。
    // 経緯: docs/devlog/2026-08-29-reminder-schema-conformance.md

    /// The note body (schema-required spelling of `todoDescription`).
    @ComputedProperty(title: "Note")
    public var note: String? {
        todoDescription
    }

    /// The creation date (schema-required spelling of `createdAt`).
    @ComputedProperty(title: "Creation Date")
    public var creationDate: Date? {
        createdAt
    }

    /// Whether the todo is flagged (schema-required spelling of `isFavorite`).
    @ComputedProperty(title: "Is Flagged")
    public var isFlagged: Bool? {
        isFavorite
    }

    /// The list this todo belongs to (schema-required spelling of `category`).
    ///
    /// スキーマは**非 optional**を要求するが、`TodoItem.category` は CloudKit 要件で
    /// optional。未分類の todo には合成の `CategoryAppEntity.uncategorized` を見せる。
    @ComputedProperty(title: "List")
    public var list: CategoryAppEntity {
        category ?? .uncategorized
    }

    // MARK: - Derived Properties (WWDC 2026 property macros)

    /// Whether the todo is past its due date and still incomplete.
    ///
    /// Uses `@ComputedProperty` (iOS 26+) so the value is derived live from the
    /// entity's snapshot fields and exposed to Shortcuts / Siri without being
    /// stored. Cheap and synchronous — no external source access.
    @ComputedProperty(title: "Is Overdue")
    public var isOverdue: Bool {
        Self.isOverdue(isCompleted: isCompleted, dueDate: dueDateValue)
    }

    /// A short human-readable summary of subtask completion (e.g. "2/5 completed").
    ///
    /// Uses `@DeferredProperty` (iOS 26+): subtasks are a SwiftData relationship
    /// that isn't carried in the lightweight entity snapshot, so the value is
    /// fetched on demand only when Shortcuts / Siri actually request it.
    @DeferredProperty(title: "Subtask Progress")
    public var subtaskProgress: String {
        get async throws {
            try await Self.loadSubtaskProgress(forID: id)
        }
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
        self.dueDateValue = todoItem.dueDate
        self.category = todoItem.category.map(CategoryAppEntity.init(from:))
        self.estimatedDuration = todoItem.estimatedDuration.map { Duration.seconds($0) }
        self.assigneeName = todoItem.assigneeName
        self.location = TodoPlace.descriptor(
            name: todoItem.locationName,
            latitude: todoItem.locationLatitude,
            longitude: todoItem.locationLongitude
        )
        self.completionDate = todoItem.completionDate
        self.recurrence = TodoRecurrence.rule(
            frequency: todoItem.recurrenceFrequency,
            interval: todoItem.recurrenceInterval
        )
        self.locationTrigger = TodoLocationTriggerAppEntity.make(from: todoItem)
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
        location: PlaceDescriptor? = nil,
        completionDate: Date? = nil,
        recurrence: Calendar.RecurrenceRule? = nil,
        locationTrigger: TodoLocationTriggerAppEntity? = nil
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
        self.completionDate = completionDate
        self.recurrence = recurrence
        self.locationTrigger = locationTrigger
    }
}

// MARK: - 同一ファイルに置く理由
//
// `Transferable` / `URLRepresentableEntity` の宣言は **const 抽出**（swiftconstvalues）で
// 読まれるため、型宣言と別ファイルに置くと
// `The property 'transferRepresentation' must be static, have a compile-time constant
// value, and cannot be computed or dynamic` でメタデータ抽出が落ちる（実測）。
// 他の共通実装は `TodoAppEntity+Shared.swift` にある。

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
extension TodoAppEntity: Transferable {
    public static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.title)

        // `exporting:` は Transferable DSL で表現の向きを選ぶラベルで（`importing:` /
        // `exporting:importing:` の兄弟がある）、外すと向きの決定がクロージャの型推論に
        // 委ねられる。上の `ProxyRepresentation(exporting:)` とも綴りを揃える。
        // swiftlint:disable:next trailing_closure
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

        // swiftlint:disable:next trailing_closure
        ValueRepresentation(exporting: { (todo: TodoAppEntity) -> PlaceDescriptor in
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
extension TodoAppEntity: URLRepresentableEntity {
    public static var urlRepresentation: URLRepresentation {
        "intenttodo://todo/\(.id)"
    }
}

#endif
