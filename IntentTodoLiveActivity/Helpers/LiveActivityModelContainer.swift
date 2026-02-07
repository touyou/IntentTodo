//
//  LiveActivityModelContainer.swift
//  IntentTodoLiveActivity
//
//  Shared ModelContainer for Live Activity extension.
//

import Domain
import SwiftData

/// Shared ModelContainer for Live Activity Extension.
/// Uses SharedModelContainer for data sharing with the main app via App Group.
let liveActivityModelContainer: ModelContainer = {
    // swiftlint:disable:next force_try
    return try! SharedModelContainer.createContainer()
}()
