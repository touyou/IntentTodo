//
//  ListManagementView.swift
//  UI
//
//  Where lists are created, renamed, merged and deleted.
//
//  Every mutation runs through `Button(intent:)`, so Siri, Shortcuts and this screen share
//  one implementation. The confirmations are `.alert` / `.confirmationDialog` rather than
//  `requestConfirmation`: an intent that asks has no surface to be answered on when the
//  caller is an in-app button, and fails silently.
//

#if os(iOS) || os(visionOS) || os(macOS)
import AppIntents
import SwiftUI
import TodoAppIntents

/// Lists, with their todo and section counts, plus the actions that tidy them up.
public struct ListManagementView: View {
    public init() {}

    public var body: some View {
        OrganizeSnapshotReader { snapshot in
            ListManagementContent(snapshot: snapshot)
        }
    }
}

// MARK: - Content

private struct ListManagementContent: View {
    let snapshot: TodoOrganizeSnapshot?

    /// Name typed into the "new list" alert.
    @State private var newListName = ""
    @State private var isAddingList = false

    /// The list a destructive or merging action is aimed at. Doubles as the dialogs' source
    /// of truth, so the row being acted on can't drift from the one named in the message.
    @State private var listPendingDeletion: CategoryAppEntity?
    @State private var listPendingMerge: CategoryAppEntity?

    private var lists: [CategoryAppEntity] { snapshot?.lists ?? [] }

