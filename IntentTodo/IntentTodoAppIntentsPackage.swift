//
//  IntentTodoAppIntentsPackage.swift
//  IntentTodo
//
//  Every target that consumes the shared package declares its own `AppIntentsPackage` with
//  `includedPackages`: "You must register each target as an App Intents Package to ensure
//  proper indexing and validation." [Apple: wwdc2025-244 23:29–24:00]
//

import AppIntents
import TodoAppIntents

struct IntentTodoAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [TodoIntentsPackage.self]
    }
}
