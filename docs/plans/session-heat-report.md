# Plan: how warm the last session got

- Status: proposed, not yet implemented
- Target version: 2.2.0, together with `unplug-guard.md`, which moves the helper to protocol 9; this feature changes no helper code
- Written: 2026-09-28, against `dev` at 2.1.0 (commit `488336f`); revised 2026-09-29 against 2.1.0 as released (commit `8ccd5f6`)
- Scope: `app/AwakeStatusApp`, `.github/workflows/ci.yml`, a new `tests/app/` check, `README.md`, `CHANGELOG.md`

## How this plan was checked

- The first draft was reviewed against 2.1.0 as released, which had since added `other_user_session` to the status and left-aligned the Settings window's groups. The review found gaps in the recording rules, the check, the wording, and the Settings layout. This version includes its findings.
- The review ran on Linux, without a Swift toolchain. What this plan says about AppKit and Foundation comes from Apple's documentation and the app's code. Everything that needs a real Mac is in the QA checklist (8).

## 1. Goals

1. After a session in which the Mac got hot, say so: for how long, and whether Awake ended the session. Most sessions have nothing to report.
2. Use macOS's thermal state (nominal, fair, serious, critical), the value the guard itself uses.
3. Show it in the Settings window, under `Stop when too hot`.

Not in scope:

- processor temperatures, which on Apple silicon need undocumented interfaces;
- the battery temperature: charging warms the battery whatever the Mac is doing, so it says more about the power adapter than about heat;
- a history of more than the last session;
- charts;
- the CLI: `awake --status` and `--status-json` do not change.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Where the numbers are collected | In the menu bar app, not in `bin/awake` or the helper. The app already checks the session every 10 seconds. Collecting there needs no root code and no helper change, and it works the same for lid-closed and Caffeine sessions. The cost is that sessions run while the app is not running are not covered. |
| 2 | Whether it depends on `Stop when too hot` | No. The app records every session. The report is most useful when the guard is off. |
| 3 | Where it is shown | Only in the Settings window, as a note under `Stop when too hot`, which it concerns, hidden when there is nothing to report. No notification, and no menu item. |
| 4 | Which session | The last session that ended. While a session runs, the note keeps showing the one before it. |
| 5 | Which sessions are recorded | This account's own. Sleep settings left without a session (`leftover_settings`) are not a session, another account's lid-closed session (`other_user_session`) is not recorded, and a status that could not be read changes nothing. |
| 6 | What counts as something to report | Only a Mac that got hot: the serious or critical thermal state, or a session the guard ended. Fair, which a busy Mac often reaches, does not count (3.1). |

## 3. What the user sees

The Guardrails group of the Settings window becomes, with the `Stop when unplugged` checkbox of `unplug-guard.md`:

```
Guardrails
[x] Stop when too hot
    Last session: hot for 3 minutes, so Awake ended it.
Stop at low battery  [ 5% ▾ ]
[ ] Stop when unplugged
Apply to sessions started afterwards.
```

The note sits under `Stop when too hot` because it concerns that setting: it says how hot the Mac got, in the terms the guard uses. It is small secondary text, like the other notes in the window, and it is not selectable. It is indented to line up with the checkbox's title, as macOS does for text that explains a checkbox, and it wraps at 360 points less that indent, so the window's right margin stays. It can wrap to a second line. Its tooltip says: "Shown after a session in which the Mac got hot: macOS reported its serious or critical thermal state, or Awake ended the session because of the heat. Only sessions that end while Awake.app is running are recorded."

### 3.1 When there is something to report

Most sessions have nothing to report. The note is shown only when at least one of these holds for the last session:

- the thermal state reached serious or critical, the levels at which the guard can act;
- the guard ended the session (`last_completion_reason` is `overheated`).

Otherwise the note is hidden, and the group looks as it does in 2.1.0.

- Fair does not count. A busy Mac often reaches it, and macOS calls it only slightly elevated.
- Serious counts also with the lid open, where the guard lets the session go on: the Mac did get hot, which is worth knowing when deciding about the guard.

