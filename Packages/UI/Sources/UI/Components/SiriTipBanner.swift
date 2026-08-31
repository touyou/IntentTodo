//
//  SiriTipBanner.swift
//  UI
//
//  Teaches an App Shortcut phrase right after the matching action.
//

import AppIntents
import SwiftUI
import TodoAppIntents

/// Transient banner telling people what they can say.
///
/// App Shortcuts are discoverable from Spotlight, Siri and Shortcuts, but only get used if
/// someone knows the phrase. `SiriTipView` renders the phrase belonging to the intent it is
/// given, so nothing is hard-coded here — editing `TodoAppShortcuts` is enough.
///
/// Placed in the list's `safeAreaInset` rather than as a row: it should read as temporary,
/// like the sibling banners, and a non-todo row would end up inside the container that
/// `.appEntityIdentifier(forSelectionType:)` and `.reorderable()` operate on.
///
/// When to show it is ``SiriTipModel``'s decision. Not built on macOS, where `SiriTipView`
/// is unavailable.
struct SiriTipBanner: View {
    let model: SiriTipModel

    var body: some View {
        #if os(macOS)
        EmptyView()
        #else
        if model.isPresented {
            SiriTipView(
                intent: AddTodoIntent(),
                // The close button writes `false`, which counts as a dismissal.
                isVisible: Binding(
                    get: { model.isPresented },
                    set: { isVisible in
                        guard !isVisible else { return }
                        model.dismiss()
                    }
                )
            )
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Chrome is left to the system material rather than painted here.
            .background(.bar)
        }
        #endif
    }
}
