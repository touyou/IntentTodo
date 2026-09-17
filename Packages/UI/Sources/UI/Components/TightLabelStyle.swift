//
//  TightLabelStyle.swift
//  UI
//
//  The gap between a symbol and its text, for labels that have to read as one token.
//

import SwiftUI

/// A `Label` laid out with a chosen gap between symbol and text.
///
/// **Every inline label needs this.** `Label`'s default gap is sized for a list row, where the
/// icon sits in its own column; inside a capsule or a caption line that much space reads as
/// the symbol and the word having come apart. The detail header's badges had it, and so did
/// the search-reason chips until someone looked at them side by side.
///
/// A `LabelStyle` rather than a hand-rolled `HStack` so the two stay one accessibility
/// element, and so a caller can still switch the label to icon-only.
struct TightLabelStyle: LabelStyle {
    /// Points between symbol and text. 3 suits caption sizes, 5 the larger spatial variants.
    let spacing: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: spacing) {
            configuration.icon
            configuration.title
        }
    }
}

extension LabelStyle where Self == TightLabelStyle {
    /// The gap for caption-sized inline labels: badges, chips, match reasons.
    static var tight: TightLabelStyle { TightLabelStyle(spacing: 3) }

    /// The gap for the larger labels visionOS uses.
    static var tightProminent: TightLabelStyle { TightLabelStyle(spacing: 5) }
}
