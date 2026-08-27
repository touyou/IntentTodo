//
//  TodoFocusFilter.swift
//  TodoAppIntents
//
//  集中モードごとの絞り込み設定。`TodoFocusFilterIntent`（SetFocusFilterIntent）が
//  書き、リスト UI とウィジェットが読む。
//
//  読み手が別プロセス（Widget Extension）にも居るため、転送は App Group の
//  UserDefaults を通す。値の解釈（どの Todo を残すか）はこの型の純関数に集約し、
//  UI とウィジェットで判定がずれないようにする。
//
//  詳細: docs/insights/03-app-intents-core.md（Focus filter）
//

import Domain
import Foundation

// MARK: - Value

/// 集中モード中に「どの Todo を見せるか」の設定一式。
public struct TodoFocusFilter: Equatable, Sendable, Codable {
    /// 表示対象のカテゴリ ID（`nil` はカテゴリで絞らない）。
    public var categoryID: String?

    /// 設定 UI / インジケータ表示用のカテゴリ名。ID から引き直さずに済ませるため
    /// 一緒に持つ（カテゴリ名の変更は次の Focus 遷移で追従する）。
    public var categoryName: String?

    /// 期限が近い / 過ぎている Todo だけを残す。
    public var showsUrgentOnly: Bool

    /// 完了済みを隠す。
    public var hidesCompleted: Bool

    /// 何も絞らない状態。Focus が切れたときと、未設定のときの値。
    public static let inactive = TodoFocusFilter(
        categoryID: nil,
        categoryName: nil,
        showsUrgentOnly: false,
        hidesCompleted: false
    )

    public init(
        categoryID: String? = nil,
        categoryName: String? = nil,
        showsUrgentOnly: Bool = false,
        hidesCompleted: Bool = false
    ) {
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.showsUrgentOnly = showsUrgentOnly
        self.hidesCompleted = hidesCompleted
    }

    /// 1 つでも絞り込みが効いているか。UI のインジケータ表示条件でもある。
    public var isActive: Bool {
        categoryID != nil || showsUrgentOnly || hidesCompleted
    }

    // MARK: - Application

    /// 設定を Todo 一覧に適用する。
    ///
    /// リスト UI とウィジェットの両方から呼ぶ純関数。`now` を引数に取るのは
    /// 「期限が近い」の判定を固定時刻でテストできるようにするため。
    public func apply(to todos: [TodoAppEntity], now: Date = Date()) -> [TodoAppEntity] {
        guard isActive else { return todos }
        return todos.filter { todo in
            if let categoryID, todo.category?.id != categoryID { return false }
            if hidesCompleted, todo.isCompleted { return false }
            if showsUrgentOnly, !Self.isUrgent(todo, now: now) { return false }
            return true
        }
    }

    /// 「急ぎ」の定義は `DueDateStatus` に合わせる（期限切れ or 1 時間以内）。
    /// UI のバッジ表示と同じ閾値にしておかないと、絞り込み結果と見た目が食い違う。
    static func isUrgent(_ todo: TodoAppEntity, now: Date) -> Bool {
        guard let dueDate = todo.dueDate else { return false }
        switch DueDateStatus.evaluate(date: dueDate, isCompleted: todo.isCompleted, now: now) {
        case .overdue, .dueSoon:
            return true
        case .normal:
            return false
        }
    }

    // MARK: - Notification filter criteria

    /// アプリ自身の都合で出す通知（コントロールの失敗通知など）に付ける criteria。
    ///
    /// `FocusFilterAppContext.notificationFilterPredicate` に一致しない通知は
    /// システムが黙らせる（wwdc2022-10121 13:15）。失敗を知らせる通知が消えると
    /// 「何も起きなかった」と区別できなくなるので、常に許可リストに入れる。
    public static let systemNotificationCriteria = "system"

    /// Todo に紐づく通知の criteria。カテゴリ未設定の Todo は `category:none`。
    public static func notificationCriteria(categoryID: String?) -> String {
        "category:\(categoryID ?? "none")"
    }

    /// この設定で通す通知 criteria の許可リスト。
    ///
    /// カテゴリで絞っていないときは `nil`（＝通知は絞らない）。`showsUrgentOnly` /
    /// `hidesCompleted` は「一覧の見せ方」の設定で、通知の宛先を変える性質のもの
    /// ではないため通知側には効かせない。
    public var allowedNotificationCriteria: [String]? {
        guard let categoryID else { return nil }
        return [Self.systemNotificationCriteria, Self.notificationCriteria(categoryID: categoryID)]
    }

    // MARK: - Shared storage

    /// App Group の UserDefaults に書かれる際のキー。
    static let sharedDefaultsKey = "focusFilter"

    /// App Group の UserDefaults。取得できない構成では `nil` を返し、呼び出し側は
    /// 「絞り込み無し」にフォールバックする。
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    /// 保存されている設定を読む。未設定・壊れている場合は `.inactive`。
    ///
    /// `nonisolated` かつ同期。ウィジェットのタイムライン生成からも呼ぶ。
    public static func loadFromSharedDefaults(_ defaults: UserDefaults? = nil) -> TodoFocusFilter {
        guard let defaults = defaults ?? sharedDefaults(),
              let data = defaults.data(forKey: sharedDefaultsKey),
              let filter = try? JSONDecoder().decode(TodoFocusFilter.self, from: data) else {
            return .inactive
        }
        return filter
    }

    /// 設定を保存する。`.inactive` はキーごと消す（読み手のフォールバックと同義）。
    public func saveToSharedDefaults(_ defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? Self.sharedDefaults() else { return }
        guard isActive else {
            defaults.removeObject(forKey: Self.sharedDefaultsKey)
            return
        }
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: Self.sharedDefaultsKey)
    }
}
