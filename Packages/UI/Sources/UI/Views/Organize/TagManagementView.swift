//
//  TagManagementView.swift
//  UI
//
//  Where tags are renamed and removed.
//
//  There is no "create tag": a tag exists because a todo carries it, so the add sheet's tag
//  field is the only place one can be brought into being. What was missing is everything
//  afterwards — a tag typed twice with different capitalisation had nowhere to be fixed.
//

#if os(iOS) || os(visionOS) || os(macOS)
import AppIntents
import SwiftUI
import TodoAppIntents

/// Tags in use, with how many todos carry each, plus rename and delete.
public struct TagManagementView: View {
    public init() {}

    public var body: some View {
        OrganizeSnapshotReader { snapshot in
            TagManagementContent(snapshot: snapshot)
        }
    }
}

// MARK: - Content

private struct TagManagementContent: View {
    let snapshot: TodoOrganizeSnapshot?

    /// The tag being renamed, and the name being typed for it.
    @State private var tagPendingRename: String?
    @State private var renamedTag = ""

    @State private var tagPendingDeletion: String?

    private var tags: [String] { snapshot?.tags ?? [] }

    private var trimmedRenamedTag: String {
        renamedTag.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if tags.isEmpty {
                ContentUnavailableView {
                    Label(.copy("No Tags"), systemImage: "number")
                } description: {
                    Text(.copy("Tags come from the Tags field on a todo. Add one there and it shows up here."))
                }
            } else {
                tagRows
            }
        }
        .navigationTitle(.copy("Tags"))
        .alert(
            Text(.copy("Rename “\(tagPendingRename ?? "")”")),
            isPresented: Binding { tagPendingRename != nil } set: { if !$0 { tagPendingRename = nil } }
        ) {
            TextField(.copy("Tag"), text: $renamedTag)
                .accessibilityIdentifier("tagNameField")
            Button(intent: RenameTagIntent(tag: tagPendingRename ?? "", newName: trimmedRenamedTag)) {
                Text(.copy("Rename"))
            }
            .disabled(trimmedRenamedTag.isEmpty)
            .accessibilityIdentifier("renameTagButton")
            Button(role: .cancel) {} label: { Text(.copy("Cancel")) }
        } message: {
            Text(.copy("Renaming onto a tag that already exists merges the two."))
        }
        .confirmationDialog(
            Text(.copy("Delete the tag “\(tagPendingDeletion ?? "")”?")),
            item: $tagPendingDeletion,
            titleVisibility: .visible
        ) { tag in
            Button(role: .destructive, intent: DeleteTagIntent(tag: tag)) {
                Text(.copy("Delete Tag"))
            }
            .accessibilityIdentifier("confirmDeleteTagButton")
        } message: { _ in
            Text(.copy("The todos are kept — only the tag is removed from them."))
        }
    }

    private var tagRows: some View {
        List {
            Section {
                ForEach(tags, id: \.self) { tag in
                    Button {
                        startRenaming(tag)
                    } label: {
                        LabeledContent {
                            Text(.copy("^[\(snapshot?.todoCount(withTag: tag) ?? 0) todo](inflect: true)"))
                        } label: {
                            Label(tag, systemImage: "number")
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            startRenaming(tag)
                        } label: {
                            Label(.copy("Rename Tag"), systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            tagPendingDeletion = tag
                        } label: {
                            Label(.copy("Delete Tag"), systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            tagPendingDeletion = tag
                        } label: {
                            Label(.copy("Delete"), systemImage: "trash")
                        }
                    }
                }
            } footer: {
                Text(.copy("Tap a tag to rename it everywhere. To see the todos carrying one, filter the list by tag."))
            }
        }
    }

    private func startRenaming(_ tag: String) {
        renamedTag = tag
        tagPendingRename = tag
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        TagManagementView()
    }
}
#endif
