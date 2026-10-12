//
//  ToolbarMenus.swift
//  IntentTodoUITest
//

import XCTest

/// Reaches the list's options menu and the detail screen's More menu.
///
/// On iOS both are the system overflow menu, which the app does not label: the button
/// carries a system identifier, and the rows inside keep their title and symbol but not
/// their accessibility identifier. Elsewhere they are the app's own menus, with identifiers.
extension XCUIApplication {
    enum ToolbarMenu {
        case listOptions
        case detailMore

        fileprivate var identifier: String {
            switch self {
            case .listOptions: "filterSortMenu"
            case .detailMore: "todoDetailMoreMenu"
            }
        }
    }

    func toolbarMenu(_ menu: ToolbarMenu) -> XCUIElement {
        #if os(iOS)
        // `OverflowBarButtonItem` in a horizontal bar, `BottomOverflowBarButtonItem` in
        // iPhone Duo's vertical one.
        let overflow = buttons.matching(NSPredicate(format: "identifier ENDSWITH 'OverflowBarButtonItem'"))
        switch menu {
        case .listOptions:
            return overflow.firstMatch
        case .detailMore:
            // In a split view both columns have one, and the list column comes first.
            return overflow.element(boundBy: max(overflow.count - 1, 0))
        }
        #else
        return buttons[menu.identifier]
        #endif
    }

    /// A row of an open toolbar menu.
    ///
    /// Matched by symbol on iOS rather than by title, so it resolves in every language.
    func toolbarMenuRow(_ identifier: String, symbol: String) -> XCUIElement {
        #if os(iOS)
        buttons.containing(.image, identifier: symbol).firstMatch
        #else
        buttons[identifier]
        #endif
    }
}
