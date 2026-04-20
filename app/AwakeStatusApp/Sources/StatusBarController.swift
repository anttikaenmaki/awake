import AppKit
import Foundation

final class StatusBarController: NSObject {
    private struct CustomStartSelection {
        let durationSeconds: Int
        let backend: AwakeBackend
    }

    private enum CustomStartAuthorization {
        case cancelled
        case noPasswordNeeded
        case password(String)
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let cli = AwakeCLI()
    private let preferences = PreferencesStore.shared
    private let notifications = NotificationController.shared
    private let launchAgentManager = LaunchAgentManager()
    private let readmeWindowController = ReadmeWindowController()

    private var currentStatus = AwakeStatus.inactivePlaceholder
    private var pollTimer: Timer?
    private var isCommandInFlight = false
    private var lastNotifiedCompletionIdentifier: String?
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
    }

    @objc
    private func handleStatusBarClick(_ sender: Any?) {
        guard !isCommandInFlight else {
            return
        }

        let event = NSApp.currentEvent
        let shouldOpenMenu = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if shouldOpenMenu {
            showContextMenu()
        } else {
            toggleAwake()
        }
    }

    private func toggleAwake() {
        let preferencesSnapshot = preferences.snapshot()
        var customPassword: String?
        var startDurationSeconds: Int?
        var startBackend: AwakeBackend?
        if !currentStatus.active && preferencesSnapshot.useCustomPasswordDialog {
            guard let selection = promptForCustomStartSelection() else {
                return
            }
            startDurationSeconds = selection.durationSeconds
            startBackend = selection.backend
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
        } else {
            customPassword = validCachedCustomPassword()
        }

        isCommandInFlight = true
        updateStatusItem()
        cli.performToggle(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            startDurationSeconds: startDurationSeconds,
            startBackend: startBackend
        ) { [weak self] result in
            self?.handleCommandResult(result, quitAfterStop: false)
        }
    }

    private func stopThenQuitIfNeeded() {
        guard !isCommandInFlight else {
            return
        }

        if !currentStatus.active {
            NSApp.terminate(nil)
            return
        }

        let preferencesSnapshot = preferences.snapshot()
        isCommandInFlight = true
        updateStatusItem()
        cli.performStop(preferences: preferencesSnapshot, customPassword: validCachedCustomPassword()) { [weak self] result in
            self?.handleCommandResult(result, quitAfterStop: true)
        }
    }

    private func handleCommandResult(_ result: Result<AwakeCommandOutcome, Error>, quitAfterStop: Bool) {
        isCommandInFlight = false

        switch result {
        case let .failure(error):
            currentStatus = AwakeStatus.errorPlaceholder(error.localizedDescription)
            updateStatusItem()
            clearCachedCustomPassword()
            notifications.postFailure(message: error.localizedDescription)
            return
        case let .success(outcome):
            currentStatus = outcome.after
            updateStatusItem()

            let soundEnabled = preferences.soundEnabled
            if outcome.processResult.exitCode != 0 {
                clearCachedCustomPassword()
                let message = normalizedErrorMessage(from: outcome.processResult)
                notifications.postFailure(message: message, backend: outcome.before.sessionBackend ?? outcome.after.sessionBackend)
                return
            }

            if !outcome.before.active && outcome.after.active {
                notifications.postStarted(soundEnabled: soundEnabled, backend: outcome.after.sessionBackend)
                return
            }

            if outcome.before.active && !outcome.after.active {
                rememberCompletionIfNeeded(from: outcome.after)
                playStopSoundIfNeeded(enabled: soundEnabled)
                notifications.postStopped(
                    soundEnabled: soundEnabled,
                    reason: outcome.after.lastCompletionReason,
                    backend: outcome.after.sessionBackend ?? outcome.before.sessionBackend
                )
                if quitAfterStop {
                    NSApp.terminate(nil)
                }
                return
            }

            if quitAfterStop {
                notifications.postQuitCancelled()
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
                if self.isCommandInFlight, previousStatus.active != status.active {
                    self.isCommandInFlight = false
                }
                self.currentStatus = status
                self.updateStatusItem()
                if notifyTransitions {
                    self.maybeNotifyCompletionTransition(from: previousStatus, to: status)
                }
            }
        }
    }

    private func maybeNotifyCompletionTransition(from previousStatus: AwakeStatus, to status: AwakeStatus) {
        guard previousStatus.active, !status.active else {
            return
        }
        guard let identifier = status.completionIdentifier, identifier != lastNotifiedCompletionIdentifier else {
            return
        }

        rememberCompletionIfNeeded(from: status)
        if status.lastCompletionReason == "failed" {
            if status.sessionBackend == .caffeinate {
                notifications.postFailure(message: "Awake stopped unexpectedly before the timed session finished.", backend: .caffeinate)
            } else {
                notifications.postFailure(message: "Awake stopped, but the normal sleep settings may still need attention.", backend: .awake)
            }
        } else {
            notifications.postStopped(soundEnabled: preferences.soundEnabled, reason: status.lastCompletionReason, backend: status.sessionBackend)
        }
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

        button.image = currentStatus.active ? onStatusImage() : offStatusImage()
        if isCommandInFlight {
            button.toolTip = "Awake is working..."
        } else {
            button.toolTip = currentStatus.displayText
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        let statusTitle = isCommandInFlight ? "Awake is working..." : currentStatus.displayText
        let statusMenuItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
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
        menu.addItem(customDialogItem)

        let soundItem = NSMenuItem(
            title: "Sound on",
            action: #selector(toggleSound(_:)),
            keyEquivalent: ""
        )
        soundItem.target = self
        soundItem.state = preferences.soundEnabled ? .on : .off
        menu.addItem(soundItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitAwake(_:)), keyEquivalent: "q")
        quitItem.target = self
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
        if let cachedPassword = validCachedCustomPassword() {
            return .password(cachedPassword)
        }
        if cli.hasValidSudoTicket() {
            return .noPasswordNeeded
        }
        guard let promptedPassword = promptForCustomPassword() else {
            return .cancelled
        }
        storeCustomPassword(promptedPassword)
        return .password(promptedPassword)
    }

    private func promptForCustomStartSelection() -> CustomStartSelection? {
        do {
            guard let selection = try cli.promptStartSelection() else {
                return nil
            }
            return CustomStartSelection(durationSeconds: selection.durationSeconds, backend: selection.sessionBackend)
        } catch {
            notifications.postFailure(message: error.localizedDescription)
            return nil
        }
    }

    private func promptForCustomPassword() -> String? {
        let process = Process()
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = [
            "-l",
            "JavaScript",
            "-",
            "Awake",
            "awake needs your password to start awake mode."
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

    private func onStatusImage() -> NSImage {
        loadStatusImage(resource: "awake-on", fallbackSymbol: "a.circle.fill")
    }

    private func offStatusImage() -> NSImage {
        loadStatusImage(resource: "awake-off", fallbackSymbol: "a.circle")
    }

    private func loadStatusImage(resource: String, fallbackSymbol: String) -> NSImage {
        if let url = Bundle.main.url(forResource: resource, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = false
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        let image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: nil) ?? NSImage()
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        return image
    }
}
