//
//  TodoFocusFilterIntent.swift
//  TodoAppIntents
//
//  集中モードごとに一覧の見せ方を変える Focus filter（wwdc2022-10121）。
//  設定 > 集中モード > アプリのフィルタ に現れ、Focus の切り替わりでシステムが
//  `perform()` を呼ぶ。
//

import AppIntents
import Foundation
import os.log

private let logger = Logger(subsystem: "com.touyou.IntentTodo", category: "TodoFocusFilterIntent")

/// 集中モード中に表示する Todo を絞り込む。
///
/// `allowedExecutionTargets` は宣言しない。Focus filter の実行先は Focus の仕組みが
/// 決める（アプリが動いていればアプリ、そうでなければ AppIntents Extension。
/// wwdc2022-10121 9:29）ので、こちらから固定する意味がない。本アプリは Extension を
/// 持たないため、アプリ未起動中の遷移は `TodoFocusFilterStore.syncFromSystem()` が
/// 起動時に `current` で取り直して埋める。
public struct TodoFocusFilterIntent: SetFocusFilterIntent {
    public static let title: LocalizedStringResource = "Filter Todos"

    public static let description = IntentDescription(
        "Choose which todos to show while this Focus is on",
        categoryName: "Todos"
    )

    /// Focus の切り替わりでアプリを開いてはいけないので背景実行のみ。
    public static var supportedModes: IntentModes { .background }

    // MARK: - Parameters

    @Parameter(title: "Category")
    public var category: CategoryAppEntity?

    @Parameter(title: "Only Urgent Todos", default: false)
    public var showsUrgentOnly: Bool

    @Parameter(title: "Hide Completed Todos", default: false)
    public var hidesCompleted: Bool

    public init() {}

    public init(category: CategoryAppEntity?, showsUrgentOnly: Bool, hidesCompleted: Bool) {
        self.category = category
        self.showsUrgentOnly = showsUrgentOnly
        self.hidesCompleted = hidesCompleted
    }

    // MARK: - Value bridging

    /// パラメータをアプリ側の値型へ落とす。`perform()` と `current` の両方が使う。
    public var resolvedFilter: TodoFocusFilter {
        TodoFocusFilter(
            categoryID: category?.id,
            categoryName: category?.name,
            showsUrgentOnly: showsUrgentOnly,
            hidesCompleted: hidesCompleted
        )
    }

    // MARK: - Display

    /// 設定画面のセルに出る文言。設定済みの内容を動的に反映する
    /// （wwdc2022-10121 8:07）。ランタイム値は `"\(value)"` の補間で渡す
    /// （`LocalizedStringResource(stringLiteral:)` は実行時文字列をキー扱いする）。
    public var displayRepresentation: DisplayRepresentation {
        let filter = resolvedFilter
        guard filter.isActive else {
            return DisplayRepresentation(
                title: "Show All Todos",
                subtitle: "No filtering"
            )
        }

        var configured: [LocalizedStringResource] = []
        var values: [String] = []

        if let categoryName = filter.categoryName {
            configured.append("Category")
            values.append(categoryName)
        }
        if filter.showsUrgentOnly {
            configured.append("Urgency")
            values.append(String(localized: "Urgent only"))
        }
        if filter.hidesCompleted {
            configured.append("Completed")
            values.append(String(localized: "Hidden"))
        }

        return DisplayRepresentation(
            title: "Filter \(configured, format: .list(type: .and))",
            subtitle: "\(values.formatted())"
        )
    }

    // MARK: - App Context

    /// 通知の絞り込み条件をシステムへ返す。
    ///
    /// `notificationFilterPredicate` に一致しない `filterCriteria` を持つ通知は
    /// 黙らされる（wwdc2022-10121 13:15）ので、カテゴリで絞っているときだけ
    /// 述語を返す。許可リストには必ず `systemNotificationCriteria` を含める
    /// （失敗通知は Focus 中でも届かないと気づけない）。
    public var appContext: FocusFilterAppContext {
        guard let allowed = resolvedFilter.allowedNotificationCriteria else {
            return FocusFilterAppContext()
        }
        return FocusFilterAppContext(
            notificationFilterPredicate: NSPredicate(format: "SELF IN %@", allowed)
        )
    }

    // MARK: - Perform

    @MainActor
    public func perform() async throws -> some IntentResult {
        let filter = resolvedFilter
        logger.info(
            "focus filter applied category=\(filter.categoryID ?? "nil", privacy: .public) urgentOnly=\(filter.showsUrgentOnly) hidesCompleted=\(filter.hidesCompleted)"
        )
        TodoFocusFilterStore.shared.apply(filter)
        // ウィジェットは共有ストレージ経由で同じ設定を読むので、書いた直後に描き直させる。
        WidgetReloader.reloadAllWidgets()
        return .result()
    }
}
