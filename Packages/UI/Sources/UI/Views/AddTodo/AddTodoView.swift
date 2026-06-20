//
//  AddTodoView.swift
//  IntentTodo
//

import SwiftUI
import AppIntents
import Foundation
import GeoToolbox
import TodoAppIntents

/// A view for adding a new todo item.
///
/// This view collects todo details and creates the todo via AddTodoIntent.
/// Uses `Button(intent:)` with a computed property for dynamic intent generation.
public struct AddTodoView: View {
    // MARK: - Properties

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var todoDescription = ""
    @State private var dueDate = Date()
    @State private var hasDueDate = false
    @State private var isFavorite = false

    // WWDC 2026 で AddTodoIntent / TodoItem に追加した属性の入力。
    @State private var assignee = ""
    @State private var location = ""
    @State private var hasEstimatedDuration = false
    @State private var estimatedDurationMinutes = 30

    /// 所要時間の選択肢 (分)。
    private static let durationOptions = [15, 30, 45, 60, 90, 120, 180, 240]

    // MARK: - Computed Intent

    /// Dynamically generated intent based on current form state.
    ///
    /// 所要時間 / 担当者 / 場所は、AddTodoIntent が受け取る App Intents ネイティブ型
    /// (`Duration` / `PersonNameComponents` / `PlaceDescriptor`) へ橋渡しして渡す。
    private var addTodoIntent: AddTodoIntent {
        AddTodoIntent(
            title: title,
            todoDescription: todoDescription.isEmpty ? nil : todoDescription,
            dueDate: hasDueDate ? dueDate : nil,
            isFavorite: isFavorite,
            estimatedDuration: hasEstimatedDuration
                ? .seconds(estimatedDurationMinutes * 60)
                : nil,
            assignee: assigneeComponents,
            location: locationDescriptor
        )
    }

    private var trimmedAssignee: String {
        assignee.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var assigneeComponents: PersonNameComponents? {
        guard !trimmedAssignee.isEmpty else { return nil }
        return PersonNameComponentsFormatter().personNameComponents(from: trimmedAssignee)
    }

    private var locationDescriptor: PlaceDescriptor? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return PlaceDescriptor(representations: [.address(trimmed)], commonName: trimmed)
    }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 分単位の所要時間を "30m" / "1h 30m" 形式へ整形する。
    private static func durationLabel(minutes: Int) -> String {
        Duration.seconds(minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    // MARK: - Initialization

    public init() {}

    // MARK: - Body

    public var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                    .accessibilityIdentifier("todoTitleField")
                #if os(iOS)
                    .textInputAutocapitalization(.sentences)
                #endif

                TextField("Description (optional)", text: $todoDescription, axis: .vertical)
                    .accessibilityIdentifier("todoDescriptionField")
                    .lineLimit(3...6)
            }

            Section {
                Toggle("Set Due Date", isOn: $hasDueDate.animation())
                    .accessibilityIdentifier("dueDateToggle")

                if hasDueDate {
                    DatePicker(
                        "Date",
                        selection: $dueDate,
                        displayedComponents: [.date]
                    )
                    .accessibilityIdentifier("dueDatePicker")

                    DatePicker(
                        "Time",
                        selection: $dueDate,
                        displayedComponents: [.hourAndMinute]
                    )
                    .accessibilityIdentifier("dueTimePicker")
                }

                Toggle("Mark as Favorite", isOn: $isFavorite)
                    .accessibilityIdentifier("favoriteToggle")
            }

            Section("Details") {
                Toggle("Set Estimated Duration", isOn: $hasEstimatedDuration.animation())
                    .accessibilityIdentifier("estimatedDurationToggle")

                if hasEstimatedDuration {
                    Picker("Duration", selection: $estimatedDurationMinutes) {
                        ForEach(Self.durationOptions, id: \.self) { minutes in
                            Text(Self.durationLabel(minutes: minutes)).tag(minutes)
                        }
                    }
                    .accessibilityIdentifier("estimatedDurationPicker")
                }

                TextField("Assignee (optional)", text: $assignee)
                    .accessibilityIdentifier("assigneeField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif

                TextField("Location (optional)", text: $location)
                    .accessibilityIdentifier("locationField")
                #if os(iOS)
                    .textInputAutocapitalization(.words)
                #endif
            }
        }
        #if os(macOS)
        // macOS の Form デフォルト (.automatic) は背景無し・横端密着で窮屈なので
        // grouped にして iOS と同じインセット付きカード見た目に揃える。
        .formStyle(.grouped)
        #endif
        .navigationTitle("New Todo")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
                .accessibilityIdentifier("cancelButton")
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(intent: addTodoIntent) {
                    Text("Add")
                }
                .accessibilityIdentifier("addButton")
                .disabled(!isValid)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AddTodoView()
    }
}
