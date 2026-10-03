// Copyright (C) 2026 Antti Käenmäki

import Foundation

// The menu bar icon check: what the icon shows and VoiceOver reads for
// every command in progress, how the app picks that from the password mode
// and the last status, the status texts, and which status polls may replace
// the status shown. Built with StatusIcon.swift alone, as CI does:
//
//   swiftc -target arm64-apple-macos12.5 -parse-as-library \
//     app/AwakeStatusApp/Sources/StatusIcon.swift tests/app/status-icon-check.swift \
//     -o status-icon-check

/// The outcome of every check.
final class IconCheckLog {
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
struct StatusIconCheck {
    typealias Preview = StatusIcon.Preview

    static func main() {
        let log = IconCheckLog()
        checkIdle(log)
        checkEveryCommand(log)
        checkPasswordRule(log)
        checkPreviews(log)
        checkWhatTheUserSees(log)
        checkTexts(log)
        checkPolls(log)

        if log.failures.isEmpty {
            print("Status icon check: all \(log.passed) checks passed.")
        } else {
            for failure in log.failures {
                print("FAIL: \(failure)")
            }
            print("Status icon check: \(log.failures.count) of \(log.passed + log.failures.count) checks failed.")
            exit(1)
        }
    }

    // MARK: Helpers

    static func icon(_ active: Bool, _ pending: PendingCommand?) -> StatusIcon {
        StatusIcon(active: active, pending: pending)
    }

    static func expectIcon(_ log: IconCheckLog, _ icon: StatusIcon, on: Bool, dimmed: Bool, _ description: String) {
        log.expectEqual(icon.showsOn, on, "\(description): bold A")
        log.expectEqual(icon.dimmed, dimmed, "\(description): dimmed")
    }

    static func mayAsk(helper: Bool, custom: Bool, passwordless: Bool?, current: Bool?) -> Bool {
        StatusIcon.cliMayAskForPassword(
            runsHelper: helper,
            customPasswordDialog: custom,
            passwordless: passwordless,
            helperInstalled: current
        )
    }

    /// The icon while a start runs from off, picked as StatusBarController's
    /// startAwake and startDefaultSession pick it: a lid-closed start runs
    /// the helper.
    static func startIcon(lengthChosen: Bool, lidClosed: Bool, custom: Bool, passwordless: Bool?, current: Bool?) -> StatusIcon {
        let preview = StatusIcon.startPreview(
            lengthChosen: lengthChosen,
            lidClosed: lidClosed,
            cliMayAskForPassword: mayAsk(helper: lidClosed, custom: custom, passwordless: passwordless, current: current)
        )
        return icon(false, .starting(preview))
    }

    /// The icon while a stop runs from on, picked as StatusBarController's
    /// stopAwake picks it: a stop runs the helper for sleep left off or
    /// another account's session.
    static func stopIcon(runsHelper: Bool, custom: Bool, passwordless: Bool?, current: Bool?) -> StatusIcon {
        let preview = StatusIcon.stopPreview(
            cliMayAskForPassword: mayAsk(helper: runsHelper, custom: custom, passwordless: passwordless, current: current)
        )
        return icon(true, .stopping(preview))
    }

    // MARK: Checks

    static func checkIdle(_ log: IconCheckLog) {
        expectIcon(log, icon(false, nil), on: false, dimmed: false, "off")
        expectIcon(log, icon(true, nil), on: true, dimmed: false, "on")
        log.expectEqual(icon(false, nil).accessibilityLabel, "Awake is off", "off: VoiceOver")
        log.expectEqual(icon(true, nil).accessibilityLabel, "Awake is on", "on: VoiceOver")
    }

    /// Each command, from off and from on: whether the icon shows the bold
    /// A then, whether it is dimmed, and that VoiceOver reads the status
    /// text, never a state the icon only previews.
    static func checkEveryCommand(_ log: IconCheckLog) {
        let rows: [(pending: PendingCommand, fromOff: Bool, fromOn: Bool, dimmed: Bool, name: String)] = [
            (.starting(.outcome), true, true, false, "lid-open start"),
            (.starting(.dimmedOutcome), true, true, true, "lid-closed start"),
            (.starting(.dimmedCurrent), false, true, true, "start with the picker or a password"),
            (.stopping(.outcome), false, false, false, "stop"),
            (.stopping(.dimmedOutcome), false, false, true, "dimmed stop"),
            (.stopping(.dimmedCurrent), false, true, true, "stop with a password"),
            (.extending, false, true, false, "added time"),
            (.configuring, false, true, false, "helper change"),
        ]
        for row in rows {
            expectIcon(log, icon(false, row.pending), on: row.fromOff, dimmed: row.dimmed, "\(row.name), from off")
            expectIcon(log, icon(true, row.pending), on: row.fromOn, dimmed: row.dimmed, "\(row.name), from on")
            log.expectEqual(icon(false, row.pending).accessibilityLabel, row.pending.statusText, "\(row.name), from off: VoiceOver")
            log.expectEqual(icon(true, row.pending).accessibilityLabel, row.pending.statusText, "\(row.name), from on: VoiceOver")
        }
    }

