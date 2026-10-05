// Copyright (C) 2026 Antti Käenmäki

import Foundation

enum AwakeBackend: String, Decodable {
    case awake
    case caffeinate
}

struct AwakeStatus: Decodable {
    let schemaVersion: Int
    let active: Bool
    let statusText: String?
    let remainingSeconds: Int?
    let durationSeconds: Int?
    let sessionMode: String?
    let sessionBackend: AwakeBackend?
    let soundNotifications: Bool?
    let sessionToken: String?
    let lastCompletionReason: String?
    let lastCompletedAt: Int?
    let lastRestoreResult: String?
    let helperInstalled: Bool?
    let passwordless: Bool?
    let error: String?
    /// For a running Caffeine session: whether it keeps the display on.
    var keepDisplay: Bool? = nil
    /// For a session tied to a process (`awake -w PID` or `awake -- CMD`):
    /// the process it waits for, and that process's name.
    var watchPid: Int? = nil
    var watchCommand: String? = nil
    /// How the running session ends: "duration", "until", or "none" (no end
    /// time).
    var endMode: String? = nil
    /// When the running session ends, in seconds since 1970, if it has an
    /// end time.
    var deadlineAt: Int? = nil
    /// That end time as the CLI words it: "18:30", "tomorrow 07:00", or
    /// "2026-09-30 07:00".
    var deadlineLabel: String? = nil
    /// Sleep is turned off, but no session is running, for example after a
    /// crash.
    var leftoverSettings: Bool? = nil
    /// A guardrail ended the last session and turned SleepDisabled off,
    /// although it was on before the session.
    var disablesleepForced: Bool? = nil
    /// The running lid-closed session was started by another account (with
    /// fast user switching, for example). Stopping it needs an administrator
    /// password.
    var otherUserSession: Bool? = nil
    /// When the read of this status started, or, for the status a command
    /// reported for the state it left, when that command exited, just after
    /// its read; for the state it found, when it was launched, just before
    /// its read. Not part of the JSON; lets the app count down
    /// `remainingSeconds` between polls.
    var fetchedAt = Date()
    /// `ProcessInfo.processInfo.systemUptime` at that same moment. Not part
    /// of the JSON; puts status reads in order, as the clock can be set back:
    /// for the heat report, and so that no poll that started before the read
    /// of the status shown counts as newer.
    var fetchedUptime = ProcessInfo.processInfo.systemUptime

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case active
        case statusText = "status_text"
        case remainingSeconds = "remaining_seconds"
        case durationSeconds = "duration_seconds"
        case sessionMode = "session_mode"
        case sessionBackend = "session_backend"
        case soundNotifications = "sound_notifications"
        case sessionToken = "session_token"
        case lastCompletionReason = "last_completion_reason"
        case lastCompletedAt = "last_completed_at"
        case lastRestoreResult = "last_restore_result"
        case helperInstalled = "helper_installed"
        case passwordless
        case error
        case keepDisplay = "keep_display"
        case watchPid = "watch_pid"
        case watchCommand = "watch_command"
        case endMode = "end_mode"
        case deadlineAt = "deadline_at"
        case deadlineLabel = "deadline_label"
        case leftoverSettings = "leftover_settings"
        case disablesleepForced = "disablesleep_forced"
        case otherUserSession = "other_user_session"
    }

    static let inactivePlaceholder = AwakeStatus(
        schemaVersion: 1,
        active: false,
        statusText: "Awake is off.",
        remainingSeconds: nil,
        durationSeconds: nil,
        sessionMode: nil,
        sessionBackend: nil,
        soundNotifications: nil,
        sessionToken: nil,
        lastCompletionReason: nil,
        lastCompletedAt: nil,
        lastRestoreResult: nil,
        helperInstalled: nil,
        passwordless: nil,
        error: nil
    )

    static func errorPlaceholder(_ message: String) -> AwakeStatus {
        AwakeStatus(
            schemaVersion: 1,
            active: false,
            statusText: "Awake is off.",
            remainingSeconds: nil,
            durationSeconds: nil,
            sessionMode: nil,
            sessionBackend: nil,
            soundNotifications: nil,
            sessionToken: nil,
            lastCompletionReason: nil,
            lastCompletedAt: nil,
            lastRestoreResult: nil,
            helperInstalled: nil,
            passwordless: nil,
            error: message
        )
    }

    var hasError: Bool {
        !(error ?? "").isEmpty
    }

    /// The time left at `date`: until `deadlineAt` when the session has an
    /// end time, otherwise `remainingSeconds` counted down from `fetchedAt`.
    func secondsLeft(at date: Date) -> Int? {
        if let deadlineAt {
            return max(deadlineAt - Int(date.timeIntervalSince1970), 0)
        }
        guard let reported = remainingSeconds else {
            return nil
        }
        let elapsed = max(Int(date.timeIntervalSince(fetchedAt)), 0)
        return max(reported - elapsed, 0)
    }

    var lastCompletedDate: Date? {
        lastCompletedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }

    var completionIdentifier: String? {
        guard let token = sessionToken, let completedAt = lastCompletedAt else {
            return nil
        }
        return "\(token):\(completedAt)"
    }
}

