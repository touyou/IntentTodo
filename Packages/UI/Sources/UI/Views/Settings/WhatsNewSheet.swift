#if os(iOS) || os(visionOS) || os(macOS)
import SwiftUI

/// What's new, per version. Add a release at the top when a version brings something new
/// (not for fix-only versions). Shown once after updating, and reopenable from About.
public enum WhatsNew {
    struct Item: Identifiable {
        let systemImage: String
        let title: LocalizedStringResource
        let message: LocalizedStringResource
        var id: String { systemImage }
    }

    struct Release: Identifiable {
        let version: String
        let greeting: LocalizedStringResource
        let items: [Item]
        var id: String { version }
    }

    static let releases: [Release] = []

    /// The release to show at launch, decided by `prepareOnLaunch()`.
    @MainActor private(set) static var pending: Release?

    /// Call once at launch, also in versions with no release, so a fresh install marks this version as seen.
    @MainActor public static func prepareOnLaunch(defaults: UserDefaults = .standard) {
        // No launch record predates this, so people already on the app are first shown the next release.
        let isReturning = false
        let shows = AppUpdate.shouldShowWhatsNew(hasExistingData: isReturning, defaults: defaults)
        pending = shows ? releases.first { $0.version == AppUpdate.currentVersion } : nil
    }
}

/// Decides whether to show What's New: only after an update, never on a fresh install, and once per version.
enum AppUpdate {
    private static let seenVersionKey = "whatsNewSeenVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func shouldShowWhatsNew(
        hasExistingData: Bool, current: String = currentVersion, defaults: UserDefaults = .standard
    ) -> Bool {
        let seen = defaults.string(forKey: seenVersionKey)
        let shows = isUpdate(from: seen, to: current, hasExistingData: hasExistingData)
        // A fresh install counts this version as seen, so the next update shows its release.
        if seen == nil, !shows { markSeen(current: current, defaults: defaults) }
        return shows
    }

    /// Call on dismiss; quitting before dismissing shows it again next launch.
    static func markSeen(current: String = currentVersion, defaults: UserDefaults = .standard) {
        defaults.set(current, forKey: seenVersionKey)
    }

    static func isUpdate(from previous: String?, to current: String, hasExistingData: Bool) -> Bool {
        guard let previous else { return hasExistingData }
        return previous.compare(current, options: .numeric) == .orderedAscending
    }
}

extension View {
    /// Attach to the outermost view; presents the release `WhatsNew.prepareOnLaunch()` picked.
    public func whatsNewOnUpdate() -> some View {
        modifier(WhatsNewOnUpdate())
    }
}

private struct WhatsNewOnUpdate: ViewModifier {
    @State private var release = WhatsNew.pending

    func body(content: Content) -> some View {
        content
            .sheet(item: $release, onDismiss: { AppUpdate.markSeen() }) { release in
                WhatsNewSheet(release: release)
            }
    }
}

struct WhatsNewSheet: View {
    let release: WhatsNew.Release
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    VStack(spacing: 12) {
                        Text(.copy("What's New in Intento"))
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(.copy("Version \(release.version)"))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(release.greeting)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(release.items) { item in
                            WhatsNewRow(item: item)
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 48)
                .padding(.bottom, 24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            Button {
                dismiss()
            } label: {
                Text(.copy("Continue"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: 496)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }
}

private struct WhatsNewRow: View {
    let item: WhatsNew.Item

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: item.systemImage)
                .font(.title)
                .foregroundStyle(.tint)
                .frame(width: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                Text(item.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// About → What's New. Picking a version shows its sheet again.
struct WhatsNewHistoryView: View {
    @State private var selection: WhatsNew.Release?

    var body: some View {
        List(WhatsNew.releases) { release in
            Button {
                selection = release
            } label: {
                WhatsNewHistoryRow(release: release)
            }
            .foregroundStyle(.primary)
        }
        .navigationTitle(Text(.copy("What's New")))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selection) { release in
            WhatsNewSheet(release: release)
        }
    }
}

private struct WhatsNewHistoryRow: View {
    let release: WhatsNew.Release

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(.copy("Version \(release.version)"))
                    .font(.headline.monospacedDigit())
                // The item titles hint at what each release holds before it is opened.
                HStack(spacing: 0) {
                    ForEach(Array(release.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Text(verbatim: " · ") }
                        Text(item.title)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}
#endif
