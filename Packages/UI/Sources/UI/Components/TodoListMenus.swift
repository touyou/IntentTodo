//
//  TodoListMenus.swift
//  UI
//
//  Filter / Sort 用の `Picker` を共通化したコンポーネント。iOS の
//  combined Menu (Filter + Sort 統合) と visionOS の独立 Menu (Filter / Sort
//  並列) で同じ Picker 中身が二重実装されていた問題を解消する。
//
//  Picker のみ切り出して `Menu { … }` でのラップは呼出側に任せることで、
//  両プラットフォームの UX (combined vs 並列) は維持したまま中身だけ共通化。
//

import SwiftUI

/// Todo フィルタ用 Picker (Menu の中身として使う想定)。
/// `TodoFilter` / `TodoSortOrder` は同 UI パッケージ内 (`TodoListViewModel.swift`) で定義。
public struct FilterPicker: View {
    @Binding private var selection: TodoFilter

    public init(selection: Binding<TodoFilter>) {
        self._selection = selection
    }

    public var body: some View {
        Picker(.copy("Filter"), selection: $selection) {
            ForEach(TodoFilter.allCases) { filter in
                Label(filter.displayName, systemImage: filter.systemImage)
                    .tag(filter)
            }
        }
    }
}

/// Todo ソート用 Picker (Menu の中身として使う想定)。
public struct SortPicker: View {
    @Binding private var selection: TodoSortOrder

    public init(selection: Binding<TodoSortOrder>) {
        self._selection = selection
    }

    public var body: some View {
        Picker(.copy("Sort"), selection: $selection) {
            ForEach(TodoSortOrder.allCases) { order in
                Text(order.displayName).tag(order)
            }
        }
    }
}
