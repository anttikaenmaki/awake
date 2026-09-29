// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = StatusBarController()
        statusBarController = controller
        NSApp.mainMenu = makeMainMenu(settingsTarget: controller)
        controller.start()
    }
}

/// The app runs without a menu bar of its own, but its windows still need
/// the usual shortcuts: Settings (Command-comma), Close (Command-W), and
/// editing. There is no Quit item: quitting goes through the menu bar
/// icon, which stops a running session first.
func makeMainMenu(settingsTarget: StatusBarController) -> NSMenu {
    let mainMenu = NSMenu()

    let appMenu = NSMenu(title: "Awake")
    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(StatusBarController.showSettings(_:)), keyEquivalent: ",")
    settingsItem.target = settingsTarget
    appMenu.addItem(settingsItem)
    let appItem = NSMenuItem()
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)

    let fileMenu = NSMenu(title: "File")
    fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
    let fileItem = NSMenuItem()
    fileItem.submenu = fileMenu
    mainMenu.addItem(fileItem)

    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    let redoItem = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
    redoItem.keyEquivalentModifierMask = [.command, .shift]
    editMenu.addItem(.separator())
    editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    let editItem = NSMenuItem()
    editItem.submenu = editMenu
    mainMenu.addItem(editItem)

    return mainMenu
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