### 3.2 Wording

The note has the form `Last session: <heat>.`, where the heat part depends on the highest thermal state reached:

- **serious:** `hot for 3 minutes`, where 3 minutes is the time at serious or higher.
- **critical:** `hot for 3 minutes, very hot for 1 minute`, where 1 minute is the time at critical.

Further rules:

- When the guard ended the session, the heat part ends with `, so Awake ended it`. If the app never saw serious or higher, which can happen when it missed the end of the heat, the heat part is `the Mac got too hot, so Awake ended it` instead.
- Times are rounded down to whole minutes, so rounding never makes the note claim more than was counted. They use the menu's words: `less than a minute`, `1 minute`, `12 minutes`, `1 hour 5 minutes`, and from a day on `1 day 2 hours`. The menu's time left rounds up instead, so the note has its own function for this (5.1).
- If the app was not watching when the session started, because it was launched during it, the note begins `Last session (from 14:05):`, giving the time the app began watching. Clock times are 24-hour, like the CLI's end times, whatever the region's clock format. If watching began on an earlier day than the session ended, the date comes first: `Last session (from 2026-09-28 23:50):`.

Examples:

- `Last session: hot for 3 minutes.`
- `Last session: hot for 3 minutes, so Awake ended it.`
- `Last session: hot for 1 hour 5 minutes.`
- `Last session (from 14:05): hot for 8 minutes, very hot for 1 minute.`
- `Last session: the Mac got too hot, so Awake ended it.`

## 4. Thermal state

`ProcessInfo.processInfo.thermalState` (macOS 10.10.3+), read in the app itself. This is the same value that `bin/awake` and the helper read through `osascript`.

- The app reads it on every poll. It also observes `ProcessInfo.thermalStateDidChangeNotification`, so a change is counted when it happens, not up to 10 seconds later.
- It observes the notification with `queue: .main`: the notification is not guaranteed to arrive on the main thread, and the recorder runs there.
- With each change it passes the recorder the clock time and `ProcessInfo.processInfo.systemUptime`, taken when the notification arrives (5.2).
- The recorder never reads the state itself. It is passed in (5.2), so the check can feed made-up states.

## 5. Recording

A new file, `app/AwakeStatusApp/Sources/HeatReport.swift`, holds `HeatSummary`, `HeatPoll`, and `HeatRecorder`. They use Foundation only, and none refers to the app's other types, such as `AwakeStatus`, so the check (7) builds with this file alone.

### 5.1 `HeatSummary`

A `Codable` struct:

- `sessionToken`
- `firstSeenAt`: when the app first saw the session running
- `watchedFromStart`: false when the session was already running at the app's first poll after it launched
- `endedAt`: when the session ended; in a recording in progress, when it was last brought up to date
- `endedOnOverheating`
- `secondsAtLeastSerious`, `secondsCritical`
- `secondsAtLeastFair`: not shown; for QA (8, item 1), as fair is the level a Mac can safely be driven to.
- `highestState` (0–3)
- `secondsWatched`: the time counted at any level. Not shown; for QA.
- `samples`: the number of polls that fed the recording. Not shown; for QA.

It also has:

- `shouldReport`: the 3.1 rules.
- `func noteText(timeZone: TimeZone) -> String?`, which returns nil when there is nothing to report. The app passes `.current`; the check passes a fixed one.
- `static func durationText(seconds:)`: the rounded-down times of 3.2.
- A conversion to and from a property-list dictionary, through `PropertyListEncoder` and `PropertyListSerialization`. The app stores the dictionary rather than JSON data, so `defaults read net.kaenmaki.awake.statusbar lastSessionHeat` prints the numbers readably, as it does the app's other values.
- The reader returns nil for anything but a stored summary: a wrong type or a missing field, and also a date that is not finite or is more than 10^12 seconds from 1970, or a sample count that is negative or the largest `Int`. Only a damaged value can be one of these, and the recorder could trap on it.

