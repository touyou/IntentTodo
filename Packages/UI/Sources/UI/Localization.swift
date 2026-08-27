//
//  Localization.swift
//  UI
//
//  パッケージ内の UI コピーを、このパッケージ自身の String Catalog に結び付ける。
//

import Foundation

extension LocalizedStringResource {
    /// このパッケージの String Catalog（`Resources/Localizable.xcstrings`）を引く UI コピー。
    ///
    /// SwiftUI の `Text("Cancel")` 形（`LocalizedStringKey`）は既定で `Bundle.main` を
    /// 見るため、SPM パッケージに同梱した catalog には**当たらない**。文言は必ず
    /// `Text(.copy("Cancel"))` の形でここを通し、`Bundle.module` に向ける。
    ///
    /// 抽出（String Catalog への取り込み）はリテラルの型で決まるので、`String` の
    /// 変数を経由させると catalog に載らない。UI コピーを運ぶプロパティ / パラメータの
    /// 型も `LocalizedStringResource` にする。
    ///
    /// 詳細: docs/insights/04-ui-integration.md「SPM パッケージの UI コピーと String Catalog」
    static func copy(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
