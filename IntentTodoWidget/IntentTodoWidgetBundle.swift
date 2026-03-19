//
//  IntentTodoWidgetBundle.swift
//  IntentTodoWidget
//
//  Created by 藤井陽介 on 2026/01/30.
//

import SwiftUI
import WidgetKit

@main
struct IntentTodoWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home screen widgets
        IntentTodoWidget()

        // Control Center widgets (iOS 18+)
        if #available(iOS 18.0, *) {
            QuickAddTodoControl()
            TodoCountControl()
            ToggleUrgentTodoControl()
        }
    }
}