### 5.2 `HeatPoll` and `HeatRecorder`

`StatusBarController` builds a `HeatPoll` from each status it reads, with the thermal state taken at that moment:

- `at`: when the status read started, by the clock (`fetchedAt`, 6);
- `uptime`: `ProcessInfo.processInfo.systemUptime` when the status read started (`fetchedUptime`, 6);
- `runningToken`: the token of the running session, or nil when none runs;
- `finishedToken`: when no session runs, the token of the last finished one (the status's `session_token`), otherwise nil;
- `lastCompletedAt` and `lastCompletionReason`, from the status;
- `thermalState` (0–3).

Its failable initializer takes the status's fields as plain values rather than an `AwakeStatus`, so the check covers the mapping without the app's other files:

- a status with an error gives no poll;
- leftover sleep settings and another account's session give nil tokens: neither is a session of this account's;
- a running session without a token counts as none.

`HeatRecorder` is created at launch with the saved recording in progress, if any, and the token of the saved summary. It is fed:

- `observe(_ poll: HeatPoll) -> HeatSummary?` for every poll; it returns a summary when a recording has finished, for the controller to save;
- `thermalStateChanged(to:at:uptime:)` from the notification;
- `systemWillSleep(at:uptime:)` and `systemDidWake(at:uptime:)` from `NSWorkspace`'s sleep and wake notifications;
- `snapshot(at:uptime:) -> HeatSummary?`, which brings the recording in progress up to date and returns it, for saving.

Every event comes with two times, and the recorder reads neither itself:

- `at`, the clock's. It is stored as `firstSeenAt` and `endedAt`, and compared with `last_completed_at`, which is the helper's clock time.
- `uptime`, `ProcessInfo.processInfo.systemUptime` when the event arrives, or for a poll when its read started. It never goes back, and it does not advance while the Mac sleeps ("the amount of time the system has been awake since the last time it was restarted"). The clock can be set back or forward at any time, by the user or a time sync. So the uptime puts events in order and measures the time between them, and a clock step between events changes no count. Only the end at `last_completed_at` is a clock time: it is placed among the events, and the time up to it is measured, by the clock (rule 4). So a clock step before the poll that shows the end can change the counts when it comes after the first state the recorder keeps for the end: the last poll that showed the session running, or, when that poll's read started before the previous event, the newest event at or before its read start (rule 4).

Rules:

1. **Which statuses count.** The controller builds a poll from every status it reads: the one read every 10 seconds, and the one read after a start or stop from the app, so that `Stop Awake and Quit` finishes the recording before the app quits.
   - A status that could not be read (`error`) gives no poll, so it neither starts nor ends a recording.
   - A poll whose read started, by uptime, before that of the last one the recorder saw is ignored. Status reads are not serialized, so a slow read that finishes late would otherwise undo a newer one. The order is by uptime, not by the clock, so a clock set back does not make the recorder ignore polls until the clock catches up.
2. **Start.** When a poll shows a running session whose token differs from the one being recorded, a new recording begins with the poll's thermal state. A recording of another token ends first (rule 4).
   - It counts as watched from the start, unless this is the first poll since the app launched: the session was then running before the app could see it, and `watchedFromStart` is false.
   - A token that already has a saved summary never starts a recording again.
3. **Time.** The time since the previous event (a poll, a thermal change, sleep, wake, or a snapshot) is the difference of their uptimes. It is counted in `secondsWatched`, and in the level fields for the thermal state in effect during it: the state known at that previous event. Then the event's state, if it carries one, becomes the current state, and `highestState` is updated.
   - Each interval is capped at 60 seconds, so a gap when the app was not running, or its timers were held back (5.3), is never counted as time at one level.
   - Time asleep is not counted. The uptime does not advance while the Mac sleeps, and nothing is added from `systemWillSleep` to `systemDidWake`, also for polls in between, during a dark wake, when the uptime does advance.
   - A read that started before the previous event, by uptime, but arrived after it, as when a thermal change or sleep came during the read, adds no time: that time is already counted. Its thermal state, read when the poll was built, still applies.
   - A recording's first event is the poll's read start, unless the last sleep, wake or thermal change came after that read started, by uptime: it is then the latest of them, by the clock and by the uptime. A read that started before a sleep can arrive during a dark wake, which posts no wake, or after the wake; a read that started during a dark wake can arrive after the wake; and a read that a thermal change came during carries the state after the change. Nothing before that event is then counted for it, and the poll's thermal state, read when the poll was built, counts only from there: when the session ended before that event, neither time nor that state counts (rule 4).
   - A read that started before a sleep and arrives during a dark wake has its state stamped at the sleep, whether it starts or continues a recording, as the recorder does not know when it arrived. So an end between the sleep and its arrival keeps that state.
4. **End.** A recording ends when a poll shows no running session, or one with another token. The end is found in this order:
   - The poll's `finishedToken` is the recording's: the session ended at `last_completed_at`, and `endedOnOverheating` is whether `last_completion_reason` is `overheated`.
   - The poll has no `finishedToken`, as when it shows a new session, `last_completed_at` is no earlier than the clock time of the last poll that showed the session running, compared in whole seconds, and that poll came since the app launched: the same two fields are used. The status does not say which session they describe, but normally only the recorded session can have ended since that poll. A session that starts and ends between two polls is not seen: its end and its reason are then taken as the recorded session's. This needs two sessions to start within one poll interval, and is accepted. A recording loaded at launch has not been polled: other sessions may have come and gone while the app was not running. A clock set back after that poll, before the end, can put `last_completed_at` before it: the end is then `endedAt`, not overheated, and nothing is taken back, as in the third case, so a thermal change, sleep or snapshot after the end still counts, and the note can claim more than happened.
   - Otherwise the end is `endedAt`, the last time the recording was brought up to date, and `endedOnOverheating` is false. Nothing is taken back.

   At `last_completed_at`, the events that came after the end, before the poll that shows it, are taken back: neither their time nor their thermal state counts.
   - The recorder keeps its state after the last poll that showed the session running, and after each later event. A poll whose read started before the previous event, by uptime, keeps the states from the newest one at or before its read start, as the session may have ended before the events in between; its own state is stamped with the previous event's times. It goes back to the newest of these stamped at or before `last_completed_at` by the clock, as that is a clock time. `last_completed_at` is in whole seconds, so an event later in the second of the end is taken back too.
   - A clock step can put a stamp on the wrong side of the end. So only the states before the first one stamped earlier than the one before it count; from there on, all are taken back, so an event after a clock set back is taken back even if it came before the end. A small set-back after the end, which leaves an event stamped at or before the end and no earlier than the one before it, leaves that event counted. When none is at or before the end, the first state is used: it is from before the end, or it is the state from before the poll's, stamped with the sleep, wake or thermal change of rule 3, and then nothing, neither time nor the poll's thermal state, is counted for an end before that event.
   - The time from that state to the end is measured by the clock, but it is no more than the uptime until the first event taken back, as the state gone back to held only until then, or, when none is, until the read that shows the end started, capped as in rule 3. So a set-back before the end that leaves the end at `last_completed_at`, whether or not it takes an event back, can make the note claim less than happened, not more. It leaves out no more than the time from the state gone back to until the end: as much as the set-back, or, when it takes back an event from before the end, all the time from that event to the end, if that is more. A set-back that moves the end to `endedAt` (the second case) can make the note claim more. A clock set forward between that state and the end can add up to the time until that read started, at the state gone back to: the recorder cannot tell whether the step came before or after the end, and measuring back from the poll would undercount a step after the end.

   The summary is returned for saving, and its token counts as saved.
5. **Saving and relaunching.**
   - The finished summary is saved as `lastSessionHeat`, and `sessionHeatInProgress` is removed.
   - The recording in progress is saved as `sessionHeatInProgress` after a poll once a minute has passed since the last save, when the Mac goes to sleep, and when the app quits normally.
   - At launch, a saved recording in progress is loaded before the first poll. It has no previous event, so nothing is counted for the time the app was not running, not even the 60 seconds of rule 3. The first poll decides what happens to it:
     - The poll shows the same token running: the recording continues, and `firstSeenAt` and `watchedFromStart` stay as they were.
     - Otherwise it ends by rule 4. When no session runs, the tokens normally match and the end is `last_completed_at`: after an update, as the installer stops the session and then quits the app with `kill -TERM`, which skips the quit hook, and whenever the session ended while the app was not running. When another session is running, the end is the saved `endedAt`, not overheated: `last_completed_at` and its reason may be another session's. So a session that ended, and another that started, while the app was not running loses its end time and a guard ending, rather than risk taking another session's.

     Then, if another session is running, a new recording starts for it (rule 2).
6. **Uninstall.** The uninstaller already removes the whole preferences domain, so both keys go with it.

### 5.3 App Nap

The app is an accessory app with no visible window. During a lid-closed session macOS may slow its timers down.

- While a recording runs, the app calls `ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Recording how warm the Mac gets during an Awake session")`. It ends the activity when the recording ends.
- That option keeps the timers running without keeping the Mac awake, so it never interferes with the session's own sleep handling.
- The cost: the 10-second poll, which runs `awake --status-json` in Bash, keeps its full rate for the whole session, which can last days, where App Nap might otherwise slow it while the display is off. That is the rate the app already polls at whenever it is not napped, and each poll is small, but on battery it is not free.
- `samples` and `secondsWatched` show during QA whether this works: a 30-minute session should have about 180 samples and about 1,800 seconds watched.

## 6. Code changes

- `HeatReport.swift`: new (5.1, 5.2). Foundation only.
- `AwakeCLI.swift`: `fetchStatus` records when the read started rather than when it finished: `fetchedAt` gets the clock time, and a new `fetchedUptime`, which like `fetchedAt` is not part of the JSON, gets `ProcessInfo.processInfo.systemUptime`. Polls are put in order and timed by the uptime (5.2, rules 1 and 3). The countdown between polls, which also uses `fetchedAt`, is not affected in practice.
- `StatusBarController.swift`:
  - own a `HeatRecorder`, created at launch from the two saved keys;
  - build a `HeatPoll` from each status read in `refreshStatus`'s main-queue block and in `handleCommandResult`, with `fetchedAt`, `fetchedUptime` and the thermal state, and feed it to the recorder before `updateStatusItem()`, so that the redraw that follows already shows the new note;
  - observe the thermal notification on the main queue, and sleep and wake on `NSWorkspace.shared.notificationCenter`;
  - pass each thermal change, sleep, wake and snapshot the clock time and `ProcessInfo.processInfo.systemUptime`, both taken when it happens;
  - save finished summaries, and the recording in progress as in 5.2 (rule 5), including on `NSApplication.willTerminateNotification`;
  - begin and end the App Nap activity (5.3).
- `InstallSupport.swift` (`PreferencesStore`): the keys `lastSessionHeat` and `sessionHeatInProgress`, holding `HeatSummary` property-list dictionaries (5.1).
- `SettingsWindowController.swift`:
  - a `heatNote` label (the existing `note(_:)` style) directly under `thermalBox`, indented to line up with the checkbox's title, with its `preferredMaxLayoutWidth` reduced by the indent (3);
  - `reload` sets its text from `HeatSummary.noteText` and hides it when that is nil;
  - the window's size is set once, in `buildContent`, and hiding a view shrinks the stack's content but not necessarily the window. So when the note appears, disappears, or changes its number of lines, the window is resized with the same rule as in `buildContent`, keeping its top edge in place;
  - the tooltip from 3;
  - `reloadIfVisible` already runs on every poll, so the note appears as soon as a session ends.
- `StatusDescription.swift`: no change. The note has its own time wording (3.2).

The installer builds the app on the user's Mac, with Swift 5.7 or later (`scripts/install-awake.sh`), while CI uses the newest compiler, which accepts newer syntax without complaint. The new code avoids Swift 5.8 and later features, such as `if` and `switch` expressions and implicit `self` after `guard let self`.

## 7. Tests

- **New:** `tests/app/heat-report-check.swift`. It is a small `@main` program, built with `-parse-as-library` together with `HeatReport.swift` and nothing else. It feeds `HeatRecorder` made-up polls, thermal changes, sleep and wake, with made-up clock times and uptimes, and never reads the real clock, uptime or thermal state. It checks:
  - the `HeatPoll` mapping: a status with an error, leftover settings, another account's session, and a running session without a token;
  - the time at each level, including the 60-second cap, sleep, and a poll during a dark wake;
  - the start rules: after a poll without a session, at the first poll after launch, and never again for a token that has a saved summary;
  - the end rules: a matching finished token, a new token without a poll between (by time), neither (at `endedAt`, not overheated), a new token after the clock was set back during the session (still at `last_completed_at`, overheated), and a new token after the clock was set back after the last poll that showed the session running and before the end, then a rise (at `endedAt`, not overheated, and the rise counts);
  - that a poll read before the last one is ignored;
  - reads that a thermal change, sleep or snapshot came during: no time is counted twice;
  - clock steps: the clock set back and forward between polls, and between thermal changes, sleep, wake and snapshots, and set back during a read, changes no count;
  - events after the end, before the poll that shows it: a thermal change, sleep, a snapshot, and a late read, all taken back;
  - a clock step near the end, before the poll that shows it: set back or forward after the end, where the events after the end are taken back, also one stamped before the end after a set-back; set back before a change, a fall or a sleep and the end, where that event is taken back and the time at the state gone back to is counted no further than it, which can leave out more than the set-back; set back before the end with no event after the last poll that showed the session running, where the time up to the end, by the clock, loses up to the set-back; and set forward before the end, where the time up to the end is no more than the uptime until the read that shows the end started;
  - a read that started before a sleep, or during a dark wake, and arrived after the wake, which starts a recording, ends one and starts another, or is a loaded recording's first poll: nothing before the wake is counted, also when the next poll shows the end, after the wake, during the sleep or before it, and the poll's thermal state counts only for an end after the wake;
  - a read that started before a sleep and arrived during a dark wake, which starts a recording or is a loaded recording's first poll, and a later dark-wake poll that shows the end: nothing is counted, and the poll's thermal state counts only for an end after the sleep;
  - a read that a thermal change came during, which starts a recording: nothing before the change is counted, and an end before the change reports nothing;
  - relaunching: the same token continues without counting the gap, a poll without a session ends the saved recording at `last_completed_at`, and a poll showing another session ends it at `endedAt`, not overheated, also with an `overheated` completion;
  - the 3.1 rules: fair alone reports nothing, while serious, critical, and a guard ending do;
  - every example in 3.2, with a fixed time zone;
  - the times at 59, 60, 119, 3,600, 3,660 and 90,000 seconds;
  - the property-list round trip, and that damaged dates and sample counts are rejected.
- **CI:** a new step, "Check the heat report", builds the check for macOS 12.5 and runs it:

  ```
  swiftc -target arm64-apple-macos12.5 -parse-as-library \
    app/AwakeStatusApp/Sources/HeatReport.swift tests/app/heat-report-check.swift \
    -o "$RUNNER_TEMP/heat-report-check"
  "$RUNNER_TEMP/heat-report-check"
  ```

  This is the project's first Swift unit check. The macOS runner is arm64, so the binary runs there, and it compiles `HeatReport.swift` against the real SDK.
- **Existing checks:** the app build and the macOS 12.5 build cover the rest of the Swift changes. The dry-run self-test does not change, because the CLI does not.

## 8. macOS QA checklist

1. **Measuring.** Start a 20-minute Caffeine session on AC. In another Terminal window, log the thermal state every 5 seconds as the reference, since `pmset -g therm` and Activity Monitor do not show it: `while :; do printf '%s %s\n' "$(date +%T)" "$(osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState')"; sleep 5; done`. Load every core for 10 minutes: `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`, then `killall yes`. The seconds at each level in the saved summary (`defaults read net.kaenmaki.awake.statusbar lastSessionHeat`), including `secondsAtLeastFair`, should match the log to within a poll or two. Unless the log reached serious (`2`), the note stays hidden. A MacBook Air heats up sooner; on a MacBook Pro this load may not leave nominal.
2. **Nothing to report.** Run a 10-minute idle session, and one while charging from a low charge, unplugging and plugging the adapter in between. The note stays hidden both times.
3. **Lid closed.** Run a 30-minute lid-closed session on battery with the lid closed. Afterwards, `samples` should be about 180 and `secondsWatched` about 1,800, proving App Nap did not stop the recording. The note appears if the Mac got hot.
4. **Guard ending.** A session ended by the guard reads `…, so Awake ended it.` The guard counts serious only with the lid closed, so a MacBook Air under the load of item 1, with its lid closed, is the likeliest way to get there. If the Mac cannot be made hot enough safely, this is covered by the heat report check (7) instead.
5. **Mid-session start.** With the app quit, start `awake --duration 10m` in Terminal, then open the app. Afterwards `lastSessionHeat` has `watchedFromStart = 0`, and the note, if shown, begins `Last session (from HH:MM):`.
6. **Relaunch during a session.** During a 10-minute session, run `killall AwakeStatusBar`, wait two minutes, and open the app again. Afterwards `watchedFromStart` is still 1, and `secondsWatched` is two to three minutes short of the session's length: the two minutes, and whatever the app had not saved before it was killed.
7. **Quitting and updating.** End a session with `Stop Awake and Quit`, then open the app again. Separately, run the installer during a session. Each time, `lastSessionHeat` holds that session's token with `endedAt` at the session's end, and `sessionHeatInProgress` is gone.
8. **CLI session with the app running.** A session started with `awake --duration 15m` in Terminal is recorded too.
9. **Settings window.** Open Settings with a report and without one, and keep it open while a session with a report ends. The note appears under `Stop when too hot`, lined up with its title, the window grows and shrinks with it without clipping or a blank strip, and the right margin stays as it is.

## 9. Docs

- **README, Settings window section:** under `Stop when too hot`, add: "After a session in which the Mac got hot, a note below this box says for how long, and whether Awake ended the session, for example `Last session: hot for 3 minutes, so Awake ended it.` Hot means macOS's `serious` or `critical` thermal state, so most sessions have nothing to report. The note does not depend on this setting. Only sessions that end while `Awake.app` is running are recorded, and `defaults read net.kaenmaki.awake.statusbar lastSessionHeat` shows the numbers behind the note."
- **CHANGELOG `[Unreleased]`,** under Added: the note, when it is shown, that it needs the app running, and that it does not depend on `Stop when too hot`.

## 10. Phases

1. `HeatReport.swift` and its check, green on CI.
2. The app wiring (6) and docs (9), green on CI.
3. QA (8) on a real Mac, together with the QA of `unplug-guard.md` (9).
4. Version 2.2.0 with `tools/release.sh minor`, once both plans are done.

## 11. Risks and open points

- **Intel Macs** report `thermalState` more coarsely. It often stays nominal until throttling is heavy, so the note shows up less often there. This is acceptable.
- **A session between two polls.** A session started and ended from the CLI between two polls, just before another starts, is not seen, and its end and reason are taken as the recorded one's (5.2, rule 4). The window is one poll, 10 seconds.
- **App Nap.** If `beginActivity` turns out not to be enough during lid-closed sessions (QA item 3), the note undercounts rather than overcounts: the 60-second cap keeps a gap from being counted as warm or hot time. The tooltip should then say that the times are what the app saw.
- **Open.** Whether the note should also appear, briefly, in the `Awake stopped` notification when the guard ended a session. Left out for now (decision 3).
