//
//  Localization.swift
//  WatchUI
//
//  Binds this package's UI copy to this package's own String Catalog.
//

import Foundation

extension LocalizedStringResource {
    /// UI copy resolved against this package's `Resources/Localizable.xcstrings`.
    ///
    /// `Text("Cancel")` takes a `LocalizedStringKey`, which resolves against `Bundle.main`
    /// and therefore never finds a catalog shipped inside a package. Routing copy through
    /// `Text(.copy("Cancel"))` points it at `Bundle.module` instead.
    ///
    static func copy(_ key: String.LocalizationValue) -> LocalizedStringResource {
        LocalizedStringResource(key, bundle: .atURL(Bundle.module.bundleURL))
    }
}
