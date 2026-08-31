//
//  SiriTipModel.swift
//  UI
//
//  Owns only the question of *when* to show the Siri tip.
//

import Foundation
import Observation

/// Presentation policy for `SiriTipView`.
///
/// Apple asks for tips to appear at a chosen moment rather than permanently: "carefully
/// select moments within your app to surface these tips, at a time when people are likely
/// to benefit from the education, such as immediately before or after completing an action
/// that they may want to repeat" [Apple: wwdc2022-10169 18:58], "Siri Tips are best placed
/// contextually" [Apple: wwdc2023-10102 11:14]. Here that moment is just after adding a
/// todo from the app's own sheet.
///
/// Three rules: start at the `presentationThreshold`-th in-app add, show it at most
/// `maxPresentations` times, and never again once it has been dismissed.
///
@MainActor
@Observable
public final class SiriTipModel {
    // MARK: - Policy

    /// Which in-app add first shows the tip.
    private static let presentationThreshold = 3

    /// Total presentations allowed.
    private static let maxPresentations = 2

    // MARK: - Storage keys

    private enum Key {
        static let addCount = "siriTip.addTodo.inAppAddCount"
        static let presentationCount = "siriTip.addTodo.presentationCount"
        static let isDismissed = "siriTip.addTodo.isDismissed"
        /// Key from when the tip was permanent (`false` meaning dismissed).
        static let legacyIsVisible = "siriTip.addTodo.isVisible"
    }

    // MARK: - State

    /// The only thing the view reads.
    public private(set) var isPresented = false

    private let defaults: UserDefaults

    /// Injectable for tests; defaults to `UserDefaults.standard`.
    ///
    /// App-local rather than the App Group: whether this person has already been taught is
    /// app-UI state, and no extension needs it.
    public init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? .standard
    }

    // MARK: - Events

    /// Reports an addition made from the app's UI, driven by changes to
    /// `NavigationModel.inAppAddCount`. The count persists, so the threshold can be reached
    /// across launches.
    public func recordInAppAdd() {
        guard !isFinished else { return }

        let count = defaults.integer(forKey: Key.addCount) + 1
        defaults.set(count, forKey: Key.addCount)

        // Adding another todo while the tip is up means it has served its purpose: hide it
        // without spending another presentation.
        if isPresented {
            isPresented = false
            return
        }

        guard count >= Self.presentationThreshold else { return }
        defaults.set(defaults.integer(forKey: Key.presentationCount) + 1, forKey: Key.presentationCount)
        isPresented = true
    }

    /// Dismissed by the person; never shown again.
    public func dismiss() {
        isPresented = false
        defaults.set(true, forKey: Key.isDismissed)
    }

    /// Hides without counting as a dismissal, so a later add can show it again.
    public func hide() {
        isPresented = false
    }

    // MARK: - Private

    /// Whether the tip is retired for good.
    private var isFinished: Bool {
        if defaults.bool(forKey: Key.isDismissed) { return true }
        // Anyone who dismissed the permanent version is not taught again. The old key
        // tracked "not yet dismissed", so `false` means dismissed.
        if defaults.object(forKey: Key.legacyIsVisible) != nil,
           !defaults.bool(forKey: Key.legacyIsVisible) {
            return true
        }
        return defaults.integer(forKey: Key.presentationCount) >= Self.maxPresentations
    }
}
