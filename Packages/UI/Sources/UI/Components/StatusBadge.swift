//
//  StatusBadge.swift
//  UI
//
//  完了 / お気に入り / 期限ステータスを表示するチップ。iOS と visionOS で
//  別個の private struct を抱えていたのを 1 つに統合し、size variant でだけ
//  外見差を出す。
//

import SwiftUI

public struct StatusBadge: View {
    /// 表示サイズ。視覚優先度の差を吸収するためにのみ使う。
    public enum Size: Sendable {
        /// 標準サイズ — iOS / iPadOS / macOS の Detail Header で使用。
        case compact
        /// 大きめサイズ — visionOS の空間 UI で視認性を確保するために使用。
        case prominent
    }

    /// 文言は `LocalizedStringResource` で受ける。`String` で受けると呼出側の
    /// リテラルが String Catalog に抽出されない（verbatim 扱いになる）。
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
            .font(size == .compact ? .caption : .subheadline)
            .foregroundStyle(color)
            .padding(.horizontal, size == .compact ? 8 : 12)
            .padding(.vertical, size == .compact ? 4 : 6)
            .background(color.opacity(0.15), in: Capsule())
    }
}
