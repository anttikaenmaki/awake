// Copyright (C) 2026 Antti Käenmäki

import AppKit
import Foundation

final class StatusBarController: NSObject {
    private struct CustomStartSelection {
        /// The one end option the picker chose, for example `--until @EPOCH`.
        let startArguments: [String]
        let backend: AwakeBackend
        let keepDisplay: Bool
    }

    /// What the user asked for (CommandResult.swift).
    private typealias CommandIntent = CommandResult.Intent

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
    /// Built when Settings is first opened; it redraws on every state change.
    private lazy var settingsWindowController: SettingsWindowController = {
        let controller = SettingsWindowController(host: self)
        self.onStateChange = { [weak controller] in
            controller?.reloadIfVisible()
        }
        return controller
    }()
    /// Called on the main queue after the status, a pending command, or a
    /// setting changes, so an open Settings window can show the real state.
    private var onStateChange: (() -> Void)?
    private lazy var onImage = statusImage(
        resource: "StatusOnTemplate",
        fallbackSymbol: "a.circle.fill",
        description: StatusIcon.onLabel
    )
    private lazy var offImage = statusImage(
        resource: "StatusOffTemplate",
        fallbackSymbol: "a.circle",
        description: StatusIcon.offLabel
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
    /// How hot the Mac gets during each session, for the note in Settings,
    /// going on from the recording saved before the app last quit.
    private lazy var heatRecorder: HeatRecorder = HeatRecorder(
        saved: preferences.sessionHeatInProgress,
        lastFinishedToken: preferences.lastSessionHeat?.sessionToken
    )
    /// Keeps App Nap from slowing the polls while a session is recorded.
    private var heatActivity: NSObjectProtocol?
    /// The uptime when the recording in progress was last saved.
    private var lastHeatSaveUptime: TimeInterval?
    private var heatObservers: [NSObjectProtocol] = []
    /// The keyboard shortcut that starts or stops a session from any app.
    private let startShortcutHotKey = StartShortcutHotKey()
    /// The Ctrl-click menu while it is open, so that a press of the shortcut
    /// can close it, as a key equivalent of the menu's own would.
    private weak var openContextMenu: NSMenu?
    /// Why the stored shortcut is not registered, for the Settings window.
    private var startShortcutFailure: String?
    /// Carbon's event time when the app's last prompt of its own closed. A
    /// press from before then was queued while the prompt held the main
    /// thread, and is dropped: it would act once the prompt closed, also
    /// after a cancel.
    private var lastPromptEndedAt: TimeInterval = 0

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

        startShortcutHotKey.onPress = { [weak self] time in
            self?.startShortcutPressed(at: time)
        }
        registerStoredStartShortcut(notifyOnFailure: true)

        observeHeatEvents()
        // Also drops a saved recording that the recorder left out.
        saveHeatInProgress()
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
        var endArguments: [String] = []
        // Without an end option the CLI shows the picker, opening with the
        // lid mode used last time.
        var backend = preferences.lastBackend
        var keepDisplay = preferences.lastKeepDisplay
        if preferencesSnapshot.useCustomPasswordDialog {
            guard let selection = promptForCustomStartSelection() else {
                return
            }
            endArguments = selection.startArguments
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

        // Without an end option the CLI shows its picker, which can be
        // cancelled, so the icon only dims. The app's own picker has chosen
        // one already, and its password dialog, if any, has closed.
        pendingCommand = .starting(StatusIcon.startPreview(
            lengthChosen: !endArguments.isEmpty,
            lidClosed: backend == .awake,
            cliMayAskForPassword: cliMayAskForPassword(runsHelper: backend == .awake, preferencesSnapshot)
        ))
        updateStatusItem()
        let shown = currentStatus
        cli.performStart(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            durationSeconds: nil,
            endArguments: endArguments,
            backend: backend,
            keepDisplay: keepDisplay
        ) { [weak self] result in
            self?.handleCommandResult(result, intent: .start, shown: shown)
        }
    }

    /// Adds the time to add from Settings, an hour until changed, to the
    /// running session. The CLI treats a start with a duration while a
    /// session runs as added time.
    @objc
    private func addTime(_ sender: Any?) {
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
        let shown = currentStatus
        cli.performStart(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            durationSeconds: preferences.addTimeSeconds,
            backend: backend,
            keepDisplay: currentStatus.keepDisplay ?? preferences.lastKeepDisplay
        ) { [weak self] result in
            self?.handleCommandResult(result, intent: .extend, shown: shown)
        }
    }

    // MARK: Keyboard shortcut

    /// Registers the stored keyboard shortcut while it is on. When it is on
    /// and none is stored, ⇧⌘A is stored first, with the key that types A in
    /// the keyboard layout in use, after the check a recorded shortcut gets.
    /// At launch a failure to register is also posted once, since the key
    /// will not work.
    private func registerStoredStartShortcut(notifyOnFailure: Bool) {
        startShortcutFailure = nil
        guard preferences.startShortcutEnabled else {
            startShortcutHotKey.unregister()
            return
        }
        let shortcut: StartShortcut
        if let stored = preferences.startShortcut {
            shortcut = stored
        } else {
            let fallback = StartShortcut.defaultShortcut(keyCode: StartShortcutHotKey.keyCode(typing: "a"))
            if let problem = fallback.problem(macOSShortcuts: StartShortcutHotKey.macOSShortcuts()) {
                // Not stored, so that Settings goes on showing ⇧⌘A with
                // the reason, until another shortcut is recorded.
                startShortcutHotKey.unregister()
                startShortcutFailure = fallback.message(for: problem)
                return
            }
            preferences.startShortcut = fallback
            shortcut = fallback
        }
        if let failure = startShortcutHotKey.register(shortcut) {
            startShortcutFailure = shortcut.registrationFailureMessage(takenByAnotherApp: failure.takenByAnotherApp, status: failure.status)
            if notifyOnFailure {
                notifications.postNeedsAttention(
                    message: shortcut.launchFailureMessage(takenByAnotherApp: failure.takenByAnotherApp, status: failure.status)
                )
            }
        }
    }

    /// A press of the keyboard shortcut does what a click on the icon does,
    /// without the picker. It beeps while a command runs, and is dropped
    /// during one of the app's own alerts or prompts.
    private func startShortcutPressed(at time: TimeInterval) {
        // The press does what Start default session or Stop session would,
        // whose title would then be stale.
        openContextMenu?.cancelTracking()
        guard time > lastPromptEndedAt, NSApp.modalWindow == nil else {
            return
        }
        guard pendingCommand == nil else {
            NSSound.beep()
            return
        }
        if currentStatus.active {
            stopAwake()
        } else {
            startDefaultSession()
        }
    }

    /// Starts a session of the Settings window's default length, in the
    /// shortcut's mode, with the Guardrails settings, for the keyboard
    /// shortcut and Start default session in the menu. It never adds time to
    /// a session started elsewhere since the last poll: the app then says
    /// that Awake is already on.
    private func startDefaultSession() {
        let preferencesSnapshot = preferences.snapshot()
        let mode = preferences.startShortcutMode
        let request = StartShortcut.startRequest(defaultToken: PickerSettings.load().defaultToken)
        let backend: AwakeBackend = mode.isLidClosed ? .awake : .caffeinate
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

        pendingCommand = .starting(StatusIcon.startPreview(
            lengthChosen: true,
            lidClosed: mode.isLidClosed,
            cliMayAskForPassword: cliMayAskForPassword(runsHelper: backend == .awake, preferencesSnapshot)
        ))
        updateStatusItem()
        let shown = currentStatus
        cli.performStart(
            preferences: preferencesSnapshot,
            customPassword: customPassword,
            durationSeconds: request.durationSeconds,
            endArguments: request.endArguments,
            backend: backend,
            keepDisplay: mode.keepsDisplayOn,
            startOnlyIfOff: true
        ) { [weak self] result in
            self?.handleCommandResult(result, intent: .defaultStart, shown: shown)
        }
    }

    /// Stops the session; with `.stopAndQuit`, the app then quits once the
    /// stop succeeded.
    private func stopAwake(intent: CommandIntent = .stop) {
        let preferencesSnapshot = preferences.snapshot()
        guard let customPassword = customPasswordForStop(preferencesSnapshot) else {
            return
        }
        pendingCommand = .stopping(StatusIcon.stopPreview(
            cliMayAskForPassword: cliMayAskForPassword(runsHelper: stopRunsHelper, preferencesSnapshot)
        ))
        updateStatusItem()
        let shown = currentStatus
        cli.performStop(preferences: preferencesSnapshot, customPassword: customPassword) { [weak self] result in
            self?.handleCommandResult(result, intent: intent, shown: shown)
        }
    }

    /// Settings left without a session, or another account's session, are
    /// restored by running the helper. A stop needs no helper while the
    /// helper's timer runs: the CLI asks the timer to stop.
    private var stopRunsHelper: Bool {
        currentStatus.leftoverSettings == true || currentStatus.otherUserSession == true
    }

    /// Whether the CLI may show the macOS password dialog for a command,
    /// judged from the last status. The icon then only dims.
    private func cliMayAskForPassword(runsHelper: Bool, _ preferencesSnapshot: PreferencesSnapshot) -> Bool {
        StatusIcon.cliMayAskForPassword(
            runsHelper: runsHelper,
            customPasswordDialog: preferencesSnapshot.useCustomPasswordDialog,
            passwordless: currentStatus.passwordless,
            helperInstalled: currentStatus.helperInstalled
        )
    }

    /// The password for a stop, or nil when the user cancelled Awake's own
    /// password dialog. A stop that runs the helper needs, in custom
    /// password mode, the password from Awake's dialog: the CLI does not ask
    /// then, as the app owns the dialog.
    private func customPasswordForStop(_ preferencesSnapshot: PreferencesSnapshot) -> String?? {
        guard preferencesSnapshot.useCustomPasswordDialog, stopRunsHelper else {
            return .some(validCachedCustomPassword())
        }
        switch customAuthorizationForAwakeStart() {
        case .cancelled:
            return nil
        case .noPasswordNeeded:
            return .some(nil)
        case let .password(password):
            return .some(password)
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
        stopAwake(intent: .stopAndQuit)
    }

    /// `shown` is the status the app showed when the command was asked for.
    private func handleCommandResult(_ result: Result<AwakeCommandOutcome, Error>, intent: CommandIntent, shown: AwakeStatus) {
        pendingCommand = nil

        switch result {
        case let .failure(error):
            // Back to the last known state from what the icon showed while
            // the command ran; the poll below corrects it.
            updateStatusItem()
            clearCachedCustomPassword()
            notifications.postFailure(message: error.localizedDescription)
            refreshStatus(notifyTransitions: true)
            return
        case let .success(outcome):
            // A session shown as on may have ended on its own before the
            // command took the CLI's lock. Its end is posted as the poll
            // that missed it would have posted it, and only once. Without
            // the status found, a CLI that failed stopped before its lock
            // and changed nothing, so the status read after it serves.
            if let found = CommandResult.foundOrRead(
                found: outcome.before,
                after: outcome.after,
                exitCode: outcome.processResult.exitCode
            ),
               CommandResult.endedBeforeCommand(shown: shown.commandFacts, found: found.commandFacts) {
                recordStopTime(from: shown, to: found)
                maybeNotifyCompletionTransition(from: shown, to: found)
            }
            let before = CommandResult.before(found: outcome.before, shown: shown)
            currentStatus = outcome.after
            recordStopTime(from: before, to: outcome.after)
            // Before a quit, so that Stop Awake and quit saves the summary.
            recordHeat(from: outcome.after)
            updateStatusItem()

            let soundEnabled = preferences.soundEnabled
            let announcement = CommandResult.announcement(
                intent: intent,
                exitCode: outcome.processResult.exitCode,
                before: before.commandFacts,
                after: outcome.after.commandFacts,
                appSessionToken: preferences.appSessionToken
            )
            switch announcement {
            case .failed:
                clearCachedCustomPassword()
                notifications.postFailure(message: normalizedErrorMessage(from: outcome.processResult))
            case .started:
                announceStart(outcome.after, intent: intent, soundEnabled: soundEnabled)
            case let .replaced(appSession):
                // Added time met the session's own end behind its password
                // dialog, and the CLI started a new session. The old one's
                // end is posted once, as a poll would have; the new one is
                // the app's start.
                if appSession {
                    announceReplacedEnd(before: before, after: outcome.after, soundEnabled: soundEnabled)
                }
                announceStart(outcome.after, intent: intent, soundEnabled: soundEnabled)
            case .extended:
                notifications.postExtended(
                    statusText: StatusDescription.text(for: outcome.after, lastStoppedAt: nil)
                )
            case .alreadyOn:
                notifications.postAlreadyOn(statusText: StatusDescription.text(for: outcome.after, lastStoppedAt: nil))
            case let .ended(appSession):
                rememberCompletionIfNeeded(from: outcome.after)
                if appSession {
                    playSoundIfNeeded(enabled: soundEnabled)
                    notifications.postStopped(
                        soundEnabled: soundEnabled,
                        reason: outcome.after.lastCompletionReason,
                        backend: outcome.after.sessionBackend ?? before.sessionBackend,
                        processName: before.watchCommand
                    )
                }
            case .nothing:
                break
            }
            switch CommandResult.quit(intent: intent, announcement: announcement, after: outcome.after.commandFacts) {
            case .quit:
                NSApp.terminate(nil)
            case .cancelled:
                notifications.postQuitCancelled()
            case .no:
                break
            }
        }
    }

    /// Takes the session in `status`, which a command just started, as the
    /// app's own, and announces it.
    private func announceStart(_ status: AwakeStatus, intent: CommandIntent, soundEnabled: Bool) {
        preferences.appSessionToken = status.sessionToken
        // The picker opens with the choices made in it, which a start of the
        // default session, in the shortcut's mode, leaves alone.
        if intent != .defaultStart {
            preferences.lastBackend = status.sessionBackend
            if let keepDisplay = status.keepDisplay {
                preferences.lastKeepDisplay = keepDisplay
            }
        }
        playSoundIfNeeded(enabled: soundEnabled)
        notifications.postStarted(soundEnabled: soundEnabled, status: status)
    }

    /// Posts the end of the app's session that added time met: its token,
    /// lid mode and process come from `before`, the state the command
    /// started from; its reason and time from `after`, whose last finished
    /// session it is. Only once, like an end a poll posts.
    private func announceReplacedEnd(before: AwakeStatus, after: AwakeStatus, soundEnabled: Bool) {
        if let token = before.sessionToken, let completedAt = after.lastCompletedAt {
            let identifier = "\(token):\(completedAt)"
            if identifier == lastNotifiedCompletionIdentifier {
                return
            }
            lastNotifiedCompletionIdentifier = identifier
        }
        playSoundIfNeeded(enabled: soundEnabled)
        notifications.postStopped(
            soundEnabled: soundEnabled,
            reason: after.lastCompletionReason,
            backend: before.sessionBackend,
            processName: before.watchCommand
        )
    }

    private func refreshStatus(notifyTransitions: Bool) {
        // A start or a stop brings the status read when it ends; a poll
        // meanwhile would only compete with it.
        if pendingCommand?.pausesPolls == true {
            return
        }
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else {
                return
            }

            // A failed read describes the moment it started too, so that it
            // is put in order with the others.
            let startedAt = Date()
            let startedUptime = ProcessInfo.processInfo.systemUptime
            let status: AwakeStatus
            do {
                status = try self.cli.fetchStatus()
            } catch {
                var failed = AwakeStatus.errorPlaceholder(error.localizedDescription)
                failed.fetchedAt = startedAt
                failed.fetchedUptime = startedUptime
                status = failed
            }

            DispatchQueue.main.async {
                // A read that ends while a start or a stop runs, or that
                // started before the status shown, would undo a newer
                // state, such as the icon a start just turned bold.
                guard PendingCommand.pollResultApplies(
                    readStartedAt: status.fetchedUptime,
                    shownReadStartedAt: self.currentStatus.fetchedUptime,
                    pending: self.pendingCommand
                ) else {
                    return
                }
                let previousStatus = self.currentStatus
                self.currentStatus = status
                self.recordStopTime(from: previousStatus, to: status)
                // Before the redraw, so an open Settings window shows the
                // note as soon as a session ends.
                self.recordHeat(from: status)
                self.updateStatusItem()
                // While a start, extend, or stop runs, its result announces
                // the change. Updating the helper announces nothing, so a
                // session that ends meanwhile is still reported.
                if notifyTransitions && (self.pendingCommand == nil || self.pendingCommand == .configuring) {
                    self.maybeNotifyCompletionTransition(from: previousStatus, to: status)
                    self.maybeNotifyStuckStatus(status)
                }
            }
        }
    }

    /// Sleep can stay disabled without a running session, for example after
    /// a crash. The icon then shows Awake as on; say once what that means.
    /// Two polls in a row rule out a session that is just starting or ending.
    private func maybeNotifyStuckStatus(_ status: AwakeStatus) {
        guard status.active, !status.hasError, status.leftoverSettings == true else {
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
                notifications.postFailure(message: "Awake stopped unexpectedly before the session finished.")
            } else {
                notifications.postFailure(message: "Awake stopped, but the normal sleep settings may still need attention.")
            }
        } else {
            playSoundIfNeeded(enabled: preferences.soundEnabled)
            notifications.postStopped(
                soundEnabled: preferences.soundEnabled,
                reason: status.lastCompletionReason,
                backend: status.sessionBackend,
                processName: previousStatus.watchCommand
            )
        }
    }

