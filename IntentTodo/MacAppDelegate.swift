//
//  MacAppDelegate.swift
//  IntentTodo
//
//  The macOS `NSApplicationDelegate`. The delegate body lives in `NotificationHandler`, so
//  this only installs it at launch. Native macOS has no `UIScene`, hence no SceneDelegate.
//

#if os(macOS)
import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationHandler.shared.install()
    }
}
#endif
