// Copyright (C) 2026 Antti Käenmäki

import Foundation

// The command result check: what the menu bar app posts once a start, added
// time, or stop has ended, from the status the app showed, the status the
// CLI found under its lock, and the status it left. Built with
// CommandResult.swift alone, as CI does:
//
//   swiftc -target arm64-apple-macos12.5 -parse-as-library \
//     app/AwakeStatusApp/Sources/CommandResult.swift tests/app/command-result-check.swift \
//     -o command-result-check

/// The outcome of every check.
final class ResultCheckLog {
    private(set) var passed = 0
    private(set) var failures: [String] = []

    func expect(_ condition: Bool, _ description: String) {
        if condition {
            passed += 1
        } else {
            failures.append(description)
        }
    }

    func expectEqual<Value: Equatable>(_ actual: Value, _ expected: Value, _ description: String) {
        if actual == expected {
            passed += 1
        } else {
            failures.append("\(description): got \(String(describing: actual)), expected \(String(describing: expected))")
        }
    }
}

@main
struct CommandResultCheck {
    typealias Facts = CommandResult.Facts
    typealias Intent = CommandResult.Intent
    typealias Announcement = CommandResult.Announcement

    static let allIntents: [Intent] = [.start, .defaultStart, .extend, .stop, .stopAndQuit]
    static let appToken = "1791150000-100-1"
    static let off = Facts(active: false, sessionToken: nil)
    static let appOn = Facts(active: true, sessionToken: appToken)
    static let appEnded = Facts(active: false, sessionToken: appToken)
    static let terminalOn = Facts(active: true, sessionToken: "1791150005-200-2")
    /// A session the CLI started for the command, after the one that was on
    /// had ended.
    static let newOn = Facts(active: true, sessionToken: "1791150100-300-3")

    static func main() {
        let log = ResultCheckLog()
        checkFailures(log)
        checkStarts(log)
        checkAddedTime(log)
        checkStops(log)
        checkQuit(log)
        checkBefore(log)
        checkAppSession(log)
        checkWhatTheUserSees(log)

        if log.failures.isEmpty {
            print("Command result check: all \(log.passed) checks passed.")
        } else {
            for failure in log.failures {
                print("FAIL: \(failure)")
            }
            print("Command result check: \(log.failures.count) of \(log.passed + log.failures.count) checks failed.")
            exit(1)
        }
    }

    static func announce(_ intent: Intent, _ exitCode: Int32, _ before: Facts, _ after: Facts) -> Announcement {
        CommandResult.announcement(intent: intent, exitCode: exitCode, before: before, after: after, appSessionToken: appToken)
    }

    /// Any exit status but 0 is a failure, whatever the statuses say.
    static func checkFailures(_ log: ResultCheckLog) {
        let statuses = [off, appOn, appEnded, terminalOn, newOn]
        for intent in allIntents {
            for before in statuses {
                for after in statuses {
                    for exitCode: Int32 in [1, 2, 15] {
                        log.expectEqual(announce(intent, exitCode, before, after), .failed, "\(intent) exiting \(exitCode) from \(before) to \(after)")
                    }
                }
            }
        }
    }

    static func checkStarts(_ log: ResultCheckLog) {
        for intent in [Intent.start, .defaultStart] {
            log.expectEqual(announce(intent, 0, off, appOn), .started, "\(intent) from off")
            log.expectEqual(announce(intent, 0, appEnded, appOn), .started, "\(intent) after a session ended")
            log.expectEqual(announce(intent, 0, terminalOn, terminalOn), .alreadyOn, "\(intent) while on")
            // Only added time takes a new token for a new session (H3h).
            log.expectEqual(announce(intent, 0, terminalOn, newOn), .alreadyOn, "\(intent) while on, another session after")
            log.expectEqual(announce(intent, 0, off, off), .nothing, "\(intent) cancelled")
            log.expectEqual(announce(intent, 0, appOn, appEnded), .ended(appSession: true), "\(intent) while the app's session ended")
            log.expectEqual(announce(intent, 0, terminalOn, off), .ended(appSession: false), "\(intent) while another session ended")
        }
    }

