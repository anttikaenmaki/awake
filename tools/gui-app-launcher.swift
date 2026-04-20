import AppKit
import Foundation

struct LauncherConfiguration {
    let successTitle: String
    let failureTitle: String
    let emptyMessage: String
    let scriptURL: URL
    let autoCloseSeconds: Double?

    static func load() -> LauncherConfiguration {
        let environment = ProcessInfo.processInfo.environment
        let bundle = Bundle.main
        let repoRoot = bundle.bundleURL.deletingLastPathComponent()
        let bundleIdentifier = bundle.bundleIdentifier ?? ""

        let isUninstall = bundleIdentifier.contains("uninstall")

        let defaultSuccessTitle = isUninstall ? "Awake Uninstall Complete" : "Awake Installation Complete"
        let defaultFailureTitle = isUninstall ? "Awake Uninstall Failed" : "Awake Installation Failed"
        let defaultEmptyMessage = isUninstall ? "Awake has been uninstalled." : "Awake installation complete."
        let defaultScriptName = isUninstall ? "uninstall-awake.sh" : "install-awake.sh"

        let scriptURL: URL
        if let overriddenScript = environment["AWAKE_GUI_LAUNCHER_SCRIPT"], !overriddenScript.isEmpty {
            scriptURL = URL(fileURLWithPath: overriddenScript)
        } else {
            scriptURL = repoRoot.appendingPathComponent(defaultScriptName, isDirectory: false)
        }

        let autoCloseSeconds: Double?
        if let value = environment["AWAKE_GUI_LAUNCHER_AUTO_CLOSE_SECONDS"], let parsed = Double(value), parsed > 0 {
            autoCloseSeconds = parsed
        } else {
            autoCloseSeconds = nil
        }

        return LauncherConfiguration(
            successTitle: environment["AWAKE_GUI_LAUNCHER_SUCCESS_TITLE"] ?? defaultSuccessTitle,
            failureTitle: environment["AWAKE_GUI_LAUNCHER_FAILURE_TITLE"] ?? defaultFailureTitle,
            emptyMessage: environment["AWAKE_GUI_LAUNCHER_EMPTY_MESSAGE"] ?? defaultEmptyMessage,
            scriptURL: scriptURL,
            autoCloseSeconds: autoCloseSeconds
        )
    }
}

struct LauncherResult {
    let title: String
    let message: String
    let isFailure: Bool
    let exitCode: Int32
}

final class LauncherDelegate: NSObject, NSApplicationDelegate {
    private let configuration = LauncherConfiguration.load()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let appIcon = bundledAppIcon() {
            NSApp.applicationIconImage = appIcon
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = self.runTargetScript()
            DispatchQueue.main.async {
                self.present(result: result)
            }
        }
    }

    private func runTargetScript() -> LauncherResult {
        let fileManager = FileManager.default

        guard fileManager.isExecutableFile(atPath: configuration.scriptURL.path) else {
            return LauncherResult(
                title: configuration.failureTitle,
                message: "The launcher could not find an executable script at:\n\n\(configuration.scriptURL.path)",
                isFailure: true,
                exitCode: 127
            )
        }

        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [configuration.scriptURL.path]
        process.currentDirectoryURL = configuration.scriptURL.deletingLastPathComponent()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        do {
            try process.run()
        } catch {
            return LauncherResult(
                title: configuration.failureTitle,
                message: "Failed to start the launcher script.\n\n\(error.localizedDescription)",
                isFailure: true,
                exitCode: 1
            )
        }

        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let rawOutput = String(data: outputData, encoding: .utf8) ?? ""
        let output = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)

        if process.terminationStatus == 0 {
            let message = output.isEmpty ? configuration.emptyMessage : "Completed actions:\n\n\(output)"
            return LauncherResult(
                title: configuration.successTitle,
                message: message,
                isFailure: false,
                exitCode: 0
            )
        }

        let failureBody: String
        if output.isEmpty {
            failureBody = "The command did not produce any output."
        } else {
            failureBody = "The command reported the following before it failed:\n\n\(output)"
        }

        return LauncherResult(
            title: configuration.failureTitle,
            message: "\(failureBody)\n\nExit code: \(process.terminationStatus)",
            isFailure: true,
            exitCode: process.terminationStatus
        )
    }

    private func present(result: LauncherResult) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        if let appIcon = bundledAppIcon() {
            alert.icon = appIcon
        }
        alert.messageText = result.title
        alert.informativeText = result.message
        alert.alertStyle = result.isFailure ? .critical : .informational

        let okButton = alert.addButton(withTitle: "OK")
        okButton.keyEquivalent = "\r"

        if let autoCloseSeconds = configuration.autoCloseSeconds {
            DispatchQueue.main.asyncAfter(deadline: .now() + autoCloseSeconds) {
                NSApp.abortModal()
                alert.window.orderOut(nil)
            }
        }

        _ = alert.runModal()
        NSApp.terminate(nil)
        exit(result.exitCode)
    }

    private func bundledAppIcon() -> NSImage? {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: iconURL)
    }
}

let application = NSApplication.shared
let delegate = LauncherDelegate()

application.setActivationPolicy(.accessory)
application.delegate = delegate
application.run()
