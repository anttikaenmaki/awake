// Copyright (C) 2026 Antti Käenmäki

import Foundation

// The heat report check: feeds HeatRecorder made-up polls, thermal changes,
// sleep and wake, and checks the note's wording. Built with HeatReport.swift
// alone, as CI does:
//
//   swiftc -target arm64-apple-macos12.5 -parse-as-library \
//     app/AwakeStatusApp/Sources/HeatReport.swift tests/app/heat-report-check.swift \
//     -o heat-report-check

/// The outcome of every check.
final class HeatCheckLog {
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
struct HeatReportCheck {
    static let zone: TimeZone = TimeZone(identifier: "Europe/Helsinki")!

    static func main() {
        let log = HeatCheckLog()
        checkPollMapping(log)
        checkLevels(log)
        checkStartRules(log)
        checkEndRules(log)
        checkPollOrder(log)
        checkOverlappingReads(log)
        checkClockSetBack(log)
        checkEventsAfterEnd(log)
        checkRelaunch(log)
        checkReportRules(log)
        checkWording(log)
        checkDurations(log)
        checkPropertyList(log)

        if log.failures.isEmpty {
            print("Heat report check: all \(log.passed) checks passed.")
        } else {
            for failure in log.failures {
                print("FAIL: \(failure)")
            }
            print("Heat report check: \(log.failures.count) of \(log.passed + log.failures.count) checks failed.")
            exit(1)
        }
    }

    // MARK: Helpers

    /// A time in Helsinki.
    static func makeDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return calendar.date(from: components)!
    }

    /// 2026-09-28 14:00 in Helsinki, a whole number of seconds since 1970.
    static func baseDate() -> Date {
        makeDate(2026, 9, 28, 14, 0)
    }

    /// A poll of this account's status: a running session when `running` is
    /// given, otherwise no session, with `finished` as the last one's token.
    /// Polls are put in order by their time unless `order` is given.
    static func makePoll(
        _ at: Date,
        running: String? = nil,
        finished: String? = nil,
        completedAt: Date? = nil,
        reason: String? = nil,
        thermal: Int = 0,
        order: TimeInterval? = nil
    ) -> HeatPoll {
        var completed: Int? = nil
        if let completedAt = completedAt {
            completed = Int(completedAt.timeIntervalSince1970)
        }
        let result = HeatPoll(
            at: at,
            readOrder: order ?? at.timeIntervalSince1970,
            active: running != nil,
            hasError: false,
            leftoverSettings: false,
            otherUserSession: false,
            sessionToken: running ?? finished,
            lastCompletedAt: completed,
            lastCompletionReason: reason,
            thermalState: thermal
        )
        return result!
    }

    static func makeSummary(
        highest: Int,
        serious: TimeInterval = 0,
        critical: TimeInterval = 0,
        fair: TimeInterval = 0,
        overheated: Bool = false,
        watchedFromStart: Bool = true,
        firstSeenAt: Date? = nil,
        endedAt: Date? = nil
    ) -> HeatSummary {
        HeatSummary(
            sessionToken: "A",
            firstSeenAt: firstSeenAt ?? makeDate(2026, 9, 28, 14, 0),
            watchedFromStart: watchedFromStart,
            endedAt: endedAt ?? makeDate(2026, 9, 28, 15, 0),
            endedOnOverheating: overheated,
            secondsAtLeastFair: max(fair, serious),
            secondsAtLeastSerious: serious,
            secondsCritical: critical,
            highestState: highest,
            secondsWatched: 3600,
            samples: 360
        )
    }

    // MARK: HeatPoll

    static func checkPollMapping(_ log: HeatCheckLog) {
        let at = baseDate()

        let failed = HeatPoll(at: at, readOrder: 0, active: true, hasError: true, leftoverSettings: false, otherUserSession: false,
                              sessionToken: "A", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0)
        log.expect(failed == nil, "a status with an error gives no poll")

        if let leftover = HeatPoll(at: at, readOrder: 0, active: true, hasError: false, leftoverSettings: true, otherUserSession: false,
                                   sessionToken: "A", lastCompletedAt: 100, lastCompletionReason: "stopped", thermalState: 1) {
            log.expect(leftover.runningToken == nil, "leftover sleep settings give no running token")
            log.expect(leftover.finishedToken == nil, "leftover sleep settings give no finished token")
        } else {
            log.expect(false, "leftover sleep settings give a poll")
        }

        if let other = HeatPoll(at: at, readOrder: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: true,
                                sessionToken: "B", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(other.runningToken == nil, "another account's session gives no running token")
            log.expect(other.finishedToken == nil, "another account's session gives no finished token")
        } else {
            log.expect(false, "another account's session gives a poll")
        }

        if let tokenless = HeatPoll(at: at, readOrder: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                    sessionToken: nil, lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(tokenless.runningToken == nil, "a running session without a token counts as none")
            log.expect(tokenless.finishedToken == nil, "a running session without a token gives no finished token")
        } else {
            log.expect(false, "a running session without a token gives a poll")
        }

        if let empty = HeatPoll(at: at, readOrder: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                sessionToken: "", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(empty.runningToken == nil, "a running session with an empty token counts as none")
        } else {
            log.expect(false, "a running session with an empty token gives a poll")
        }

        if let running = HeatPoll(at: at, readOrder: 5, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                  sessionToken: "A", lastCompletedAt: 50, lastCompletionReason: "timeout", thermalState: 2) {
            log.expectEqual(running.runningToken, "A", "a running session's token")
            log.expect(running.finishedToken == nil, "a running session gives no finished token")
            log.expectEqual(running.at, at, "a poll's time")
            log.expectEqual(running.readOrder, 5, "a poll's read order")
            log.expectEqual(running.thermalState, 2, "a poll's thermal state")
        } else {
            log.expect(false, "a running session gives a poll")
        }

        if let stopped = HeatPoll(at: at, readOrder: 0, active: false, hasError: false, leftoverSettings: false, otherUserSession: false,
                                  sessionToken: "A", lastCompletedAt: 1234, lastCompletionReason: "overheated", thermalState: 0) {
            log.expect(stopped.runningToken == nil, "no running session gives no running token")
            log.expectEqual(stopped.finishedToken, "A", "no running session gives the finished token")
            log.expectEqual(stopped.lastCompletedAt, 1234, "a poll's last_completed_at")
            log.expectEqual(stopped.lastCompletionReason, "overheated", "a poll's last_completion_reason")
        } else {
            log.expect(false, "no running session gives a poll")
        }

        log.expectEqual(makePoll(at, thermal: 7).thermalState, 3, "a thermal state above 3 is clamped")
        log.expectEqual(makePoll(at, thermal: -2).thermalState, 0, "a thermal state below 0 is clamped")
    }

