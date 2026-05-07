//
//  ColorHex.swift
//  UI
//
//  `Category.colorHex` (16 進文字列) を SwiftUI `Color` に変換するヘルパ。
//  Widget / Watch / visionOS でも `Category` の色を再現したくなるため、
//  個別 View に private extension で持たせず Components に集約する。
//

import SwiftUI

public extension Color {
    /// `"#RRGGBB"` または `"RRGGBB"` 形式の 16 進文字列から `Color` を生成する。
    /// 不正な文字列の場合は `nil` を返す。
    init?(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.replacingOccurrences(of: "#", with: "")
        guard sanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: sanitized).scanHexInt64(&rgb) else { return nil }

        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
