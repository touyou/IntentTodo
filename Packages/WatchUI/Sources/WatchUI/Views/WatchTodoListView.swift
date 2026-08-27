//
//  WatchTodoListView.swift
//  WatchUI
//

import Domain
import SwiftData
import SwiftUI
import TodoAppIntents

/// Main list view showing incomplete todos on watchOS.
public struct WatchTodoListView: View {
    @Query(
        filter: #Predicate<TodoItem> { !$0.isCompleted },
        sort: [
            SortDescriptor(\TodoItem.dueDate),
            SortDescriptor(\TodoItem.createdAt, order: .reverse)
        ]
    )
    private var incompleteTodos: [TodoItem]

    /// Intent が書き込むナビゲーション状態。iOS と同じ `NavigationModel` を共有する
    /// ので、`OpenTodoIntent`（Siri / Spotlight の「この Todo を開く」）と
    /// `LaunchAppIntent(.addTodo)` が watch でもそのまま効く。
    @Environment(NavigationModel.self) private var navigationModel

    public init() {}

    public var body: some View {
        @Bindable var navigationModel = navigationModel
        // path を NavigationModel に預ける（iOS の NavigationSplitView + selectedTodo に
        // 対する、watch のスタック版）。`NavigationModel.showDetail(for:)` が path に
        // 積むので、Intent 経由の遷移もここに流れ込む。
        NavigationStack(path: $navigationModel.path) {
            Group {
                if incompleteTodos.isEmpty {
                    emptyView
                } else {
                    todoList
                }
            }
            .navigationTitle(.copy("Todos"))
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .todoDetail(let todo):
                    WatchTodoDetailView(todo: todo)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationModel.showAddTodo()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addTodoButton")
                    .accessibilityLabel(.copy("Add todo"))
                }
            }
            // 追加はシートで出す。`AddTodoIntent` の完了時に
            // `navigationModel.dismissAddTodo()` が呼ばれて閉じるため、
            // 「Intent 完了 = シートが閉じる」が iOS と同じ 1 対 1 対応になる。
            .sheet(isPresented: $navigationModel.showingAddTodo) {
                WatchAddTodoView()
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)

            Text(.copy("All Done!"))
                .font(.headline)

            Text(.copy("No incomplete todos"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var todoList: some View {
        // 旧実装は `incompleteTodos.filter { isDueSoon($0) }` と
        // `incompleteTodos.filter { !isDueSoon($0) }` で同じ配列を 2 周し、
        // さらに `isDueSoon` の中で `Date()` を都度生成していた。watchOS は
        // CPU が弱いので 1 周の partition + Date() 1 回に圧縮する。
        let now = Date()
        let oneHourFromNow = now.addingTimeInterval(3600)
        var dueSoon: [TodoItem] = []
        var others: [TodoItem] = []
        for todo in incompleteTodos {
            if let dueDate = todo.dueDate, dueDate > now, dueDate <= oneHourFromNow {
                dueSoon.append(todo)
            } else {
                others.append(todo)
            }
        }

        return List {
            if !dueSoon.isEmpty {
                Section(.copy("Due Soon")) {
                    ForEach(dueSoon) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }
            if !others.isEmpty {
                Section(.copy("Upcoming")) {
                    ForEach(others.prefix(10)) { todo in
                        WatchTodoRow(todo: todo)
                    }
                }
            }
        }
    }
}