struct ProcessResult {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

/// A state-changing command's result, with the statuses it reported for the
/// state it found and the state it left, if it reported them.
private struct ManagedCommandResult {
    let processResult: ProcessResult
    /// Only some keys: a status that tells which session the command
    /// started from, never one to show (AWAKE_STATUS_BEFORE_JSON_FILE).
    let foundStatus: AwakeStatus?
    let reportedStatus: AwakeStatus?

    /// True when the CLI stopped at `option` as unknown: an awake older than
    /// this app, which then changed nothing. Every released version prints
    /// this line first, before its usage, and exits 1.
    func cliRefused(option: String) -> Bool {
        processResult.exitCode == 1 && foundStatus == nil && reportedStatus == nil &&
            processResult.stderr.hasPrefix("Unknown option: \(option)\n")
    }
}

struct AwakeStartSelection: Decodable {
    let schemaVersion: Int
    /// Kept for older apps; this app starts with `startArguments`.
    let durationSeconds: Int?
    let sessionBackend: AwakeBackend
    let keepLidClosed: Bool
    /// Missing from pickers older than the display choice.
    let keepDisplay: Bool?
    /// Exactly one end option for the start: `--duration-seconds N`,
    /// `--until @EPOCH`, `--indefinite`, or `-w PID`.
    let startArguments: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case durationSeconds = "duration_seconds"
        case sessionBackend = "session_backend"
        case keepLidClosed = "keep_lid_closed"
        case keepDisplay = "keep_display"
        case startArguments = "start_arguments"
    }

    /// True when `startArguments` is one of the end options the CLI sends.
    var hasValidStartArguments: Bool {
        switch startArguments.first ?? "" {
        case "--indefinite":
            return startArguments.count == 1
        case "--duration-seconds", "-w":
            return startArguments.count == 2 && Int(startArguments[1]) != nil
        case "--until":
            return startArguments.count == 2 && startArguments[1].hasPrefix("@") && Int(startArguments[1].dropFirst()) != nil
        default:
            return false
        }
    }
}

enum PasswordCheck {
    case valid
    case incorrect
    case notAllowed(String)
}

struct AwakeCommandOutcome {
    /// The state the command started from, as the CLI found it under its
    /// lock, with only the keys that tell which session that was; or, when
    /// an awake older than this app refused `--if-off`, as read just before
    /// the start. Nil when the CLI reported none: an awake older than this
    /// app, or one that stopped before it read the state under its lock,
    /// with an exit status other than 0. The app then judges the result
    /// from the status it showed (CommandResult.before).
    let before: AwakeStatus?
    let after: AwakeStatus
    let processResult: ProcessResult
}

enum AwakeCLIError: LocalizedError {
    case missingExecutable(String)
    case invalidStatusOutput(String)
    case invalidPromptOutput(String)
    case launchFailed(String)

    var errorDescription: String? {
        switch self {
        case let .missingExecutable(path):
            return "Awake is not installed at \(path). Run the installer again."
        case let .invalidStatusOutput(output):
            return "Awake returned an invalid status response: \(output)"
        case let .invalidPromptOutput(output):
            return "Awake returned an invalid start selection response: \(output)"
        case let .launchFailed(message):
            return message
        }
    }
}

final class AwakeCLI {
    private let decoder = JSONDecoder()
    /// Start and stop commands run here one at a time, off the main thread.
    private let commandQueue = DispatchQueue(label: "net.kaenmaki.awake.statusbar.command", qos: .userInitiated)

