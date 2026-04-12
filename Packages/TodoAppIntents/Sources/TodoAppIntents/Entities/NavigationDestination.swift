//
//  NavigationDestination.swift
//  TodoAppIntents
//
//  Navigation destinations shared between Intents and UI.
//  Lives in TodoAppIntents so NavigationModel (used via @Dependency) can reference it.
//

import Foundation

/// Navigation destinations for the app's NavigationStack.
public enum NavigationDestination: Hashable, Sendable {
    case todoDetail(TodoAppEntity)
}
