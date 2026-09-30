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
    /// The level passed to `--min-battery`; 0 when `Stop at low battery` is
    /// off.
    let minBatteryPercent: Int
    let thermalGuardEnabled: Bool
    let unplugGuardEnabled: Bool
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
        static let lowBatteryGuardEnabled = "lowBatteryGuardEnabled"
        static let thermalGuardDisabled = "thermalGuardDisabled"
        static let unplugGuardEnabled = "unplugGuardEnabled"
        static let lastKeepDisplayOff = "lastKeepDisplayOff"
        static let lastSessionHeat = "lastSessionHeat"
        static let sessionHeatInProgress = "sessionHeatInProgress"
        static let startShortcut = "startShortcut"
        static let startShortcutEnabled = "startShortcutEnabled"
        static let startShortcutMode = "startShortcutMode"
    }

    /// The battery levels offered in Settings. The check itself is turned
    /// off with `lowBatteryGuardEnabled`.
    static let minBatteryChoices = [5, 10, 15, 20, 25, 30]
    static let defaultMinBatteryPercent = 5

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

    /// The battery charge at which a session ends on battery power, 5 to 50,
    /// while `lowBatteryGuardEnabled` is on. Until 2.2.0, 0 stored here meant
    /// never; it now reads as the default level, with the check off.
    var minBatteryPercent: Int {
        get {
            guard let value = defaults.object(forKey: Keys.minBatteryPercent) as? Int,
                  (5...50).contains(value) else {
                return Self.defaultMinBatteryPercent
            }
            return value
        }
        set { defaults.set(newValue, forKey: Keys.minBatteryPercent) }
    }

    /// Whether a session ends on low battery. On until turned off in
    /// Settings, except that a stored level of 0, the `Never` of 2.2.0 and
    /// earlier, counts as off. Turning it off keeps the level.
    var lowBatteryGuardEnabled: Bool {
        get {
            if let stored = defaults.object(forKey: Keys.lowBatteryGuardEnabled) as? Bool {
                return stored
            }
            return (defaults.object(forKey: Keys.minBatteryPercent) as? Int) != 0
        }
        set { defaults.set(newValue, forKey: Keys.lowBatteryGuardEnabled) }
    }

    /// Whether a session ends when the Mac overheats. Stored inverted so the
    /// check is on until the user turns it off.
    var thermalGuardEnabled: Bool {
        get { !defaults.bool(forKey: Keys.thermalGuardDisabled) }
        set { defaults.set(!newValue, forKey: Keys.thermalGuardDisabled) }
    }

    /// Whether a session ends when the Mac is unplugged. Off until the user
    /// turns it on.
    var unplugGuardEnabled: Bool {
        get { defaults.bool(forKey: Keys.unplugGuardEnabled) }
        set { defaults.set(newValue, forKey: Keys.unplugGuardEnabled) }
    }

    /// The display choice of the last Caffeine session started from the app.
    /// The start picker opens with it; stored inverted so it starts out on.
    var lastKeepDisplay: Bool {
        get { !defaults.bool(forKey: Keys.lastKeepDisplayOff) }
        set { defaults.set(!newValue, forKey: Keys.lastKeepDisplayOff) }
    }

    /// How warm the Mac got during the last session that ended while the app
    /// ran, for the note in Settings. Stored as a dictionary, so `defaults
    /// read` shows the numbers; nil removes it.
    var lastSessionHeat: HeatSummary? {
        get { defaults.dictionary(forKey: Keys.lastSessionHeat).flatMap(HeatSummary.init(propertyList:)) }
        set { defaults.set(newValue.flatMap { $0.propertyList }, forKey: Keys.lastSessionHeat) }
    }

    /// The recording of the running session, so that a relaunch during it
    /// goes on with it; nil removes it.
    var sessionHeatInProgress: HeatSummary? {
        get { defaults.dictionary(forKey: Keys.sessionHeatInProgress).flatMap(HeatSummary.init(propertyList:)) }
        set { defaults.set(newValue.flatMap { $0.propertyList }, forKey: Keys.sessionHeatInProgress) }
    }

    /// The keyboard shortcut that starts or stops a session from any app,
    /// or nil until one is recorded or the shortcut is first turned on,
    /// which stores ⇧⌘A. Stored as a dictionary, so that `defaults read`
    /// shows it; nil removes it.
    var startShortcut: StartShortcut? {
        get { defaults.dictionary(forKey: Keys.startShortcut).flatMap(StartShortcut.init(propertyList:)) }
        set { defaults.set(newValue.map { $0.propertyList }, forKey: Keys.startShortcut) }
    }

    /// Whether the keyboard shortcut is on. Off until turned on in Settings,
    /// except that a shortcut recorded in 2.2.0, which had no such setting,
    /// stays on. Turning it off keeps the stored shortcut.
    var startShortcutEnabled: Bool {
        get {
            StartShortcut.isEnabled(
                storedFlag: defaults.object(forKey: Keys.startShortcutEnabled) as? Bool,
                hasStoredShortcut: startShortcut != nil
            )
        }
        set { defaults.set(newValue, forKey: Keys.startShortcutEnabled) }
    }

    /// What the keyboard shortcut starts: lid-open with the display on until
    /// changed. The picker keeps its own choice.
    var startShortcutMode: StartShortcutMode {
        get { StartShortcutMode(storedValue: defaults.string(forKey: Keys.startShortcutMode)) }
        set { defaults.set(newValue.rawValue, forKey: Keys.startShortcutMode) }
    }

    func snapshot() -> PreferencesSnapshot {
        PreferencesSnapshot(
            launchAtLoginEnabled: launchAtLoginEnabled,
            useCustomPasswordDialog: useCustomPasswordDialog,
            soundEnabled: soundEnabled,
            minBatteryPercent: lowBatteryGuardEnabled ? minBatteryPercent : 0,
            thermalGuardEnabled: thermalGuardEnabled,
            unplugGuardEnabled: unplugGuardEnabled
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

    /// Announces the session in `status`, which just started. The body says
    /// how it ends, as `awake` does in its own notification.
    func postStarted(soundEnabled: Bool, status: AwakeStatus) {
        let sessionBackend = status.sessionBackend ?? .awake
        let ending: String
        if let command = status.watchCommand, status.watchPid != nil {
            ending = "until \(command) exits"
        } else if status.endMode == "until", let label = status.deadlineLabel {
            ending = "until \(label)"
        } else if status.endMode == "none" {
            ending = "until you stop it"
        } else if let seconds = status.durationSeconds, seconds > 0 {
            // The length, as `awake`'s own notification names it: a start
            // with the keyboard shortcut shows it nowhere else.
            ending = "for \(PickerSettings.lengthLabel(seconds: seconds))"
        } else {
            ending = "until the chosen session ends"
        }
        postNotification(
            title: "Awake started",
            body: sessionBackend == .caffeinate
                ? "The Mac will stay awake while the lid remains open \(ending)."
                : "The Mac will stay awake with the lid closed \(ending).",
            soundEnabled: soundEnabled
        )
    }

    /// `processName` names the process a session tied to one waited for;
    /// only the status from before the end has it.
    func postStopped(soundEnabled: Bool, reason: String?, backend: AwakeBackend? = nil, processName: String? = nil) {
        let sessionBackend = backend ?? .awake
        let process = processName.map { "\($0), which Awake was waiting for," } ?? "The process Awake was waiting for"
        let body: String
        if sessionBackend == .caffeinate {
            switch reason {
            case "timeout":
                body = "The timed session finished."
            case "low_battery":
                body = "The battery ran low, so Awake stopped early. Connect the charger before starting again."
            case "overheated":
                body = "The Mac got too hot, so Awake stopped early to let it cool down."
            case "unplugged":
                body = "The Mac was unplugged, so Awake stopped."
            case "process_exited":
                body = "\(process) has exited."
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
            case "unplugged":
                body = "The Mac was unplugged, so Awake stopped and restored the normal sleep settings."
            case "process_exited":
                body = "\(process) has exited, and normal sleep settings were restored."
            case "failed":
                body = "Awake ended, but restoring the normal sleep settings needs attention."
            default:
                body = "Normal sleep settings were restored."
            }
        }

        // The same titles as `awake`'s own notifications. Like every
        // message, they name the program, Awake, also for a lid-open session.
        let title: String
        switch reason {
        case "timeout":
            title = "Awake finished"
        case "low_battery":
            title = "Awake stopped: the battery is low"
        case "overheated":
            title = "Awake stopped: the Mac got too hot"
        case "unplugged":
            title = "Awake stopped: the Mac was unplugged"
        case "process_exited":
            title = "Awake finished: the process it waited for exited"
        case "failed":
            title = "Awake failed"
        default:
            title = "Awake stopped"
        }
        postNotification(
            title: title,
            body: body,
            soundEnabled: soundEnabled
        )
    }

    func postFailure(message: String) {
        postNotification(
            title: "Awake failed",
            body: message,
            soundEnabled: false
        )
    }

    func postExtended(statusText: String) {
        postNotification(
            title: "Awake extended",
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
