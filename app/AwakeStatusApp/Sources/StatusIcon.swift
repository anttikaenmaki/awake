// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// A start, added time, stop, or helper change that the menu bar app runs.
/// A start or a stop carries what the icon shows while it runs. Foundation
/// only, so that the check (tests/app/status-icon-check.swift) builds with
/// this file alone.
enum PendingCommand: Equatable {
    case starting(StatusIcon.Preview)
    case extending
    case stopping(StatusIcon.Preview)
    case configuring

    /// The tooltip, the first line of the Ctrl-click menu, and what
    /// VoiceOver reads for the icon while the command runs.
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

    /// True for a start or a stop: no status poll runs or counts meanwhile,
    /// as the command's own result brings the status. Added time and helper
    /// changes keep their polls: added time can wait minutes on a password
    /// dialog, and a session that ends meanwhile still turns the icon
    /// regular.
    var pausesPolls: Bool {
        switch self {
        case .starting, .stopping:
            return true
        case .extending, .configuring:
            return false
        }
    }

    /// Whether a status poll's result may replace the status shown. Polls
    /// are not serialized with each other or with commands, so a result is
    /// dropped while a start or a stop runs, and when its read started
    /// before that of the status shown: a late read never undoes a newer
    /// state, such as the icon a start just turned bold. The times are
    /// system uptimes, which never go back.
    static func pollResultApplies(
        readStartedAt: TimeInterval,
        shownReadStartedAt: TimeInterval,
        pending: PendingCommand?
    ) -> Bool {
        if pending?.pausesPolls == true {
            return false
        }
        return readStartedAt >= shownReadStartedAt
    }
}

/// What the menu bar icon shows: the bold A of a running session or the
/// regular A, dimmed while the outcome of a start or a stop is not known, or
/// while a lid-closed session is not running yet.
struct StatusIcon: Equatable {
    /// What the icon shows while a start or a stop runs.
    enum Preview: Equatable {
        /// The state the command leads to, as if it were done. Seeing it
        /// early does no harm: a lid-open start, and a stop.
        case outcome
        /// The state it leads to, dimmed until it is done: a lid-closed
        /// start, as closing the lid before the session runs lets the Mac
        /// sleep.
        case dimmedOutcome
        /// The state before it, dimmed: while the CLI shows its picker or
        /// the macOS password dialog, which can be cancelled, the outcome is
        /// not known.
        case dimmedCurrent
    }

    /// The images' descriptions, and what VoiceOver reads when no command
    /// runs.
    static let onLabel = "Awake is on"
    static let offLabel = "Awake is off"

    /// The bold A, or else the regular A.
    let showsOn: Bool
    /// Drawn as macOS draws a control that is not available.
    let dimmed: Bool
    /// What VoiceOver reads: the command's status text while one runs, as
    /// the tooltip shows it, so that it never reads a state the icon only
    /// previews.
    let accessibilityLabel: String

    /// `active` is the status last read; `pending` the command that runs.
    init(active: Bool, pending: PendingCommand?) {
        var preview: Preview?
        var target = active
        switch pending {
        case let .starting(chosen)?:
            preview = chosen
            target = true
        case let .stopping(chosen)?:
            preview = chosen
            target = false
        case .extending?, .configuring?, nil:
            break
        }
        switch preview {
        case .outcome?:
            showsOn = target
            dimmed = false
        case .dimmedOutcome?:
            showsOn = target
            dimmed = true
        case .dimmedCurrent?:
            showsOn = active
            dimmed = true
        case nil:
            showsOn = active
            dimmed = false
        }
        accessibilityLabel = pending?.statusText ?? (active ? StatusIcon.onLabel : StatusIcon.offLabel)
    }

    // MARK: Choosing the preview

    /// Whether the CLI may show the macOS password dialog for a command
    /// that runs the privileged helper: unless password-free mode is set up
    /// with a helper of the current version, as the CLI installs or updates
    /// the helper first. In custom password mode the app asks before the
    /// command runs, and the CLI never does. Unknown values, before the
    /// first status or after a failed one, count as asking.
    static func cliMayAskForPassword(
        runsHelper: Bool,
        customPasswordDialog: Bool,
        passwordless: Bool?,
        helperInstalled: Bool?
    ) -> Bool {
        guard runsHelper, !customPasswordDialog else {
            return false
        }
        return passwordless != true || helperInstalled != true
    }

    /// For a start. `lengthChosen` is false when the CLI shows its picker.
    static func startPreview(lengthChosen: Bool, lidClosed: Bool, cliMayAskForPassword: Bool) -> Preview {
        if !lengthChosen || cliMayAskForPassword {
            return .dimmedCurrent
        }
        return lidClosed ? .dimmedOutcome : .outcome
    }

    /// For a stop.
    static func stopPreview(cliMayAskForPassword: Bool) -> Preview {
        cliMayAskForPassword ? .dimmedCurrent : .outcome
    }
}
