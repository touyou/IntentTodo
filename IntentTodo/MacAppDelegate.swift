//
//  MacAppDelegate.swift
//  IntentTodo
//
//  macOS native 用の NSApplicationDelegate。通知ハンドラ本体は
//  NotificationHandler に集約しているので、ここは起動時に install するだけ。
//  UIScene は macOS native に存在しないため SceneDelegate は不要。
//

#if os(macOS)
import AppKit

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationHandler.shared.install()
    }
}
#endif
