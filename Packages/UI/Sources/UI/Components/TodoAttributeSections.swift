//
//  TodoAttributeSections.swift
//  UI
//
//  `.reminders.reminder` 由来の属性（tags / urls / recurrence / locationTriggerEvent）を
//  編集する Form セクション。追加画面（`AddTodoView`）と詳細からの編集シート
//  （`TodoAttributesEditView`）が同じ部品を共有する。
//
//  ここは入力の収集だけを担い、書き込みは呼出側の `Button(intent:)` が
//  `AddTodoIntent` / `UpdateTodoIntent` を走らせて行う（ロジックの二重実装を避ける）。
//

import AppIntents
import SwiftUI
import TodoAppIntents

// MARK: - Draft

/// フォームが編集中に持つ、reminders 属性の下書き。
///
/// `TodoAppEntity` をそのまま可変で持たないのは、`tags` / `urls` が
/// `@DeferredProperty`（entity のスナップショットに載らない）で、編集の起点として
/// 使えないため。値は `TodoItem` から直接読む。
struct TodoAttributesDraft {
    var tags: [String] = []
    var urls: [URL] = []
    var recurrenceFrequency: TodoRecurrenceFrequency?
    var recurrenceInterval: Int = TodoRecurrenceFrequency.minimumInterval
    var locationTriggerEvent: TodoLocationTriggerEvent?
}

// MARK: - Tags

/// タグの一覧と追加欄。
struct TodoTagsSection: View {
    @Binding var tags: [String]

    @State private var newTag = ""

    private var trimmedNewTag: String {
        newTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 追加できるのは空でなく、既にある綴りと（大文字小文字を無視して）重ならないときだけ。
    /// 判定を UI 側にも置くのは、押せるのに何も起きないボタンを見せないため。実際の
    /// 正規化は `TodoService` 側が最終的に行う。
    private var canAddNewTag: Bool {
        guard !trimmedNewTag.isEmpty else { return false }
        return !tags.contains { $0.caseInsensitiveCompare(trimmedNewTag) == .orderedSame }
    }

    var body: some View {
        Section {
            ForEach(tags, id: \.self) { tag in
                Label(tag, systemImage: "number")
            }
            .onDelete { offsets in
                tags.remove(atOffsets: offsets)
            }

            HStack {
                TextField(.copy("Add Tag"), text: $newTag)
                    .accessibilityIdentifier("tagField")
                    .onSubmit(addTag)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif

                Button(.copy("Add"), action: addTag)
                    .accessibilityIdentifier("addTagButton")
                    .disabled(!canAddNewTag)
                    .buttonStyle(.borderless)
            }
        } header: {
            Text(.copy("Tags"))
        }
    }

    private func addTag() {
        guard canAddNewTag else { return }
        tags.append(trimmedNewTag)
        newTag = ""
    }
}

// MARK: - Links

/// 添付リンクの一覧と追加欄。
struct TodoLinksSection: View {
    @Binding var urls: [URL]

    @State private var newLink = ""

    private var parsedNewLink: URL? {
        TodoLinkInput.url(from: newLink)
    }

    private var canAddNewLink: Bool {
        guard let parsedNewLink else { return false }
        return !urls.contains(parsedNewLink)
    }

    var body: some View {
        Section {
            ForEach(urls, id: \.self) { url in
                // 表示は絶対文字列。タップで開くのは編集中の意図と衝突するので Link にしない。
                Label(url.absoluteString, systemImage: "link")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onDelete { offsets in
                urls.remove(atOffsets: offsets)
            }

            HStack {
                TextField(.copy("Add Link"), text: $newLink)
                    .accessibilityIdentifier("linkField")
                    .onSubmit(addLink)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    #endif

                Button(.copy("Add"), action: addLink)
                    .accessibilityIdentifier("addLinkButton")
                    .disabled(!canAddNewLink)
                    .buttonStyle(.borderless)
            }
        } header: {
            Text(.copy("Links"))
        }
    }

    private func addLink() {
        guard let parsedNewLink, canAddNewLink else { return }
        urls.append(parsedNewLink)
        newLink = ""
    }
}

/// 入力欄の文字列を `URL` にする。
enum TodoLinkInput {
    /// スキームを省いた入力（`example.com`）に `https://` を補う。
    ///
    /// `URL(string:)` は `"example.com"` を**スキーム無しの相対 URL として受け入れる**ので、
    /// そのまま保存すると開けないリンクが並ぶ。補ってから作り直す。
    static func url(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let candidate = URL(string: trimmed) else { return nil }
        if candidate.scheme != nil {
            return candidate
        }
        return URL(string: "https://\(trimmed)")
    }
}

// MARK: - Recurrence

/// 繰り返しの頻度と間隔。
struct TodoRecurrenceSection: View {
    @Binding var frequency: TodoRecurrenceFrequency?
    @Binding var interval: Int

    /// 間隔の上限。年単位でも意味を持つ範囲で、Picker ではなく Stepper に収まる幅。
    private static let intervalRange = TodoRecurrenceFrequency.minimumInterval...30

    var body: some View {
        Section {
            Picker(selection: $frequency.animation()) {
                Text(.copy("Never")).tag(TodoRecurrenceFrequency?.none)
                // 表示名は `AppEnum` の `caseDisplayRepresentations` を `localizedStringResource`
                // 経由で読む。文言を 1 セットに保ち、Siri / Shortcuts とアプリ UI が同じものを
                // 見る（`TodoAppIntents` は catalog を持たないので、解決先はアプリターゲットの
                // main bundle）。UI パッケージの catalog にもう 1 組置くと 2 箇所で腐る。
                // 詳細: docs/insights/04-ui-integration.md
                ForEach(TodoRecurrenceFrequency.allCases, id: \.self) { option in
                    Text(option.localizedStringResource).tag(TodoRecurrenceFrequency?.some(option))
                }
            } label: {
                Text(.copy("Repeat"))
            }
            .accessibilityIdentifier("recurrencePicker")

            if frequency != nil {
                Stepper(value: $interval, in: Self.intervalRange) {
                    LabeledContent(.copy("Repeat Every")) {
                        Text(interval, format: .number)
                    }
                }
                .accessibilityIdentifier("recurrenceIntervalStepper")
            }
        }
    }
}

// MARK: - Location trigger

/// 到着 / 出発のどちらで Todo を出すか。
struct TodoLocationTriggerSection: View {
    @Binding var event: TodoLocationTriggerEvent?

    /// 場所が無いと trigger は成立しない（`TodoLocationTriggerAppEntity` は場所と event の
    /// 両方を要求する）。選べるままにしておいて、効かない理由をフッターで伝える。
    let hasLocation: Bool

    var body: some View {
        Section {
            Picker(selection: $event) {
                Text(.copy("Never")).tag(TodoLocationTriggerEvent?.none)
                ForEach(TodoLocationTriggerEvent.allCases, id: \.self) { option in
                    Text(option.localizedStringResource).tag(TodoLocationTriggerEvent?.some(option))
                }
            } label: {
                Text(.copy("Location Trigger"))
            }
            .accessibilityIdentifier("locationTriggerPicker")
        } footer: {
            if event != nil && !hasLocation {
                Text(.copy("Add a location for this to take effect."))
            }
        }
    }
}