    static func checkPasswordRule(_ log: IconCheckLog) {
        let unknownOrNot: [Bool?] = [true, false, nil]
        for passwordless in unknownOrNot {
            for current in unknownOrNot {
                let name = "password-free \(String(describing: passwordless)), helper current \(String(describing: current))"
                log.expect(!mayAsk(helper: false, custom: false, passwordless: passwordless, current: current), "lid-open never asks: \(name)")
                log.expect(!mayAsk(helper: false, custom: true, passwordless: passwordless, current: current), "lid-open never asks, custom dialog: \(name)")
                log.expect(!mayAsk(helper: true, custom: true, passwordless: passwordless, current: current), "custom dialog, the app has asked: \(name)")
                let asks = mayAsk(helper: true, custom: false, passwordless: passwordless, current: current)
                log.expectEqual(asks, !(passwordless == true && current == true), "the macOS dialog unless password-free with a current helper: \(name)")
            }
        }
        log.expect(!mayAsk(helper: true, custom: false, passwordless: true, current: true), "password-free with a current helper: no dialog")
        log.expect(mayAsk(helper: true, custom: false, passwordless: false, current: true), "not password-free: the dialog")
        log.expect(mayAsk(helper: true, custom: false, passwordless: true, current: false), "an out-of-date helper is updated with a password, also in password-free mode")
        log.expect(mayAsk(helper: true, custom: false, passwordless: false, current: false), "neither")
        log.expect(mayAsk(helper: true, custom: false, passwordless: nil, current: true), "password-free unknown: may ask")
        log.expect(mayAsk(helper: true, custom: false, passwordless: true, current: nil), "helper unknown: may ask")
        log.expect(mayAsk(helper: true, custom: false, passwordless: nil, current: nil), "both unknown, before the first status: may ask")
    }

    static func checkPreviews(_ log: IconCheckLog) {
        log.expectEqual(StatusIcon.startPreview(lengthChosen: true, lidClosed: false, cliMayAskForPassword: false), Preview.outcome, "lid-open, length known")
        log.expectEqual(StatusIcon.startPreview(lengthChosen: true, lidClosed: true, cliMayAskForPassword: false), Preview.dimmedOutcome, "lid-closed, length known, no dialog")
        log.expectEqual(StatusIcon.startPreview(lengthChosen: true, lidClosed: true, cliMayAskForPassword: true), Preview.dimmedCurrent, "lid-closed, the macOS dialog")
        log.expectEqual(StatusIcon.startPreview(lengthChosen: true, lidClosed: false, cliMayAskForPassword: true), Preview.dimmedCurrent, "a dialog wins")
        for lidClosed in [false, true] {
            for asks in [false, true] {
                log.expectEqual(StatusIcon.startPreview(lengthChosen: false, lidClosed: lidClosed, cliMayAskForPassword: asks), Preview.dimmedCurrent, "the CLI's picker: lid-closed \(lidClosed), dialog \(asks)")
            }
        }
        log.expectEqual(StatusIcon.stopPreview(cliMayAskForPassword: false), Preview.outcome, "stop")
        log.expectEqual(StatusIcon.stopPreview(cliMayAskForPassword: true), Preview.dimmedCurrent, "stop with the macOS dialog")
    }

