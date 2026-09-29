# Plan: how warm the last session got

- Status: proposed, not yet implemented
- Target version: 2.2.0 (no helper change; helper protocol stays 8)
- Written: 2026-09-28, against `dev` at 2.1.0 (commit `488336f`)
- Scope: `app/AwakeStatusApp`, `.github/workflows/ci.yml`, a new `tests/app/` check, `README.md`, `CHANGELOG.md`

## 1. Goals

1. After a session, show how warm the Mac got, when there is something worth saying.
2. Use two sources:
   - macOS's thermal state (nominal, fair, serious, critical);
   - the battery's temperature.
3. Show it in the Settings window, under `Stop when too hot`.

Not in scope:

- processor temperatures, which on Apple silicon need undocumented interfaces;
- a history of more than the last session;
- charts;
- the CLI: `awake --status` and `--status-json` do not change.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Where the numbers are collected | In the menu bar app, not in `bin/awake` or the helper. The app already checks the session every 10 seconds. Collecting there needs no root code, so updating needs no password prompt, and it works the same for lid-closed and Caffeine sessions. The cost is that sessions run while the app is not running are not covered. |
| 2 | Whether it depends on `Stop when too hot` | No. The app records every session. The report is most useful when the guard is off. |
| 3 | Where it is shown | Only in the Settings window, as a note under `Stop when too hot`, hidden when there is nothing to report. No notification, and no menu item. |
| 4 | Which session | The last session that ended. While a session runs, the note keeps showing the one before it. |
| 5 | Temperature unit | The user's: `MeasurementFormatter` shows °C or °F from the region settings. |

## 3. What the user sees

The Guardrails group of the Settings window becomes:

```
Guardrails
  [x] Stop when too hot
      Last session: warm for 12 minutes, never hot. Battery 31 → 38 °C.
  Stop at low battery  [ 5% ▾ ]
  Apply to sessions started afterwards.
```

The note is small secondary text, like the other notes in the window, and it is not selectable. Its tooltip says: "How warm the Mac got during the last session that ended while Awake.app was running: macOS's thermal state, and the battery temperature at the start and at its highest."

### 3.1 When there is something to report

The note is shown when at least one of these holds for the last session:

- the thermal state reached fair or higher;
- the session ended because the Mac got too hot (`last_completion_reason` is `overheated`);
- the battery reached 40 °C or more.

Otherwise the note is hidden, and the group looks as it does in 2.1.0. The 40 °C threshold is a first guess, to be checked during QA (8, item 3).

### 3.2 Wording

The note has the form `Last session: <heat>. <battery>.`

The heat part depends on the highest thermal state reached:

- **fair:** `warm for 12 minutes, never hot`, where 12 minutes is the time at fair or higher.
- **serious:** `hot for 3 minutes`, where 3 minutes is the time at serious or higher.
- **critical:** `hot for 3 minutes, very hot for 1 minute`.
- **nominal:** the heat part is left out, and the note reads `Last session: battery 30 → 42 °C.` This happens only when the battery rule alone applies.

Further rules:

- When the session ended on overheating, the heat part ends with `, so Awake ended it`.
- The battery part is `Battery 31 → 38 °C`: the first reading and the highest one. It is left out when there was no reading, for example on a Mac without a battery.
- Times use the app's existing duration words: `less than a minute`, `1 minute`, `12 minutes`, `1 hour 5 minutes`.
- If the app was started or restarted during the session, the note begins `Last session (from 14:05):`, giving the time the app began watching.

Examples:

- `Last session: warm for 12 minutes, never hot. Battery 31 → 38 °C.`
- `Last session: hot for 3 minutes, so Awake ended it. Battery 30 → 44 °C.`
- `Last session: battery 30 → 42 °C.`
- `Last session (from 14:05): hot for 8 minutes, very hot for 1 minute. Battery 33 → 41 °C.`

## 4. Sources

### 4.1 Thermal state

`ProcessInfo.processInfo.thermalState` (macOS 10.10.3+), read in the app itself. This is the same value that `bin/awake` and the helper read through `osascript`.

