//
//  MissedFeedback.swift
//  TodoAppIntents
//
//  Records feedback that could not be delivered, so the app can point at Settings.
//

import Domain
import Foundation

/// Notes that feedback could not be delivered because the channel is disabled in Settings.
///
/// A control or widget shows neither dialogs nor snippets, so a local notification is the
/// *only* way a failed intent can report itself. With notifications denied that path dies
/// silently and the control simply redraws its old state — indistinguishable from "nothing
/// happened". Live Activities have the same problem: disabled, there is no way for someone
/// to find out why todos stopped appearing on the lock screen.
///
/// Stored in the App Group `UserDefaults` because the writer may be an extension process.
/// The app's list reads it, offers a route to Settings, and then clears the record.
public enum MissedFeedback {
    /// Channels that Settings can block.
    public enum Channel: String, CaseIterable, Sendable {
        /// Local notification: the only failure path available to controls and widgets.
        case notification
        /// Live Activity, i.e. the lock screen and Dynamic Island.
        case liveActivity
    }

    static let sharedDefaultsKey = "missedFeedbackChannels"

    /// `nil` when the App Group is unavailable, in which case recording is given up on.
    static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier)
    }

    /// Records an undelivered channel, collapsing duplicates.
    public static func record(_ channel: Channel, defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        var stored = storedRawValues(defaults)
        guard !stored.contains(channel.rawValue) else { return }
        stored.append(channel.rawValue)
        defaults.set(stored, forKey: sharedDefaultsKey)
    }

    /// Outstanding records, in `Channel.allCases` order so the display order is stable.
    public static func pending(_ defaults: UserDefaults? = nil) -> [Channel] {
        guard let defaults = defaults ?? sharedDefaults() else { return [] }
        let stored = Set(storedRawValues(defaults))
        return Channel.allCases.filter { stored.contains($0.rawValue) }
    }

    /// Clears a record, either after the banner has been acted on or once the channel is
    /// known to work again — a stale record must not keep the banner on screen.
    public static func clear(_ channel: Channel, defaults: UserDefaults? = nil) {
        guard let defaults = defaults ?? sharedDefaults() else { return }
        let stored = storedRawValues(defaults)
        guard stored.contains(channel.rawValue) else { return }
        let remaining = stored.filter { $0 != channel.rawValue }
        if remaining.isEmpty {
            defaults.removeObject(forKey: sharedDefaultsKey)
        } else {
            defaults.set(remaining, forKey: sharedDefaultsKey)
        }
    }

    private static func storedRawValues(_ defaults: UserDefaults) -> [String] {
        defaults.stringArray(forKey: sharedDefaultsKey) ?? []
    }
}
