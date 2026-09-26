// Copyright (C) 2026 Antti Käenmäki

import Foundation

enum AwakeBackend: String, Decodable {
    case awake
    case caffeinate

    var displayName: String {
        "Awake"
    }
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
    /// When this status was read. Not part of the JSON; lets the app count
    /// down `remainingSeconds` between polls.
    var fetchedAt = Date()

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

    /// `remainingSeconds` counted down from `fetchedAt` to `date`.
    func secondsLeft(at date: Date) -> Int? {
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

struct AwakeStartSelection: Decodable {
    let schemaVersion: Int
    let durationSeconds: Int
    let sessionBackend: AwakeBackend
    let keepLidClosed: Bool

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case durationSeconds = "duration_seconds"
        case sessionBackend = "session_backend"
        case keepLidClosed = "keep_lid_closed"
    }
}

enum PasswordCheck {
    case valid
    case incorrect
    case notAllowed(String)
}

struct AwakeCommandOutcome {
    let before: AwakeStatus
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
        let result = try runProcess(arguments: ["--status-json"], suppressNotifications: false)
        if let status = try? decoder.decode(AwakeStatus.self, from: Data(result.stdout.utf8)) {
            return status
        }
        throw AwakeCLIError.invalidStatusOutput(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Shows the duration and lid-mode picker. `defaultBackend` is the lid
    /// mode it opens with; without one the CLI uses the last session's.
    func promptStartSelection(defaultBackend: AwakeBackend?) throws -> AwakeStartSelection? {
        var arguments = ["--prompt-gui-selection"]
        if let defaultBackend {
            arguments.append(defaultBackend.rawValue)
        }
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
        if let selection = try? decoder.decode(AwakeStartSelection.self, from: Data(output.utf8)) {
            return selection
        }
        throw AwakeCLIError.invalidPromptOutput(output)
    }

    /// Starts a session. It never stops one: if a session is already running
    /// (for example one started in Terminal since the last poll), the CLI
    /// leaves it alone. Without a duration the CLI shows its picker, which
    /// opens with `backend` selected.
    func performStart(
        preferences: PreferencesSnapshot,
        customPassword: String?,
        durationSeconds: Int?,
        backend: AwakeBackend?,
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        commandQueue.async {
            let result = Result<AwakeCommandOutcome, Error> {
                let before = try self.fetchStatus()
                return try self.runCommand(
                    arguments: self.startArguments(preferences: preferences, durationSeconds: durationSeconds, backend: backend),
                    before: before,
                    customPassword: customPassword,
                    appCustomPasswordMode: preferences.useCustomPasswordDialog
                )
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
                let before = try self.fetchStatus()
                return try self.runCommand(
                    arguments: self.stopArguments(preferences: preferences),
                    before: before,
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
                let before = try self.fetchStatus()
                return try self.runCommand(
                    arguments: ["--gui"] + arguments,
                    before: before,
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
        before: AwakeStatus,
        customPassword: String?,
        appCustomPasswordMode: Bool
    ) throws -> AwakeCommandOutcome {
        let processResult = try runManagedCommand(
            arguments: arguments,
            customPassword: customPassword,
            appCustomPasswordMode: appCustomPasswordMode
        )
        let after = try fetchStatus()
        return AwakeCommandOutcome(before: before, after: after, processResult: processResult)
    }

    private func startArguments(preferences: PreferencesSnapshot, durationSeconds: Int?, backend: AwakeBackend?) -> [String] {
        var arguments = guiModeArguments(preferences: preferences)
        arguments.append("--start")
        if let durationSeconds {
            arguments.append("--duration-seconds")
            arguments.append(String(durationSeconds))
        }
        if let backend {
            arguments.append("--backend")
            arguments.append(backend.rawValue)
        }
        arguments.append("--min-battery")
        arguments.append(preferences.minBatteryPercent > 0 ? String(preferences.minBatteryPercent) : "off")
        arguments.append("--thermal-guard")
        arguments.append(preferences.thermalGuardEnabled ? "on" : "off")
        if preferences.soundEnabled {
            arguments.append("--sound")
        }
        return arguments
    }

    private func stopArguments(preferences: PreferencesSnapshot) -> [String] {
        var arguments = guiModeArguments(preferences: preferences)
        arguments.append("--stop")
        if preferences.soundEnabled {
            arguments.append("--sound")
        }
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
    /// end-of-file until the session ends.
    private func runManagedCommand(
        arguments: [String],
        customPassword: String?,
        appCustomPasswordMode: Bool
    ) throws -> ProcessResult {
        try ensureExecutable()

        let fileManager = FileManager.default
        let captureDirectory = fileManager.temporaryDirectory
        let stdoutURL = captureDirectory.appendingPathComponent("awake-statusbar-stdout-\(UUID().uuidString)")
        let stderrURL = captureDirectory.appendingPathComponent("awake-statusbar-stderr-\(UUID().uuidString)")
        defer {
            try? fileManager.removeItem(at: stdoutURL)
            try? fileManager.removeItem(at: stderrURL)
        }

        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle
        do {
            fileManager.createFile(atPath: stdoutURL.path, contents: Data())
            fileManager.createFile(atPath: stderrURL.path, contents: Data())
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
        process.environment = environment(
            suppressNotifications: true,
            appCustomPasswordMode: appCustomPasswordMode
        )

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

        let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
        let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
        return ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func environment(
        suppressNotifications: Bool,
        appCustomPasswordMode: Bool
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
        environment.removeValue(forKey: "AWAKE_GUI_CUSTOM_PASSWORD")
        return environment
    }

    private func ensureExecutable() throws {
        guard FileManager.default.isExecutableFile(atPath: InstallPaths.managedCLIURL.path) else {
            throw AwakeCLIError.missingExecutable(InstallPaths.managedCLIURL.path)
        }
    }
}