    /// True when password-free mode is set up: sudo runs the privileged
    /// helper without asking.
    func helperRunsWithoutPassword() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", InstallPaths.helperURL.path, "check"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return false
        }

        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Checks an administrator password with sudo without keeping a sudo
    /// session (-k), so a wrong password can be reported in the dialog.
    func verifyAdministratorPassword(_ password: String) -> PasswordCheck {
        let process = Process()
        let inputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-S", "-k", "-v", "-p", ""]
        process.standardInput = inputPipe
        process.standardOutput = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return .notAllowed(error.localizedDescription)
        }
        inputPipe.fileHandleForWriting.write(Data("\(password)\n".utf8))
        try? inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            return .valid
        }
        let output = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if output.contains("not in the sudoers") || output.contains("not allowed") || output.contains("may not run sudo") {
            return .notAllowed("Your account cannot make administrator changes, so Awake cannot change the sleep settings.")
        }
        return .incorrect
    }

    func fetchStatus() throws -> AwakeStatus {
        // The status describes the moment the read started, not when it
        // finished.
        let startedAt = Date()
        let startedUptime = ProcessInfo.processInfo.systemUptime
        let result = try runProcess(arguments: ["--status-json"], suppressNotifications: false)
        if var status = try? decoder.decode(AwakeStatus.self, from: Data(result.stdout.utf8)) {
            status.fetchedAt = startedAt
            status.fetchedUptime = startedUptime
            return status
        }
        throw AwakeCLIError.invalidStatusOutput(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Shows the duration, lid-mode, and display picker. `defaultBackend` is
    /// the lid mode it opens with; without one the CLI uses the last
    /// session's. `defaultKeepDisplay` is the display choice it opens with.
    func promptStartSelection(defaultBackend: AwakeBackend?, defaultKeepDisplay: Bool) throws -> AwakeStartSelection? {
        var arguments = ["--prompt-gui-selection"]
        arguments.append((defaultBackend ?? .awake).rawValue)
        arguments.append(defaultKeepDisplay ? "on" : "off")
        let result = try runProcess(arguments: arguments, suppressNotifications: true)
        if result.exitCode != 0 {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = !stderr.isEmpty ? stderr : (!stdout.isEmpty ? stdout : "Awake failed to display the start picker.")
            throw AwakeCLIError.launchFailed(message)
        }
        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if output == "CANCELLED" {
            return nil
        }
        if let selection = try? decoder.decode(AwakeStartSelection.self, from: Data(output.utf8)),
           selection.hasValidStartArguments {
            return selection
        }
        throw AwakeCLIError.invalidPromptOutput(output)
    }

    /// Starts a session. It never stops one: if a session is already running
    /// (for example one started in Terminal since the last poll), the CLI
    /// leaves it alone. Without a duration or `endArguments` the CLI shows its
    /// picker, which opens with `backend` selected; a session started in the
    /// other lid mode since the last poll then gets the CLI's refusal to add
    /// time across modes. With `startOnlyIfOff`, a running session gets no
    /// time added either: the CLI changes nothing (`--if-off`).
    func performStart(
        preferences: PreferencesSnapshot,
        customPassword: String?,
        durationSeconds: Int?,
        endArguments: [String] = [],
        backend: AwakeBackend?,
        keepDisplay: Bool,
        startOnlyIfOff: Bool = false,
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        commandQueue.async {
            let result = Result<AwakeCommandOutcome, Error> {
                let arguments = self.startArguments(
                    preferences: preferences,
                    durationSeconds: durationSeconds,
                    endArguments: endArguments,
                    backend: backend,
                    keepDisplay: keepDisplay,
                    onlyIfOff: startOnlyIfOff
                )
                let run = try self.runManagedCommand(
                    arguments: arguments,
                    customPassword: customPassword,
                    appCustomPasswordMode: preferences.useCustomPasswordDialog
                )
                guard startOnlyIfOff && run.cliRefused(option: "--if-off") else {
                    return try self.outcome(of: run)
                }
                // An awake older than this app: as older apps did, the status
                // is read first, and a session that is on is left alone.
                let before = try self.fetchStatus()
                if before.active {
                    return AwakeCommandOutcome(
                        before: before,
                        after: before,
                        processResult: ProcessResult(exitCode: 0, stdout: "", stderr: "")
                    )
                }
                let started = try self.runCommand(
                    arguments: arguments.filter { $0 != "--if-off" },
                    customPassword: customPassword,
                    appCustomPasswordMode: preferences.useCustomPasswordDialog
                )
                return AwakeCommandOutcome(before: before, after: started.after, processResult: started.processResult)
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func performStop(
        preferences: PreferencesSnapshot,
        customPassword: String?,
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        commandQueue.async {
            let result = Result<AwakeCommandOutcome, Error> {
                try self.runCommand(
                    arguments: self.stopArguments(preferences: preferences),
                    customPassword: customPassword,
                    appCustomPasswordMode: preferences.useCustomPasswordDialog
                )
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// Runs a setup command such as `--passwordless on`. It asks for the
    /// password with the macOS dialog.
    func performMaintenance(
        arguments: [String],
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        commandQueue.async {
            let result = Result<AwakeCommandOutcome, Error> {
                try self.runCommand(
                    arguments: ["--gui"] + arguments,
                    customPassword: nil,
                    appCustomPasswordMode: false
                )
            }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private func runCommand(
        arguments: [String],
        customPassword: String?,
        appCustomPasswordMode: Bool
    ) throws -> AwakeCommandOutcome {
        try outcome(of: runManagedCommand(
            arguments: arguments,
            customPassword: customPassword,
            appCustomPasswordMode: appCustomPasswordMode
        ))
    }

    private func outcome(of result: ManagedCommandResult) throws -> AwakeCommandOutcome {
        // The command reports the status it left. Without that report (an
        // older CLI, or one that stopped before its checks) it is read.
        let after = try result.reportedStatus ?? fetchStatus()
        return AwakeCommandOutcome(before: result.foundStatus, after: after, processResult: result.processResult)
    }

    /// Without a duration or `endArguments` the CLI shows its picker, which
    /// opens with `backend` and `keepDisplay`; the choices made there win.
    /// `--if-off` comes right after `--start`, so that an awake older than
    /// this app stops at it before it looks at anything else.
    private func startArguments(
        preferences: PreferencesSnapshot,
        durationSeconds: Int?,
        endArguments: [String],
        backend: AwakeBackend?,
        keepDisplay: Bool,
        onlyIfOff: Bool
    ) -> [String] {
        var arguments = guiModeArguments(preferences: preferences)
        arguments.append("--start")
        if onlyIfOff {
            arguments.append("--if-off")
        }
        if let durationSeconds {
            arguments.append("--duration-seconds")
            arguments.append(String(durationSeconds))
        }
        arguments.append(contentsOf: endArguments)
        if let backend {
            arguments.append("--backend")
            arguments.append(backend.rawValue)
        }
        arguments.append("--min-battery")
        arguments.append(preferences.minBatteryPercent > 0 ? String(preferences.minBatteryPercent) : "off")
        arguments.append("--thermal-guard")
        arguments.append(preferences.thermalGuardEnabled ? "on" : "off")
        arguments.append("--unplug-guard")
        arguments.append(preferences.unplugGuardEnabled ? "on" : "off")
        arguments.append("--keep-display")
        arguments.append(keepDisplay ? "on" : "off")
        // No --sound: the app plays the start and stop sounds itself, so a
        // start does not wait for awake to play it.
        return arguments
    }

    private func stopArguments(preferences: PreferencesSnapshot) -> [String] {
        var arguments = guiModeArguments(preferences: preferences)
        arguments.append("--stop")
        return arguments
    }

    private func guiModeArguments(preferences: PreferencesSnapshot) -> [String] {
        if preferences.useCustomPasswordDialog {
            return ["--gui-custom"]
        }
        return ["--gui"]
    }

    private func runProcess(arguments: [String], suppressNotifications: Bool) throws -> ProcessResult {
        try ensureExecutable()

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.executableURL = InstallPaths.managedCLIURL
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environment(
            suppressNotifications: suppressNotifications,
            appCustomPasswordMode: false
        )

        do {
            try process.run()
        } catch {
            throw AwakeCLIError.launchFailed(error.localizedDescription)
        }
        process.waitUntilExit()

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    /// Runs a state-changing command and waits for it. Output is captured in
    /// temporary files rather than pipes: a start leaves background helpers
    /// running that inherit the output handles, so a pipe would not reach
    /// end-of-file until the session ends. The CLI writes the status it
    /// leaves to a third file, named in `AWAKE_STATUS_JSON_FILE`, as
    /// `--status-json` would print it, and the state it found, before it
    /// changes anything, to a fourth, named in
    /// `AWAKE_STATUS_BEFORE_JSON_FILE`, with only some of those keys.
    private func runManagedCommand(
        arguments: [String],
        customPassword: String?,
        appCustomPasswordMode: Bool
    ) throws -> ManagedCommandResult {
        try ensureExecutable()

        let fileManager = FileManager.default
        let captureDirectory = fileManager.temporaryDirectory
        let stdoutURL = captureDirectory.appendingPathComponent("awake-statusbar-stdout-\(UUID().uuidString)")
        let stderrURL = captureDirectory.appendingPathComponent("awake-statusbar-stderr-\(UUID().uuidString)")
        let statusURL = captureDirectory.appendingPathComponent("awake-statusbar-status-\(UUID().uuidString)")
        let foundURL = captureDirectory.appendingPathComponent("awake-statusbar-found-\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
            try? fileManager.removeItem(at: statusURL)
            try? fileManager.removeItem(at: foundURL)
        }

        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle
        do {
            fileManager.createFile(atPath: stdoutURL.path, contents: Data())
            fileManager.createFile(atPath: stderrURL.path, contents: Data())
            // The CLI writes only into files that exist.
            fileManager.createFile(atPath: statusURL.path, contents: Data())
            fileManager.createFile(atPath: foundURL.path, contents: Data())
            stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            throw AwakeCLIError.launchFailed(error.localizedDescription)
        }
        defer {
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
        }

        let process = Process()
        let stdinPipe = (appCustomPasswordMode || customPassword != nil) ? Pipe() : nil
        process.executableURL = InstallPaths.managedCLIURL
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        if let stdinPipe {
            process.standardInput = stdinPipe
        }
        // A new name: `environment` would shadow the method in its own
        // initializer.
        var commandEnvironment = environment(
            suppressNotifications: true,
            appCustomPasswordMode: appCustomPasswordMode,
            passThermalState: true
        )
        commandEnvironment["AWAKE_STATUS_JSON_FILE"] = statusURL.path
        commandEnvironment["AWAKE_STATUS_BEFORE_JSON_FILE"] = foundURL.path
        process.environment = commandEnvironment

        // The CLI reads the state it found just after it starts.
        let launchedAt = Date()
        let launchedUptime = ProcessInfo.processInfo.systemUptime
        do {
            try process.run()
        } catch {
            stdinPipe?.fileHandleForWriting.closeFile()
            throw AwakeCLIError.launchFailed(error.localizedDescription)
        }
        if let stdinPipe {
            if let customPassword, let passwordData = "\(customPassword)\n".data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(passwordData)
            }
            stdinPipe.fileHandleForWriting.closeFile()
        }
        process.waitUntilExit()
        // The CLI read the status just before it exited.
        let exitedAt = Date()
        let exitedUptime = ProcessInfo.processInfo.systemUptime

        let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        var reportedStatus: AwakeStatus?
        if let data = try? Data(contentsOf: statusURL), !data.isEmpty,
           var status = try? decoder.decode(AwakeStatus.self, from: data) {
            status.fetchedAt = exitedAt
            status.fetchedUptime = exitedUptime
            reportedStatus = status
        }
        var foundStatus: AwakeStatus?
        if let data = try? Data(contentsOf: foundURL), !data.isEmpty,
           var status = try? decoder.decode(AwakeStatus.self, from: data) {
            status.fetchedAt = launchedAt
            status.fetchedUptime = launchedUptime
            foundStatus = status
        }
        return ManagedCommandResult(
            processResult: ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr),
            foundStatus: foundStatus,
            reportedStatus: reportedStatus
        )
    }

    private func environment(
        suppressNotifications: Bool,
        appCustomPasswordMode: Bool,
        passThermalState: Bool = false
    ) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        if suppressNotifications {
            environment["AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY"] = "true"
            environment.removeValue(forKey: "AWAKE_NO_NOTIFICATIONS")
        } else {
            environment.removeValue(forKey: "AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY")
        }
        if appCustomPasswordMode {
            environment["AWAKE_APP_CUSTOM_PASSWORD_MODE"] = "true"
        } else {
            environment.removeValue(forKey: "AWAKE_APP_CUSTOM_PASSWORD_MODE")
        }
        // A start or added time checks the thermal state first; the app's
        // reading spares the CLI an osascript run. Read here, right before
        // the command starts, as the CLI trusts it only for 30 seconds and
        // never hands it on. Status reads and the picker never pass it, not
        // even one the app itself was started with.
        if passThermalState, let state = HeatSummary.number(for: ProcessInfo.processInfo.thermalState) {
            environment["AWAKE_APP_THERMAL_STATE"] = String(state)
        } else {
            environment.removeValue(forKey: "AWAKE_APP_THERMAL_STATE")
        }
        environment.removeValue(forKey: "AWAKE_GUI_CUSTOM_PASSWORD")
        // Set by runManagedCommand alone.
        environment.removeValue(forKey: "AWAKE_STATUS_JSON_FILE")
        environment.removeValue(forKey: "AWAKE_STATUS_BEFORE_JSON_FILE")
        return environment
    }

    private func ensureExecutable() throws {
        guard FileManager.default.isExecutableFile(atPath: InstallPaths.managedCLIURL.path) else {
            throw AwakeCLIError.missingExecutable(InstallPaths.managedCLIURL.path)
        }
    }
}
