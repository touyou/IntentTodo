//
//  TodoAttributesEditView.swift
//  UI
//

import Domain
import SwiftUI
import TodoAppIntents

/// 既存 Todo の reminders 属性（tags / urls / recurrence / locationTriggerEvent）を編集する。
///
/// 保存は `Button(intent: UpdateTodoIntent(...))`。`UpdateTodoIntent` は
/// `IntentParameter.valueState` の三状態で「置き換え / クリア / 放置」を区別するので、
/// この画面が触る 4 つだけを init で代入し、残りは `.unset` のまま渡す（タイトルや期限が
/// 巻き戻らない）。
/// 詳細: docs/insights/03-app-intents-core.md
struct TodoAttributesEditView: View {
    @Environment(\.dismiss) private var dismiss

    let entity: TodoAppEntity

    /// 場所の有無だけを渡す。`locationTriggerEvent` は場所と対で初めて trigger になるため。
    let hasLocation: Bool

    @State private var attributes: TodoAttributesDraft

    /// - Parameters:
    ///   - todo: 編集対象。scalar な属性だけをここから読む。
    ///   - tags: 呼出側が id 経由で取り直したタグ。**モデルの配列属性を読んではいけない**
    ///     ため引数で受ける（削除済みオブジェクトの配列読みは trap する）。
    ///     詳細: `TodoDetailContent.tags` のコメント
    ///   - urls: 同上。
    init(todo: TodoItem, tags: [String], urls: [URL]) {
        self.entity = TodoAppEntity(from: todo)
        self.hasLocation = !(todo.locationName ?? "").isEmpty
        _attributes = State(
            initialValue: TodoAttributesDraft(
                tags: tags,
                urls: urls,
                recurrenceFrequency: todo.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:)),
                recurrenceInterval: max(TodoRecurrenceFrequency.minimumInterval, todo.recurrenceInterval),
                locationTriggerEvent: todo.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
            )
        )
    }

    private var updateIntent: UpdateTodoIntent {
        UpdateTodoIntent(
            todo: entity,
            tags: attributes.tags,
            urls: attributes.urls,
            recurrenceFrequency: attributes.recurrenceFrequency,
            recurrenceInterval: attributes.recurrenceInterval,
            locationTriggerEvent: attributes.locationTriggerEvent
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                TodoTagsSection(tags: $attributes.tags)
                TodoLinksSection(urls: $attributes.urls)
                TodoRecurrenceSection(
                    frequency: $attributes.recurrenceFrequency,
                    interval: $attributes.recurrenceInterval
                )
                TodoLocationTriggerSection(
                    event: $attributes.locationTriggerEvent,
                    hasLocation: hasLocation
                )
            }
            #if os(macOS)
            // AddTodoView と同じ理由で grouped に揃える（既定の .automatic は横端密着）。
            .formStyle(.grouped)
            #endif
            .navigationTitle(.copy("Edit Details"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.copy("Cancel")) {
                        dismiss()
                    }
                    .accessibilityIdentifier("cancelAttributesButton")
                }

                ToolbarItem(placement: .confirmationAction) {
                    // シートを閉じるのは `UpdateTodoIntent.perform()`
                    // （`navigationModel.dismissAttributeEditor()`）。ここで併せて
                    // dismiss すると、Intent が失敗しても閉じてしまい「保存された」ように
                    // 見える。`AddTodoIntent` と同じ「Intent 完了 = シート閉じる」形に揃える。
                    Button(intent: updateIntent) {
                        Text(.copy("Save"))
                    }
                    .accessibilityIdentifier("saveAttributesButton")
                }
            }
        }
    }
}
