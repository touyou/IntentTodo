//
//  WidgetReloader.swift
//  TodoAppIntents
//
//  Helper for reloading widgets when data changes.
//

import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// Helper for reloading widgets after data changes.
public enum WidgetReloader {
    /// Reloads all widget timelines.
    ///
    /// Call this after any data modification (create, update, delete)
    /// to ensure widgets display the latest data.
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    /// Reloads a specific widget kind.
    /// - Parameter kind: The widget kind identifier.
    public static func reloadWidget(kind: String) {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        #endif
    }
}