    /// The rows of "What the user sees" in docs/plans/faster-start-stop.md
    /// (3.1), picked as StatusBarController picks them.
    static func checkWhatTheUserSees(_ log: IconCheckLog) {
        // The keyboard shortcut or Start default session: a length is
        // always chosen.
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: false, custom: false, passwordless: nil, current: nil), on: true, dimmed: false, "shortcut, lid-open, before the first status")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: false, custom: false, passwordless: false, current: false), on: true, dimmed: false, "shortcut, lid-open")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: false, passwordless: true, current: true), on: true, dimmed: true, "shortcut, lid-closed, password-free")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: true, passwordless: false, current: true), on: true, dimmed: true, "shortcut, lid-closed, after the app's own dialog")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: false, passwordless: false, current: true), on: false, dimmed: true, "shortcut, lid-closed, macOS dialog, password-free off")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: false, passwordless: true, current: false), on: false, dimmed: true, "shortcut, lid-closed, macOS dialog, helper missing or out of date")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: false, passwordless: nil, current: nil), on: false, dimmed: true, "shortcut, lid-closed, before the first status")

        // A click while off: the CLI's picker with the macOS dialog setting,
        // in either of the lid modes it opens with; the app's own picker
        // and dialog first with the custom one.
        expectIcon(log, startIcon(lengthChosen: false, lidClosed: false, custom: false, passwordless: false, current: false), on: false, dimmed: true, "click, the CLI's picker, opening lid-open")
        expectIcon(log, startIcon(lengthChosen: false, lidClosed: true, custom: false, passwordless: true, current: true), on: false, dimmed: true, "click, the CLI's picker, opening lid-closed")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: false, custom: true, passwordless: false, current: false), on: true, dimmed: false, "click, the app's picker, lid-open")
        expectIcon(log, startIcon(lengthChosen: true, lidClosed: true, custom: true, passwordless: false, current: false), on: true, dimmed: true, "click, the app's picker and dialog, lid-closed")

        // Added time and helper changes keep the icon.
        expectIcon(log, icon(true, .extending), on: true, dimmed: false, "add time")
        expectIcon(log, icon(false, .configuring), on: false, dimmed: false, "install helper while off")
        expectIcon(log, icon(true, .configuring), on: true, dimmed: false, "install helper while on")

        // Stops, also Stop Awake and quit.
        expectIcon(log, stopIcon(runsHelper: false, custom: false, passwordless: false, current: false), on: false, dimmed: false, "stop")
        expectIcon(log, stopIcon(runsHelper: false, custom: false, passwordless: nil, current: nil), on: false, dimmed: false, "stop, the helper's timer stops it, before the first status")
        expectIcon(log, stopIcon(runsHelper: true, custom: false, passwordless: false, current: true), on: true, dimmed: true, "stop, sleep left off, macOS dialog, password-free off")
        expectIcon(log, stopIcon(runsHelper: true, custom: false, passwordless: true, current: true), on: false, dimmed: false, "stop, sleep left off, password-free")
        expectIcon(log, stopIcon(runsHelper: true, custom: true, passwordless: false, current: true), on: false, dimmed: false, "stop, sleep left off, after the app's own dialog")

        // When the command ends, the icon follows the status read, whatever
        // it showed meanwhile: a failed start, a cancelled picker or dialog.
        expectIcon(log, icon(false, nil), on: false, dimmed: false, "after a failed or cancelled start")
        expectIcon(log, icon(true, nil), on: true, dimmed: false, "after a failed or cancelled stop")
    }

    static func checkTexts(_ log: IconCheckLog) {
        // README.md quotes these.
        log.expectEqual(PendingCommand.starting(.outcome).statusText, "Starting Awake…", "starting")
        log.expectEqual(PendingCommand.starting(.dimmedOutcome).statusText, "Starting Awake…", "starting, dimmed until done")
        log.expectEqual(PendingCommand.starting(.dimmedCurrent).statusText, "Starting Awake…", "starting, dimmed")
        log.expectEqual(PendingCommand.extending.statusText, "Adding time…", "extending")
        log.expectEqual(PendingCommand.stopping(.outcome).statusText, "Stopping Awake…", "stopping")
        log.expectEqual(PendingCommand.stopping(.dimmedCurrent).statusText, "Stopping Awake…", "stopping, dimmed")
        log.expectEqual(PendingCommand.configuring.statusText, "Updating Awake’s helper…", "configuring")
        log.expectEqual(StatusIcon.onLabel, "Awake is on", "on label")
        log.expectEqual(StatusIcon.offLabel, "Awake is off", "off label")
    }

    static func checkPolls(_ log: IconCheckLog) {
        let previews: [Preview] = [.outcome, .dimmedOutcome, .dimmedCurrent]
        var startsAndStops: [PendingCommand] = []
        for preview in previews {
            startsAndStops.append(.starting(preview))
            startsAndStops.append(.stopping(preview))
        }
        for pending in startsAndStops {
            log.expect(pending.pausesPolls, "\(pending) pauses polls")
        }
        log.expect(!PendingCommand.extending.pausesPolls, "added time keeps its polls")
        log.expect(!PendingCommand.configuring.pausesPolls, "a helper change keeps its polls")

        log.expect(PendingCommand.pollResultApplies(readStartedAt: 20, shownReadStartedAt: 10, pending: nil), "a newer poll applies")
        log.expect(PendingCommand.pollResultApplies(readStartedAt: 10, shownReadStartedAt: 10, pending: nil), "a poll that started with the status shown applies")
        // The icon-flip race: a poll read at 100, before the start; the
        // start's own read at 101.5 is shown; the poll arrives after it.
        log.expect(!PendingCommand.pollResultApplies(readStartedAt: 100, shownReadStartedAt: 101.5, pending: nil), "an older poll is dropped")
        for pending in startsAndStops {
            log.expect(!PendingCommand.pollResultApplies(readStartedAt: 20, shownReadStartedAt: 10, pending: pending), "a newer poll is dropped while \(pending) runs")
            log.expect(!PendingCommand.pollResultApplies(readStartedAt: 5, shownReadStartedAt: 10, pending: pending), "an older poll is dropped while \(pending) runs")
        }
        for pending in [PendingCommand.extending, PendingCommand.configuring] {
            log.expect(PendingCommand.pollResultApplies(readStartedAt: 20, shownReadStartedAt: 10, pending: pending), "a newer poll applies while \(pending) runs")
            log.expect(PendingCommand.pollResultApplies(readStartedAt: 10, shownReadStartedAt: 10, pending: pending), "an equal poll applies while \(pending) runs")
            log.expect(!PendingCommand.pollResultApplies(readStartedAt: 5, shownReadStartedAt: 10, pending: pending), "an older poll is dropped while \(pending) runs")
        }
    }
}