    private var trimmedNewListName: String {
        newListName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label(.copy("No Lists"), systemImage: "folder")
                } description: {
                    Text(.copy("Lists group todos together. Create one, then pick it while adding a todo."))
                } actions: {
                    Button(.copy("Create List"), action: startAddingList)
                        .buttonStyle(.borderedProminent)
                }
            } else {
                listRows
            }
        }
        .navigationTitle(.copy("Lists"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: startAddingList) {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addListButton")
                .accessibilityLabel(.copy("Create List"))
            }
        }
        // An alert rather than a sheet: it closes itself when either button is tapped, so
        // `Button(intent:)` needs no way to dismiss what presented it.
        .alert(Text(.copy("New List")), isPresented: $isAddingList) {
            TextField(.copy("Name"), text: $newListName)
                .accessibilityIdentifier("listNameField")
            Button(intent: CreateListIntent(name: trimmedNewListName)) {
                Text(.copy("Create"))
            }
            .disabled(trimmedNewListName.isEmpty)
            .accessibilityIdentifier("createListButton")
            Button(role: .cancel) {} label: { Text(.copy("Cancel")) }
        } message: {
            Text(.copy("Two lists can’t share a name — typing one that already exists just reuses it."))
        }
        .confirmationDialog(
            Text(.copy("Delete “\(listPendingDeletion?.name ?? "")”?")),
            item: $listPendingDeletion,
            titleVisibility: .visible
        ) { list in
            Button(role: .destructive, intent: DeleteListIntent(list: list)) {
                Text(.copy("Delete List"))
            }
            .accessibilityIdentifier("confirmDeleteListButton")
        } message: { _ in
            Text(.copy("The todos in it are kept and become uncategorized."))
        }
        .confirmationDialog(
            Text(.copy("Merge “\(listPendingMerge?.name ?? "")” into…")),
            item: $listPendingMerge,
            titleVisibility: .visible
        ) { list in
            // `Text` labels only: a confirmation dialog silently omits any action whose
            // label is another kind of view.
            ForEach(lists.filter { $0.id != list.id }, id: \.id) { destination in
                Button(intent: MergeListsIntent(lists: [list], destination: destination)) {
                    Text(destination.name)
                }
            }
        } message: { _ in
            Text(.copy("Its todos move to the list you pick, and the emptied list is deleted."))
        }
    }

    private var listRows: some View {
        List {
            if let snapshot, !snapshot.duplicateNameGroups.isEmpty {
                DuplicateListsSection(groups: snapshot.duplicateNameGroups)
            }

            Section {
                ForEach(lists, id: \.id) { list in
                    NavigationLink {
                        ListDetailView(list: list, snapshot: snapshot)
                    } label: {
                        ListRow(
                            list: list,
                            todoCount: snapshot?.todoCount(inList: list.id) ?? 0,
                            sectionCount: snapshot?.sectionCount(inList: list.id) ?? 0
                        )
                    }
                    .contextMenu {
                        if lists.count > 1 {
                            Button {
                                listPendingMerge = list
                            } label: {
                                Label(.copy("Merge Into…"), systemImage: "arrow.triangle.merge")
                            }
                        }
                        Button(role: .destructive) {
                            listPendingDeletion = list
                        } label: {
                            Label(.copy("Delete List"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            listPendingDeletion = list
                        } label: {
                            Label(.copy("Delete"), systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text(.copy("Deleting a list keeps its todos — they become uncategorized."))
            }

            Section {
                LabeledContent(.copy("Uncategorized")) {
                    Text(.copy("\(snapshot?.todoCount(inList: CategoryAppEntity.uncategorizedID) ?? 0) todos"))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func startAddingList() {
        newListName = ""
        isAddingList = true
    }
}

// MARK: - Row

private struct ListRow: View {
    let list: CategoryAppEntity
    let todoCount: Int
    let sectionCount: Int

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(list.colorHex.flatMap(Color.init(hex:)) ?? Color.gray)
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Each part is localised on its own and joined with `.list`, not concatenated: both the
    /// separator and the order are locale-dependent, and a `+` chain leaves a sentence no
    /// translator can reach.
    ///
    /// The counts are plain keys (`%lld todos`) with the singular / plural forms carried by
    /// the catalog's **`en` localization**, not `^[…](inflect: true)`. A package bundle only
    /// ships the locales the catalog actually lists, so English is served by the key itself —
    /// and a key with inflection markup in it reaches the screen verbatim.
    private var summary: String {
        var parts = [String(localized: .copy("\(todoCount) todos"))]
        if sectionCount > 0 {
            parts.append(String(localized: .copy("\(sectionCount) sections")))
        }
        return parts.formatted(.list(type: .and, width: .narrow))
    }
}

// MARK: - Duplicates

/// Points at the lists whose names differ only in case or diacritics.
///
/// `CreateListIntent` folds a repeated name into the existing list, so new duplicates can't
/// appear — these are the ones that pre-date that rule, and they are exactly what is hard
/// to spot by eye in a long list.
private struct DuplicateListsSection: View {
    let groups: [[CategoryAppEntity]]

    @State private var groupPendingMerge: [CategoryAppEntity]?

    var body: some View {
        Section {
            ForEach(groups, id: \.first?.id) { group in
                Button {
                    groupPendingMerge = group
                } label: {
                    DuplicateGroupRow(group: group)
                }
            }
        } header: {
            Label(.copy("Possible Duplicates"), systemImage: "exclamationmark.triangle")
        } footer: {
            Text(.copy("These names differ only in capitalisation or accents. Tap one to merge them into a single list."))
        }
        .confirmationDialog(
            Text(.copy("Keep which list?")),
            isPresented: Binding { groupPendingMerge != nil } set: { if !$0 { groupPendingMerge = nil } },
            titleVisibility: .visible,
            presenting: groupPendingMerge
        ) { group in
            ForEach(group, id: \.id) { keeper in
                Button(
                    intent: MergeListsIntent(
                        lists: group.filter { $0.id != keeper.id },
                        destination: keeper
                    )
                ) {
                    Text(keeper.name)
                }
            }
        } message: { _ in
            Text(.copy("The todos from the others move into the list you keep."))
        }
    }
}

/// One group of same-looking names: the shared name, and how many lists carry it.
private struct DuplicateGroupRow: View {
    let group: [CategoryAppEntity]

    /// The name is the list's own, so it is verbatim rather than UI copy.
    private var name: String {
        group.first?.name ?? ""
    }

    var body: some View {
        LabeledContent {
            Text(.copy("\(group.count) lists"))
        } label: {
            Text(verbatim: name)
        }
    }
}

// MARK: - Detail

/// Renames and recolours one list, and shows what is filed under it.
///
/// Stays on screen after saving: the save runs `UpdateListIntent`, and `Button(intent:)`
/// reports nothing back that a `dismiss()` could hang off. The fields already show the
/// saved values, so nothing stale is left behind.
private struct ListDetailView: View {
    let list: CategoryAppEntity
    let snapshot: TodoOrganizeSnapshot?

    @State private var name: String
    @State private var colorHex: String?

    /// Presets rather than a continuous colour picker: the value is stored as a hex string
    /// for CloudKit, and a picker would offer precision the row's 12pt dot cannot show.
    private static let palette = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759",
        "#00C7BE", "#007AFF", "#5856D6", "#AF52DE"
    ]

    init(list: CategoryAppEntity, snapshot: TodoOrganizeSnapshot?) {
        self.list = list
        self.snapshot = snapshot
        _name = State(initialValue: list.name)
        _colorHex = State(initialValue: list.colorHex)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasChanges: Bool {
        trimmedName != list.name || colorHex != list.colorHex
    }

    var body: some View {
        Form {
            Section {
                TextField(.copy("Name"), text: $name)
                    .accessibilityIdentifier("listDetailNameField")
                ColorSwatchPicker(selection: $colorHex, palette: Self.palette)
            }

            Section {
                LabeledContent(.copy("Todos")) {
                    Text(.copy("\(snapshot?.todoCount(inList: list.id) ?? 0) todos"))
                }
                LabeledContent(.copy("Sections")) {
                    Text(.copy("\(snapshot?.sectionCount(inList: list.id) ?? 0) sections"))
                }
            } footer: {
                Text(.copy("Sections are added from Shortcuts, or by asking Siri to add one to this list."))
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(list.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(
                    intent: UpdateListIntent(
                        list: list,
                        name: trimmedName,
                        colorHex: colorHex
                    )
                ) {
                    ToolbarActionLabel(text: .copy("Save"), systemImage: "checkmark")
                }
                .disabled(trimmedName.isEmpty || !hasChanges)
                .accessibilityIdentifier("saveListButton")
                .accessibilityLabel(.copy("Save"))
            }
        }
    }
}

/// A row of tappable colour swatches, plus "no colour".
private struct ColorSwatchPicker: View {
    @Binding var selection: String?
    let palette: [String]

    var body: some View {
        LabeledContent(.copy("Color")) {
            HStack(spacing: 10) {
                swatch(hex: nil, color: .gray.opacity(0.3))
                ForEach(palette, id: \.self) { hex in
                    swatch(hex: hex, color: Color(hex: hex) ?? .gray)
                }
            }
        }
    }

    @ViewBuilder
    private func swatch(hex: String?, color: Color) -> some View {
        Button {
            selection = hex
        } label: {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay {
                    if selection == hex {
                        Image(systemName: "checkmark")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hex.map { Text(verbatim: $0) } ?? Text(.copy("No Color")))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ListManagementView()
    }
}
#endif
