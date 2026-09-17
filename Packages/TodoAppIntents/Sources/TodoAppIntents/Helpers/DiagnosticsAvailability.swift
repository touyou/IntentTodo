//
//  DiagnosticsAvailability.swift
//  TodoAppIntents
//
//  Decides whether the developer-facing diagnostics are switched on for this build.
//

import Foundation

/// Whether this build may collect and show diagnostics.
///
/// Three kinds of build, two answers:
///
/// - a **debug** build: on, as before
/// - a **TestFlight** build: on. The things worth diagnosing here — which query the system
///   called, whether App Intents metadata survived distribution — only misbehave *after*
///   the app has been through App Store Connect, so a diagnostic that exists only in debug
///   builds cannot see the failure it was written for
/// - an **App Store** build: off. Nothing is recorded and nothing is shown
///
/// TestFlight is told apart by its receipt filename, which is `sandboxReceipt` for builds
/// installed from TestFlight and `receipt` for ones from the App Store.
///
/// The diagnostics screens are therefore compiled into release builds. Their copy stays
/// English-only (`Text(verbatim:)`): the audience is whoever is debugging the build, and a
/// person on the App Store version can never reach them.
public enum DiagnosticsAvailability {
    /// Computed once — the receipt URL cannot change while the process is alive.
    public static let isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()
}
