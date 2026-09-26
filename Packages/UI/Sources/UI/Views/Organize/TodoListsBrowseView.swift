//
//  TodoListsBrowseView.swift
//  UI
//
//  Browsing by list, from the todo list itself.
//
//  Deliberately separate from `ListManagementView`: **this screen picks what you are looking
//  at, that one edits what exists.** Renaming a list is a settings-shaped job you do rarely;
//  switching to a list is part of reading your todos. Folding both into one screen made the
//  destructive actions sit in the path of ordinary browsing.
//

#if os(iOS) || os(visionOS) || os(macOS)
import SwiftUI
import TodoAppIntents

/// Picks the list the todo list is narrowed to.
struct TodoListsBrowseView: View {
    @Binding var selection: TodoListFilter

    var body: some View {
        OrganizeSnapshotReader { snapshot in
            TodoListsBrowseContent(selection: $selection, snapshot: snapshot)
        }
    }
}

// MARK: - Content

private struct TodoListsBrowseContent: View {
    @Binding var selection: TodoListFilter
    let snapshot: TodoOrganizeSnapshot?

    @Environment(\.dismiss) private var dismiss

    private var lists: [CategoryAppEntity] { snapshot?.lists ?? [] }

    /// Todos in no list at all. Hidden when there are none, so the row does not advertise an
    /// empty destination.
    private var uncategorizedCount: Int {
        snapshot?.todoCount(inList: CategoryAppEntity.uncategorizedID) ?? 0
    }

    private var totalCount: Int {
        snapshot?.todoIDsByListID.values.reduce(0) { $0 + $1.count } ?? 0
    }

    var body: some View {
        List {
            Section {
                row(
                    filter: .all,
                    title: Text(.copy("All Todos")),
                    systemImage: "tray.full",
                    tint: .accentColor,
                    count: totalCount
                )
                if uncategorizedCount > 0 {
                    row(
                        filter: .uncategorized,
                        title: Text(.copy("Uncategorized")),
                        systemImage: "tray",
                        tint: .gray,
                        count: uncategorizedCount
                    )
                }
            }

            if !lists.isEmpty {
                Section {
                    ForEach(lists, id: \.id) { list in
                        row(
                            filter: .list(id: list.id),
                            title: Text(list.name),
                            systemImage: "folder.fill",
                            tint: list.colorHex.flatMap(Color.init(hex:)) ?? .gray,
                            count: snapshot?.todoCount(inList: list.id) ?? 0
                        )
                    }
                } header: {
                    Text(.copy("My Lists"))
                }
            }
        }
        .accessibilityIdentifier("listsBrowseView")
        .navigationTitle(.copy("Lists"))
        #if os(iOS) || os(visionOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .overlay {
            if lists.isEmpty {
                ContentUnavailableView {
                    Label(.copy("No Lists"), systemImage: "folder")
                } description: {
                    Text(.copy("Create a list in Settings, then file todos under it."))
                }
                // Behind the two fixed rows there is still a usable screen, so the empty
                // state only covers the area the lists would have filled.
                .background(.background)
            }
        }
    }

    /// One destination. Picking it narrows the list and returns, so the result is visible
    /// immediately rather than behind a Done button.
    private func row(
        filter: TodoListFilter,
        title: Text,
        systemImage: String,
        tint: Color,
        count: Int
    ) -> some View {
        Button {
            selection = filter
            dismiss()
        } label: {
            LabeledContent {
                HStack(spacing: 8) {
                    Text(count, format: .number)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    if selection == filter {
                        Image(systemName: "checkmark")
                            .font(.footnote.bold())
                            .foregroundStyle(.tint)
                    }
                }
            } label: {
                Label {
                    title
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(tint)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TodoListsBrowseView(selection: .constant(.all))
    }
}
#endif
