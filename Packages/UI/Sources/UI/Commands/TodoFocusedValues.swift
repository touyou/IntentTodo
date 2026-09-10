//
//  TodoFocusedValues.swift
//  UI
//
//  What the menu bar commands need from whichever window is in front.
//

#if os(macOS)
import SwiftUI
import TodoAppIntents

private struct SelectedTodoKey: FocusedValueKey {
    typealias Value = TodoAppEntity
}

private struct TodoDeletionRequestKey: FocusedValueKey {
    typealias Value = Binding<TodoAppEntity?>
}

private struct TodoSearchFieldFocusKey: FocusedValueKey {
    typealias Value = Binding<Bool>
}

extension FocusedValues {
    /// The todo the front window has selected, or `nil` when nothing is selected.
    ///
    /// A focused value rather than a captured one: the menu is rebuilt whenever this
    /// changes, so an item can never run its intent against a stale selection.
    var selectedTodo: TodoAppEntity? {
        get { self[SelectedTodoKey.self] }
        set { self[SelectedTodoKey.self] = newValue }
    }

    /// Setting this asks the list to confirm deleting the todo.
    var todoDeletionRequest: Binding<TodoAppEntity?>? {
        get { self[TodoDeletionRequestKey.self] }
        set { self[TodoDeletionRequestKey.self] = newValue }
    }

    /// Setting this to `true` puts the caret in the list's search field.
    var todoSearchFieldFocus: Binding<Bool>? {
        get { self[TodoSearchFieldFocusKey.self] }
        set { self[TodoSearchFieldFocusKey.self] = newValue }
    }
}
#endif
