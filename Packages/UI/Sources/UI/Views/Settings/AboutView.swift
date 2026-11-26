//
//  AboutView.swift
//  UI
//
//  The build, feedback and the privacy policy, pushed from Settings.
//

#if os(iOS) || os(visionOS) || os(macOS)
import Domain
import SwiftUI
import TodoAppIntents

struct AboutView: View {
    var body: some View {
        Form {
            AboutHeaderSection()

            Section {
                AboutLinkRow(title: .copy("Rate Intento"), systemImage: "star", destination: AboutLinks.writeReview)
                AboutLinkRow(title: .copy("Feedback & Bug Reports"), systemImage: "envelope", destination: AboutLinks.support)
                ShareLink(
                    item: AboutLinks.appStore,
                    subject: Text(verbatim: "Intento"),
                    message: Text(.copy("Intento is a to-do list you can reach from anywhere: Siri, Shortcuts, widgets and Spotlight."))
                ) {
                    Label(.copy("Share Intento"), systemImage: "square.and.arrow.up")
                }
            } header: {
                Text(.copy("Feedback"))
            }

            TipJarSection()

            Section {
                if !WhatsNew.releases.isEmpty {
                    NavigationLink {
                        WhatsNewHistoryView()
                    } label: {
                        Label(.copy("What's New"), systemImage: "sparkles")
                    }
                }
                AboutLinkRow(title: .copy("Developer"), systemImage: "person", destination: AboutLinks.developer)
            }

            Section {
                AboutLinkRow(title: .copy("Privacy Policy"), systemImage: "hand.raised", destination: AboutLinks.privacy)
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .navigationTitle(.copy("About"))
    }
}

private struct AboutHeaderSection: View {
    /// Read from the bundle rather than kept as a constant: the point of showing it is to
    /// identify the build a report came from.
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Section {
            VStack(spacing: 8) {
                Image("AboutIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .clipShape(.rect(cornerRadius: 14, style: .continuous))
                    .accessibilityHidden(true)
                Text(verbatim: "Intento")
                    .font(.title3.bold())
                Text(.copy("Version \(version)"))
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(.copy("Made in Japan."))
                    .font(.footnote)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } footer: {
            Text(.copy("Everything this app can do is an App Intent, so Siri, Shortcuts, widgets, controls and Spotlight all reach the same actions."))
        }
    }
}

/// A row that leaves the app (Safari or the App Store), marked with an arrow so that is
/// clear before the tap.
private struct AboutLinkRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
    }
}

private enum AboutLinks {
    static let appStore = URL(string: "https://apps.apple.com/app/id6788623037")!
    static let writeReview = URL(string: "https://apps.apple.com/app/id6788623037?action=write-review")!
    static let support = URL(string: "https://touyou.dev/intento/support")!
    static let privacy = URL(string: "https://touyou.dev/intento/privacy")!
    static let developer = URL(string: "https://touyou.dev")!
}
#endif