    static func checkAddedTime(_ log: ResultCheckLog) {
        log.expectEqual(announce(.extend, 0, appOn, appOn), .extended, "added time")
        log.expectEqual(announce(.extend, 0, terminalOn, terminalOn), .extended, "added time to another session")
        // The session ended before the CLI's lock, so the CLI started one.
        log.expectEqual(announce(.extend, 0, appEnded, appOn), .started, "added time after the session ended")
        log.expectEqual(announce(.extend, 0, appOn, appEnded), .ended(appSession: true), "added time while the session ended")
        log.expectEqual(announce(.extend, 0, off, off), .nothing, "added time with nothing on")
        // The session ended behind the password dialog, the password was
        // given, and the CLI started a new session (a new token).
        log.expectEqual(announce(.extend, 0, appOn, newOn), .replaced(appSession: true), "added time that met the end of the app's session")
        log.expectEqual(announce(.extend, 0, terminalOn, newOn), .replaced(appSession: false), "added time that met the end of another session")
        // Without a token on either side, nothing tells a new session from
        // the old one.
        log.expectEqual(announce(.extend, 0, Facts(active: true, sessionToken: nil), newOn), .extended, "added time to a session without a token")
        log.expectEqual(announce(.extend, 0, appOn, Facts(active: true, sessionToken: nil)), .extended, "added time, no token after")
        log.expectEqual(announce(.extend, 0, Facts(active: true, sessionToken: ""), newOn), .extended, "added time to a session with an empty token")
    }

    static func checkStops(_ log: ResultCheckLog) {
        for intent in [Intent.stop, .stopAndQuit] {
            log.expectEqual(announce(intent, 0, appOn, appEnded), .ended(appSession: true), "\(intent) of the app's session")
            log.expectEqual(announce(intent, 0, terminalOn, off), .ended(appSession: false), "\(intent) of another session")
            log.expectEqual(announce(intent, 0, appEnded, appEnded), .nothing, "\(intent) with nothing on")
            log.expectEqual(announce(intent, 0, appOn, appOn), .nothing, "\(intent) cancelled")
            log.expectEqual(announce(intent, 0, appOn, newOn), .nothing, "\(intent) cancelled, another session after")
        }
    }

    static func checkQuit(_ log: ResultCheckLog) {
        let announcements: [Announcement] = [
            .failed, .started, .extended, .replaced(appSession: true), .replaced(appSession: false), .alreadyOn,
            .ended(appSession: true), .ended(appSession: false), .nothing,
        ]
        for intent in allIntents where intent != .stopAndQuit {
            for announcement in announcements {
                for after in [off, appOn] {
                    log.expectEqual(CommandResult.quit(intent: intent, announcement: announcement, after: after), .no, "\(intent) never quits")
                }
            }
        }
        log.expectEqual(CommandResult.quit(intent: .stopAndQuit, announcement: .ended(appSession: true), after: appEnded), .quit, "quit after the stop")
        log.expectEqual(CommandResult.quit(intent: .stopAndQuit, announcement: .ended(appSession: false), after: off), .quit, "quit after stopping another session")
        log.expectEqual(CommandResult.quit(intent: .stopAndQuit, announcement: .nothing, after: off), .quit, "quit with nothing on")
        log.expectEqual(CommandResult.quit(intent: .stopAndQuit, announcement: .nothing, after: appOn), .cancelled, "quit cancelled")
        for announcement in [Announcement.failed, .started, .extended, .replaced(appSession: true), .alreadyOn] {
            log.expectEqual(CommandResult.quit(intent: .stopAndQuit, announcement: announcement, after: appOn), .no, "no quit after \(announcement)")
        }
    }

    static func checkBefore(_ log: ResultCheckLog) {
        log.expectEqual(CommandResult.before(found: nil, shown: appOn), appOn, "without a report, the status shown")
        log.expectEqual(CommandResult.before(found: appEnded, shown: appOn), appEnded, "the status found wins")
        log.expectEqual(CommandResult.before(found: terminalOn, shown: off), terminalOn, "a session found that the app did not show")
        log.expect(CommandResult.endedBeforeCommand(shown: appOn, found: appEnded), "a session that ended before the lock")
        log.expect(!CommandResult.endedBeforeCommand(shown: appOn, found: appOn), "a session still on")
        log.expect(!CommandResult.endedBeforeCommand(shown: off, found: off), "nothing shown as on")
        log.expect(!CommandResult.endedBeforeCommand(shown: off, found: terminalOn), "a session that started")
        log.expect(!CommandResult.endedBeforeCommand(shown: appOn, found: nil), "no report")
        log.expectEqual(CommandResult.foundOrRead(found: appEnded, after: newOn, exitCode: 0), appEnded, "found or read: the status found")
        log.expectEqual(CommandResult.foundOrRead(found: appOn, after: appEnded, exitCode: 1), appOn, "found or read: the status found, after a failure")
        log.expectEqual(CommandResult.foundOrRead(found: nil, after: appEnded, exitCode: 1), appEnded, "found or read: stopped before the lock, the read after it")
        log.expectEqual(CommandResult.foundOrRead(found: nil, after: appEnded, exitCode: 0), nil, "found or read: an older CLI that did its work")
    }

