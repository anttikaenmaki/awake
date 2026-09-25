// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation
import UserNotifications

enum InstallPaths {
    static let bundleIdentifier = "net.kaenmaki.awake.statusbar"
    static let launchAgentLabel = bundleIdentifier
    static let executableName = "AwakeStatusBar"

    static var homeDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
    }

    static var installedAppURL: URL {
        homeDirectory.appendingPathComponent("Applications/Awake.app", isDirectory: true)
    }

    static var supportDirectory: URL {
        homeDirectory.appendingPathComponent("Library/Application Support/Awake", isDirectory: true)
    }

    static var managedCLIURL: URL {
        supportDirectory.appendingPathComponent("bin/awake", isDirectory: false)
    }

    static var installInfoURL: URL {
        supportDirectory.appendingPathComponent("install-info.sh", isDirectory: false)
    }

    static var launchAgentURL: URL {
        homeDirectory.appendingPathComponent("Library/LaunchAgents/\(launchAgentLabel).plist", isDirectory: false)
    }

    static var launchAgentDirectory: URL {
        launchAgentURL.deletingLastPathComponent()
    }

    static var launchdDomain: String {
        "gui/\(getuid())"
    }
}

struct PreferencesSnapshot {
    let launchAtLoginEnabled: Bool
    let useCustomPasswordDialog: Bool
    let soundEnabled: Bool
}

final class PreferencesStore {
    static let shared = PreferencesStore()

    private enum Keys {
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let useCustomPasswordDialog = "useCustomPasswordDialog"
        static let soundEnabled = "soundEnabled"
        static let lastStoppedAt = "lastStoppedAt"
        static let appSessionToken = "appSessionToken"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    var launchAtLoginEnabled: Bool {
        get { defaults.bool(forKey: Keys.launchAtLoginEnabled) }
        set { defaults.set(newValue, forKey: Keys.launchAtLoginEnabled) }
    }

    var useCustomPasswordDialog: Bool {
        get { defaults.bool(forKey: Keys.useCustomPasswordDialog) }
        set { defaults.set(newValue, forKey: Keys.useCustomPasswordDialog) }
    }

    var soundEnabled: Bool {
        get { defaults.bool(forKey: Keys.soundEnabled) }
        set { defaults.set(newValue, forKey: Keys.soundEnabled) }
    }

    /// When the most recent Awake session ended, as far as the app knows.
    var lastStoppedAt: Date? {
        get { defaults.object(forKey: Keys.lastStoppedAt) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastStoppedAt) }
    }

    /// Session token of the last session this app started. The app only posts
    /// stop notifications for its own sessions; the CLI announces the rest.
    var appSessionToken: String? {
        get { defaults.string(forKey: Keys.appSessionToken) }
        set { defaults.set(newValue, forKey: Keys.appSessionToken) }
    }

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            launchAtLoginEnabled: launchAtLoginEnabled,
            useCustomPasswordDialog: useCustomPasswordDialog,
            soundEnabled: soundEnabled
        )
    }
}

enum LaunchAgentManagerError: LocalizedError {
    case failedToWritePlist
    case launchctlFailed(arguments: [String], output: String)

    var errorDescription: String? {
        switch self {
        case .failedToWritePlist:
            return "Failed to write the login-launch configuration."
        case let .launchctlFailed(arguments, output):
            let command = (["launchctl"] + arguments).joined(separator: " ")
            if output.isEmpty {
                return "The command `\(command)` failed."
            }
            return "The command `\(command)` failed: \(output)"
        }
    }
}

final class LaunchAgentManager {
    private let fileManager = FileManager.default

    func isEnabled() -> Bool {
        fileManager.fileExists(atPath: InstallPaths.launchAgentURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try ensureDirectories()
            try writeLaunchAgent()
            try? bootOut()
            try bootstrap()
        } else {
            try? bootOut()
            try removeLaunchAgent()
        }
    }

