//
//  MissedFeedbackBanner.swift
//  UI
//
//  通知 / ライブアクティビティが設定で塞がれていて伝達できなかったことを伝え、
//  設定アプリへ送るバナー。
//

import SwiftUI
import TodoAppIntents
#if canImport(UIKit)
import UIKit
#endif

/// 「伝えられなかった」記録があるときだけ出る設定誘導バナー。
///
/// 出す条件を「設定が無効」ではなく**実際に取りこぼしたとき**にしているのは、
/// ユーザーが意図的に切っている設定を毎回蒸し返さないため。取りこぼしは
/// `MissedFeedback` に記録され、閉じると消える。
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
        // Liquid Glass 時代のクロームは自前で塗らずシステムマテリアルに任せる。
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
            // Control / Widget から実行した Intent の失敗は通知が唯一の伝達手段。
            return .copy("Actions from Control Center and widgets can't report failures.")
        case .liveActivity:
            return .copy("Todos due within the hour can't appear on the Lock Screen.")
        }
    }

    /// システム設定の該当ページ。
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