The app also observes `ProcessInfo.thermalStateDidChangeNotification`, so a change is counted when it happens, not up to 10 seconds later.

### 4.2 Battery temperature

The `Temperature` property of the `AppleSmartBattery` service in the I/O Registry. It is read with:

- `IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))`, where `kIOMainPortDefault` is macOS 12+;
- then `IORegistryEntryCreateCFProperty`.

This needs no special rights. It is what `ioreg -rn AppleSmartBattery` shows.

- The value is an integer, expected to be in hundredths of a degree Celsius (`3055` is 30.55 °C). QA item 1 confirms this on a real Mac, against the menu bar tools that show it.
- Readings outside 0–80 °C are ignored as unreadable.
- A Mac without the service, which is a desktop, has no battery part.

## 5. Recording

A new file, `app/AwakeStatusApp/Sources/HeatReport.swift`, holds two types. Neither uses AppKit.

### 5.1 `HeatSummary`

A `Codable` struct:

- `sessionToken`
- `watchedFrom` (a date; nil when watched from the start)
- `endedAt`
- `endedOnOverheating`
- `secondsAtLeastFair`, `secondsAtLeastSerious`, `secondsCritical`
- `highestState` (0–3)
- `batteryFirst`, `batteryHighest` (hundredths of °C, optional)
- `samples`: the number of readings. Not shown; for QA.

It also has two functions:

- `func noteText(now:formatter:) -> String?`, which returns nil when there is nothing to report (3.1).
- `static func shouldReport(...)`.

### 5.2 `HeatRecorder`

It is fed by `StatusBarController`:

- `observe(status: AwakeStatus, at: Date)` on every status poll.
- `thermalStateChanged(at:)` from the notification.
- `systemWillSleep(at:)` and `systemDidWake(at:)` from `NSWorkspace`'s sleep and wake notifications.

Rules:

1. **Start.** When a poll shows an active session whose token differs from the one being recorded, a new recording begins.
   - If the previous poll showed no session, the recording counts as watched from the start.
   - If the app just launched and the session was already running, `watchedFrom` is set to now. The same applies after a relaunch with a saved in-progress recording for another token.
2. **Time.** Time is added to the current thermal level between events: polls, thermal changes, sleep and wake.
   - Each interval is capped at 60 seconds, so a gap when the app was not running is never counted as time at one level.
   - Time asleep is not counted.
3. **Battery.** The battery is read on every poll, and the first and highest readings are kept.
4. **End.** When a poll shows no session, or a session with another token, the recording ends:
   - `endedAt` is the poll time, or `last_completed_at` when the completed session's token matches;
   - `endedOnOverheating` comes from `last_completion_reason`;
   - the summary is saved.
5. **Saving.** The finished summary goes to the app's preferences as `lastSessionHeat` (JSON data). The recording in progress is also saved, as `sessionHeatInProgress`, at most once a minute and on quit. A relaunch during the same session then continues it, with `watchedFrom` set, instead of losing it.
6. **Uninstall.** The uninstaller already removes the whole preferences domain, so both keys go with it.

### 5.3 App Nap

The app is an accessory app with no visible window. During a lid-closed session macOS may slow its timers down.

- While a recording runs, the app calls `ProcessInfo.processInfo.beginActivity(options: .userInitiatedAllowingIdleSystemSleep, reason: "Recording how warm the Mac gets during an Awake session")`. It ends the activity when the recording ends.
- That option keeps the timers running without keeping the Mac awake, so it never interferes with the session's own sleep handling.
- The `samples` count shows during QA whether this works: a 30-minute session should have about 180 samples.

## 6. Code changes

- `HeatReport.swift`: new (5.1, 5.2).
- `StatusBarController.swift`:
  - own a `HeatRecorder`;
  - feed it from `refreshStatus`'s main-queue block and from the thermal, sleep and wake notifications;
  - on quit, save the recording in progress;
  - `onStateChange` already redraws the Settings window.
