//
//  IntentTodoWatchAppAppIntentsPackage.swift
//  IntentTodoWatchApp
//
//  Every target consuming the shared package declares its own `AppIntentsPackage`.
//  [Apple: wwdc2025-244 23:29–24:00]
//

import AppIntents
import TodoAppIntents

struct IntentTodoWatchAppAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
