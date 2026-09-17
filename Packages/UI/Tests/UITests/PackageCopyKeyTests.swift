//
//  PackageCopyKeyTests.swift
//  UITests
//
//  Guards the one rule that makes package UI copy safe in the source language.
//

import Foundation
import Testing

@Suite("パッケージの UI コピーのキー")
struct PackageCopyKeyTests {
    /// Every String Catalog that belongs to a UI package.
    private static var catalogs: [URL] {
        // …/Packages/UI/Tests/UITests/ → …/Packages
        let packages = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return ["UI", "WidgetUI", "WatchUI", "LiveActivity"].map {
            packages
                .appending(path: $0)
                .appending(path: "Sources/\($0)/Resources/Localizable.xcstrings")
        }
    }

    private func keys(of catalog: URL) throws -> [String] {
        let data = try Data(contentsOf: catalog)
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let strings = decoded?["strings"] as? [String: Any] ?? [:]
        return Array(strings.keys)
    }

    /// **A package's bundle only ships the locales its catalog lists.** There is no
    /// `en.lproj` unless something in the catalog carries an `en` localization, so in the
    /// source language `.copy("…")` resolves to *the key itself*.
    ///
    /// That is invisible for plain copy (the key is the English text) and produces garbage
    /// for automatic grammar agreement: `^[%lld todo](inflect: true)` reaches the screen
    /// verbatim, markup and all. It shipped that way in the widget until 2026-09-17.
    ///
    /// Plural agreement belongs in the catalog instead — a plain `%lld todos` key with
    /// `plural.one` / `plural.other` under `en`.
    @Test("UI パッケージのキーに inflect マークアップを持ち込まない", arguments: catalogs)
    func noInflectionMarkupInPackageKeys(catalog: URL) throws {
        // A missing catalog means the package layout moved; that is a failure, not a skip,
        // because a silently empty test is exactly what this rule cannot afford.
        #expect(
            FileManager.default.fileExists(atPath: catalog.path),
            "カタログを解決できていない: \(catalog.path)"
        )

        let offenders = try keys(of: catalog).filter { $0.contains("(inflect:") }
        #expect(
            offenders.isEmpty,
            """
            \(catalog.lastPathComponent) のキーに inflect マークアップがある: \(offenders)
            パッケージのバンドルには en.lproj が無いので、ソース言語ではキーがそのまま
            画面に出る。複数形はカタログ側（en の plural.one / plural.other）に持たせる。
            """
        )
    }
}
