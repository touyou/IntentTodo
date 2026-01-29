//
//  AppIntentsExtension.swift
//  IntentTodo
//
//  Created by 藤井陽介 on 2026/01/30.
//

import AppIntents
import TodoAppIntents

/// Integrates the TodoAppIntents package with the main app.
///
/// This allows all App Intents defined in the package to be
/// recognized by the system (Siri, Shortcuts, Spotlight).
struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
