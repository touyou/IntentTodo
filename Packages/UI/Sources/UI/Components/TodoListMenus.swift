//
//  TodoListMenus.swift
//  UI
//
//  Shared `Picker` contents for filtering and sorting. Only the pickers live here; wrapping
//  them in a `Menu` is left to the caller, so iOS can combine both into one menu while
//  visionOS keeps them side by side.
//

import SwiftUI
import TodoAppIntents

/// Filter picker, intended as the contents of a `Menu`.
public struct FilterPicker: View {
    @Binding private var selection: TodoFilter

    public init(selection: Binding<TodoFilter>) {
        self._selection = selection
    }

    public var body: some View {
        Picker(.copy("Filter"), selection: $selection.onUserSet(UIActionDonation.showList)) {
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

/// Narrows the list to one list, intended as the contents of a `Menu`.
///
/// "Uncategorized" is its own choice rather than folded into "All Lists": todos that were
/// never filed are the ones worth finding, and there is no stored list to pick for them.
public struct ListFilterPicker: View {
    @Binding private var selection: TodoListFilter
    private let lists: [CategoryAppEntity]

    public init(selection: Binding<TodoListFilter>, lists: [CategoryAppEntity]) {
        self._selection = selection
        self.lists = lists
    }

    public var body: some View {
        Picker(.copy("List"), selection: $selection) {
            Text(.copy("All Lists")).tag(TodoListFilter.all)
            Text(.copy("Uncategorized")).tag(TodoListFilter.uncategorized)
            ForEach(lists, id: \.id) { list in
                Text(list.name).tag(TodoListFilter.list(id: list.id))
            }
        }
    }
}

/// Narrows the list to one tag, intended as the contents of a `Menu`.
public struct TagFilterPicker: View {
    @Binding private var selection: String?
    private let tags: [String]

    public init(selection: Binding<String?>, tags: [String]) {
        self._selection = selection
        self.tags = tags
    }

    public var body: some View {
        Picker(.copy("Tag"), selection: $selection) {
            Text(.copy("All Tags")).tag(String?.none)
            ForEach(tags, id: \.self) { tag in
                Text(tag).tag(String?.some(tag))
            }
        }
    }
}
