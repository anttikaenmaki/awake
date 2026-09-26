// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation

final class StatusBarController: NSObject {
    private struct CustomStartSelection {
        let durationSeconds: Int
        let backend: AwakeBackend
        let keepDisplay: Bool
    }

    /// What the user asked for. The app passes it to the CLI explicitly, so a
    /// click never does the opposite of what the icon showed, even when the
    /// state changed since the last poll.
    private enum CommandIntent {
        case start
        case extend
        case stop
        case stopAndQuit
    }

    private enum CustomStartAuthorization {
        case cancelled
        case noPasswordNeeded
        case password(String)
    }

    private enum PendingCommand {
        case starting
        case extending
        case stopping
        case configuring

        var statusText: String {
            switch self {
            case .starting:
                return "Starting Awake…"
            case .extending:
                return "Adding time…"
            case .stopping:
                return "Stopping Awake…"
            case .configuring:
                return "Updating Awake’s helper…"
            }
        }
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let cli = AwakeCLI()
    private let preferences = PreferencesStore.shared
    private let notifications = NotificationController.shared
    private let launchAgentManager = LaunchAgentManager()
    private let readmeWindowController = ReadmeWindowController()
    private lazy var onImage = statusImage(
        resource: "StatusOnTemplate",
        fallbackSymbol: "a.circle.fill",
        description: "Awake is on"
    )
    private lazy var offImage = statusImage(
        resource: "StatusOffTemplate",
        fallbackSymbol: "a.circle",
        description: "Awake is off"
    )

    private var currentStatus = AwakeStatus.inactivePlaceholder
    private var pollTimer: Timer?
    private var pendingCommand: PendingCommand?
    private var lastNotifiedCompletionIdentifier: String?
    /// Consecutive polls that found sleep disabled without a running session.
    private var stuckStatusPolls = 0
    private var cachedCustomPassword: String?
    private var cachedCustomPasswordExpiry: Date?
    private let customPasswordCacheLifetime: TimeInterval = 120

    func start() {
        guard let button = statusItem.button else {
            return
        }

        notifications.requestAuthorizationIfNeeded()
        preferences.launchAtLoginEnabled = launchAgentManager.isEnabled()

        button.target = self
        button.action = #selector(handleStatusBarClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()

        refreshStatus(notifyTransitions: false)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.refreshStatus(notifyTransitions: true)
        }
        pollTimer?.tolerance = 2.0
    }

    @objc
    private func handleStatusBarClick(_ sender: Any?) {
        let event = NSApp.currentEvent
        let shouldOpenMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if shouldOpenMenu {
            showContextMenu()
        } else if pendingCommand == nil {
            toggleAwake()
        }
    }

    /// A click does what the icon shows: it stops a session that is on and
    /// starts one otherwise.
    private func toggleAwake() {
        if currentStatus.active {
            stopAwake()
        } else {
            startAwake()
        }
    }

    private func startAwake() {
        let preferencesSnapshot = preferences.snapshot()
        var customPassword: String?
        var durationSeconds: Int?
        // Without a duration the CLI shows the picker, opening with the lid
        // mode used last time.
        var backend = preferences.lastBackend
        var keepDisplay = preferences.lastKeepDisplay
        if preferencesSnapshot.useCustomPasswordDialog {
            guard let selection = promptForCustomStartSelection() else {
                return
            }
            durationSeconds = selection.durationSeconds
            backend = selection.backend
            keepDisplay = selection.keepDisplay
            if selection.backend == .awake {
                switch customAuthorizationForAwakeStart() {
                case .cancelled:
                    return
                case .noPasswordNeeded:
                    customPassword = nil
                case let .password(password):
                    customPassword = password
                }
            }
        }

        pendingCommand = .starting
        updateStatusItem()
        cli.performStart(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            durationSeconds: durationSeconds,
            backend: backend,
            keepDisplay: keepDisplay
        ) { [weak self] result in
            self?.handleCommandResult(result, intent: .start)
        }
    }

    /// Adds an hour to the running session. The CLI treats a start with a
    /// duration while a session runs as added time.
    @objc
    private func addOneHour(_ sender: Any?) {
        guard pendingCommand == nil, currentStatus.active else {
            return
        }
        let preferencesSnapshot = preferences.snapshot()
        let backend = currentStatus.sessionBackend ?? .awake
        var customPassword: String?
        if preferencesSnapshot.useCustomPasswordDialog && backend == .awake {
            switch customAuthorizationForAwakeStart() {
            case .cancelled:
                return
            case .noPasswordNeeded:
                customPassword = nil
            case let .password(password):
                customPassword = password
            }
        }

        pendingCommand = .extending
        updateStatusItem()
        cli.performStart(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            durationSeconds: 3600,
            backend: backend,
            keepDisplay: currentStatus.keepDisplay ?? preferences.lastKeepDisplay
        ) { [weak self] result in
            self?.handleCommandResult(result, intent: .extend)
        }
    }

