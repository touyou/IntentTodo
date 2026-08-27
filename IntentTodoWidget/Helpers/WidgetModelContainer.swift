//
//  WidgetModelContainer.swift
//  IntentTodoWidget
//
//  Shared ModelContainer for all widgets in this extension.
//

import Domain
import Foundation
import os.log
import SwiftData

private let logger = Logger(subsystem: "dev.touyou.IntentTodo", category: "WidgetModelContainer")

// MARK: - Shared Model Container

/// Shared ModelContainer for Widget Extension.
/// Uses SharedModelContainer for data sharing with the main app via App Group.
///
/// A container this target cannot open leaves every widget and control in the
/// extension without data, so there is nothing useful to fall back to and
/// `fatalError` stays the outcome. What changes versus `try!` is that the reason
/// reaches the log first: a trap carries no message, and an extension crash only
/// shows up as a blank widget. Same shape as `IntentTodoApp.init()`.
let sharedWidgetModelContainer: ModelContainer = {
    do {
        return try SharedModelContainer.createContainer()
    } catch {
        logger.critical("Widget ModelContainer init failed: \(String(reflecting: error))")
        let nsError = error as NSError
        logger.critical("NSError domain=\(nsError.domain) code=\(nsError.code)")
        logger.critical("NSError userInfo=\(nsError.userInfo)")
        fatalError("Could not create ModelContainer for the widget extension: \(String(reflecting: error))")
    }
}()
