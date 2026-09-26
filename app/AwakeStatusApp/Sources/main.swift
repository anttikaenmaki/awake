// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        statusBarController?.start()
    }
}

// `AwakeStatusBar --notify TITLE [BODY]` posts one notification as Awake.app
// and exits. The awake command uses it so its notifications show the Awake
// icon instead of the Script Editor icon that osascript notifications get.
let arguments = CommandLine.arguments
if arguments.count >= 3, arguments.count <= 4, arguments[1] == "--notify" {
    exit(NotificationController.shared.postFromCommandLine(
        title: arguments[2],
        body: arguments.count == 4 ? arguments[3] : ""
    ))
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