    private func stopAwake() {
        let preferencesSnapshot = preferences.snapshot()
        pendingCommand = .stopping
        updateStatusItem()
        cli.performStop(preferences: preferencesSnapshot, customPassword: validCachedCustomPassword()) { [weak self] result in
            self?.handleCommandResult(result, intent: .stop)
        }
    }

    private func stopThenQuitIfNeeded() {
        guard pendingCommand == nil else {
            return
        }

        if !currentStatus.active {
            NSApp.terminate(nil)
            return
        }

        let preferencesSnapshot = preferences.snapshot()
        pendingCommand = .stopping
        updateStatusItem()
        cli.performStop(preferences: preferencesSnapshot, customPassword: validCachedCustomPassword()) { [weak self] result in
            self?.handleCommandResult(result, intent: .stopAndQuit)
        }
    }

    private func handleCommandResult(_ result: Result<AwakeCommandOutcome, Error>, intent: CommandIntent) {
        let quitAfterStop = intent == .stopAndQuit
        pendingCommand = nil

        switch result {
        case let .failure(error):
            // Keep showing the last known state; the next poll corrects it.
            updateStatusItem()
            clearCachedCustomPassword()
            notifications.postFailure(message: error.localizedDescription)
            refreshStatus(notifyTransitions: true)
            return
        case let .success(outcome):
            currentStatus = outcome.after
            recordStopTime(from: outcome.before, to: outcome.after)
            updateStatusItem()

            let soundEnabled = preferences.soundEnabled
            if outcome.processResult.exitCode != 0 {
                clearCachedCustomPassword()
                let message = normalizedErrorMessage(from: outcome.processResult)
                notifications.postFailure(message: message, backend: outcome.before.sessionBackend ?? outcome.after.sessionBackend)
                return
            }

            if !outcome.before.active && outcome.after.active {
                preferences.appSessionToken = outcome.after.sessionToken
                preferences.lastBackend = outcome.after.sessionBackend
                if let keepDisplay = outcome.after.keepDisplay {
                    preferences.lastKeepDisplay = keepDisplay
                }
                notifications.postStarted(soundEnabled: soundEnabled, backend: outcome.after.sessionBackend)
                return
            }

            if intent == .extend && outcome.after.active {
                notifications.postExtended(
                    statusText: StatusDescription.text(for: outcome.after, lastStoppedAt: nil),
                    backend: outcome.after.sessionBackend
                )
                return
            }

            if intent == .start && outcome.before.active && outcome.after.active {
                // Started elsewhere since the last poll; the CLI left it running.
                notifications.postAlreadyOn(statusText: StatusDescription.text(for: outcome.after, lastStoppedAt: nil))
                return
            }

            if outcome.before.active && !outcome.after.active {
                rememberCompletionIfNeeded(from: outcome.after)
                // A session started elsewhere is announced by the process
                // that started it, so only confirm the app's own sessions.
                if isAppSession(outcome.before) {
                    playStopSoundIfNeeded(enabled: soundEnabled)
                    notifications.postStopped(
                        soundEnabled: soundEnabled,
                        reason: outcome.after.lastCompletionReason,
                        backend: outcome.after.sessionBackend ?? outcome.before.sessionBackend
                    )
                }
                if quitAfterStop {
                    NSApp.terminate(nil)
                }
                return
            }

            if quitAfterStop {
                // The session may have ended on its own since the last poll.
                if outcome.after.active {
                    notifications.postQuitCancelled()
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    private func refreshStatus(notifyTransitions: Bool) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                return
            }

            let status: AwakeStatus
            do {
                status = try self.cli.fetchStatus()
            } catch {
                status = AwakeStatus.errorPlaceholder(error.localizedDescription)
            }

            DispatchQueue.main.async {
                let previousStatus = self.currentStatus
                self.currentStatus = status
                self.recordStopTime(from: previousStatus, to: status)
                self.updateStatusItem()
                // While a start or stop runs, its result announces the change.
                if notifyTransitions && self.pendingCommand == nil {
                    self.maybeNotifyCompletionTransition(from: previousStatus, to: status)
                    self.maybeNotifyStuckStatus(status)
                }
            }
        }
    }

    /// Sleep can stay disabled without a running session, for example after
    /// a crash. The icon then shows Awake as on with no end time; say once
    /// what that means. Two polls in a row rule out a session that is just
    /// starting or ending.
    private func maybeNotifyStuckStatus(_ status: AwakeStatus) {
        guard status.active, !status.hasError, status.remainingSeconds == nil, status.sessionBackend != .caffeinate else {
            stuckStatusPolls = 0
            return
        }
        stuckStatusPolls += 1
        if stuckStatusPolls == 2 {
            notifications.postNeedsAttention(
                message: "Sleep is still turned off, but no Awake session is running. Click the Awake icon to restore normal sleep."
            )
        }
    }

    private func maybeNotifyCompletionTransition(from previousStatus: AwakeStatus, to status: AwakeStatus) {
        guard previousStatus.active, !status.active, !status.hasError else {
            return
        }
        guard let identifier = status.completionIdentifier, identifier != lastNotifiedCompletionIdentifier else {
            return
        }

        rememberCompletionIfNeeded(from: status)
        guard isAppSession(status) else {
            return
        }
        if status.lastCompletionReason == "failed" {
            if status.sessionBackend == .caffeinate {
                notifications.postFailure(message: "Awake stopped unexpectedly before the timed session finished.", backend: .caffeinate)
            } else {
                notifications.postFailure(message: "Awake stopped, but the normal sleep settings may still need attention.", backend: .awake)
            }
        } else {
            playStopSoundIfNeeded(enabled: preferences.soundEnabled)
            notifications.postStopped(soundEnabled: preferences.soundEnabled, reason: status.lastCompletionReason, backend: status.sessionBackend)
        }
    }

    private func isAppSession(_ status: AwakeStatus) -> Bool {
        guard let token = status.sessionToken, !token.isEmpty else {
            return false
        }
        return token == preferences.appSessionToken
    }

    /// Remembers when Awake last turned off so the status line can say how
    /// long it has been off. The CLI keeps completion times only in /tmp, so
    /// the app stores its own copy that survives restarts.
    private func recordStopTime(from previousStatus: AwakeStatus, to status: AwakeStatus) {
        guard !status.active, !status.hasError else {
            return
        }

        let sawSessionEnd = previousStatus.active && !previousStatus.hasError
        let stoppedAt: Date
        if let completedAt = status.lastCompletedDate,
           sawSessionEnd || status.lastCompletionReason != "failed" {
            // A failed record without an observed session is usually a start
            // that never got going, so it does not count as a stop.
            stoppedAt = completedAt
        } else if sawSessionEnd {
            stoppedAt = Date()
        } else {
            return
        }

        if let lastStoppedAt = preferences.lastStoppedAt, lastStoppedAt >= stoppedAt {
            return
        }
        preferences.lastStoppedAt = stoppedAt
    }

    private func rememberCompletionIfNeeded(from status: AwakeStatus) {
        if let identifier = status.completionIdentifier {
            lastNotifiedCompletionIdentifier = identifier
        }
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = currentStatus.active ? onImage : offImage
        button.toolTip = statusText()
    }

    private func statusText() -> String {
        if let pendingCommand {
            return pendingCommand.statusText
        }
        return StatusDescription.text(for: currentStatus, lastStoppedAt: preferences.lastStoppedAt)
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusMenuItem = NSMenuItem(title: statusText(), action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        // Only a running session has time to add to. Sleep left disabled
        // without a session shows as active but has no end time.
        if currentStatus.active && currentStatus.remainingSeconds != nil && !currentStatus.hasError {
            let addHourItem = NSMenuItem(
                title: "Add 1 hour",
                action: #selector(addOneHour(_:)),
                keyEquivalent: ""
            )
            addHourItem.target = self
            addHourItem.isEnabled = pendingCommand == nil
            menu.addItem(addHourItem)
        }
        menu.addItem(.separator())

        let guideItem = NSMenuItem(
            title: "About / Instructions...",
            action: #selector(showAwakeGuide(_:)),
            keyEquivalent: ""
        )
        guideItem.target = self
        menu.addItem(guideItem)
        menu.addItem(.separator())

        let launchAtLoginItem = NSMenuItem(
            title: "Launch at login",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        launchAtLoginItem.state = preferences.launchAtLoginEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        let customDialogItem = NSMenuItem(
            title: "Use custom password dialog",
            action: #selector(toggleCustomPasswordDialog(_:)),
            keyEquivalent: ""
        )
        customDialogItem.target = self
        customDialogItem.state = preferences.useCustomPasswordDialog ? .on : .off
        if currentStatus.passwordless == true {
            // No password is asked for, so there is no dialog to choose.
            customDialogItem.isEnabled = false
            customDialogItem.toolTip = "Not used while Start without password is on."
        }
        menu.addItem(customDialogItem)

        let passwordlessItem = NSMenuItem(
            title: "Start without password",
            action: #selector(togglePasswordless(_:)),
            keyEquivalent: ""
        )
        passwordlessItem.target = self
        passwordlessItem.state = currentStatus.passwordless == true ? .on : .off
        passwordlessItem.isEnabled = pendingCommand == nil
        passwordlessItem.toolTip = "Lets Awake's helper change the sleep settings without asking for your password. Other apps running as you could then change them too."
        menu.addItem(passwordlessItem)

        let soundItem = NSMenuItem(
            title: "Sound on",
            action: #selector(toggleSound(_:)),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = preferences.soundEnabled ? .on : .off
        menu.addItem(soundItem)

        // Guardrails apply to sessions started after a change.
        let batteryItem = NSMenuItem(title: "Stop at low battery", action: nil, keyEquivalent: "")
        let batteryMenu = NSMenu()
        for percent in PreferencesStore.minBatteryChoices {
            let item = NSMenuItem(
                title: percent == 0 ? "Never" : "\(percent)%",
                action: #selector(setMinBattery(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = percent
            item.state = preferences.minBatteryPercent == percent ? .on : .off
            batteryMenu.addItem(item)
        }
        batteryItem.submenu = batteryMenu
        batteryItem.toolTip = "Ends a session when the Mac runs on battery power and the charge drops to this level. Applies to the next session."
        menu.addItem(batteryItem)

        let thermalItem = NSMenuItem(
            title: "Stop when too hot",
            action: #selector(toggleThermalGuard(_:)),
            keyEquivalent: ""
        )
        thermalItem.target = self
        thermalItem.state = preferences.thermalGuardEnabled ? .on : .off
        thermalItem.toolTip = "Ends a session when macOS reports that the Mac is overheating, so it can sleep and cool down. Applies to the next session."
        menu.addItem(thermalItem)

        if currentStatus.helperInstalled == false {
            let installHelperItem = NSMenuItem(
                title: "Install Helper…",
                action: #selector(installHelper(_:)),
                keyEquivalent: ""
            )
            installHelperItem.target = self
            installHelperItem.isEnabled = pendingCommand == nil
            installHelperItem.toolTip = "Lid-closed mode needs Awake’s helper, which is installed with your administrator password."
            menu.addItem(installHelperItem)
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: currentStatus.active ? "Stop Awake and Quit" : "Quit",
            action: #selector(quitAwake(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = pendingCommand == nil
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        self.statusItem.button?.performClick(nil)
        self.statusItem.menu = nil
    }

    @objc
    private func toggleLaunchAtLogin(_ sender: Any?) {
        let newValue = !preferences.launchAtLoginEnabled
        do {
            try launchAgentManager.setEnabled(newValue)
            preferences.launchAtLoginEnabled = newValue
        } catch {
            notifications.postFailure(message: error.localizedDescription)
        }
    }

    @objc
    private func toggleCustomPasswordDialog(_ sender: Any?) {
        preferences.useCustomPasswordDialog.toggle()
        if !preferences.useCustomPasswordDialog {
            clearCachedCustomPassword()
        }
    }

    @objc
    private func toggleSound(_ sender: Any?) {
        preferences.soundEnabled.toggle()
    }

    @objc
    private func setMinBattery(_ sender: NSMenuItem) {
        preferences.minBatteryPercent = sender.tag
    }

    @objc
    private func toggleThermalGuard(_ sender: Any?) {
        preferences.thermalGuardEnabled.toggle()
    }

    @objc
    private func togglePasswordless(_ sender: Any?) {
        let enable = currentStatus.passwordless != true
        runMaintenance(arguments: ["--passwordless", enable ? "on" : "off"])
        if !enable {
            clearCachedCustomPassword()
        }
    }

    @objc
    private func installHelper(_ sender: Any?) {
        runMaintenance(arguments: ["--install-helper"])
    }

    private func runMaintenance(arguments: [String]) {
        guard pendingCommand == nil else {
            return
        }
        pendingCommand = .configuring
        updateStatusItem()
        cli.performMaintenance(arguments: arguments) { [weak self] result in
            guard let self else {
                return
            }
            self.pendingCommand = nil
            switch result {
            case let .failure(error):
                self.notifications.postFailure(message: error.localizedDescription)
            case let .success(outcome):
                self.currentStatus = outcome.after
                if outcome.processResult.exitCode != 0 {
                    self.notifications.postFailure(message: self.normalizedErrorMessage(from: outcome.processResult))
                }
            }
            self.updateStatusItem()
        }
    }

    @objc
    private func showAwakeGuide(_ sender: Any?) {
        readmeWindowController.showReadmeWindow()
    }

    @objc
    private func quitAwake(_ sender: Any?) {
        stopThenQuitIfNeeded()
    }

    private func normalizedErrorMessage(from result: ProcessResult) -> String {
        let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stderr.isEmpty {
            return stderr
        }
        let stdout = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stdout.isEmpty {
            return stdout
        }
        return "Awake returned exit code \(result.exitCode)."
    }

    private func validCachedCustomPassword() -> String? {
        guard let cachedCustomPassword, let cachedCustomPasswordExpiry else {
            return nil
        }
        if cachedCustomPasswordExpiry > Date() {
            return cachedCustomPassword
        }
        clearCachedCustomPassword()
        return nil
    }

    private func storeCustomPassword(_ password: String) {
        cachedCustomPassword = password
        cachedCustomPasswordExpiry = Date().addingTimeInterval(customPasswordCacheLifetime)
    }

    private func clearCachedCustomPassword() {
        cachedCustomPassword = nil
        cachedCustomPasswordExpiry = nil
    }

    private func customAuthorizationForAwakeStart() -> CustomStartAuthorization {
        // An out-of-date helper is updated first, which needs the password
        // even in password-free mode.
        if currentStatus.helperInstalled != false && cli.helperRunsWithoutPassword() {
            return .noPasswordNeeded
        }
        if let cachedPassword = validCachedCustomPassword() {
            return .password(cachedPassword)
        }

        let request = "Awake needs your password to change the sleep settings."
        var message = request
        for _ in 1...3 {
            guard let promptedPassword = promptForCustomPassword(message: message) else {
                return .cancelled
            }
            switch cli.verifyAdministratorPassword(promptedPassword) {
            case .valid:
                storeCustomPassword(promptedPassword)
                return .password(promptedPassword)
            case .incorrect:
                message = "The password was incorrect. Try again.\n\n\(request)"
            case let .notAllowed(reason):
                showAlert(reason)
                return .cancelled
            }
        }
        showAlert("The password was incorrect, so Awake did not start.")
        return .cancelled
    }

    private func showAlert(_ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Awake"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }

    private func promptForCustomStartSelection() -> CustomStartSelection? {
        do {
            guard let selection = try cli.promptStartSelection(
                defaultBackend: preferences.lastBackend,
                defaultKeepDisplay: preferences.lastKeepDisplay
            ) else {
                return nil
            }
            return CustomStartSelection(
                durationSeconds: selection.durationSeconds,
                backend: selection.sessionBackend,
                keepDisplay: selection.keepDisplay ?? preferences.lastKeepDisplay
            )
        } catch {
            notifications.postFailure(message: error.localizedDescription)
            return nil
        }
    }

    private func promptForCustomPassword(message: String) -> String? {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l",
            "JavaScript",
            "-",
            "Awake",
            message
        ]
        process.standardOutput = outputPipe
        process.standardError = Pipe()
        process.standardInput = inputPipe

        let script = """
        function run(argv) {
            const title = argv[0];
            const promptText = argv[1];
            const app = Application.currentApplication();
            app.includeStandardAdditions = true;
            try {
                const dialogResult = app.displayDialog(promptText, {
                    withTitle: title,
                    defaultAnswer: "",
                    hiddenAnswer: true,
                    buttons: ["Cancel", "OK"],
                    defaultButton: "OK",
                    cancelButton: "Cancel"
                });
                return dialogResult.textReturned;
            } catch (error) {
                if (error.errorNumber === -128) {
                    return "__CANCELLED__";
                }
                throw error;
            }
        }
        """

        do {
            try process.run()
        } catch {
            return nil
        }
        inputPipe.fileHandleForWriting.write(Data(script.utf8))
        try? inputPipe.fileHandleForWriting.close()
        process.waitUntilExit()

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0, output != "__CANCELLED__", !output.isEmpty else {
            return nil
        }
        return output
    }

    private func playStopSoundIfNeeded(enabled: Bool) {
        guard enabled else {
            return
        }
        NSSound(named: NSSound.Name("Tink"))?.play()
    }

    /// Loads a menu bar icon. Template images are tinted by macOS, so the
    /// glyph turns black on light menu bars and white on dark ones. The
    /// bundle lookup also picks up the @2x file for Retina displays.
    private func statusImage(resource: String, fallbackSymbol: String, description: String) -> NSImage {
        let image = Bundle.main.image(forResource: NSImage.Name(resource))
            ?? NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: description)
            ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        image.accessibilityDescription = description
        return image
    }
}
