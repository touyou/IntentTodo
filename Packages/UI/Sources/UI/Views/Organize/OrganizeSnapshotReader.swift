//
//  OrganizeSnapshotReader.swift
//  UI
//
//  Keeps a `TodoOrganizeSnapshot` in step with the store for the screens that organise by
//  list and tag.
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// The signal that a snapshot is stale.
///
/// A `TodoOrganizeSnapshot` has to be *fetched* — reading `TodoItem.tags` off a `@Query`
/// result can trap, because the result still holds a deleted object for one frame — and a
/// fetch publishes nothing SwiftUI can observe. So the change signal is built from the
/// `@Query` results instead, out of **scalar fields only**, which stay readable even for
/// that deleted object.
enum TodoStoreDigest {
    /// A value that changes whenever anything the snapshot reports could have changed.
    ///
    /// - todo count: catches additions and deletions
    /// - latest `modifiedAt`: catches edits, including tag edits, and an
    ///   add-plus-delete that leaves the count where it was
    /// - list names and colours: catches list edits, which touch no todo at all
    static func make(todos: [TodoItem], categories: [Domain.Category]) -> String {
        let latest = todos.map(\.modifiedAt).max()?.timeIntervalSinceReferenceDate ?? 0
        let lists = categories
            .map { "\($0.id.uuidString)#\($0.name)#\($0.colorHex ?? "")" }
            .joined(separator: ",")
        return "\(todos.count)|\(latest)|\(lists)"
    }
}

/// Loads a `TodoOrganizeSnapshot` and hands it to `content`, reloading when the store moves.
///
/// `nil` until the first read finishes, so a screen can tell "empty" from "not read yet".
struct OrganizeSnapshotReader<Content: View>: View {
    @Query(sort: \TodoItem.createdAt, order: .reverse) private var todos: [TodoItem]
    @Query(sort: \Domain.Category.name) private var categories: [Domain.Category]
    @Environment(\.modelContext) private var modelContext

    @State private var snapshot: TodoOrganizeSnapshot?

    private let content: (TodoOrganizeSnapshot?) -> Content

    init(@ViewBuilder content: @escaping (TodoOrganizeSnapshot?) -> Content) {
        self.content = content
    }

    var body: some View {
        content(snapshot)
            .task(id: TodoStoreDigest.make(todos: todos, categories: categories)) {
                // `modelContext.container` is the app's shared container, so the read sees
                // whatever the intents have just written.
                let service = TodoService.swiftDataBacked(container: modelContext.container)
                snapshot = (try? service.organizeSnapshot()) ?? .empty
            }
    }
}
