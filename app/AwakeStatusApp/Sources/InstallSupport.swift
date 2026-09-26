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
    let minBatteryPercent: Int
    let thermalGuardEnabled: Bool
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
        static let minBatteryPercent = "minBatteryPercent"
        static let thermalGuardDisabled = "thermalGuardDisabled"
        static let lastKeepDisplayOff = "lastKeepDisplayOff"
    }

    /// The battery levels offered in the menu; 0 turns the check off.
    static let minBatteryChoices = [0, 10, 20, 30]
    static let defaultMinBatteryPercent = 10

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

    /// The battery charge at which a session ends on battery power; 0 means
    /// never.
    var minBatteryPercent: Int {
        get {
            guard let value = defaults.object(forKey: Keys.minBatteryPercent) as? Int,
                  value == 0 || (5...50).contains(value) else {
                return Self.defaultMinBatteryPercent
            }
            return value
        }
        set { defaults.set(newValue, forKey: Keys.minBatteryPercent) }
    }

    /// Whether a session ends when the Mac overheats. Stored inverted so the
    /// check is on until the user turns it off.
    var thermalGuardEnabled: Bool {
        get { !defaults.bool(forKey: Keys.thermalGuardDisabled) }
        set { defaults.set(!newValue, forKey: Keys.thermalGuardDisabled) }
    }

    /// The display choice of the last Caffeine session started from the app.
    /// The start picker opens with it; stored inverted so it starts out on.
    var lastKeepDisplay: Bool {
        get { !defaults.bool(forKey: Keys.lastKeepDisplayOff) }
        set { defaults.set(!newValue, forKey: Keys.lastKeepDisplayOff) }
    }

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            launchAtLoginEnabled: launchAtLoginEnabled,
            useCustomPasswordDialog: useCustomPasswordDialog,
            soundEnabled: soundEnabled,
            minBatteryPercent: minBatteryPercent,
            thermalGuardEnabled: thermalGuardEnabled
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
            case "low_battery":
                body = "The battery ran low, so Awake stopped early. Connect the charger before starting again."
            case "overheated":
                body = "The Mac got too hot, so Awake stopped early to let it cool down."
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
            case "overheated":
                body = "The Mac got too hot, so Awake stopped early and restored the normal sleep settings to let it sleep and cool down. Keep it on a hard, well-ventilated surface."
            case "failed":
                body = "Awake ended, but restoring the normal sleep settings needs attention."
            default:
                body = "Normal sleep settings were restored."
            }
        }

        postNotification(
            title: "\(sessionBackend.displayName) stopped",
            body: body,
            soundEnabled: soundEnabled
        )
    }

    func postFailure(message: String, backend: AwakeBackend? = nil) {
        let sessionBackend = backend ?? .awake
        postNotification(
            title: "\(sessionBackend.displayName) failed",
            body: message,
            soundEnabled: false
        )
    }

    func postExtended(statusText: String, backend: AwakeBackend? = nil) {
        postNotification(
            title: "\((backend ?? .awake).displayName) extended",
            body: statusText,
            soundEnabled: false
        )
    }

    func postAlreadyOn(statusText: String) {
        postNotification(
            title: "Awake is already on",
            body: statusText,
            soundEnabled: false
        )
    }

    func postNeedsAttention(message: String) {
        postNotification(
            title: "Awake needs attention",
            body: message,
            soundEnabled: false
        )
    }

    func postQuitCancelled() {
        postNotification(
            title: "Quit cancelled",
            body: "Awake is still running because the stop command did not finish.",
            soundEnabled: false
        )
    }

    /// Posts one notification for `AwakeStatusBar --notify` and waits until
    /// the system has it. Returns the exit status: 0 when posted, 3 when
    /// notifications for Awake are turned off, 4 when macOS did not grant
    /// permission (for example an unsigned build), 1 on any other failure.
    /// The awake command then falls back to osascript.
    func postFromCommandLine(title: String, body: String) -> Int32 {
        let semaphore = DispatchSemaphore(value: 0)
        let authorized = ResultFlag()
        let undecided = ResultFlag()
        center.getNotificationSettings { settings in
            authorized.value = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
            undecided.value = settings.authorizationStatus == .notDetermined
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success else {
            return 1
        }
        if undecided.value {
            // Not asked yet, for example when the menu bar app never ran:
            // ask now. macOS shows its permission prompt once.
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                authorized.value = granted
                semaphore.signal()
            }
            guard semaphore.wait(timeout: .now() + 120) == .success, authorized.value else {
                return 4
            }
        }
        guard authorized.value else {
            return 3
        }

        let posted = ResultFlag()
        center.add(makeRequest(title: title, body: body)) { error in
            posted.value = error == nil
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + 5) == .success, posted.value else {
            return 1
        }
        return 0
    }

    private func postNotification(title: String, body: String, soundEnabled _: Bool) {
        center.add(makeRequest(title: title, body: body))
    }

    /// Plain notifications: macOS shows the app icon, and an image
    /// attachment would only add a thumbnail on the right.
    private func makeRequest(title: String, body: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
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
