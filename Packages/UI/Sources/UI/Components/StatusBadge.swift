//
//  StatusBadge.swift
//  UI
//
//  Chip showing favourite and due-date status. One type for every platform, with a size
//  variant for the visual differences.
//

import SwiftUI

public struct StatusBadge: View {
    /// Absorbs the difference in visual weight between platforms.
    public enum Size: Sendable {
        /// Used in the detail header on iOS, iPadOS and macOS.
        case compact
        /// Larger, for legibility in visionOS's spatial UI.
        case prominent
    }

    /// `LocalizedStringResource`, not `String`: the latter makes the caller's literal
    /// verbatim and it never reaches the String Catalog.
    private let title: LocalizedStringResource
    private let systemImage: String
    private let color: Color
    private let size: Size

    public init(
        title: LocalizedStringResource,
        systemImage: String,
        color: Color,
        size: Size = .compact
    ) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.size = size
    }

    public var body: some View {
        Label(title, systemImage: systemImage)
            // `Label`'s default gap is sized for a body-weight row, so at caption size the
            // symbol and the word drift apart inside a capsule only a few points taller
            // than the text itself.
            .labelStyle(TightLabelStyle(spacing: size == .compact ? 3 : 5))
            .font(size == .compact ? .caption : .subheadline)
            .foregroundStyle(color)
            .padding(.horizontal, size == .compact ? 8 : 12)
            .padding(.vertical, size == .compact ? 4 : 6)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// A `Label` laid out with a chosen gap between symbol and text.
///
/// A `LabelStyle` rather than a hand-rolled `HStack` so the two stay one accessibility
/// element, and so a caller can still switch the badge to icon-only further up.
private struct TightLabelStyle: LabelStyle {
    let spacing: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}