    private func isAppSession(_ status: AwakeStatus) -> Bool {
        CommandResult.isAppSession(status.commandFacts, appSessionToken: preferences.appSessionToken)
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

    /// Feeds a status read to the heat recorder. A finished summary is saved
    /// for the note in Settings, and the recording in progress once a minute,
    /// so that a relaunch during the session goes on with it.
    private func recordHeat(from status: AwakeStatus) {
        guard let poll = HeatPoll(
            at: status.fetchedAt,
            uptime: status.fetchedUptime,
            active: status.active,
            hasError: status.hasError,
            leftoverSettings: status.leftoverSettings == true,
            otherUserSession: status.otherUserSession == true,
            sessionToken: status.sessionToken,
            lastCompletedAt: status.lastCompletedAt,
            lastCompletionReason: status.lastCompletionReason,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue
        ) else {
            return
        }
        let finished = heatRecorder.observe(poll)
        if let finished = finished {
            preferences.lastSessionHeat = finished
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        let minutePassed = lastHeatSaveUptime.map { uptime - $0 >= 60 } ?? true
        if finished != nil || (heatRecorder.isRecording && minutePassed) {
            saveHeatInProgress()
        }
        updateHeatActivity()
    }

    /// Saves the recording in progress, or removes the saved one when
    /// nothing is being recorded.
    private func saveHeatInProgress() {
        preferences.sessionHeatInProgress = heatRecorder.inProgress
        lastHeatSaveUptime = ProcessInfo.processInfo.systemUptime
    }

    /// Keeps App Nap from slowing the timers while a session is recorded.
    /// The activity lets the Mac sleep, so it never gets in the way of the
    /// session's own sleep handling.
    private func updateHeatActivity() {
        if heatRecorder.isRecording, heatActivity == nil {
            heatActivity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep,
                reason: "Recording how warm the Mac gets during an Awake session"
            )
        } else if !heatRecorder.isRecording, let activity = heatActivity {
            ProcessInfo.processInfo.endActivity(activity)
            heatActivity = nil
        }
    }

    /// Feeds the heat recorder the thermal changes, sleep and wake, each with
    /// the uptime when it arrives, and saves the recording in progress when
    /// the Mac goes to sleep and when the app quits.
    private func observeHeatEvents() {
        let center = NotificationCenter.default
        let workspace = NSWorkspace.shared.notificationCenter
        heatObservers = [
            center.addObserver(forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.heatRecorder.thermalStateChanged(
                    to: ProcessInfo.processInfo.thermalState.rawValue,
                    uptime: ProcessInfo.processInfo.systemUptime
                )
            },
            workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else {
                    return
                }
                self.heatRecorder.systemWillSleep(uptime: ProcessInfo.processInfo.systemUptime)
                if self.heatRecorder.isRecording {
                    self.saveHeatInProgress()
                }
            },
            workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.heatRecorder.systemDidWake(uptime: ProcessInfo.processInfo.systemUptime)
            },
            center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else {
                    return
                }
                if self.heatRecorder.isRecording {
                    self.saveHeatInProgress()
                }
            },
        ]
    }

    private func rememberCompletionIfNeeded(from status: AwakeStatus) {
        if let identifier = status.completionIdentifier {
            lastNotifiedCompletionIdentifier = identifier
        }
    }

    // Follows every change of the status and of a pending command. While a
    // start or a stop runs, the icon shows what it leads to, or dims while
    // that is not known (StatusIcon.swift).
    private func updateStatusItem() {
        defer {
            onStateChange?()
        }
        guard let button = statusItem.button else {
            return
        }

        let icon = StatusIcon(active: currentStatus.active, pending: pendingCommand)
        button.image = icon.showsOn ? onImage : offImage
        button.appearsDisabled = icon.dimmed
        button.setAccessibilityLabel(icon.accessibilityLabel)
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
        // Only a session with an end time has time to add to. Sessions
        // without one, and sleep left disabled without a session, have none.
        if currentStatus.active && currentStatus.deadlineAt != nil && !currentStatus.hasError {
            let addTimeItem = NSMenuItem(
                title: "Add \(PickerSettings.lengthLabel(seconds: preferences.addTimeSeconds))",
                action: #selector(addTime(_:)),
                keyEquivalent: ""
            )
            addTimeItem.target = self
            addTimeItem.isEnabled = pendingCommand == nil
            menu.addItem(addTimeItem)
        }
        menu.addItem(defaultSessionMenuItem())
        menu.addItem(.separator())

        let helpItem = NSMenuItem(
            title: "Help",
            action: #selector(showAwakeGuide(_:)),
            keyEquivalent: ""
        )
        helpItem.target = self
        menu.addItem(helpItem)

        // The settings live in their own window.
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(showSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        if currentStatus.helperInstalled == false {
            let installHelperItem = NSMenuItem(
                title: "Install helper…",
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
            title: currentStatus.active ? "Stop Awake and quit" : "Quit",
            action: #selector(quitAwake(_:)),
            keyEquivalent: "q"
        )
        quitItem.target = self
        quitItem.isEnabled = pendingCommand == nil
        menu.addItem(quitItem)

        self.statusItem.menu = menu
        openContextMenu = menu
        self.statusItem.button?.performClick(nil)
        openContextMenu = nil
        self.statusItem.menu = nil
    }

    /// What a press of the keyboard shortcut does, as a menu item: Start
    /// default session while Awake is off, Stop session while it is on. The
    /// shortcut is shown next to it while it works, so that the menu makes
    /// it known.
    private func defaultSessionMenuItem() -> NSMenuItem {
        let item = NSMenuItem(
            title: currentStatus.active ? "Stop session" : "Start default session",
            action: #selector(startOrStopDefaultSession(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.isEnabled = pendingCommand == nil
        // What the title offers, which the click then does, even if Awake
        // started or stopped while the menu was open.
        item.tag = currentStatus.active ? DefaultSessionAction.stop.rawValue : DefaultSessionAction.start.rawValue
        if !currentStatus.active {
            let request = StartShortcut.startRequest(defaultToken: PickerSettings.load().defaultToken)
            let length = request.durationSeconds.map { "of \(PickerSettings.lengthLabel(seconds: $0))" } ?? "without an end time"
            item.toolTip = "Starts a session \(length), in the mode set under Keyboard shortcut in Settings."
        }
        if startShortcutHotKey.isRegistered, let shortcut = preferences.startShortcut, let key = shortcut.menuKeyEquivalent {
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: shortcut.modifiers.cocoaFlags)
        }
        return item
    }

    /// What Start default session or Stop session offered when the menu
    /// opened, kept in the item's tag.
    private enum DefaultSessionAction: Int {
        case start
        case stop
    }

    /// Start default session or Stop session in the menu: what a press of
    /// the keyboard shortcut does, as the title said. A start never adds
    /// time to a session that began meanwhile (`startOnlyIfOff`), and a stop
    /// does nothing once Awake is off.
    @objc
    private func startOrStopDefaultSession(_ sender: Any?) {
        guard pendingCommand == nil else {
            return
        }
        let action = (sender as? NSMenuItem).flatMap { DefaultSessionAction(rawValue: $0.tag) }
        if action == .stop {
            if currentStatus.active {
                stopAwake()
            }
        } else {
            startDefaultSession()
        }
    }

    @objc
    func showSettings(_ sender: Any?) {
        settingsWindowController.showSettingsWindow()
    }

    @objc
    private func installHelper(_ sender: Any?) {
        runMaintenance(arguments: ["--install-helper"])
    }

    /// Runs a setup command such as `--passwordless on`. Returns false,
    /// without running it, while another command is pending.
    @discardableResult
    private func runMaintenance(arguments: [String]) -> Bool {
        guard pendingCommand == nil else {
            return false
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
        return true
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
        defer {
            lastPromptEndedAt = StartShortcutHotKey.currentEventTime()
        }
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
        defer {
            lastPromptEndedAt = StartShortcutHotKey.currentEventTime()
        }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Awake"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        _ = alert.runModal()
    }

    private func promptForCustomStartSelection() -> CustomStartSelection? {
        defer {
            lastPromptEndedAt = StartShortcutHotKey.currentEventTime()
        }
        do {
            guard let selection = try cli.promptStartSelection(
                defaultBackend: preferences.lastBackend,
                defaultKeepDisplay: preferences.lastKeepDisplay
            ) else {
                return nil
            }
            return CustomStartSelection(
                startArguments: selection.startArguments,
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

    private func playSoundIfNeeded(enabled: Bool) {
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

// MARK: - Settings

// The Settings window shows these values as they really are, and changes
// them only through these methods.
extension StatusBarController: SettingsHost {
    /// Whether password-free mode is on, or nil while that is not known yet
    /// (before the first status, or after a failed one).
    var passwordlessSetting: Bool? {
        currentStatus.hasError ? nil : currentStatus.passwordless
    }

    var isCommandPending: Bool {
        pendingCommand != nil
    }

    /// Whether the login item is really there, not what was last asked for.
    var isLaunchAtLoginEnabled: Bool {
        launchAgentManager.isEnabled()
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        defer {
            // Also after a failure, which may leave the login item half set up.
            preferences.launchAtLoginEnabled = launchAgentManager.isEnabled()
            onStateChange?()
        }
        try launchAgentManager.setEnabled(enabled)
    }

    /// Asks for the administrator password and turns password-free mode on
    /// or off. The window shows the result once the command has finished;
    /// a cancelled prompt leaves the setting as it was.
    func setPasswordless(_ enabled: Bool) {
        guard currentStatus.passwordless != enabled, runMaintenance(arguments: ["--passwordless", enabled ? "on" : "off"]) else {
            onStateChange?()
            return
        }
        if !enabled {
            clearCachedCustomPassword()
        }
    }

    func setUseCustomPasswordDialog(_ enabled: Bool) {
        preferences.useCustomPasswordDialog = enabled
        if !enabled {
            clearCachedCustomPassword()
        }
        onStateChange?()
    }

    var startShortcutProblem: String? {
        startShortcutFailure
    }

    /// Registers `shortcut` and stores it. Returns why it could not be
    /// registered; the one stored before then stays, and goes back on when
    /// recording ends.
    func setStartShortcut(_ shortcut: StartShortcut) -> String? {
        if let failure = startShortcutHotKey.register(shortcut) {
            return shortcut.registrationFailureMessage(takenByAnotherApp: failure.takenByAnotherApp, status: failure.status)
        }
        preferences.startShortcut = shortcut
        startShortcutFailure = nil
        onStateChange?()
        return nil
    }

    /// Turns the keyboard shortcut on or off. The stored shortcut stays, so
    /// turning it on again brings it back.
    func setStartShortcutEnabled(_ enabled: Bool) {
        preferences.startShortcutEnabled = enabled
        registerStoredStartShortcut(notifyOnFailure: false)
        onStateChange?()
    }

    /// Turns the stored shortcut off while the Settings window records a
    /// new one, so that pressing it records it, and on again afterwards.
    func pauseStartShortcut(_ paused: Bool) {
        if paused {
            startShortcutHotKey.unregister()
        } else if !startShortcutHotKey.isRegistered {
            registerStoredStartShortcut(notifyOnFailure: false)
        }
    }
}

private extension AwakeStatus {
    /// What CommandResult judges a command's result from.
    var commandFacts: CommandResult.Facts {
        CommandResult.Facts(active: active, sessionToken: sessionToken)
    }
}