    private func ensureDirectories() throws {
        try fileManager.createDirectory(at: InstallPaths.launchAgentDirectory, withIntermediateDirectories: true)
    }

    private func writeLaunchAgent() throws {
        let plist: [String: Any] = [
            "Label": InstallPaths.launchAgentLabel,
            "ProgramArguments": ["/usr/bin/open", "-gj", InstallPaths.installedAppURL.path],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]

        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        do {
            try plistData.write(to: InstallPaths.launchAgentURL, options: .atomic)
        } catch {
            throw LaunchAgentManagerError.failedToWritePlist
        }
    }

    private func removeLaunchAgent() throws {
        if fileManager.fileExists(atPath: InstallPaths.launchAgentURL.path) {
            try fileManager.removeItem(at: InstallPaths.launchAgentURL)
        }
    }

    private func bootstrap() throws {
        try runLaunchctl(["bootstrap", InstallPaths.launchdDomain, InstallPaths.launchAgentURL.path])
    }

    private func bootOut() throws {
        guard isEnabled() else {
            return
        }
        try runLaunchctl(["bootout", InstallPaths.launchdDomain, InstallPaths.launchAgentURL.path])
    }

    private func runLaunchctl(_ arguments: [String]) throws {
        let process = Process()
        let outputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if process.terminationStatus != 0 {
            throw LaunchAgentManagerError.launchctlFailed(arguments: arguments, output: output)
        }
    }
}

final class NotificationController {
    static let shared = NotificationController()

    private let center = UNUserNotificationCenter.current()
    private var authorizationRequested = false

    private init() {}

    func requestAuthorizationIfNeeded() {
        guard !authorizationRequested else {
            return
        }
        authorizationRequested = true
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func postStarted(soundEnabled: Bool, backend: AwakeBackend? = nil) {
        let sessionBackend = backend ?? .awake
        postNotification(
            title: "\(sessionBackend.displayName) started",
            body: sessionBackend == .caffeinate
                ? "The Mac will stay awake while the lid remains open until the chosen session ends."
                : "The Mac will stay awake with the lid closed until the chosen session ends.",
            attachmentResource: "NotificationOn",
            soundEnabled: soundEnabled
        )
    }

    func postStopped(soundEnabled: Bool, reason: String?, backend: AwakeBackend? = nil) {
        let sessionBackend = backend ?? .awake
        let body: String
        if sessionBackend == .caffeinate {
            switch reason {
            case "timeout":
                body = "The timed session finished. The lid must have stayed open."
            case "failed":
                body = "Awake ended unexpectedly before the session finished."
            default:
                body = "Awake stopped."
            }
        } else {
            switch reason {
            case "timeout":
                body = "The timed session finished and normal sleep settings were restored."
            case "failed":
                body = "Awake ended, but restoring the normal sleep settings needs attention."
            default:
                body = "Normal sleep settings were restored."
            }
        }

        postNotification(
            title: "\(sessionBackend.displayName) stopped",
            body: body,
            attachmentResource: "NotificationOff",
            soundEnabled: soundEnabled
        )
    }

    func postFailure(message: String, backend: AwakeBackend? = nil) {
        let sessionBackend = backend ?? .awake
        postNotification(
            title: "\(sessionBackend.displayName) failed",
            body: message,
            attachmentResource: "NotificationOff",
            soundEnabled: false
        )
    }

    func postQuitCancelled() {
        postNotification(
            title: "Quit cancelled",
            body: "Awake is still running because the stop command did not finish.",
            attachmentResource: "NotificationOn",
            soundEnabled: false
        )
    }

    private func postNotification(title: String, body: String, attachmentResource: String, soundEnabled _: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let attachmentURL = Bundle.main.url(forResource: attachmentResource, withExtension: "png"),
           let attachment = try? UNNotificationAttachment(identifier: attachmentResource, url: attachmentURL) {
            content.attachments = [attachment]
        }
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }
}
