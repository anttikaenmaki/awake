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

    /// The root-owned helper that changes the sleep settings.
    static let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper")

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
        static let lastBackend = "lastBackend"
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

    /// The lid mode of the last session started from the app. The start
    /// picker opens with it selected.
    var lastBackend: AwakeBackend? {
        get { defaults.string(forKey: Keys.lastBackend).flatMap(AwakeBackend.init(rawValue:)) }
        set { defaults.set(newValue?.rawValue, forKey: Keys.lastBackend) }
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
                body = "The timed session finished."
            case "failed":
                body = "Awake ended unexpectedly before the session finished."
            default:
                body = "Awake stopped."
            }
        } else {
            switch reason {
            case "timeout":
                body = "The timed session finished and normal sleep settings were restored."
            case "low_battery":
                body = "The battery ran low, so Awake stopped early and restored the normal sleep settings. Connect the charger before starting again."
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

    func postExtended(statusText: String, backend: AwakeBackend? = nil) {
        postNotification(
            title: "\((backend ?? .awake).displayName) extended",
            body: statusText,
            attachmentResource: "NotificationOn",
            soundEnabled: false
        )
    }

    func postAlreadyOn(statusText: String) {
        postNotification(
            title: "Awake is already on",
            body: statusText,
            attachmentResource: "NotificationOn",
            soundEnabled: false
        )
    }

    func postNeedsAttention(message: String) {
        postNotification(
            title: "Awake needs attention",
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

    /// Posts one notification for `AwakeStatusBar --notify` and waits until
    /// the system has it. Returns the exit status: 0 when posted, 3 when
    /// Awake may not post notifications (the caller then uses osascript),
    /// 1 on any other failure.
    func postFromCommandLine(title: String, body: String) -> Int32 {
        let semaphore = DispatchSemaphore(value: 0)
        let authorized = ResultFlag()
        center.getNotificationSettings { settings in
            authorized.value = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success, authorized.value else {
            return 3
        }

        let lowercasedTitle = title.lowercased()
        let showsOn = lowercasedTitle.hasSuffix("started") || lowercasedTitle.hasSuffix("extended") || lowercasedTitle.hasSuffix("already on")
        let posted = ResultFlag()
        center.add(makeRequest(title: title, body: body, attachmentResource: showsOn ? "NotificationOn" : "NotificationOff")) { error in
            posted.value = error == nil
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success, posted.value else {
            return 1
        }
        return 0
    }

    private func postNotification(title: String, body: String, attachmentResource: String, soundEnabled _: Bool) {
        center.add(makeRequest(title: title, body: body, attachmentResource: attachmentResource))
    }

    private func makeRequest(title: String, body: String, attachmentResource: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if let attachmentURL = Bundle.main.url(forResource: attachmentResource, withExtension: "png"),
           let attachment = try? UNNotificationAttachment(identifier: attachmentResource, url: attachmentURL) {
            content.attachments = [attachment]
        }
        return UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
    }
}

/// A flag set from a notification-center callback and read after waiting
/// for it; the semaphore orders the accesses.
private final class ResultFlag: @unchecked Sendable {
    var value = false
}
