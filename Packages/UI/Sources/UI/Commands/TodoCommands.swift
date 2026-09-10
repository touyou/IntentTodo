//
//  TodoCommands.swift
//  UI
//
//  Menu bar entries and their keyboard shortcuts for the Mac app.
//

#if os(macOS)
import AppIntents
import SwiftUI
import TodoAppIntents

/// The Mac app's menu bar commands.
///
/// Every action a menu item performs is the App Intent the equivalent on-screen control
/// runs — `Button(intent:)` here too, so the menu goes through the same dispatch as
/// Siri and Shortcuts. Items that only present something (the add sheet, the editor,
/// the delete confirmation) call `NavigationModel`, exactly as the toolbar buttons do.
public struct TodoCommands: Commands {
    // MARK: - Properties

    @FocusedValue(\.selectedTodo) private var selectedTodo
    @FocusedValue(\.todoDeletionRequest) private var deletionRequest
    @FocusedValue(\.todoSearchFieldFocus) private var searchFieldFocus

    private let navigationModel: NavigationModel

    // MARK: - Initialization

    /// - Parameter navigationModel: The same instance the scene puts in the
    ///   environment and `App.init()` registers with `AppDependencyManager`.
    public init(navigationModel: NavigationModel) {
        self.navigationModel = navigationModel
    }

    // MARK: - Body

    public var body: some Commands {
        // The app has no documents, so the New slot belongs to the add sheet.
        CommandGroup(replacing: .newItem) {
            Button(.copy("New Todo")) {
                navigationModel.showAddTodo()
            }
            .keyboardShortcut("n")
        }

        // View ▸ Show/Hide Sidebar. The toolbar button and this item move the same
        // split view, so the two never disagree.
        SidebarCommands()

        CommandGroup(after: .textEditing) {
            Button(.copy("Find")) {
                searchFieldFocus?.wrappedValue = true
            }
            .keyboardShortcut("f")
            .disabled(searchFieldFocus == nil)
        }

        CommandMenu(String(localized: .copy("Todo"))) {
            completionItem
            favoriteItem

            Divider()

            Button(.copy("Edit Details")) {
                navigationModel.showAttributeEditor()
            }
            .keyboardShortcut("e")
            .disabled(selectedTodo == nil)

            // Confirmed by the list before anything is deleted; see `TodoListView`.
            Button(.copy("Delete Todo")) {
                deletionRequest?.wrappedValue = selectedTodo
            }
            .keyboardShortcut(.delete)
            .disabled(selectedTodo == nil || deletionRequest == nil)
        }
    }

    // MARK: - Private Views

    /// Both branches carry the shortcut so it stays listed — and reserved — while
    /// nothing is selected.
    @ViewBuilder
    private var completionItem: some View {
        if let selectedTodo {
            Button(intent: ToggleTodoCompletionIntent(todo: selectedTodo)) {
                Text(selectedTodo.isCompleted ? .copy("Mark as Not Completed") : .copy("Mark as Completed"))
            }
            .keyboardShortcut(.return)
        } else {
            Button(.copy("Mark as Completed")) {}
                .keyboardShortcut(.return)
                .disabled(true)
        }
    }

    @ViewBuilder
    private var favoriteItem: some View {
        if let selectedTodo {
            Button(intent: ToggleFavoriteIntent(todo: selectedTodo)) {
                Text(selectedTodo.isFavorite ? .copy("Remove from Favorites") : .copy("Add to Favorites"))
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
        } else {
            Button(.copy("Add to Favorites")) {}
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(true)
        }
    }
}
#endif
