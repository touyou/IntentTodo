//
//  ReviewPrompt.swift
//  IntentTodo
//

import Foundation

/// Decides whether to ask for an App Store review right after the person clears
/// their last open todo. Asks only after the second clear, 3 days after the first
/// launch, and at most once per version — the system still decides whether the
/// prompt appears.
public enum ReviewPrompt {
    private static let firstLaunchKey = "reviewFirstLaunchDate"
    private static let achievementCountKey = "reviewAchievementCount"
    private static let requestedVersionKey = "reviewRequestedVersion"

    static let minimumDays = 3
    static let minimumAchievements = 2

    /// UI test and screenshot runs pass this argument; they must never see the prompt.
    static var isUITestLaunch: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest-ephemeral-store")
    }

    public static func recordLaunch(defaults: UserDefaults = .standard, now: Date = .now) {
        if defaults.object(forKey: firstLaunchKey) == nil { defaults.set(now, forKey: firstLaunchKey) }
    }

    /// Returns true when the prompt should be requested now, and marks this version as asked.
    static func recordAchievement(defaults: UserDefaults = .standard, now: Date = .now) -> Bool {
        let count = defaults.integer(forKey: achievementCountKey) + 1
        defaults.set(count, forKey: achievementCountKey)
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date ?? now
        let days = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
        let requests = count >= minimumAchievements && days >= minimumDays
            && defaults.string(forKey: requestedVersionKey) != version
        if requests { defaults.set(version, forKey: requestedVersionKey) }
        return requests
    }

    /// Open and completed counts, compared across a store change.
    struct Progress: Equatable {
        let open: Int
        let completed: Int

        /// The last open todo was completed — not deleted, which also empties the list.
        func isCleared(from old: Progress) -> Bool {
            old.open > 0 && open == 0 && completed > old.completed
        }
    }
}
