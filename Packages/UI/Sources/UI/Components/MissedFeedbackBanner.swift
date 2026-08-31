//
//  MissedFeedbackBanner.swift
//  UI
//
//  Banner reporting feedback that Settings blocked, with a route to Settings.
//

import SwiftUI
import TodoAppIntents
#if canImport(UIKit)
import UIKit
#endif

/// Appears only when something was actually lost, not merely because a setting is off:
/// a deliberate choice should not be re-litigated on every launch. The record lives in
/// `MissedFeedback` and is cleared on dismissal.
struct MissedFeedbackBanner: View {
    let model: MissedFeedbackModel

    var body: some View {
        ForEach(model.channels, id: \.rawValue) { channel in
            MissedFeedbackRow(channel: channel) {
                model.dismiss(channel)
            }
        }
    }
}

private struct MissedFeedbackRow: View {
    let channel: MissedFeedback.Channel
    let onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.bubble")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.footnote)
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let settingsURL {
                Button(.copy("Open Settings")) {
                    openURL(settingsURL)
                    onDismiss()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
            }
            Button(role: .close, action: onDismiss) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(.copy("Dismiss"))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        // Chrome is left to the system material rather than painted here.
        .background(.bar)
        .accessibilityElement(children: .combine)
    }

    private var title: LocalizedStringResource {
        switch channel {
        case .notification: return .copy("Notifications are turned off")
        case .liveActivity: return .copy("Live Activities are turned off")
        }
    }

    private var message: LocalizedStringResource {
        switch channel {
        case .notification:
            // A notification is the only way a control or widget can report a failure.
            return .copy("Actions from Control Center and widgets can't report failures.")
        case .liveActivity:
            return .copy("Todos due within the hour can't appear on the Lock Screen.")
        }
    }

    /// The relevant page in Settings.
    private var settingsURL: URL? {
        #if canImport(UIKit)
        return URL(string: UIApplication.openSettingsURLString)
        #elseif os(macOS)
        return URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #else
        return nil
        #endif
    }
}
