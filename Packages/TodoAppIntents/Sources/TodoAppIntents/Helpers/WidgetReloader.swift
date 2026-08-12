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
    /// ホームウィジェットとコントロールは**別の API**で、`WidgetCenter` だけでは
    /// コントロールは更新されない。システムが自動でリロードするのは
    /// 「その Intent を実行したコントロール自身」だけなので、他のコントロール
    /// （例: トグルで完了 → 未完了数のコントロール）は明示的に更新する必要がある。
    public static func reloadAllWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        // ControlCenter は visionOS では unavailable。
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
