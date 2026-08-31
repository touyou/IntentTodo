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
    /// Reloads all widget timelines and Control Center controls.
    ///
    /// Call this after any data modification (create, update, delete)
    /// to ensure widgets display the latest data.
    ///
    /// Home widgets and controls are **separate APIs**: `WidgetCenter` alone leaves
    /// controls stale. The system only reloads the one control that ran the intent, so any
    /// other control — a count next to a toggle, say — has to be reloaded explicitly.
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        // ControlCenter is unavailable on visionOS.
        #if !os(visionOS)
        ControlCenter.shared.reloadAllControls()
        #endif
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
