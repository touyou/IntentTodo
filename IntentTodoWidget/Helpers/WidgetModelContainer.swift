//
//  WidgetModelContainer.swift
//  IntentTodoWidget
//
//  Shared ModelContainer for all widgets in this extension.
//

import Domain
import SwiftData

// MARK: - Shared Model Container

/// Shared ModelContainer for Widget Extension.
/// Uses SharedModelContainer for data sharing with the main app via App Group.
let sharedWidgetModelContainer: ModelContainer = {
    // swiftlint:disable:next force_try
    return try! SharedModelContainer.createContainer()
}()