    static func checkAppSession(_ log: ResultCheckLog) {
        log.expect(CommandResult.isAppSession(appOn, appSessionToken: appToken), "the app's token")
        log.expect(!CommandResult.isAppSession(terminalOn, appSessionToken: appToken), "another token")
        log.expect(!CommandResult.isAppSession(off, appSessionToken: appToken), "no token")
        log.expect(!CommandResult.isAppSession(Facts(active: true, sessionToken: ""), appSessionToken: ""), "an empty token")
        log.expect(!CommandResult.isAppSession(appOn, appSessionToken: nil), "no token stored")
    }

    /// One row per case of the plan's table of what the user sees: what the
    /// app showed, what the CLI found, what it left, and its exit status.
    struct Row {
        let name: String
        let intent: Intent
        let shown: Facts
        let found: Facts?
        let after: Facts
        let exitCode: Int32
        let endedBefore: Bool
        let announcement: Announcement
        let quit: CommandResult.Quit
    }

    static func checkWhatTheUserSees(_ log: ResultCheckLog) {
        let rows = [
            Row(name: "shortcut start while off", intent: .defaultStart, shown: off, found: off, after: appOn, exitCode: 0,
                endedBefore: false, announcement: .started, quit: .no),
            Row(name: "shortcut start, Terminal session since the last poll", intent: .defaultStart, shown: off, found: terminalOn,
                after: terminalOn, exitCode: 0, endedBefore: false, announcement: .alreadyOn, quit: .no),
            Row(name: "click start, picker cancelled", intent: .start, shown: off, found: off, after: off, exitCode: 0,
                endedBefore: false, announcement: .nothing, quit: .no),
            Row(name: "start refused, low battery", intent: .defaultStart, shown: off, found: off, after: off, exitCode: 1,
                endedBefore: false, announcement: .failed, quit: .no),
            Row(name: "stop of the app's session", intent: .stop, shown: appOn, found: appOn, after: appEnded, exitCode: 0,
                endedBefore: false, announcement: .ended(appSession: true), quit: .no),
            Row(name: "stop of a Terminal session", intent: .stop, shown: terminalOn, found: terminalOn, after: off, exitCode: 0,
                endedBefore: false, announcement: .ended(appSession: false), quit: .no),
            Row(name: "stop just after the app's session ended", intent: .stop, shown: appOn, found: appEnded, after: appEnded,
                exitCode: 0, endedBefore: true, announcement: .nothing, quit: .no),
            Row(name: "stop and quit just after the session ended", intent: .stopAndQuit, shown: appOn, found: appEnded,
                after: appEnded, exitCode: 0, endedBefore: true, announcement: .nothing, quit: .quit),
            Row(name: "stop and quit, password dialog cancelled", intent: .stopAndQuit, shown: appOn, found: appOn, after: appOn,
                exitCode: 0, endedBefore: false, announcement: .nothing, quit: .cancelled),
            Row(name: "added time", intent: .extend, shown: appOn, found: appOn, after: appOn, exitCode: 0,
                endedBefore: false, announcement: .extended, quit: .no),
            Row(name: "added time just after the session ended", intent: .extend, shown: appOn, found: appEnded,
                after: newOn, exitCode: 0, endedBefore: true, announcement: .started, quit: .no),
            Row(name: "added time, the session ended behind its password dialog, cancelled", intent: .extend, shown: appOn,
                found: appOn, after: appEnded, exitCode: 0, endedBefore: false, announcement: .ended(appSession: true), quit: .no),
            Row(name: "added time, the session ended behind its password dialog, password given", intent: .extend, shown: appOn,
                found: appOn, after: newOn, exitCode: 0, endedBefore: false, announcement: .replaced(appSession: true), quit: .no),
            Row(name: "older CLI: stop just after the session ended", intent: .stop, shown: appOn, found: nil, after: appEnded,
                exitCode: 0, endedBefore: false, announcement: .ended(appSession: true), quit: .no),
            Row(name: "stopped before the lock (busy)", intent: .stop, shown: appOn, found: nil, after: appOn, exitCode: 1,
                endedBefore: false, announcement: .failed, quit: .no),
            Row(name: "stop refused before the lock just after the session ended", intent: .stop, shown: appOn, found: nil,
                after: appEnded, exitCode: 1, endedBefore: true, announcement: .failed, quit: .no),
        ]
        for row in rows {
            let before = CommandResult.before(found: row.found, shown: row.shown)
            let announcement = announce(row.intent, row.exitCode, before, row.after)
            let foundOrRead = CommandResult.foundOrRead(found: row.found, after: row.after, exitCode: row.exitCode)
            log.expectEqual(CommandResult.endedBeforeCommand(shown: row.shown, found: foundOrRead), row.endedBefore, "\(row.name): the end before the command")
            log.expectEqual(announcement, row.announcement, "\(row.name): what is posted")
            log.expectEqual(CommandResult.quit(intent: row.intent, announcement: announcement, after: row.after), row.quit, "\(row.name): quit")
        }
    }
}
