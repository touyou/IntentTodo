//
//  TodoDetailAttributeSections.swift
//  UI
//
//  詳細画面のうち、Todo の属性を並べるセクション群。`TodoDetailView.swift` から
//  切り出したのは行数の都合だけで、`VisionOSTodoDetailView.swift` を
//  `VisionOSTodoView.swift` から分けたのと同じ理由。
//

import Domain
import SwiftUI
import TodoAppIntents

// MARK: - Tags

struct TodoDetailTagsSection: View {
    let tags: [String]

    var body: some View {
        ForEach(tags, id: \.self) { tag in
            Label(tag, systemImage: "number")
                .font(.subheadline)
        }
    }
}

// MARK: - Links

struct TodoDetailLinksSection: View {
    let urls: [URL]

    var body: some View {
        ForEach(urls, id: \.self) { url in
            Link(destination: url) {
                Label(url.absoluteString, systemImage: "link")
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}

// MARK: - Metadata

struct TodoDetailMetadataSection: View {
    let todo: TodoItem

    /// 秒で保持された所要時間を "1h 30m" 形式へ整形する。
    private var formattedDuration: String? {
        guard let seconds = todo.estimatedDuration, seconds > 0 else { return nil }
        return Duration.seconds(seconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        Group {
            LabeledContent(.copy("Created")) {
                Text(todo.createdAt.formatted(date: .abbreviated, time: .shortened))
            }
            LabeledContent(.copy("Modified")) {
                Text(todo.modifiedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let category = todo.category {
                LabeledContent(.copy("Category")) {
                    HStack {
                        Circle()
                            .fill(category.colorHex.flatMap(Color.init(hex:)) ?? Color.gray)
                            .frame(width: 10, height: 10)
                        Text(category.name)
                    }
                }
            }
            // WWDC 2026 で追加した属性 (所要時間 / 担当者 / 場所) を表示。
            // 値は Created/Modified と同じく plain Text に揃える (Label を value に
            // 置くと行が縦に間延びするため)。
            if let formattedDuration {
                LabeledContent(.copy("Estimated Duration")) {
                    Text(formattedDuration)
                }
            }
            if let assignee = todo.assigneeName, !assignee.isEmpty {
                LabeledContent(.copy("Assignee")) {
                    Text(assignee)
                }
            }
            if let location = todo.locationName, !location.isEmpty {
                LabeledContent(.copy("Location")) {
                    Text(location)
                }
            }
            // reminders スキーマ属性のうち、行 1 本で足りるもの。tags / urls は件数が
            // 増えるので専用セクションに出す。
            if let frequency = recurrenceFrequency {
                LabeledContent(.copy("Repeat")) {
                    // 頻度の文言は enum の `caseDisplayRepresentations` から来るので Siri と
                    // 同じ。間隔は倍率として添える（"Every 2 weeks" 形にすると頻度 4 種 ×
                    // 複数形のキーが必要になり、得られる自然さに見合わない）。
                    HStack(spacing: 4) {
                        Text(frequency.localizedStringResource)
                        if todo.recurrenceInterval > TodoRecurrenceFrequency.minimumInterval {
                            Text(.copy("× \(todo.recurrenceInterval)"))
                        }
                    }
                }
            }
            if let event = locationTriggerEvent {
                LabeledContent(.copy("Location Trigger")) {
                    Text(event.localizedStringResource)
                }
            }
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }

    private var recurrenceFrequency: TodoRecurrenceFrequency? {
        todo.recurrenceFrequency.flatMap(TodoRecurrenceFrequency.init(rawValue:))
    }

    private var locationTriggerEvent: TodoLocationTriggerEvent? {
        todo.locationTriggerEvent.flatMap(TodoLocationTriggerEvent.init(rawValue:))
    }
}
