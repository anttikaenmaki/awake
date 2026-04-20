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
    let error: String?

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
            error: message
        )
    }

    var displayText: String {
        if let error, !error.isEmpty {
            return error
        }
        return statusText ?? (active ? "Awake is on." : "Awake is off.")
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

    func hasValidSudoTicket() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = ["-n", "-v"]
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

    func fetchStatus() throws -> AwakeStatus {
        let result = try runProcess(arguments: ["--status-json"], suppressNotifications: false)
        if let status = try? decoder.decode(AwakeStatus.self, from: Data(result.stdout.utf8)) {
            return status
        }
        throw AwakeCLIError.invalidStatusOutput(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func promptStartSelection() throws -> AwakeStartSelection? {
        let result = try runProcess(arguments: ["--prompt-gui-selection"], suppressNotifications: true)
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

    func performToggle(
        preferences: PreferencesSnapshot,
        customPassword: String?,
        startDurationSeconds: Int?,
        startBackend: AwakeBackend?,
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        do {
            let before = try fetchStatus()
            let arguments = before.active
                ? stopArguments(preferences: preferences)
                : startArguments(preferences: preferences, durationSeconds: startDurationSeconds, backend: startBackend)
            runProcessAsync(
                arguments: arguments,
                suppressNotifications: true,
                customPassword: customPassword,
                appCustomPasswordMode: preferences.useCustomPasswordDialog
            ) { result in
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case let .success(processResult):
                    do {
                        let after = try self.fetchStatus()
                        completion(.success(AwakeCommandOutcome(before: before, after: after, processResult: processResult)))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    func performStop(
        preferences: PreferencesSnapshot,
        customPassword: String?,
        completion: @escaping (Result<AwakeCommandOutcome, Error>) -> Void
    ) {
        do {
            let before = try fetchStatus()
            runProcessAsync(
                arguments: stopArguments(preferences: preferences),
                suppressNotifications: true,
                customPassword: customPassword,
                appCustomPasswordMode: preferences.useCustomPasswordDialog
            ) { result in
                switch result {
                case let .failure(error):
                    completion(.failure(error))
                case let .success(processResult):
                    do {
                        let after = try self.fetchStatus()
                        completion(.success(AwakeCommandOutcome(before: before, after: after, processResult: processResult)))
                    } catch {
                        completion(.failure(error))
                    }
                }
            }
        } catch {
            completion(.failure(error))
        }
    }

    private func startArguments(preferences: PreferencesSnapshot, durationSeconds: Int?, backend: AwakeBackend?) -> [String] {
        var arguments = guiModeArguments(preferences: preferences)
        if let durationSeconds {
            arguments.append("--duration-seconds")
            arguments.append(String(durationSeconds))
        }
        if let backend {
            arguments.append("--backend")
            arguments.append(backend.rawValue)
        }
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

    private func runProcessAsync(
        arguments: [String],
        suppressNotifications: Bool,
        customPassword: String?,
        appCustomPasswordMode: Bool,
        completion: @escaping (Result<ProcessResult, Error>) -> Void
    ) {
        do {
            try ensureExecutable()
        } catch {
            completion(.failure(error))
            return
        }

        let process = Process()
        let stdinPipe = (appCustomPasswordMode || customPassword != nil) ? Pipe() : nil
        let captureDirectory = FileManager.default.temporaryDirectory
        let stdoutURL = captureDirectory.appendingPathComponent("awake-statusbar-stdout-\(UUID().uuidString)")
        let stderrURL = captureDirectory.appendingPathComponent("awake-statusbar-stderr-\(UUID().uuidString)")
        let stdoutHandle: FileHandle
        let stderrHandle: FileHandle

        do {
            FileManager.default.createFile(atPath: stdoutURL.path, contents: Data())
            FileManager.default.createFile(atPath: stderrURL.path, contents: Data())
            stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            stderrHandle = try FileHandle(forWritingTo: stderrURL)
        } catch {
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
            completion(.failure(AwakeCLIError.launchFailed(error.localizedDescription)))
            return
        }

        process.executableURL = InstallPaths.managedCLIURL
        process.arguments = arguments
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle
        if let stdinPipe {
            process.standardInput = stdinPipe
        }
        process.environment = environment(
            suppressNotifications: suppressNotifications,
            appCustomPasswordMode: appCustomPasswordMode
        )

        process.terminationHandler = { process in
            let stdout = (try? String(contentsOf: stdoutURL, encoding: .utf8)) ?? ""
            let stderr = (try? String(contentsOf: stderrURL, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
            let result = ProcessResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
            DispatchQueue.main.async {
                completion(.success(result))
            }
        }

        do {
            try process.run()
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
            if let stdinPipe {
                if let customPassword, let passwordData = "\(customPassword)\n".data(using: .utf8) {
                    stdinPipe.fileHandleForWriting.write(passwordData)
                }
                stdinPipe.fileHandleForWriting.closeFile()
            }
        } catch {
            stdoutHandle.closeFile()
            stderrHandle.closeFile()
            try? FileManager.default.removeItem(at: stdoutURL)
            try? FileManager.default.removeItem(at: stderrURL)
            stdinPipe?.fileHandleForWriting.closeFile()
            completion(.failure(AwakeCLIError.launchFailed(error.localizedDescription)))
        }
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