- `InstallSupport.swift` (`PreferencesStore`): the keys `lastSessionHeat` and `sessionHeatInProgress`, with coding helpers.
- `SettingsWindowController.swift`:
  - a `heatNote` label (the existing `note(_:)` style, not selectable) directly under `thermalBox` in the Guardrails group;
  - `reload` sets its text from `PreferencesStore` through `HeatSummary.noteText`, and sets `isHidden` when that is nil, so the stack view closes the gap;
  - the tooltip from 3;
  - `reloadIfVisible` already runs on every poll, so the note appears as soon as a session ends.
- `StatusDescription.swift`: expose its duration wording, so the note says "12 minutes" the same way the menu does.

## 7. Tests

- **New:** `tests/app/heat-report-check.swift`. It is a small `@main` program, built with `-parse-as-library` together with `HeatReport.swift`, that feeds `HeatRecorder` made-up events and checks:
  - the time at each level, including the 60-second cap and sleep;
  - the start and end rules, including a token change without an idle poll between;
  - `watchedFrom` after a mid-session start;
  - the 3.1 rules;
  - every example sentence in 3.2, using a fixed `en_US` formatter and a fixed °F case.
- **CI:** a new step, "Check the heat report", builds and runs it with `-target arm64-apple-macos12.5`. This is the project's first Swift unit check. It runs on the macOS runner, so it also compiles `HeatReport.swift` against the real SDK.
- **Existing checks:** the app build and the macOS 12.5 build cover the rest of the Swift changes. The dry-run self-test does not change, because the CLI does not.

## 8. macOS QA checklist

1. **Battery units.** Compare `ioreg -rn AppleSmartBattery | grep '"Temperature"'` with the value in the saved summary: `defaults read net.kaenmaki.awake.statusbar lastSessionHeat` shows the data, and `plutil -p` shows a copy exported with `defaults export`. Confirm that the value is hundredths of °C.
2. **Reaching fair.** Start a 20-minute Caffeine session on AC. Load every core for 10 minutes: `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`, then `killall yes`. The note should report warm (or hot) time close to what `pmset -g therm` and Activity Monitor suggested, and a battery rise.
3. **Nothing to report.** Run a 10-minute idle session. The note should be hidden. Tune the 40 °C threshold if an idle session on battery already comes close to it.
4. **Units.** Set Region to the United States (°F). The note shows °F.
5. **Lid closed.** Run a 30-minute lid-closed session on battery with the lid closed. Afterwards, `samples` should be about 180, proving App Nap did not stop the recording. The note appears if the Mac got warm.
6. **Guard ending.** A session ended by the guard reads `…, so Awake ended it.` If the Mac cannot be made hot enough safely, this is covered by the unit check instead.
7. **Mid-session start.** Quit the app during a session and open it again. The note begins `Last session (from HH:MM):`.
8. **CLI session with the app running.** A session started with `awake --duration 15m` in Terminal is recorded too.

## 9. Docs

- **README, Settings window section:** under `Stop when too hot`, add: "After a session in which the Mac got warm, or the battery reached 40 °C, a note below this box says how warm, for example `Last session: warm for 12 minutes, never hot. Battery 31 → 38 °C.` Only sessions while `Awake.app` is running are recorded."
- **CHANGELOG `[Unreleased]`,** under Added: the note, the two sources, that it needs the app running, and that it does not depend on `Stop when too hot`.

## 10. Phases

1. `HeatReport.swift` and its check, green on CI.
2. The app wiring (6) and docs (9), green on CI.
3. QA (8) on a real Mac, then version 2.2.0 with `tools/release.sh minor`.

## 11. Risks and open points

- **The battery property.** `Temperature` could be missing or use other units on some models. The 0–80 °C check and QA item 1 limit the damage: the note leaves the battery part out rather than showing a wrong number.
- **Intel Macs** report `thermalState` more coarsely. It often stays nominal until throttling is heavy, so the note shows up less often there. This is acceptable.
- **App Nap.** If `beginActivity` turns out not to be enough during lid-closed sessions (QA item 5), fall back to reporting only what was seen, with `(from HH:MM)` wording for gaps. The 60-second cap already keeps a gap from being counted as warm or hot time.
- **Open.** Whether the note should also appear, briefly, in the `Awake stopped` notification when the guard ended a session. Left out for now (decision 3).