    // MARK: Time at each level

    static func checkLevels(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)

        log.expect(recorder.observe(makePoll(t)) == nil, "levels: a poll without a session finishes nothing")
        log.expect(!recorder.isRecording, "levels: no recording without a session")
        log.expect(recorder.snapshot(at: t) == nil, "levels: no snapshot without a recording")

        log.expect(recorder.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 0)) == nil,
                   "levels: a start finishes nothing")
        log.expect(recorder.isRecording, "levels: a running session starts a recording")
        recorder.thermalStateChanged(to: 1, at: t.addingTimeInterval(15))
        _ = recorder.observe(makePoll(t.addingTimeInterval(20), running: "A", thermal: 1))
        recorder.thermalStateChanged(to: 2, at: t.addingTimeInterval(30))
        _ = recorder.observe(makePoll(t.addingTimeInterval(40), running: "A", thermal: 2))
        recorder.thermalStateChanged(to: 3, at: t.addingTimeInterval(45))
        _ = recorder.observe(makePoll(t.addingTimeInterval(50), running: "A", thermal: 3))

        guard let first = recorder.snapshot(at: t.addingTimeInterval(50)) else {
            log.expect(false, "levels: a snapshot while recording")
            return
        }
        log.expectEqual(first.sessionToken, "A", "levels: token")
        log.expectEqual(first.firstSeenAt, t.addingTimeInterval(10), "levels: firstSeenAt")
        log.expect(first.watchedFromStart, "levels: a session started after a poll without one is watched from the start")
        log.expectEqual(first.endedAt, t.addingTimeInterval(50), "levels: endedAt of a snapshot")
        log.expectEqual(first.secondsWatched, 40, "levels: secondsWatched")
        log.expectEqual(first.secondsAtLeastFair, 35, "levels: secondsAtLeastFair")
        log.expectEqual(first.secondsAtLeastSerious, 20, "levels: secondsAtLeastSerious")
        log.expectEqual(first.secondsCritical, 5, "levels: secondsCritical")
        log.expectEqual(first.highestState, 3, "levels: highestState")
        log.expectEqual(first.samples, 4, "levels: samples")

        // 200 seconds without an event count as 60, at the state in effect.
        _ = recorder.observe(makePoll(t.addingTimeInterval(250), running: "A", thermal: 3))
        if let capped = recorder.snapshot(at: t.addingTimeInterval(250)) {
            log.expectEqual(capped.secondsWatched, 100, "cap: secondsWatched")
            log.expectEqual(capped.secondsCritical, 65, "cap: secondsCritical")
            log.expectEqual(capped.samples, 5, "cap: samples")
        } else {
            log.expect(false, "cap: a snapshot while recording")
        }

        // The clock is set back 20 seconds before a thermal change: that
        // interval counts as 0, and the next one is measured from the new
        // time. checkClockSetBack sets it back before polls.
        recorder.thermalStateChanged(to: 2, at: t.addingTimeInterval(230))
        if let setBack = recorder.snapshot(at: t.addingTimeInterval(230)) {
            log.expectEqual(setBack.secondsWatched, 100, "negative interval: nothing counted")
            log.expectEqual(setBack.secondsCritical, 65, "negative interval: nothing counted as critical")
            log.expectEqual(setBack.highestState, 3, "negative interval: highestState stays")
        } else {
            log.expect(false, "negative interval: a snapshot while recording")
        }
        _ = recorder.observe(makePoll(t.addingTimeInterval(260), running: "A", thermal: 2))
        if let after = recorder.snapshot(at: t.addingTimeInterval(260)) {
            log.expectEqual(after.secondsWatched, 130, "after a negative interval: secondsWatched")
            log.expectEqual(after.secondsAtLeastSerious, 110, "after a negative interval: secondsAtLeastSerious")
            log.expectEqual(after.secondsCritical, 65, "after a negative interval: secondsCritical")
        } else {
            log.expect(false, "after a negative interval: a snapshot while recording")
        }

        // Asleep, with a dark-wake poll and a thermal change in between.
        recorder.systemWillSleep(at: t.addingTimeInterval(270))
        log.expect(recorder.observe(makePoll(t.addingTimeInterval(900), running: "A", thermal: 3)) == nil,
                   "sleep: a dark-wake poll finishes nothing")
        recorder.thermalStateChanged(to: 1, at: t.addingTimeInterval(905))
        recorder.systemDidWake(at: t.addingTimeInterval(2000))
        if let awake = recorder.snapshot(at: t.addingTimeInterval(2000)) {
            log.expectEqual(awake.secondsWatched, 140, "sleep: only the time before sleep is counted")
            log.expectEqual(awake.secondsAtLeastSerious, 120, "sleep: serious time before sleep")
            log.expectEqual(awake.samples, 7, "sleep: a dark-wake poll is a sample")
        } else {
            log.expect(false, "sleep: a snapshot while recording")
        }
        _ = recorder.observe(makePoll(t.addingTimeInterval(2010), running: "A", thermal: 1))

        // The session ends; the poll names it as the finished one.
        let ended = recorder.observe(makePoll(t.addingTimeInterval(2030), finished: "A",
                                              completedAt: t.addingTimeInterval(2025), reason: "overheated"))
        guard let summary = ended else {
            log.expect(false, "matching finished token: a summary")
            return
        }
        log.expect(!recorder.isRecording, "matching finished token: the recording ends")
        log.expectEqual(summary.sessionToken, "A", "matching finished token: token")
        log.expectEqual(summary.endedAt, t.addingTimeInterval(2025), "matching finished token: ends at last_completed_at")
        log.expect(summary.endedOnOverheating, "matching finished token: overheated")
        log.expectEqual(summary.secondsWatched, 165, "matching finished token: time up to the end is counted")
        log.expectEqual(summary.secondsAtLeastFair, 160, "matching finished token: secondsAtLeastFair")
        log.expectEqual(summary.secondsAtLeastSerious, 120, "matching finished token: secondsAtLeastSerious")
        log.expectEqual(summary.secondsCritical, 65, "matching finished token: secondsCritical")
        log.expectEqual(summary.highestState, 3, "matching finished token: highestState")
        log.expectEqual(summary.samples, 8, "matching finished token: samples")
        log.expectEqual(summary.noteText(timeZone: zone),
                        "Last session: hot for 2 minutes, very hot for 1 minute, so Awake ended it.",
                        "matching finished token: note")

        log.expect(recorder.observe(makePoll(t.addingTimeInterval(2040), finished: "A")) == nil,
                   "after the end: a poll without a session finishes nothing")
        log.expect(recorder.observe(makePoll(t.addingTimeInterval(2050), running: "A")) == nil,
                   "after the end: a finished token finishes nothing")
        log.expect(!recorder.isRecording, "after the end: a finished token never starts a recording again")
    }

    // MARK: Start

    static func checkStartRules(_ log: HeatCheckLog) {
        let t = baseDate()

        // The first poll after launch shows a session already running.
        let launched = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = launched.observe(makePoll(t, running: "A", thermal: 2))
        log.expect(launched.isRecording, "first poll: a running session starts a recording")
        if let snapshot = launched.snapshot(at: t) {
            log.expect(!snapshot.watchedFromStart, "first poll: not watched from the start")
            log.expectEqual(snapshot.firstSeenAt, t, "first poll: firstSeenAt")
            log.expectEqual(snapshot.highestState, 2, "first poll: highestState from the poll")
            log.expectEqual(snapshot.samples, 1, "first poll: samples")
            log.expectEqual(snapshot.secondsWatched, 0, "first poll: secondsWatched")
        } else {
            log.expect(false, "first poll: a snapshot while recording")
        }
        _ = launched.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        let ended = launched.observe(makePoll(t.addingTimeInterval(20), finished: "A",
                                              completedAt: t.addingTimeInterval(20), reason: "stopped"))
        if let summary = ended {
            log.expectEqual(summary.secondsAtLeastSerious, 20, "first poll: serious time")
            log.expect(!summary.endedOnOverheating, "first poll: stopped is not overheated")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session (from 14:00): hot for less than a minute.",
                            "first poll: note")
        } else {
            log.expect(false, "first poll: a summary at the end")
        }

        // A token that already has a saved summary.
        let saved = HeatRecorder(saved: nil, lastFinishedToken: "A")
        _ = saved.observe(makePoll(t, running: "A", thermal: 3))
        log.expect(!saved.isRecording, "saved token: no recording")
        log.expect(saved.snapshot(at: t) == nil, "saved token: no snapshot")
        _ = saved.observe(makePoll(t.addingTimeInterval(10), running: "B"))
        log.expect(saved.isRecording, "saved token: another token starts a recording")
        if let snapshot = saved.snapshot(at: t.addingTimeInterval(10)) {
            log.expectEqual(snapshot.sessionToken, "B", "saved token: the new token")
            log.expect(snapshot.watchedFromStart, "saved token: the new token is watched from the start")
        } else {
            log.expect(false, "saved token: a snapshot while recording")
        }
    }

    // MARK: End

    static func checkEndRules(_ log: HeatCheckLog) {
        let t = baseDate()

        // A new token, no poll between: the end is last_completed_at, as it
        // is no earlier than firstSeenAt.
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(t))
        _ = recorder.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        _ = recorder.observe(makePoll(t.addingTimeInterval(20), running: "A", thermal: 2))
        let byTime = recorder.observe(makePoll(t.addingTimeInterval(40), running: "B",
                                               completedAt: t.addingTimeInterval(30), reason: "overheated"))
        if let summary = byTime {
            log.expectEqual(summary.sessionToken, "A", "new token: the old token finishes")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(30), "new token: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "new token: last_completion_reason is used")
            log.expectEqual(summary.secondsAtLeastSerious, 20, "new token: time up to the end is counted")
            log.expectEqual(summary.samples, 2, "new token: samples")
        } else {
            log.expect(false, "new token: a summary")
        }
        if let started = recorder.snapshot(at: t.addingTimeInterval(40)) {
            log.expectEqual(started.sessionToken, "B", "new token: a new recording starts")
            log.expect(started.watchedFromStart, "new token: watched from the start")
            log.expectEqual(started.firstSeenAt, t.addingTimeInterval(40), "new token: firstSeenAt")
        } else {
            log.expect(false, "new token: a new recording")
        }

        // Neither: last_completed_at is before firstSeenAt, so the end is
        // endedAt and not overheated.
        _ = recorder.observe(makePoll(t.addingTimeInterval(50), running: "B"))
        let neither = recorder.observe(makePoll(t.addingTimeInterval(60), running: "C",
                                                completedAt: t.addingTimeInterval(35), reason: "overheated"))
        if let summary = neither {
            log.expectEqual(summary.sessionToken, "B", "neither: the old token finishes")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(50), "neither: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "neither: not overheated")
            log.expectEqual(summary.secondsWatched, 10, "neither: secondsWatched")
        } else {
            log.expect(false, "neither: a summary")
        }

        // Another session's finished token: ends at endedAt, not overheated.
        let other = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = other.observe(makePoll(t))
        _ = other.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        _ = other.observe(makePoll(t.addingTimeInterval(20), running: "A", thermal: 2))
        let otherToken = other.observe(makePoll(t.addingTimeInterval(30), finished: "Z",
                                                completedAt: t.addingTimeInterval(25), reason: "overheated"))
        if let summary = otherToken {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(20), "other finished token: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "other finished token: not overheated")
            log.expectEqual(summary.secondsWatched, 10, "other finished token: secondsWatched")
        } else {
            log.expect(false, "other finished token: a summary")
        }
        log.expect(!other.isRecording, "other finished token: the recording ends")

        // Whole seconds: first seen at 40.5 seconds, completed at 40.
        let whole = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = whole.observe(makePoll(t))
        _ = whole.observe(makePoll(t.addingTimeInterval(40.5), running: "A", thermal: 2))
        let wholeEnd = whole.observe(makePoll(t.addingTimeInterval(50), running: "B",
                                              completedAt: t.addingTimeInterval(40)))
        if let summary = wholeEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(40), "whole seconds: ends at last_completed_at")
            log.expectEqual(summary.secondsWatched, 0, "whole seconds: nothing counted before firstSeenAt")
        } else {
            log.expect(false, "whole seconds: a summary")
        }
    }

    // MARK: Poll order

    static func checkPollOrder(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(t, running: "A"))
        _ = recorder.observe(makePoll(t.addingTimeInterval(20), running: "A"))
        let late = recorder.observe(makePoll(t.addingTimeInterval(15), finished: "A",
                                             completedAt: t.addingTimeInterval(14), reason: "stopped"))
        log.expect(late == nil, "poll order: an older poll finishes nothing")
        log.expect(recorder.isRecording, "poll order: an older poll is ignored")
        _ = recorder.observe(makePoll(t.addingTimeInterval(30), running: "A"))
        if let snapshot = recorder.snapshot(at: t.addingTimeInterval(30)) {
            log.expectEqual(snapshot.samples, 3, "poll order: the older poll is not a sample")
            log.expectEqual(snapshot.secondsWatched, 30, "poll order: secondsWatched")
            log.expectEqual(snapshot.endedAt, t.addingTimeInterval(30), "poll order: endedAt")
        } else {
            log.expect(false, "poll order: a snapshot while recording")
        }
    }

    // MARK: Overlapping reads

    /// A poll is stamped when its status read started, so a thermal change,
    /// sleep or another read's snapshot can come during the read and reach
    /// the recorder first. The time up to that event is already counted.
    static func checkOverlappingReads(_ log: HeatCheckLog) {
        let t = baseDate()

        // A thermal change during a read.
        let thermal = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = thermal.observe(makePoll(t, running: "A", thermal: 2))
        thermal.thermalStateChanged(to: 3, at: t.addingTimeInterval(5))
        _ = thermal.observe(makePoll(t.addingTimeInterval(4), running: "A", thermal: 3))
        if let during = thermal.snapshot(at: t.addingTimeInterval(5)) {
            log.expectEqual(during.secondsWatched, 5, "thermal change during a read: nothing counted again")
            log.expectEqual(during.samples, 2, "thermal change during a read: the poll is a sample")
        } else {
            log.expect(false, "thermal change during a read: a snapshot while recording")
        }
        // endedAt: the late poll does not move it back. Checked by ending the
        // recording with a poll whose end falls back to endedAt, as a snapshot
        // would set endedAt itself.
        let ended = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = ended.observe(makePoll(t, running: "A", thermal: 2))
        ended.thermalStateChanged(to: 3, at: t.addingTimeInterval(5))
        _ = ended.observe(makePoll(t.addingTimeInterval(4), running: "A", thermal: 3))
        if let summary = ended.observe(makePoll(t.addingTimeInterval(10), finished: "Z")) {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(5), "thermal change during a read: endedAt stays")
        } else {
            log.expect(false, "thermal change during a read: a summary")
        }
        _ = thermal.observe(makePoll(t.addingTimeInterval(14), running: "A", thermal: 3))
        if let after = thermal.snapshot(at: t.addingTimeInterval(14)) {
            log.expectEqual(after.secondsWatched, 14, "thermal change during a read: secondsWatched")
            log.expectEqual(after.secondsAtLeastSerious, 14, "thermal change during a read: secondsAtLeastSerious")
            log.expectEqual(after.secondsCritical, 9, "thermal change during a read: secondsCritical")
        } else {
            log.expect(false, "thermal change during a read: a snapshot after it")
        }

        // Two reads that overlap: the one that started first (t+20) is fed,
        // then a snapshot comes (t+21), then the one that started second
        // (t+20.5) arrives, stamped before that snapshot. Its time is
        // already counted, but it is still a sample.
        _ = thermal.observe(makePoll(t.addingTimeInterval(20), running: "A", thermal: 3))
        _ = thermal.snapshot(at: t.addingTimeInterval(21))
        _ = thermal.observe(makePoll(t.addingTimeInterval(20.5), running: "A", thermal: 3))
        _ = thermal.observe(makePoll(t.addingTimeInterval(30), running: "A", thermal: 3))
        if let overlapped = thermal.snapshot(at: t.addingTimeInterval(30)) {
            log.expectEqual(overlapped.secondsWatched, 30, "overlapping reads: secondsWatched")
            log.expectEqual(overlapped.secondsCritical, 25, "overlapping reads: secondsCritical")
            log.expectEqual(overlapped.samples, 6, "overlapping reads: samples")
        } else {
            log.expect(false, "overlapping reads: a snapshot while recording")
        }

        // Sleep during a read, and a read started during a dark wake, both
        // arriving after the wake: time asleep is still not counted.
        let sleep = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = sleep.observe(makePoll(t, running: "A", thermal: 2))
        _ = sleep.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        sleep.systemWillSleep(at: t.addingTimeInterval(20))
        sleep.systemDidWake(at: t.addingTimeInterval(1000))
        _ = sleep.observe(makePoll(t.addingTimeInterval(19), running: "A", thermal: 2))
        _ = sleep.observe(makePoll(t.addingTimeInterval(500), running: "A", thermal: 2))
        _ = sleep.observe(makePoll(t.addingTimeInterval(1010), running: "A", thermal: 2))
        if let woken = sleep.snapshot(at: t.addingTimeInterval(1010)) {
            log.expectEqual(woken.secondsWatched, 30, "sleep during a read: time asleep is not counted")
            log.expectEqual(woken.secondsAtLeastSerious, 30, "sleep during a read: secondsAtLeastSerious")
            log.expectEqual(woken.endedAt, t.addingTimeInterval(1010), "sleep during a read: endedAt")
            log.expectEqual(woken.samples, 5, "sleep during a read: samples")
        } else {
            log.expect(false, "sleep during a read: a snapshot while recording")
        }
    }

    // MARK: Clock set back

    /// Polls are put in order by when their reads started, not by the
    /// clock, so setting the clock back does not make the recorder ignore
    /// them; the time is then measured from the new time.
    static func checkClockSetBack(_ log: HeatCheckLog) {
        let t = baseDate()
        let order = t.timeIntervalSince1970

        // Set back 25 seconds before a thermal change, then polls.
        let thermal = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = thermal.observe(makePoll(t, running: "A", thermal: 2))
        _ = thermal.observe(makePoll(t.addingTimeInterval(50), running: "A", thermal: 2))
        thermal.thermalStateChanged(to: 3, at: t.addingTimeInterval(25))
        _ = thermal.observe(makePoll(t.addingTimeInterval(35), running: "A", thermal: 3, order: order + 60))
        if let snapshot = thermal.snapshot(at: t.addingTimeInterval(35)) {
            log.expectEqual(snapshot.samples, 3, "set back before a thermal change: the poll is a sample")
            log.expectEqual(snapshot.secondsWatched, 60, "set back before a thermal change: secondsWatched")
            log.expectEqual(snapshot.secondsAtLeastSerious, 60, "set back before a thermal change: secondsAtLeastSerious")
            log.expectEqual(snapshot.secondsCritical, 10, "set back before a thermal change: secondsCritical")
        } else {
            log.expect(false, "set back before a thermal change: a snapshot while recording")
        }
        let thermalEnd = thermal.observe(makePoll(t.addingTimeInterval(45), finished: "A",
                                                  completedAt: t.addingTimeInterval(42), reason: "overheated",
                                                  order: order + 70))
        if let summary = thermalEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(42), "set back before a thermal change: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "set back before a thermal change: overheated")
            log.expectEqual(summary.secondsWatched, 67, "set back before a thermal change: time up to the end is counted")
            log.expectEqual(summary.secondsAtLeastSerious, 67, "set back before a thermal change: secondsAtLeastSerious at the end")
            log.expectEqual(summary.secondsCritical, 17, "set back before a thermal change: secondsCritical at the end")
            log.expectEqual(summary.samples, 3, "set back before a thermal change: samples at the end")
        } else {
            log.expect(false, "set back before a thermal change: a summary")
        }

        // Set back an hour between polls: a session ends and another starts
        // and ends before the clock catches up.
        let polls = HeatRecorder(saved: nil, lastFinishedToken: nil)
        let back = t.addingTimeInterval(-3600)
        _ = polls.observe(makePoll(t, running: "A", thermal: 2))
        _ = polls.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        log.expect(polls.observe(makePoll(back.addingTimeInterval(20), running: "A", thermal: 2, order: order + 20)) == nil,
                   "set back between polls: a running poll finishes nothing")
        // A read that started before the set-back, so earlier, but finished
        // after it: its time is later, but it is still ignored.
        log.expect(polls.observe(makePoll(t.addingTimeInterval(15), finished: "A", completedAt: t.addingTimeInterval(14),
                                          reason: "stopped", order: order + 15)) == nil,
                   "set back between polls: an older read finishes nothing")
        log.expect(polls.isRecording, "set back between polls: an older read is ignored")
        _ = polls.observe(makePoll(back.addingTimeInterval(30), running: "A", thermal: 2, order: order + 30))
        let pollsEnd = polls.observe(makePoll(back.addingTimeInterval(40), finished: "A",
                                              completedAt: back.addingTimeInterval(35), reason: "overheated",
                                              order: order + 40))
        if let summary = pollsEnd {
            log.expectEqual(summary.endedAt, back.addingTimeInterval(35), "set back between polls: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "set back between polls: overheated")
            log.expectEqual(summary.secondsWatched, 25, "set back between polls: measured from the new time")
            log.expectEqual(summary.secondsAtLeastSerious, 25, "set back between polls: secondsAtLeastSerious")
            log.expectEqual(summary.samples, 4, "set back between polls: samples")
        } else {
            log.expect(false, "set back between polls: a summary")
        }
        _ = polls.observe(makePoll(back.addingTimeInterval(50), running: "B", thermal: 1, order: order + 50))
        let nextEnd = polls.observe(makePoll(back.addingTimeInterval(60), finished: "B",
                                             completedAt: back.addingTimeInterval(58), reason: "timeout",
                                             order: order + 60))
        if let summary = nextEnd {
            log.expectEqual(summary.sessionToken, "B", "set back between polls: the next session is recorded")
            log.expect(summary.watchedFromStart, "set back between polls: the next session is watched from the start")
            log.expectEqual(summary.endedAt, back.addingTimeInterval(58), "set back between polls: the next session's end")
            log.expectEqual(summary.secondsAtLeastFair, 8, "set back between polls: the next session's time")
        } else {
            log.expect(false, "set back between polls: a summary of the next session")
        }
    }

    // MARK: Events after the end

    /// Thermal changes, sleep and snapshots that come after the session
    /// ended, before the poll that shows the end, count neither their time
    /// nor their thermal state.
    static func checkEventsAfterEnd(_ log: HeatCheckLog) {
        let t = baseDate()

        // A thermal change after the end.
        let late = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = late.observe(makePoll(t))
        _ = late.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 1))
        _ = late.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 1))
        late.thermalStateChanged(to: 2, at: t.addingTimeInterval(106))
        let lateEnd = late.observe(makePoll(t.addingTimeInterval(110), finished: "A",
                                            completedAt: t.addingTimeInterval(103), reason: "timeout"))
        if let summary = lateEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(103), "thermal change after the end: ends at last_completed_at")
            log.expectEqual(summary.highestState, 1, "thermal change after the end: highestState")
            log.expectEqual(summary.secondsAtLeastSerious, 0, "thermal change after the end: secondsAtLeastSerious")
            log.expectEqual(summary.secondsWatched, 13, "thermal change after the end: secondsWatched")
            log.expectEqual(summary.secondsAtLeastFair, 13, "thermal change after the end: secondsAtLeastFair")
            log.expect(!summary.shouldReport, "thermal change after the end: nothing to report")
            log.expect(summary.noteText(timeZone: zone) == nil, "thermal change after the end: no note")
        } else {
            log.expect(false, "thermal change after the end: a summary")
        }

        // The same change before the end.
        let early = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = early.observe(makePoll(t))
        _ = early.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 1))
        _ = early.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 1))
        early.thermalStateChanged(to: 2, at: t.addingTimeInterval(101))
        let earlyEnd = early.observe(makePoll(t.addingTimeInterval(110), finished: "A",
                                              completedAt: t.addingTimeInterval(103), reason: "timeout"))
        if let summary = earlyEnd {
            log.expectEqual(summary.highestState, 2, "thermal change before the end: highestState")
            log.expectEqual(summary.secondsAtLeastSerious, 2, "thermal change before the end: secondsAtLeastSerious")
            log.expectEqual(summary.secondsWatched, 13, "thermal change before the end: secondsWatched")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute.",
                            "thermal change before the end: note")
        } else {
            log.expect(false, "thermal change before the end: a summary")
        }

        // The guard ends the session, and the Mac sleeps after the end.
        let guarded = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = guarded.observe(makePoll(t))
        _ = guarded.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 1))
        _ = guarded.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 1))
        guarded.thermalStateChanged(to: 2, at: t.addingTimeInterval(101))
        guarded.systemWillSleep(at: t.addingTimeInterval(108))
        guarded.systemDidWake(at: t.addingTimeInterval(500))
        let guardedEnd = guarded.observe(makePoll(t.addingTimeInterval(505), finished: "A",
                                                  completedAt: t.addingTimeInterval(103), reason: "overheated"))
        if let summary = guardedEnd {
            log.expectEqual(summary.highestState, 2, "sleep after a guard ending: highestState")
            log.expectEqual(summary.secondsAtLeastSerious, 2, "sleep after a guard ending: secondsAtLeastSerious")
            log.expectEqual(summary.secondsWatched, 63, "sleep after a guard ending: secondsWatched")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute, so Awake ended it.",
                            "sleep after a guard ending: note")
        } else {
            log.expect(false, "sleep after a guard ending: a summary")
        }

        // Sleep after the end, which a poll during a dark wake shows along
        // with a new session: that one starts asleep.
        let asleep = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = asleep.observe(makePoll(t))
        _ = asleep.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        _ = asleep.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 2))
        asleep.systemWillSleep(at: t.addingTimeInterval(108))
        let asleepEnd = asleep.observe(makePoll(t.addingTimeInterval(300), running: "B",
                                                completedAt: t.addingTimeInterval(103)))
        if let summary = asleepEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(103), "sleep after the end: ends at last_completed_at")
            log.expectEqual(summary.secondsWatched, 63, "sleep after the end: only the time up to the end is counted")
            log.expectEqual(summary.secondsAtLeastSerious, 63, "sleep after the end: secondsAtLeastSerious")
        } else {
            log.expect(false, "sleep after the end: a summary")
        }
        asleep.systemDidWake(at: t.addingTimeInterval(500))
        _ = asleep.observe(makePoll(t.addingTimeInterval(510), running: "B"))
        if let snapshot = asleep.snapshot(at: t.addingTimeInterval(510)) {
            log.expectEqual(snapshot.sessionToken, "B", "sleep after the end: the new session is recorded")
            log.expectEqual(snapshot.secondsWatched, 10, "sleep after the end: the new session's time asleep is not counted")
        } else {
            log.expect(false, "sleep after the end: a snapshot of the new session")
        }

        // A snapshot after the end.
        let saved = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = saved.observe(makePoll(t))
        _ = saved.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 2))
        _ = saved.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 2))
        _ = saved.snapshot(at: t.addingTimeInterval(105))
        let savedEnd = saved.observe(makePoll(t.addingTimeInterval(110), finished: "A",
                                              completedAt: t.addingTimeInterval(103), reason: "timeout"))
        if let summary = savedEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(103), "snapshot after the end: ends at last_completed_at")
            log.expectEqual(summary.secondsWatched, 13, "snapshot after the end: secondsWatched")
            log.expectEqual(summary.secondsAtLeastSerious, 13, "snapshot after the end: secondsAtLeastSerious")
        } else {
            log.expect(false, "snapshot after the end: a summary")
        }

        // A thermal change during a dark wake after the end.
        let dark = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = dark.observe(makePoll(t))
        _ = dark.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 1))
        _ = dark.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 1))
        dark.systemWillSleep(at: t.addingTimeInterval(108))
        dark.thermalStateChanged(to: 2, at: t.addingTimeInterval(200))
        let darkEnd = dark.observe(makePoll(t.addingTimeInterval(210), finished: "A",
                                            completedAt: t.addingTimeInterval(103), reason: "timeout"))
        if let summary = darkEnd {
            log.expectEqual(summary.highestState, 1, "thermal change asleep after the end: highestState")
            log.expectEqual(summary.secondsAtLeastFair, 13, "thermal change asleep after the end: secondsAtLeastFair")
            log.expect(!summary.shouldReport, "thermal change asleep after the end: nothing to report")
        } else {
            log.expect(false, "thermal change asleep after the end: a summary")
        }

        // A read that started before the end is delivered after a thermal
        // change that came after the end. The rise and fall after the end
        // are still taken back, along with the late poll's sample.
        let overlap = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = overlap.observe(makePoll(t))
        _ = overlap.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 1))
        _ = overlap.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 1))
        overlap.thermalStateChanged(to: 2, at: t.addingTimeInterval(103.5))
        overlap.thermalStateChanged(to: 1, at: t.addingTimeInterval(103.9))
        _ = overlap.observe(makePoll(t.addingTimeInterval(102.8), running: "A", thermal: 1))
        let overlapEnd = overlap.observe(makePoll(t.addingTimeInterval(110), finished: "A",
                                                  completedAt: t.addingTimeInterval(103), reason: "timeout"))
        if let summary = overlapEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(103), "late read and thermal change after the end: ends at last_completed_at")
            log.expectEqual(summary.highestState, 1, "late read and thermal change after the end: highestState")
            log.expectEqual(summary.secondsAtLeastSerious, 0, "late read and thermal change after the end: secondsAtLeastSerious")
            log.expectEqual(summary.secondsWatched, 13, "late read and thermal change after the end: secondsWatched")
            log.expectEqual(summary.secondsAtLeastFair, 13, "late read and thermal change after the end: secondsAtLeastFair")
            log.expectEqual(summary.samples, 2, "late read and thermal change after the end: samples")
            log.expect(!summary.shouldReport, "late read and thermal change after the end: nothing to report")
            log.expect(summary.noteText(timeZone: zone) == nil, "late read and thermal change after the end: no note")
        } else {
            log.expect(false, "late read and thermal change after the end: a summary")
        }

        // A read that started before the end is delivered after the Mac
        // slept and woke: the time from the end to the sleep is not counted.
        let overlapAsleep = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = overlapAsleep.observe(makePoll(t))
        _ = overlapAsleep.observe(makePoll(t.addingTimeInterval(90), running: "A", thermal: 2))
        _ = overlapAsleep.observe(makePoll(t.addingTimeInterval(100), running: "A", thermal: 2))
        overlapAsleep.systemWillSleep(at: t.addingTimeInterval(107))
        overlapAsleep.systemDidWake(at: t.addingTimeInterval(5000))
        _ = overlapAsleep.observe(makePoll(t.addingTimeInterval(101), running: "A", thermal: 0))
        let overlapAsleepEnd = overlapAsleep.observe(makePoll(t.addingTimeInterval(5010), finished: "A",
                                                              completedAt: t.addingTimeInterval(102), reason: "timeout"))
        if let summary = overlapAsleepEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(102), "late read and sleep after the end: ends at last_completed_at")
            log.expectEqual(summary.secondsWatched, 12, "late read and sleep after the end: secondsWatched")
            log.expectEqual(summary.secondsAtLeastSerious, 12, "late read and sleep after the end: secondsAtLeastSerious")
        } else {
            log.expect(false, "late read and sleep after the end: a summary")
        }
    }

    // MARK: Relaunch

    static func checkRelaunch(_ log: HeatCheckLog) {
        let t = baseDate()
        let before = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = before.observe(makePoll(t))
        _ = before.observe(makePoll(t.addingTimeInterval(10), running: "A", thermal: 2))
        _ = before.observe(makePoll(t.addingTimeInterval(40), running: "A", thermal: 2))
        guard let inProgress = before.snapshot(at: t.addingTimeInterval(50)) else {
            log.expect(false, "relaunch: a recording in progress")
            return
        }
        log.expectEqual(inProgress.secondsAtLeastSerious, 40, "relaunch: serious time before quitting")
        log.expectEqual(inProgress.endedAt, t.addingTimeInterval(50), "relaunch: endedAt of the saved recording")
        guard let stored = inProgress.propertyList, let saved = HeatSummary(propertyList: stored) else {
            log.expect(false, "relaunch: the recording in progress is stored and read back")
            return
        }
        log.expectEqual(saved, inProgress, "relaunch: the recording in progress survives storing")

        // The same token is still running: the gap is not counted.
        let same = HeatRecorder(saved: saved, lastFinishedToken: "Z")
        log.expect(same.isRecording, "relaunch: a saved recording is in progress")
        log.expect(same.observe(makePoll(t.addingTimeInterval(600), running: "A", thermal: 2)) == nil,
                   "same token: finishes nothing")
        _ = same.observe(makePoll(t.addingTimeInterval(610), running: "A", thermal: 2))
        if let snapshot = same.snapshot(at: t.addingTimeInterval(610)) {
            log.expectEqual(snapshot.secondsWatched, 50, "same token: the gap is not counted")
            log.expectEqual(snapshot.secondsAtLeastSerious, 50, "same token: serious time continues")
            log.expectEqual(snapshot.samples, 4, "same token: samples continue")
            log.expectEqual(snapshot.firstSeenAt, t.addingTimeInterval(10), "same token: firstSeenAt stays")
            log.expect(snapshot.watchedFromStart, "same token: watchedFromStart stays")
        } else {
            log.expect(false, "same token: a snapshot while recording")
        }

        // No session runs: the saved recording ends at last_completed_at.
        let stopped = HeatRecorder(saved: saved, lastFinishedToken: "Z")
        let ended = stopped.observe(makePoll(t.addingTimeInterval(900), finished: "A",
                                             completedAt: t.addingTimeInterval(300), reason: "timeout"))
        if let summary = ended {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(300), "no session: ends at last_completed_at")
            log.expect(!summary.endedOnOverheating, "no session: timeout is not overheated")
            log.expectEqual(summary.secondsWatched, 40, "no session: the gap is not counted")
            log.expectEqual(summary.samples, 2, "no session: the ending poll is not a sample")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute.",
                            "no session: note")
        } else {
            log.expect(false, "no session: a summary")
        }
        log.expect(!stopped.isRecording, "no session: the recording ends")

        // Another session runs: the saved one ends, and a new one starts,
        // not watched from the start.
        let replaced = HeatRecorder(saved: saved, lastFinishedToken: nil)
        let replacedEnd = replaced.observe(makePoll(t.addingTimeInterval(900), running: "B",
                                                    completedAt: t.addingTimeInterval(300)))
        if let summary = replacedEnd {
            log.expectEqual(summary.sessionToken, "A", "another session: the saved token finishes")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(300), "another session: ends at last_completed_at")
            log.expect(!summary.endedOnOverheating, "another session: not overheated")
        } else {
            log.expect(false, "another session: a summary")
        }
        if let snapshot = replaced.snapshot(at: t.addingTimeInterval(900)) {
            log.expectEqual(snapshot.sessionToken, "B", "another session: a new recording")
            log.expect(!snapshot.watchedFromStart, "another session: not watched from the start")
        } else {
            log.expect(false, "another session: a snapshot while recording")
        }

        // A saved recording whose token already has a summary is dropped.
        let stale = HeatRecorder(saved: saved, lastFinishedToken: "A")
        log.expect(!stale.isRecording, "stale recording: dropped")
        log.expect(stale.observe(makePoll(t.addingTimeInterval(900), running: "A")) == nil, "stale recording: no summary")
        log.expect(!stale.isRecording, "stale recording: not started again")

        // A saved recording with a damaged firstSeenAt ends without trapping.
        // Fields are compared one by one, as a NaN date is never equal.
        let damaged: [(String, TimeInterval)] = [("NaN", TimeInterval.nan), ("1e300", 1e300)]
        for (label, seconds) in damaged {
            let broken = makeSummary(highest: 2, serious: 60, firstSeenAt: Date(timeIntervalSince1970: seconds))
            let finished = HeatRecorder(saved: broken, lastFinishedToken: nil)
            let finishedEnd = finished.observe(makePoll(t.addingTimeInterval(900), finished: "A",
                                                        completedAt: t.addingTimeInterval(300), reason: "overheated"))
            if let summary = finishedEnd {
                log.expectEqual(summary.sessionToken, "A", "firstSeenAt \(label), finished token: the saved token finishes")
                log.expectEqual(summary.endedAt, t.addingTimeInterval(300),
                                "firstSeenAt \(label), finished token: ends at last_completed_at")
                log.expect(summary.endedOnOverheating, "firstSeenAt \(label), finished token: overheated")
            } else {
                log.expect(false, "firstSeenAt \(label), finished token: a summary")
            }

            let other = HeatRecorder(saved: broken, lastFinishedToken: nil)
            let otherEnd = other.observe(makePoll(t.addingTimeInterval(900), running: "B",
                                                  completedAt: t.addingTimeInterval(300), reason: "overheated"))
            if let summary = otherEnd {
                log.expectEqual(summary.sessionToken, "A", "firstSeenAt \(label), another session: the saved token finishes")
                log.expectEqual(summary.endedAt, broken.endedAt, "firstSeenAt \(label), another session: ends at endedAt")
                log.expect(!summary.endedOnOverheating, "firstSeenAt \(label), another session: not overheated")
            } else {
                log.expect(false, "firstSeenAt \(label), another session: a summary")
            }
            if let snapshot = other.snapshot(at: t.addingTimeInterval(900)) {
                log.expectEqual(snapshot.sessionToken, "B", "firstSeenAt \(label), another session: a new recording")
            } else {
                log.expect(false, "firstSeenAt \(label), another session: a snapshot while recording")
            }
        }

        // A saved sample count at the largest Int stays there.
        var full = makeSummary(highest: 2)
        full.samples = Int.max
        let counted = HeatRecorder(saved: full, lastFinishedToken: nil)
        _ = counted.observe(makePoll(t.addingTimeInterval(900), running: "A", thermal: 2))
        if let snapshot = counted.snapshot(at: t.addingTimeInterval(900)) {
            log.expectEqual(snapshot.samples, Int.max, "samples at the largest Int: no overflow")
        } else {
            log.expect(false, "samples at the largest Int: a snapshot while recording")
        }
    }

    // MARK: What is reported

    static func checkReportRules(_ log: HeatCheckLog) {
        let nominal = makeSummary(highest: 0)
        log.expect(!nominal.shouldReport, "nominal: nothing to report")
        log.expect(nominal.noteText(timeZone: zone) == nil, "nominal: no note")

        let fair = makeSummary(highest: 1, fair: 600)
        log.expect(!fair.shouldReport, "fair alone: nothing to report")
        log.expect(fair.noteText(timeZone: zone) == nil, "fair alone: no note")

        log.expect(makeSummary(highest: 2, serious: 60).shouldReport, "serious: reported")
        log.expect(makeSummary(highest: 3, serious: 120, critical: 60).shouldReport, "critical: reported")
        log.expect(makeSummary(highest: 1, fair: 60, overheated: true).shouldReport, "a guard ending: reported")
        log.expect(makeSummary(highest: 0, overheated: true).shouldReport, "a guard ending at nominal: reported")
    }

    // MARK: Wording

    static func checkWording(_ log: HeatCheckLog) {
        log.expectEqual(makeSummary(highest: 2, serious: 180, fair: 240).noteText(timeZone: zone),
                        "Last session: hot for 3 minutes.", "example: serious")
        log.expectEqual(makeSummary(highest: 2, serious: 239, overheated: true).noteText(timeZone: zone),
                        "Last session: hot for 3 minutes, so Awake ended it.", "example: guard ending")
        log.expectEqual(makeSummary(highest: 2, serious: 3930).noteText(timeZone: zone),
                        "Last session: hot for 1 hour 5 minutes.", "example: over an hour")

        let fromAfternoon = makeSummary(highest: 3, serious: 539, critical: 119, watchedFromStart: false,
                                        firstSeenAt: makeDate(2026, 9, 28, 14, 5, 30),
                                        endedAt: makeDate(2026, 9, 28, 15, 0))
        log.expectEqual(fromAfternoon.noteText(timeZone: zone),
                        "Last session (from 14:05): hot for 8 minutes, very hot for 1 minute.", "example: critical, from 14:05")

        log.expectEqual(makeSummary(highest: 1, fair: 300, overheated: true).noteText(timeZone: zone),
                        "Last session: the Mac got too hot, so Awake ended it.", "example: guard ending without serious")

        let overnight = makeSummary(highest: 2, serious: 200, watchedFromStart: false,
                                    firstSeenAt: makeDate(2026, 9, 28, 23, 50),
                                    endedAt: makeDate(2026, 9, 29, 0, 20))
        log.expectEqual(overnight.noteText(timeZone: zone),
                        "Last session (from 2026-09-28 23:50): hot for 3 minutes.", "watching began on an earlier day")
        // 20:50 to 21:20 on the same day in UTC.
        log.expectEqual(overnight.noteText(timeZone: TimeZone(identifier: "UTC")!),
                        "Last session (from 20:50): hot for 3 minutes.", "the time zone decides the day")

        log.expectEqual(makeSummary(highest: 3, serious: 30, critical: 10, overheated: true).noteText(timeZone: zone),
                        "Last session: hot for less than a minute, very hot for less than a minute, so Awake ended it.",
                        "critical and a guard ending")
    }

    // MARK: Durations

    static func checkDurations(_ log: HeatCheckLog) {
        let expected: [(Int, String)] = [
            (-5, "less than a minute"),
            (0, "less than a minute"),
            (59, "less than a minute"),
            (60, "1 minute"),
            (119, "1 minute"),
            (720, "12 minutes"),
            (3599, "59 minutes"),
            (3600, "1 hour"),
            (3660, "1 hour 1 minute"),
            (3900, "1 hour 5 minutes"),
            (7200, "2 hours"),
            (86399, "23 hours 59 minutes"),
            (86400, "1 day"),
            (90000, "1 day 1 hour"),
            (93600, "1 day 2 hours"),
            (172800, "2 days"),
            (176400, "2 days 1 hour"),
        ]
        for (seconds, text) in expected {
            log.expectEqual(HeatSummary.durationText(seconds: seconds), text, "durationText(seconds: \(seconds))")
        }
    }

    // MARK: Property list

    static func checkPropertyList(_ log: HeatCheckLog) {
        let summary = HeatSummary(
            sessionToken: "1759060800-12345",
            firstSeenAt: makeDate(2026, 9, 28, 14, 0).addingTimeInterval(0.25),
            watchedFromStart: false,
            endedAt: makeDate(2026, 9, 28, 16, 30, 15),
            endedOnOverheating: true,
            secondsAtLeastFair: 1234.5,
            secondsAtLeastSerious: 321.125,
            secondsCritical: 60,
            highestState: 3,
            secondsWatched: 8999.75,
            samples: 900
        )
        guard let stored = summary.propertyList else {
            log.expect(false, "property list: a dictionary")
            return
        }
        log.expectEqual(stored.count, 11, "property list: every field is stored")
        log.expectEqual(stored["sessionToken"] as? String, "1759060800-12345", "property list: sessionToken")
        log.expectEqual(stored["highestState"] as? Int, 3, "property list: highestState")
        log.expectEqual(stored["samples"] as? Int, 900, "property list: samples")
        log.expectEqual(stored["watchedFromStart"] as? Bool, false, "property list: watchedFromStart")
        log.expectEqual(stored["endedOnOverheating"] as? Bool, true, "property list: endedOnOverheating")
        log.expectEqual(stored["secondsWatched"] as? Double, 8999.75, "property list: secondsWatched")
        log.expect(stored["endedAt"] is Date, "property list: endedAt is a date")

        log.expectEqual(HeatSummary(propertyList: stored), summary, "property list: round trip")

        let empty: [String: Any] = [:]
        log.expect(HeatSummary(propertyList: empty) == nil, "property list: an empty dictionary is not a summary")
        var wrong = stored
        wrong["highestState"] = "critical"
        log.expect(HeatSummary(propertyList: wrong) == nil, "property list: a wrong type is not a summary")
        var missing = stored
        missing.removeValue(forKey: "sessionToken")
        log.expect(HeatSummary(propertyList: missing) == nil, "property list: a missing field is not a summary")

        // Damaged values the recorder could trap on.
        var notANumber = stored
        notANumber["firstSeenAt"] = Date(timeIntervalSince1970: .nan)
        log.expect(HeatSummary(propertyList: notANumber) == nil, "property list: a NaN firstSeenAt is not a summary")
        var farAway = stored
        farAway["endedAt"] = Date(timeIntervalSince1970: 1e300)
        log.expect(HeatSummary(propertyList: farAway) == nil, "property list: an endedAt out of range is not a summary")
        var tooMany = stored
        tooMany["samples"] = Int.max
        log.expect(HeatSummary(propertyList: tooMany) == nil, "property list: samples at the largest Int is not a summary")
        var negative = stored
        negative["samples"] = -1
        log.expect(HeatSummary(propertyList: negative) == nil, "property list: negative samples is not a summary")
    }
}
