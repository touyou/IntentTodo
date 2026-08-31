//
//  TodoListMenus.swift
//  UI
//
//  Shared `Picker` contents for filtering and sorting. Only the pickers live here; wrapping
//  them in a `Menu` is left to the caller, so iOS can combine both into one menu while
//  visionOS keeps them side by side.
//

import SwiftUI

/// Filter picker, intended as the contents of a `Menu`.
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

/// Sort picker, intended as the contents of a `Menu`.
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
