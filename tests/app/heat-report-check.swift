// Copyright (C) 2026 Antti Käenmäki

import Foundation

// The heat report check: feeds HeatRecorder made-up polls, thermal changes,
// sleep and wake, and checks the note's wording and the thermal state numbers
// the app passes to bin/awake. Built with HeatReport.swift alone, as CI does:
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
        checkPending(log)
        checkPollOrder(log)
        checkOverlappingReads(log)
        checkSleep(log)
        checkClockSteps(log)
        checkStartRules(log)
        checkEndRules(log)
        checkRelaunch(log)
        checkReportRules(log)
        checkWording(log)
        checkDurations(log)
        checkPropertyList(log)
        checkThermalNumbers(log)

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

    /// A poll of this account's status whose read started at `uptime`, and
    /// by the clock that many seconds after `baseDate()` unless `at` is
    /// given: a running session when `running` is given, otherwise no
    /// session, with `finished` as the last one's token. `completedAt` is
    /// in seconds after `baseDate()` too.
    static func makePoll(
        _ uptime: TimeInterval,
        at: Date? = nil,
        running: String? = nil,
        finished: String? = nil,
        completedAt: TimeInterval? = nil,
        reason: String? = nil,
        thermal: Int = 0
    ) -> HeatPoll {
        let base = baseDate()
        var completed: Int? = nil
        if let completedAt = completedAt {
            completed = Int(base.timeIntervalSince1970 + completedAt)
        }
        let result = HeatPoll(
            at: at ?? base.addingTimeInterval(uptime),
            uptime: uptime,
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

    /// Checks a summary's counts, the times in seconds; nil fails.
    static func expectCounts(
        _ log: HeatCheckLog,
        _ summary: HeatSummary?,
        watched: TimeInterval,
        fair: TimeInterval = 0,
        serious: TimeInterval = 0,
        critical: TimeInterval = 0,
        highest: Int,
        samples: Int,
        _ label: String
    ) {
        guard let summary = summary else {
            log.expect(false, "\(label): a summary")
            return
        }
        log.expectEqual(summary.secondsWatched, watched, "\(label): secondsWatched")
        log.expectEqual(summary.secondsAtLeastFair, fair, "\(label): secondsAtLeastFair")
        log.expectEqual(summary.secondsAtLeastSerious, serious, "\(label): secondsAtLeastSerious")
        log.expectEqual(summary.secondsCritical, critical, "\(label): secondsCritical")
        log.expectEqual(summary.highestState, highest, "\(label): highestState")
        log.expectEqual(summary.samples, samples, "\(label): samples")
    }

    // MARK: HeatPoll

    static func checkPollMapping(_ log: HeatCheckLog) {
        let at = baseDate()

        let failed = HeatPoll(at: at, uptime: 0, active: true, hasError: true, leftoverSettings: false, otherUserSession: false,
                              sessionToken: "A", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0)
        log.expect(failed == nil, "a status with an error gives no poll")

        if let leftover = HeatPoll(at: at, uptime: 0, active: true, hasError: false, leftoverSettings: true, otherUserSession: false,
                                   sessionToken: "A", lastCompletedAt: 100, lastCompletionReason: "stopped", thermalState: 1) {
            log.expect(leftover.runningToken == nil, "leftover sleep settings give no running token")
            log.expect(leftover.finishedToken == nil, "leftover sleep settings give no finished token")
        } else {
            log.expect(false, "leftover sleep settings give a poll")
        }

        if let other = HeatPoll(at: at, uptime: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: true,
                                sessionToken: "B", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(other.runningToken == nil, "another account's session gives no running token")
            log.expect(other.finishedToken == nil, "another account's session gives no finished token")
        } else {
            log.expect(false, "another account's session gives a poll")
        }

        if let tokenless = HeatPoll(at: at, uptime: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                    sessionToken: nil, lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(tokenless.runningToken == nil, "a running session without a token counts as none")
            log.expect(tokenless.finishedToken == nil, "a running session without a token gives no finished token")
        } else {
            log.expect(false, "a running session without a token gives a poll")
        }

        if let empty = HeatPoll(at: at, uptime: 0, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                sessionToken: "", lastCompletedAt: nil, lastCompletionReason: nil, thermalState: 0) {
            log.expect(empty.runningToken == nil, "a running session with an empty token counts as none")
        } else {
            log.expect(false, "a running session with an empty token gives a poll")
        }

        if let running = HeatPoll(at: at, uptime: 5, active: true, hasError: false, leftoverSettings: false, otherUserSession: false,
                                  sessionToken: "A", lastCompletedAt: 50, lastCompletionReason: "timeout", thermalState: 2) {
            log.expectEqual(running.runningToken, "A", "a running session's token")
            log.expect(running.finishedToken == nil, "a running session gives no finished token")
            log.expectEqual(running.at, at, "a poll's time")
            log.expectEqual(running.uptime, 5, "a poll's uptime")
            log.expectEqual(running.thermalState, 2, "a poll's thermal state")
        } else {
            log.expect(false, "a running session gives a poll")
        }

        if let stopped = HeatPoll(at: at, uptime: 0, active: false, hasError: false, leftoverSettings: false, otherUserSession: false,
                                  sessionToken: "A", lastCompletedAt: 1234, lastCompletionReason: "overheated", thermalState: 0) {
            log.expect(stopped.runningToken == nil, "no running session gives no running token")
            log.expectEqual(stopped.finishedToken, "A", "no running session gives the finished token")
            log.expectEqual(stopped.lastCompletedAt, 1234, "a poll's last_completed_at")
            log.expectEqual(stopped.lastCompletionReason, "overheated", "a poll's last_completion_reason")
        } else {
            log.expect(false, "no running session gives a poll")
        }

        log.expectEqual(makePoll(0, thermal: 7).thermalState, 3, "a thermal state above 3 is clamped")
        log.expectEqual(makePoll(0, thermal: -2).thermalState, 0, "a thermal state below 0 is clamped")
    }

    // MARK: Time at each level

    static func checkLevels(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)

        log.expect(recorder.observe(makePoll(0)) == nil, "levels: a poll without a session finishes nothing")
        log.expect(!recorder.isRecording, "levels: no recording without a session")
        log.expect(recorder.inProgress == nil, "levels: nothing in progress without a recording")

        log.expect(recorder.observe(makePoll(10, running: "A")) == nil, "levels: a start finishes nothing")
        log.expect(recorder.isRecording, "levels: a running session starts a recording")
        recorder.thermalStateChanged(to: 1, uptime: 15)
        _ = recorder.observe(makePoll(20, running: "A", thermal: 1))
        recorder.thermalStateChanged(to: 2, uptime: 30)
        _ = recorder.observe(makePoll(40, running: "A", thermal: 2))
        recorder.thermalStateChanged(to: 3, uptime: 45)
        _ = recorder.observe(makePoll(50, running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 40, fair: 35, serious: 20, critical: 5, highest: 3, samples: 4, "levels")
        if let summary = recorder.inProgress {
            log.expectEqual(summary.sessionToken, "A", "levels: token")
            log.expectEqual(summary.firstSeenAt, t.addingTimeInterval(10), "levels: firstSeenAt")
            log.expect(summary.watchedFromStart, "levels: a session started after a poll without one is watched from the start")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(50), "levels: endedAt is the last poll's time")
        }

        // 200 seconds without an event count as 60, at the state in effect.
        _ = recorder.observe(makePoll(250, running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 100, fair: 95, serious: 80, critical: 65, highest: 3, samples: 5, "cap")

        // A fall to serious at the poll's uptime counts nothing up to it.
        recorder.thermalStateChanged(to: 2, uptime: 250)
        _ = recorder.observe(makePoll(280, running: "A", thermal: 2))
        expectCounts(log, recorder.inProgress, watched: 130, fair: 125, serious: 110, critical: 65, highest: 3, samples: 6,
                     "after a fall to serious")

        // The session ends; the poll names it as the finished one.
        let ended = recorder.observe(makePoll(290, finished: "A", completedAt: 285, reason: "overheated"))
        expectCounts(log, ended, watched: 130, fair: 125, serious: 110, critical: 65, highest: 3, samples: 6, "end")
        if let summary = ended {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(285), "end: at last_completed_at")
            log.expect(summary.endedOnOverheating, "end: overheated")
            log.expectEqual(summary.noteText(timeZone: zone),
                            "Last session: hot for 1 minute, very hot for 1 minute, so Awake ended it.", "end: note")
        }
        log.expect(!recorder.isRecording, "end: the recording ends")
        log.expect(recorder.inProgress == nil, "end: nothing in progress")

        log.expect(recorder.observe(makePoll(300, finished: "A")) == nil, "after the end: a poll without a session finishes nothing")
        log.expect(recorder.observe(makePoll(310, running: "A")) == nil, "after the end: a finished token finishes nothing")
        log.expect(!recorder.isRecording, "after the end: a finished token never starts a recording again")
    }

    // MARK: Pending time

    static func checkPending(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(0))
        _ = recorder.observe(makePoll(10, running: "A", thermal: 2))
        recorder.thermalStateChanged(to: 3, uptime: 14)
        expectCounts(log, recorder.inProgress, watched: 0, highest: 2, samples: 1, "pending: nothing added before the next poll")

        _ = recorder.observe(makePoll(20, running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 10, fair: 10, serious: 10, critical: 6, highest: 3, samples: 2,
                     "pending: added at a running poll")
        recorder.thermalStateChanged(to: 2, uptime: 22)
        _ = recorder.observe(makePoll(30, running: "A", thermal: 2))
        expectCounts(log, recorder.inProgress, watched: 20, fair: 20, serious: 20, critical: 8, highest: 3, samples: 3,
                     "pending: a fall between polls")

        // A spike between two polls, gone by the next one, still sets the
        // highest state.
        let spike = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = spike.observe(makePoll(0))
        _ = spike.observe(makePoll(10, running: "A", thermal: 1))
        spike.thermalStateChanged(to: 3, uptime: 12)
        spike.thermalStateChanged(to: 1, uptime: 14)
        _ = spike.observe(makePoll(20, running: "A", thermal: 1))
        expectCounts(log, spike.inProgress, watched: 10, fair: 10, serious: 2, critical: 2, highest: 3, samples: 2,
                     "spike between polls")

        // A state above critical counts as critical, and the highest state
        // stays 3.
        let clamped = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = clamped.observe(makePoll(0))
        _ = clamped.observe(makePoll(10, running: "A", thermal: 1))
        clamped.thermalStateChanged(to: 7, uptime: 12)
        clamped.thermalStateChanged(to: 1, uptime: 14)
        _ = clamped.observe(makePoll(20, running: "A", thermal: 1))
        expectCounts(log, clamped.inProgress, watched: 10, fair: 10, serious: 2, critical: 2, highest: 3, samples: 2,
                     "a state above 3 between polls")

        // A thermal change with a smaller uptime than the previous event,
        // which the app never sends, counts no time but still sets the
        // highest state.
        let late = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = late.observe(makePoll(0))
        _ = late.observe(makePoll(10, running: "A", thermal: 1))
        _ = late.observe(makePoll(20, running: "A", thermal: 1))
        late.thermalStateChanged(to: 3, uptime: 18)
        late.thermalStateChanged(to: 1, uptime: 19)
        _ = late.observe(makePoll(30, running: "A", thermal: 1))
        expectCounts(log, late.inProgress, watched: 20, fair: 20, highest: 3, samples: 3, "a late spike")

        // So does a spike while asleep.
        let asleep = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = asleep.observe(makePoll(0))
        _ = asleep.observe(makePoll(10, running: "A", thermal: 1))
        asleep.systemWillSleep(uptime: 12)
        asleep.thermalStateChanged(to: 3, uptime: 14)
        asleep.thermalStateChanged(to: 1, uptime: 16)
        asleep.systemDidWake(uptime: 18)
        _ = asleep.observe(makePoll(20, running: "A", thermal: 1))
        expectCounts(log, asleep.inProgress, watched: 4, fair: 4, highest: 3, samples: 2, "a spike while asleep")

        // Heat after the last poll that showed the session running never
        // counts, whether it came before the end or after it.
        let dropped = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = dropped.observe(makePoll(0))
        _ = dropped.observe(makePoll(10, running: "A", thermal: 2))
        _ = dropped.observe(makePoll(20, running: "A", thermal: 2))
        dropped.thermalStateChanged(to: 3, uptime: 25)
        expectCounts(log, dropped.inProgress, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2,
                     "dropped: the rise is pending")
        let ended = dropped.observe(makePoll(30, finished: "A", completedAt: 27, reason: "overheated"))
        expectCounts(log, ended, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "dropped: at the end")
        if let summary = ended {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(27), "dropped: ends at last_completed_at")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute, so Awake ended it.",
                            "dropped: note")
        }
    }

    // MARK: Poll order

    static func checkPollOrder(_ log: HeatCheckLog) {
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(0))
        _ = recorder.observe(makePoll(10, running: "A", thermal: 1))
        _ = recorder.observe(makePoll(20, running: "A", thermal: 1))

        // Reads that started before the last one, by uptime, are ignored.
        log.expect(recorder.observe(makePoll(15, finished: "A", completedAt: 15)) == nil, "late poll: finishes nothing")
        log.expect(recorder.isRecording, "late poll: the recording goes on")
        _ = recorder.observe(makePoll(18, running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 10, fair: 10, highest: 1, samples: 2, "late poll: ignored")

        _ = recorder.observe(makePoll(30, running: "A", thermal: 1))
        expectCounts(log, recorder.inProgress, watched: 20, fair: 20, highest: 1, samples: 3, "late poll: the next poll")
    }

    // MARK: Overlapping reads

    static func checkOverlappingReads(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(0))
        _ = recorder.observe(makePoll(10, running: "A"))
        recorder.thermalStateChanged(to: 2, uptime: 18)

        // A read that started at 15, before the change, arrives after it: it
        // adds the time up to the change and nothing more.
        _ = recorder.observe(makePoll(15, running: "A", thermal: 2))
        expectCounts(log, recorder.inProgress, watched: 8, highest: 2, samples: 2, "overlap: the time up to the change")
        if let summary = recorder.inProgress {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(15), "overlap: endedAt is the poll's time")
        }
        _ = recorder.observe(makePoll(28, running: "A", thermal: 2))
        expectCounts(log, recorder.inProgress, watched: 18, fair: 10, serious: 10, highest: 2, samples: 3,
                     "overlap: no time counted twice")

        // A thermal change with a smaller uptime than the previous event,
        // which the app never sends (it takes a thermal change's uptime when
        // it arrives on the main queue), counts nothing and leaves the
        // previous event where it is; its state holds from there.
        recorder.thermalStateChanged(to: 3, uptime: 25)
        _ = recorder.observe(makePoll(38, running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 28, fair: 20, serious: 20, critical: 10, highest: 3, samples: 4,
                     "late change")
    }

    // MARK: Sleep

    static func checkSleep(_ log: HeatCheckLog) {
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(0))
        _ = recorder.observe(makePoll(10, running: "A", thermal: 2))
        _ = recorder.observe(makePoll(20, running: "A", thermal: 2))
        recorder.systemWillSleep(uptime: 25)

        // A dark wake: the uptime advances, but nothing is counted.
        log.expect(recorder.observe(makePoll(40, running: "A", thermal: 3)) == nil, "sleep: a dark-wake poll finishes nothing")
        expectCounts(log, recorder.inProgress, watched: 15, fair: 15, serious: 15, highest: 3, samples: 3,
                     "sleep: the time up to the sleep")
        recorder.thermalStateChanged(to: 1, uptime: 45)
        recorder.systemDidWake(uptime: 50)
        _ = recorder.observe(makePoll(60, running: "A", thermal: 1))
        expectCounts(log, recorder.inProgress, watched: 25, fair: 25, serious: 15, highest: 3, samples: 4,
                     "sleep: the time after the wake")

        // Sleep before any session: the flag holds while a recording starts,
        // and after it ends, during the same dark wake.
        let sleepFirst = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = sleepFirst.observe(makePoll(0))
        sleepFirst.systemWillSleep(uptime: 5)
        _ = sleepFirst.observe(makePoll(10, running: "A", thermal: 2))
        _ = sleepFirst.observe(makePoll(20, running: "A", thermal: 2))
        expectCounts(log, sleepFirst.inProgress, watched: 0, highest: 2, samples: 2,
                     "sleep first: a recording started during a dark wake")
        let endedDark = sleepFirst.observe(makePoll(30, finished: "A", completedAt: 30))
        expectCounts(log, endedDark, watched: 0, highest: 2, samples: 2, "sleep first: the end during the dark wake")
        _ = sleepFirst.observe(makePoll(40, running: "B", thermal: 2))
        _ = sleepFirst.observe(makePoll(50, running: "B", thermal: 2))
        expectCounts(log, sleepFirst.inProgress, watched: 0, highest: 2, samples: 2,
                     "sleep first: the next recording during the dark wake")
        sleepFirst.systemDidWake(uptime: 55)
        _ = sleepFirst.observe(makePoll(60, running: "B", thermal: 2))
        expectCounts(log, sleepFirst.inProgress, watched: 5, fair: 5, serious: 5, highest: 2, samples: 3,
                     "sleep first: the time after the wake")
    }

    // MARK: Clock steps

    static func checkClockSteps(_ log: HeatCheckLog) {
        let t = baseDate()
        let recorder = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = recorder.observe(makePoll(0))
        _ = recorder.observe(makePoll(10, running: "A", thermal: 2))
        recorder.thermalStateChanged(to: 3, uptime: 20)

        // The clock is set back an hour before the next poll.
        _ = recorder.observe(makePoll(30, at: t.addingTimeInterval(30 - 3600), running: "A", thermal: 3))
        expectCounts(log, recorder.inProgress, watched: 20, fair: 20, serious: 20, critical: 10, highest: 3, samples: 2,
                     "clock set back")
        if let summary = recorder.inProgress {
            log.expectEqual(summary.firstSeenAt, t.addingTimeInterval(10), "clock set back: firstSeenAt stays")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(30 - 3600), "clock set back: endedAt is the poll's time")
        }

        // Then two hours forward, before a change and the next poll.
        recorder.thermalStateChanged(to: 2, uptime: 35)
        _ = recorder.observe(makePoll(40, at: t.addingTimeInterval(7240), running: "A", thermal: 2))
        expectCounts(log, recorder.inProgress, watched: 30, fair: 30, serious: 30, critical: 15, highest: 3, samples: 3,
                     "clock set forward")

        let ended = recorder.observe(makePoll(50, at: t.addingTimeInterval(7250), finished: "A", completedAt: 7245, reason: "stopped"))
        expectCounts(log, ended, watched: 30, fair: 30, serious: 30, critical: 15, highest: 3, samples: 3, "clock steps: at the end")
        if let summary = ended {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(7245), "clock steps: ends at last_completed_at")
            log.expect(!summary.endedOnOverheating, "clock steps: stopped is not overheated")
        }

        // The clock set back by more than the recording had run puts
        // last_completed_at before firstSeenAt: a new token then ends it at
        // endedAt, not overheated.
        let back = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = back.observe(makePoll(0))
        _ = back.observe(makePoll(10, running: "A", thermal: 2))
        _ = back.observe(makePoll(20, at: t.addingTimeInterval(20 - 3600), running: "A", thermal: 2))
        let backEnd = back.observe(makePoll(30, at: t.addingTimeInterval(30 - 3600), running: "B",
                                            completedAt: 25 - 3600, reason: "overheated"))
        expectCounts(log, backEnd, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "clock set back, new token")
        if let summary = backEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(20 - 3600), "clock set back, new token: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "clock set back, new token: not overheated")
        }
    }

    // MARK: Start

    static func checkStartRules(_ log: HeatCheckLog) {
        let t = baseDate()

        // The first poll after launch shows a session already running.
        let launched = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = launched.observe(makePoll(0, running: "A", thermal: 2))
        log.expect(launched.isRecording, "first poll: a running session starts a recording")
        expectCounts(log, launched.inProgress, watched: 0, highest: 2, samples: 1, "first poll")
        if let summary = launched.inProgress {
            log.expect(!summary.watchedFromStart, "first poll: not watched from the start")
            log.expectEqual(summary.firstSeenAt, t, "first poll: firstSeenAt")
        }
        _ = launched.observe(makePoll(10, running: "A", thermal: 2))
        let ended = launched.observe(makePoll(20, finished: "A", completedAt: 20, reason: "stopped"))
        expectCounts(log, ended, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "first poll: at the end")
        if let summary = ended {
            log.expect(!summary.endedOnOverheating, "first poll: stopped is not overheated")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session (from 14:00): hot for less than a minute.",
                            "first poll: note")
        }

        // A token that already has a saved summary.
        let saved = HeatRecorder(saved: nil, lastFinishedToken: "A")
        _ = saved.observe(makePoll(0, running: "A", thermal: 3))
        log.expect(!saved.isRecording, "saved token: no recording")
        log.expect(saved.inProgress == nil, "saved token: nothing in progress")
        _ = saved.observe(makePoll(10, running: "B"))
        log.expect(saved.isRecording, "saved token: another token starts a recording")
        if let summary = saved.inProgress {
            log.expectEqual(summary.sessionToken, "B", "saved token: the new token")
            log.expect(summary.watchedFromStart, "saved token: the new token is watched from the start")
        } else {
            log.expect(false, "saved token: a recording in progress")
        }
    }

    // MARK: End

    static func checkEndRules(_ log: HeatCheckLog) {
        let t = baseDate()

        // The poll names the session as finished, without last_completed_at:
        // the end is the last running poll's time, and the reason is used.
        let unknown = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = unknown.observe(makePoll(0))
        _ = unknown.observe(makePoll(10, running: "A", thermal: 2))
        _ = unknown.observe(makePoll(20, running: "A", thermal: 2))
        let unknownEnd = unknown.observe(makePoll(30, finished: "A", reason: "overheated"))
        expectCounts(log, unknownEnd, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "no completion time")
        if let summary = unknownEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(20), "no completion time: ends at endedAt")
            log.expect(summary.endedOnOverheating, "no completion time: overheated")
        }

        // A new token, no finished token: last_completed_at is no earlier
        // than firstSeenAt, so it is used.
        let byTime = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = byTime.observe(makePoll(0))
        _ = byTime.observe(makePoll(10, running: "A", thermal: 2))
        _ = byTime.observe(makePoll(20, running: "A", thermal: 2))
        let byTimeEnd = byTime.observe(makePoll(40, running: "B", completedAt: 30, reason: "overheated"))
        expectCounts(log, byTimeEnd, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "new token")
        if let summary = byTimeEnd {
            log.expectEqual(summary.sessionToken, "A", "new token: the old token finishes")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(30), "new token: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "new token: last_completion_reason is used")
        }
        if let summary = byTime.inProgress {
            log.expectEqual(summary.sessionToken, "B", "new token: a new recording")
            log.expect(summary.watchedFromStart, "new token: watched from the start")
            log.expectEqual(summary.firstSeenAt, t.addingTimeInterval(40), "new token: firstSeenAt")
        } else {
            log.expect(false, "new token: a recording in progress")
        }

        // firstSeenAt is compared in whole seconds.
        let sameSecond = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = sameSecond.observe(makePoll(0))
        _ = sameSecond.observe(makePoll(10, at: t.addingTimeInterval(10.7), running: "A"))
        if let summary = sameSecond.observe(makePoll(20, running: "B", completedAt: 10, reason: "overheated")) {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(10), "same second: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "same second: overheated")
        } else {
            log.expect(false, "same second: a summary")
        }
        let earlier = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = earlier.observe(makePoll(0))
        _ = earlier.observe(makePoll(10, at: t.addingTimeInterval(10.7), running: "A"))
        if let summary = earlier.observe(makePoll(20, running: "B", completedAt: 9, reason: "overheated")) {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(10.7), "earlier second: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "earlier second: not overheated")
        } else {
            log.expect(false, "earlier second: a summary")
        }

        // Neither: no session and no token, or another finished token.
        let neither = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = neither.observe(makePoll(0))
        _ = neither.observe(makePoll(10, running: "A", thermal: 2))
        _ = neither.observe(makePoll(20, running: "A", thermal: 2))
        let neitherEnd = neither.observe(makePoll(30))
        expectCounts(log, neitherEnd, watched: 10, fair: 10, serious: 10, highest: 2, samples: 2, "neither")
        if let summary = neitherEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(20), "neither: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "neither: not overheated")
        }
        let other = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = other.observe(makePoll(0))
        _ = other.observe(makePoll(10, running: "A", thermal: 2))
        _ = other.observe(makePoll(20, running: "A", thermal: 2))
        if let summary = other.observe(makePoll(30, finished: "Z", completedAt: 25, reason: "overheated")) {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(20), "another finished token: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "another finished token: not overheated")
        } else {
            log.expect(false, "another finished token: a summary")
        }
        log.expect(!other.isRecording, "another finished token: the recording ends")
    }

    // MARK: Relaunch

    static func checkRelaunch(_ log: HeatCheckLog) {
        let t = baseDate()
        let before = HeatRecorder(saved: nil, lastFinishedToken: nil)
        _ = before.observe(makePoll(0))
        _ = before.observe(makePoll(10, running: "A", thermal: 2))
        _ = before.observe(makePoll(40, running: "A", thermal: 2))
        before.thermalStateChanged(to: 3, uptime: 45)
        guard let inProgress = before.inProgress else {
            log.expect(false, "relaunch: a recording in progress")
            return
        }
        expectCounts(log, inProgress, watched: 30, fair: 30, serious: 30, highest: 2, samples: 2, "relaunch: saved")
        log.expectEqual(inProgress.endedAt, t.addingTimeInterval(40), "relaunch: endedAt of the saved recording")
        guard let stored = inProgress.propertyList else {
            log.expect(false, "relaunch: the recording in progress is stored")
            return
        }
        guard let saved = HeatSummary(propertyList: stored) else {
            log.expect(false, "relaunch: the recording in progress is read back")
            return
        }
        log.expectEqual(saved, inProgress, "relaunch: the recording in progress survives storing")

        // The same token is still running: the gap is not counted. The Mac
        // restarted, so the uptime began again.
        let same = HeatRecorder(saved: saved, lastFinishedToken: "Z")
        log.expect(same.isRecording, "relaunch: a saved recording is in progress")
        log.expect(same.inProgress == saved, "relaunch: the saved recording is in progress")
        log.expect(same.observe(makePoll(5, at: t.addingTimeInterval(600), running: "A", thermal: 2)) == nil,
                   "same token: finishes nothing")
        expectCounts(log, same.inProgress, watched: 30, fair: 30, serious: 30, highest: 2, samples: 3,
                     "same token: the gap is not counted")
        _ = same.observe(makePoll(15, at: t.addingTimeInterval(610), running: "A", thermal: 2))
        expectCounts(log, same.inProgress, watched: 40, fair: 40, serious: 40, highest: 2, samples: 4,
                     "same token: time counts again")
        if let summary = same.inProgress {
            log.expectEqual(summary.firstSeenAt, t.addingTimeInterval(10), "same token: firstSeenAt stays")
            log.expect(summary.watchedFromStart, "same token: watchedFromStart stays")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(610), "same token: endedAt")
        }
        // Once it has had a poll, a new token ends it at last_completed_at.
        let next = same.observe(makePoll(25, at: t.addingTimeInterval(620), running: "B", completedAt: 615, reason: "overheated"))
        if let summary = next {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(615), "same token, then a new token: ends at last_completed_at")
            log.expect(summary.endedOnOverheating, "same token, then a new token: overheated")
        } else {
            log.expect(false, "same token, then a new token: a summary")
        }

        // A thermal change before a loaded recording's first poll only sets
        // the current state; it is not the recording's heat.
        let early = HeatRecorder(saved: saved, lastFinishedToken: nil)
        early.thermalStateChanged(to: 3, uptime: 2)
        _ = early.observe(makePoll(5, at: t.addingTimeInterval(600), running: "A", thermal: 2))
        expectCounts(log, early.inProgress, watched: 30, fair: 30, serious: 30, highest: 2, samples: 3,
                     "relaunch: a change before the first poll")

        // No session runs: the saved recording ends at last_completed_at.
        let stopped = HeatRecorder(saved: saved, lastFinishedToken: "Z")
        let ended = stopped.observe(makePoll(900, finished: "A", completedAt: 300, reason: "timeout"))
        expectCounts(log, ended, watched: 30, fair: 30, serious: 30, highest: 2, samples: 2, "no session")
        if let summary = ended {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(300), "no session: ends at last_completed_at")
            log.expect(!summary.endedOnOverheating, "no session: timeout is not overheated")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute.", "no session: note")
        }
        log.expect(!stopped.isRecording, "no session: the recording ends")

        // Another session runs: the saved one ends, and a new one starts,
        // not watched from the start. Sessions may have come and gone while
        // the app was not running, so last_completed_at may be another's:
        // the saved one ends at its endedAt.
        let replaced = HeatRecorder(saved: saved, lastFinishedToken: nil)
        let replacedEnd = replaced.observe(makePoll(900, running: "B", completedAt: 300))
        expectCounts(log, replacedEnd, watched: 30, fair: 30, serious: 30, highest: 2, samples: 2, "another session")
        if let summary = replacedEnd {
            log.expectEqual(summary.sessionToken, "A", "another session: the saved token finishes")
            log.expectEqual(summary.endedAt, t.addingTimeInterval(40), "another session: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "another session: not overheated")
        }
        if let summary = replaced.inProgress {
            log.expectEqual(summary.sessionToken, "B", "another session: a new recording")
            log.expect(!summary.watchedFromStart, "another session: not watched from the start")
        } else {
            log.expect(false, "another session: a recording in progress")
        }

        // The same with an overheated completion, which may be another
        // session's: the saved one does not take it.
        let hot = HeatRecorder(saved: saved, lastFinishedToken: nil)
        if let summary = hot.observe(makePoll(900, running: "C", completedAt: 300, reason: "overheated")) {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(40), "another session, overheated: ends at endedAt")
            log.expect(!summary.endedOnOverheating, "another session, overheated: not overheated")
            log.expectEqual(summary.noteText(timeZone: zone), "Last session: hot for less than a minute.",
                            "another session, overheated: the note has only the saved heat")
        } else {
            log.expect(false, "another session, overheated: a summary")
        }
        let cool = makeSummary(highest: 1, fair: 60, firstSeenAt: t.addingTimeInterval(10), endedAt: t.addingTimeInterval(70))
        let coolEnd = HeatRecorder(saved: cool, lastFinishedToken: nil)
            .observe(makePoll(900, running: "C", completedAt: 300, reason: "overheated"))
        if let summary = coolEnd {
            log.expectEqual(summary.endedAt, t.addingTimeInterval(70), "another session, overheated, fair only: ends at endedAt")
            log.expect(summary.noteText(timeZone: zone) == nil, "another session, overheated, fair only: no note")
        } else {
            log.expect(false, "another session, overheated, fair only: a summary")
        }

        // A saved recording whose token already has a summary is dropped.
        let stale = HeatRecorder(saved: saved, lastFinishedToken: "A")
        log.expect(!stale.isRecording, "stale recording: dropped")
        log.expect(stale.observe(makePoll(900, running: "A")) == nil, "stale recording: no summary")
        log.expect(!stale.isRecording, "stale recording: not started again")

        // A saved sample count at the largest Int stays there.
        var full = makeSummary(highest: 2)
        full.samples = Int.max
        let counted = HeatRecorder(saved: full, lastFinishedToken: nil)
        _ = counted.observe(makePoll(900, running: "A", thermal: 2))
        expectCounts(log, counted.inProgress, watched: 3600, highest: 2, samples: Int.max,
                     "samples at the largest Int")
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

        // Values only a damaged store can hold.
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

    // MARK: Thermal state numbers

    /// The number the app passes to bin/awake in AWAKE_APP_THERMAL_STATE. It
    /// must be on the scale that bin/awake and the helper read from
    /// NSProcessInfo.thermalState, which the raw values show on this SDK.
    static func checkThermalNumbers(_ log: HeatCheckLog) {
        let states: [(state: ProcessInfo.ThermalState, number: Int, name: String)] = [
            (state: .nominal, number: 0, name: "nominal"),
            (state: .fair, number: 1, name: "fair"),
            (state: .serious, number: 2, name: "serious"),
            (state: .critical, number: 3, name: "critical"),
        ]
        for entry in states {
            log.expectEqual(HeatSummary.number(for: entry.state), entry.number, "thermal number: \(entry.name)")
            log.expectEqual(entry.state.rawValue, entry.number, "thermal number: \(entry.name) is macOS's raw value")
        }
    }
}
