//
//  SettingsView.swift
//  UI
//
//  システム連携の入口を集める画面。
//

#if os(iOS) || os(visionOS)
import AppIntents
import SwiftUI

/// 「ほかのアプリ / システムとの連携」を集める画面。
///
/// ここに置く判断の理由:
/// - `ShortcutsLink` は **App Shortcut を一覧して探索させる**ための導線
///   （wwdc2022-10170 20:19: "great if your app has a lot of App Shortcuts and you want
///   to let users explore all of them"）。主要動線ではなく探索なので、一覧の一等地では
///   なくこの画面に置く
/// - 逆に**その場のフレーズを教える** `SiriTipView` はここに置かない。文脈のある瞬間に
///   出すもので、設定画面には文脈が無い（``SiriTipBanner``）
///
/// **macOS には出さない**: `ShortcutsLink` は macOS / watchOS SDK に型自体が存在しない。
/// Mac の導線は Shortcuts アプリ側の一覧。
///
/// 詳細: docs/insights/04-ui-integration.md
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
