// Copyright (C) 2026 Antti Käenmäki

import Foundation

/// What the menu bar app posts once a start, added time, or stop has ended,
/// worked out from the statuses alone. Foundation only, so that the check
/// (tests/app/command-result-check.swift) builds with this file alone.
enum CommandResult {
    /// What the user asked for. The app passes it to the CLI explicitly, so
    /// a click never does the opposite of what the icon showed, even when
    /// the state changed since the last poll.
    enum Intent: Equatable {
        case start
        /// A start of the default session, with the keyboard shortcut or
        /// the menu, in the shortcut's mode. It never adds time to a
        /// session that is on (`--if-off`).
        case defaultStart
        case extend
        case stop
        case stopAndQuit
    }

    /// The parts of a status that decide what is posted.
    struct Facts: Equatable {
        let active: Bool
        let sessionToken: String?
    }

    /// What is posted, in the order `announcement` checks for it.
    enum Announcement: Equatable {
        /// The command failed: `Awake failed`, with its message.
        case failed
        /// A session started, which is the app's own from now on: `Awake
        /// started`, with the start sound.
        case started
        /// Added time met the session's own end, and the CLI started a new
        /// session that ends as asked. The old session's end is posted when
        /// it was the app's own, as for `ended`; the new session is the
        /// app's from now on, as for `started`.
        case replaced(appSession: Bool)
        /// `Awake extended`.
        case extended
        /// A session was on before the start: `Awake is already on`.
        case alreadyOn
        /// The session that was on is off. Its end is noted, so that no
        /// poll posts it again; when it was the app's own, `Awake stopped`
        /// (or the title for how it ended) is posted, with the stop sound.
        case ended(appSession: Bool)
        case nothing
    }

    /// What Stop Awake and quit does once its stop has ended.
    enum Quit: Equatable {
        /// Not a quit, or a failed one, whose failure is posted.
        case no
        case quit
        /// A session is still on: `Quit cancelled`.
        case cancelled
    }

    /// The status a command's result is judged from: the one the CLI found
    /// once it held its lock (AWAKE_STATUS_BEFORE_JSON_FILE), or, when it
    /// reported none (an awake older than this app, or one that stopped
    /// before the lock, then with an exit status other than 0), the one
    /// the app showed when the command was asked for. Generic, so that the
    /// app passes its statuses and the check passes `Facts`.
    static func before<Status>(found: Status?, shown: Status) -> Status {
        found ?? shown
    }

    /// The status to look for an end in that the command did not make: the
    /// one the CLI found, or, when it reported none and its exit status is
    /// not 0, the one read after it. A CLI that stopped before its lock
    /// changed nothing, so that read is the one a poll would have made.
    /// Generic, like `before`.
    static func foundOrRead<Status>(found: Status?, after: Status, exitCode: Int32) -> Status? {
        if let found = found {
            return found
        }
        if exitCode != 0 {
            return after
        }
        return nil
    }

    /// True when a session the app showed as on had ended on its own before
    /// the CLI took its lock. The app then posts that end as the status
    /// poll that missed it would have (maybeNotifyCompletionTransition).
    static func endedBeforeCommand(shown: Facts, found: Facts?) -> Bool {
        guard let found = found else {
            return false
        }
        return shown.active && !found.active
    }

    /// What is posted once a command has ended, from its exit status, the
    /// state it started from (`before`) and the state it left (`after`).
    static func announcement(
        intent: Intent,
        exitCode: Int32,
        before: Facts,
        after: Facts,
        appSessionToken: String?
    ) -> Announcement {
        if exitCode != 0 {
            return .failed
        }
        if !before.active && after.active {
            return .started
        }
        if intent == .extend && before.active && after.active,
           let oldToken = before.sessionToken, !oldToken.isEmpty,
           let newToken = after.sessionToken, newToken != oldToken {
            // Added time keeps a session's token. A new one means that the
            // session ended behind the password dialog, and the CLI started
            // a new one (extend_running_session's 3, then main).
            return .replaced(appSession: isAppSession(before, appSessionToken: appSessionToken))
        }
        if intent == .extend && after.active {
            return .extended
        }
        if (intent == .start || intent == .defaultStart) && before.active && after.active {
            // Started elsewhere since the last poll: the CLI left it
            // running, and with --if-off changed nothing.
            return .alreadyOn
        }
        if before.active && !after.active {
            // A session started elsewhere is announced by the process that
            // started it, if that had --notifications, so only the app's
            // own sessions are confirmed.
            return .ended(appSession: isAppSession(before, appSessionToken: appSessionToken))
        }
        return .nothing
    }

    /// What Stop Awake and quit does once `announcement` is posted.
    static func quit(intent: Intent, announcement: Announcement, after: Facts) -> Quit {
        guard intent == .stopAndQuit else {
            return .no
        }
        switch announcement {
        case .ended:
            return .quit
        case .nothing:
            // Off before and after: the session had ended on its own. On
            // before and after: the stop was cancelled, for example at its
            // password dialog.
            return after.active ? .cancelled : .quit
        case .failed, .started, .replaced, .extended, .alreadyOn:
            return .no
        }
    }

    /// A session the app started: its token is the one the app stored when
    /// it started it.
    static func isAppSession(_ status: Facts, appSessionToken: String?) -> Bool {
        guard let token = status.sessionToken, !token.isEmpty else {
            return false
        }
        return token == appSessionToken
    }
}
