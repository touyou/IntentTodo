//
//  SettingsView.swift
//  UI
//
//  Collects the entry points for system integration.
//

#if os(iOS) || os(visionOS)
import AppIntents
import SwiftUI

/// Where integration with other apps and the system is gathered.
///
/// `ShortcutsLink` is for *exploring* the App Shortcuts — "great if your app has a lot of
/// App Shortcuts and you want to let users explore all of them"
/// [Apple: wwdc2022-10170 20:19] — which is a settings-shaped job, not a prime-real-estate
/// one. `SiriTipView` is the opposite: it teaches one phrase in context, so it belongs next
/// to the action (``SiriTipBanner``), not here.
///
/// Not built on macOS: `ShortcutsLink` does not exist in that SDK.
///
public struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        Form {
            Section {
                ShortcutsLink()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("shortcutsLink")
            } header: {
                Text(.copy("Siri & Shortcuts"))
            } footer: {
                Text(.copy("Browse every action this app adds to Shortcuts, then combine them into your own automations."))
            }

            #if DEBUG
            // Verification only, so the copy stays unlocalised (see `QueryCallLogView`).
            Section {
                NavigationLink {
                    QueryCallLogView()
                } label: {
                    Text(verbatim: "Query Calls")
                }
                .accessibilityIdentifier("queryCallLogLink")
            } header: {
                Text(verbatim: "Debug")
            } footer: {
                Text(verbatim: "Which entity query methods the system called, and what they returned.")
            }
            #endif
        }
        .navigationTitle(.copy("Settings"))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(.copy("Done")) { dismiss() }
                    .accessibilityIdentifier("settingsDoneButton")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
#endif
