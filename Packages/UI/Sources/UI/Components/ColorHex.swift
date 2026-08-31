//
//  ColorHex.swift
//  UI
//
//  Converts `Category.colorHex` into a SwiftUI `Color`. Shared rather than a private
//  extension because widgets, the watch app and visionOS all reproduce category colours.
//

import SwiftUI

public extension Color {
    /// Builds a `Color` from `"#RRGGBB"` or `"RRGGBB"`, returning `nil` for anything else.
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
