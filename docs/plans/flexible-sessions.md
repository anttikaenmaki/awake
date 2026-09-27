# Plan: flexible session lengths for Awake

- Status: proposed, not yet implemented
- Target version: 2.1.0 (recommended; see open decision 5), helper protocol 8
- Written: 2026-09-27, against `dev` at 2.0.0 (commit `4716771`)
- Scope: `bin/awake`, `bin/awake-helper`, `tools/awake-gui-picker.swift`, `app/AwakeStatusApp`, `scripts/`, `tests/cli/awake-self-test`, `README.md`, `CHANGELOG.md`

## How this plan was checked

- Six readers first mapped the 2.0.0 code.
- The draft was then reviewed by six independent reviewers: `bin/awake` accuracy, helper safety, macOS platform facts, UX, app integration, and tests and release.
- An adversarial verifier re-checked every finding, and a final critic looked for gaps and for contradictions between the accepted changes. This version includes the findings that held up.

The review ran on Linux. Some macOS behaviour was settled from Apple's open-source code:

- the kernel's handling of `SleepDisabled`;
- `caffeinate`'s timer;
- the daily `/tmp` cleaner.

Everything else that needs a real Mac is in the QA checklist (10.4), tagged with the phase that needs it.

## 1. Goals

1. Remove the 9-hour limit.
2. "Until a clock time" sessions from the GUI and the terminal.
3. Indefinite sessions from the GUI and the terminal.
4. Custom-length sessions from the GUI and the terminal.
5. Process-tied sessions from the GUI. The terminal already has `-w PID` and `-- COMMAND`.
6. Configure the durations in the GUI picker, and choose the default.
7. Keep the picker as simple as it is now.

Not in scope: scheduled sessions and automatic triggers.

## 2. Decisions

### 2.1 Fixed

| # | Question | Decision |
|---|---|---|
| 1 | Menu or Settings window | Both. The menu keeps its items, and a Settings window shows them too. Settings holds the **default**; the menu changes the **current** value until Awake.app quits. |
| 2 | Upper bound for timed sessions | 365 days (31,536,000 s). This is a sanity check against typos and overflow, not a policy limit. Sessions without an end time have no bound. |
| 3 | Indefinite at the terminal prompt | `i` |
| 4 | Low battery | Stop at 5 % by default. |

How decision 1 maps onto the 2.0.0 menu:

| Menu item | Kind | Behaviour |
|---|---|---|
| Launch at login | One real value (the LaunchAgent) | Both places change it through one method. |
| Start without password | One real value (the sudoers rule; needs the admin password) | Both places change it through one method. |
| Use custom password dialog, Sound on, Stop when too hot, Stop at low battery | Default plus current | The existing UserDefaults keys become the defaults, so nothing needs migrating. At launch, current = default. The menu changes only current. Settings changes both. |
| Install Helper… | Action | Stays in the menu only. |

The picker keeps remembering the last lid and display choice (`lastBackend`, `lastKeepDisplay`).

### 2.2 Open (the plan follows the recommendation until you decide otherwise)

**5. Version number.** Two behaviour changes need upgrade notes:

- `-w` and `--` without a time option no longer stop after 9 hours.
- In `--status-json`, `active: true` with `remaining_seconds: null` no longer means leftover settings.

Recommendation: **2.1.0**. Both changes are documented in the Upgrade notes, and the app ships in step with the CLI. Choose 3.0.0 if you count them as breaking.

**6. Restoring sleep after a restart during a session.** The sleep settings survive a restart, but the session does not. The Mac then has sleep disabled and no guardrails until someone runs `awake --stop` or clicks the icon. This is already true in 2.0.0, and sessions without an end time make it matter more. The options:

- a. A root LaunchDaemon, installed and removed with the helper, that runs `helper restore` at boot when `/var/db/net.kaenmaki.awake/saved` exists.
- b. The app restores leftovers automatically at launch when password-free mode is on.
- c. Keep 2.0.0's behaviour (notify only).

Recommendation: **a**, as a follow-up change after this plan. This plan keeps c and says so in the Safety Warnings.

**7. Scope of the 5 % default.** In 2.0.0 one setting serves both modes. The plan changes that one default, so Caffeine also stops at 5 %. The reason, enough charge left to sleep rather than shut down, holds for both. Keeping Caffeine at 10 % would need a second setting in the menu and in Settings.

Recommendation: **one default for both modes**.

## 3. What 2.0.0 already provides

These pieces are reused rather than rebuilt:

- **A wall-clock deadline that can move.** The helper's timer and guard re-read `deadline_at` on every pass and compare it with the wall clock (`bin/awake-helper:842-857`, `:913-936`). `finish_session` re-checks under the lock (`:527-534`). An "until" session is therefore a start with an absolute deadline.
- **Adding time.**
  - The helper's `extend` command.
  - `--start`, `--duration-seconds` and `--backend` while a session runs.
  - `Add 1 hour` in the menu.

  See `bin/awake:3886-4006` and `bin/awake-helper:670-750`.
- **Process-tied sessions for both backends.**
  - `-w PID` and `-- COMMAND`.
  - PID identity via `lstart` (`bin/awake:1330-1346`, `bin/awake-helper:302-333`).
  - The reason `process_exited`, `watch_pid`/`watch_command` in JSON, and the status sentence.
  - `awake -- CMD` exits with the command's status (`bin/awake:2643-2693`).
- **Guardrails.** `--min-battery 5..50|off` and `--thermal-guard`, applied by the helper and the Caffeine runner, with menu items.
- **Leftover detection.** It uses `helper_session_state` and pmset `SleepDisabled`. The pre-session values survive a restart (`/var/db/net.kaenmaki.awake/saved`).
- **Installer.** It stops the session, quits the app, installs, and relaunches. The CLI updates the helper in the same password prompt when protocol versions differ.
- **Release tooling.** `tools/release.sh` and CI `--check`.

## 4. User-facing design

### 4.1 Picker, step 1

The window stays the same, with one row and one button added:

```
┌ Awake ────────────────────────────────────────┐
│ Choose how long to keep the Mac awake, and    │
│ how.                                          │
│ ┌───────────────────────────────────────────┐ │
│ │ 10 minutes                                │ │
│ │ 20 minutes                           ◀sel │ │
│ │ …                                         │ │
│ │ 8 hours                                   │ │
│ │ Indefinitely                              │ │
│ └───────────────────────────────────────────┘ │
│ ☑ Keep laptop awake with lid closed           │
│ ☐ Keep the display on        (greyed out)     │
│                 [Custom…]  [Cancel]  [Start]  │
└───────────────────────────────────────────────┘
```

- **The list** shows the configured entries (6.9). "Indefinitely" is included by default and can be removed in Settings. There are no separator or special rows.
- **Custom…** is the alert's third button (`.alertThirdButtonReturn`). Return still means Start and Esc still means Cancel.
- **Double-clicking a row** is the same as Start: the table's `doubleAction` calls `alert.buttons[0].performClick(nil)`.
- **List height** is min(rows, 12) × 30 pt, capped so the alert fits the screen's visible frame. The scroller shows only when the list is capped, and the selected row is scrolled into view. In 2.0.0 the list shows about 9.7 of its 11 rows with no scroller.
- **Selected row** is the Settings default (6.9).
- **Checkboxes and tooltips** behave as in 2.0.0.

### 4.2 Picker, step 2 (Custom…)

```
┌ Awake ────────────────────────────────────────┐
│ Keep the Mac awake:                           │
│ ◉ For    [ 1 ]⇅ h  [ 30 ]⇅ min                │
│ ○ Until  [ 18:30 ]⇅   today, in 2 h 5 min     │
│ ○ While  [ Choose an app or command…  ▾]      │
│ ☑ Keep laptop awake with lid closed           │
│ ☐ Keep the display on                         │
│                [Back]  [Cancel]  [Start]      │
└───────────────────────────────────────────────┘
```

**Layout and state.**

- Step 2 is a second modal shown after step 1 closes. Back returns to step 1 with its state kept.
- The two checkboxes share their state with step 1.
- Editing a control selects its radio button.

**Start button.**

- Step 2 replaces Start's target and action (`alert.buttons[0]`) with its own handler.
- The handler validates the input. If something is wrong, it writes the message into a label in the accessory view and leaves the dialog open. Only valid input calls `NSApp.stopModal(withCode: .alertFirstButtonReturn)`.
- `isEnabled` is updated from `controlTextDidChange` and from each control's action.

**For.** Digit-only hour (0–8760) and minute (0–59) fields with steppers.

- At 8760 hours, the minutes field is set to 0.
- A total of 0 disables Start.
- More than 365 days shows `At most 365 days`.

**Until.** An `NSDatePicker` with hours and minutes, following the system's 12/24-hour setting.

- The hint (`today, in 2 h 5 min` or `tomorrow, in 23 h 30 min`) updates on every change, and every 15 s through a timer in the modal run-loop mode.
- The epoch is computed when Start is pressed, with `Calendar.current.nextDate(after:matching:matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first)`.
- If the day at that moment differs from the one the hint showed, the dialog stays open with `18:00 has just passed. Press Start again to stay awake until tomorrow 18:00.`

**While.** A pop-up, rebuilt each time it opens.

- The first item is a disabled placeholder, `Choose an app or command…`, and it is selected when the pop-up opens.
- **Apps:** running apps with `activationPolicy == .regular`, shown with their icon and the .app bundle's name, excluding Awake.
- **Terminal commands:** from `/bin/ps -ax -o pid=,ppid=,uid=,tty=,comm=`.
  - Rows are kept when `uid == getuid()` (the same owner test as the helper, `bin/awake-helper:597-603`) and the tty isn't `??`.
  - Excluded: the picker's own PID and its ancestors (found through `ppid`), shells (`bash`, `zsh`, `sh`, `fish`, `tcsh`, `csh`, `ksh`, `dash`, after removing a leading `-`), `login` and `ps`.
  - The name is the basename of `comm`, shown as `rsync (PID 4812)`.
- `Apps` and `Terminal commands` are disabled header items. A header is left out when its group is empty.
- Start needs a chosen process that is still running (`kill(pid, 0)`). Otherwise the dialog shows `rsync has exited.`

**Remembered values.** For (hours and minutes) and Until (the clock time, never an epoch) are remembered (6.9). While is never remembered. First-run values: For 1 h 0 min; Until the next full hour.

**Accessibility.** Labels are `Hours`, `Minutes`, `Until time` and `Process to wait for`. The first responder is the first enabled field.

### 4.3 Adding time: prompt and list

With a session running, `--start` without an end option asks how much to add. It asks at the terminal, or with the list `awake --gui --start` shows when a session started elsewhere is running (`prompt_add_time`, `bin/awake:3825-3870`).

- **Default.** It is the Settings default when that is a length, otherwise 1 hour, matching the menu's `Add 1 hour`. Enter never means "indefinitely" or a clock time.
- **Terminal question:** `Add how much time, or until when? [20 minutes]:`
- **Terminal help lines:**
  ```
  - Press Enter to add 20 minutes
  - Type 1-9 for hours, 01-99 for minutes, or a length like 2h30m or 1d
  - Type a clock time like 18:30 or 6:30pm to stay awake until then
  - Type i to stay awake until you stop it
  - Press Esc, q, or Ctrl+C to cancel
  ```
  Invalid input prints the 4.6 `Not understood…` line.
- **GUI list.**
  - It shows the configured lengths, without "Indefinitely", and preselects the default entry (or the first entry when the default isn't listed).
  - It drops `empty selection allowed`. Today, OK with nothing selected makes AppleScript fail and the CLI report a failure.
- **Outcomes** follow 4.8.

### 4.4 Menu

The menu is the 2.0.0 menu plus one item:

```
Awake is on until 18:30, with 2 hours 5 minutes left
Add 1 hour                      (only when the session has an end time)
──────────
About / Instructions...
Settings…                    ⌘,
──────────
Launch at login
Use custom password dialog
Start without password
Sound on
Stop when too hot
Stop at low battery        ▸
Install Helper…                 (only when needed)
──────────
Quit                         ⌘Q
```

- The four default-plus-current items change the current value.
  - Their tooltips end with `Until Awake quits. Set the default in Settings.`
  - The guardrail items keep `Applies to the next session.` before that.
- `Add 1 hour` is shown only when the running session has a deadline. That covers length and until sessions, and process sessions with a time limit.

### 4.5 Settings window

```
┌ Awake Settings ───────────────────────────────┐
│ General                                       │
│   ☑ Launch at login                           │
│   ☐ Start without password                    │
│                                               │
│ Menu defaults                                 │
│   ☐ Sound on                                  │
│   ☐ Use custom password dialog                │
│   ☑ Stop when too hot                         │
│   Stop at low battery        [ 5%        ▾]   │
│   The menu can change these until Awake       │
│   quits. Sessions started in Terminal use     │
│   awake's own options.                        │
│                                               │
│ Session lengths                               │
│   ┌──────────────────────────────┐            │
│   │ 10 minutes                   │            │
│   │ …                            │            │
│   │ 8 hours                      │            │
│   └──────────────────────────────┘            │
│   [+] [−]                  [Restore Defaults] │
│   ☑ Include Indefinitely                      │
│   Default selection     [ 20 minutes     ▾]   │
│   Shown in the picker. The default is also    │
│   what Enter picks at the terminal prompt.    │
└───────────────────────────────────────────────┘
```

- **Labels** match the menu exactly. `Use custom password dialog` is dimmed while `Start without password` is on, as in the menu.
- **General.** Both checkboxes always show the real state and never keep a state of their own.
  - They are redrawn from `currentStatus.passwordless` and the launch-at-login value on every state change (8).
  - A cancelled or failed password prompt therefore reverts the box.
  - `Start without password` is disabled while a command is pending, as in the menu.
- **Menu defaults** always shows the stored defaults, not the current menu values.
- **`+`** opens a popover `[ 90 ] [minutes ▾] [Add]`.
  - The field accepts digits only and has a stepper.
  - Units are minutes, hours or days. Return adds.
  - Values must be whole minutes, at most 365 days.
- **The list** sorts itself and removes duplicates. It holds 1–15 lengths; Indefinitely doesn't count. `−` is disabled at one length.
- **Include Indefinitely** controls the `indefinite` entry, which is always shown last.
- **Default selection** lists every length, plus "Indefinitely" when it is included. If the default's entry disappears, the default follows the rule in 6.9.
- **Restore Defaults** resets only the Session lengths group, by removing the two keys (6.9).
- **Changes apply immediately.** The window re-reads everything each time it is shown.

### 4.6 Terminal prompt

| Input | Meaning |
|---|---|
| Enter | The default from Settings (20 minutes out of the box) |
| `1`–`9` | Hours (unchanged) |
| `01`–`99` | Minutes (unchanged) |
| `2h30m`, `90m`, `1d`, `2h 30m`, `2 hours` | A custom length |
| `18:30`, `18.30`, `6:30pm`, `7am` | Until the next time the clock shows that time |
| `i` | Indefinitely |
| Esc, `q`, Ctrl+C | Cancel (unchanged) |

Grammar rules:

- **One shared parser.** A single function, `parse_end_spec`, serves the start prompt, the add-time prompt, `--duration`, `--until` and the AppleScript fallback's Custom… field. The bare-number rules and `i` apply only at the prompts.
- **Case and spaces.** Input is case-insensitive, and spaces between parts are ignored.
- **Length units:** `d`, `h`, `m`, and the words `day(s)`, `hour(s)`, `hr`, `min`, `minute(s)`. `s` is accepted only by `--duration`.
- **Clock forms.**
  - `H:MM` and `HH:MM`, plus `H.MM` and `HH.MM`, from 0:00 to 23:59, with exactly two digits after the separator. `18.30` is kept because it is the usual Finnish way to write a time.
  - `H[:MM]am|pm` with H from 1 to 12. `12am` is 00:00 and `12pm` is 12:00.
- **Rejected, with a hint:**
  - `24:00` and `13pm`;
  - `1.5` and `1.5h` (use `1h30m`);
  - zero lengths (`0m`);
  - 3 or more bare digits (`1230` could mean 12:30 or 1,230 minutes);
  - anything more than 365 days away.
- **What a clock time means.** Today at HH:MM:00 if that is strictly later than now, otherwise the next calendar day (6.7).
- **The start line** always shows the interpretation (6.2), so a surprising reading is visible before any password prompt.

Help lines, replacing `bin/awake:2933-2936` and "Terminal duration input" in `show_usage` (`:199-203`, renamed `Terminal input:`):

```
- Press Enter for the default (20 minutes)
- Type 1-9 for hours, 01-99 for minutes, or a length like 2h30m or 1d
- Type a clock time like 18:30 or 6:30pm to stay awake until then
- Type i to stay awake until you stop it
- Press Esc, q, or Ctrl+C to cancel
```

The prompt shows the effective default in brackets, for example `[20 minutes]` or `[until you stop it]`. Invalid input prints `Not understood. Examples: 2 (hours), 45 (minutes), 2h30m, 18:30, i.`

### 4.7 Command-line options

| Option | Meaning |
|---|---|
| `--duration-seconds N` | Unchanged, up to 365 days |
| `--duration SPEC` | `90m`, `2h30m`, `1d`, `45s` (a unit is required) |
| `--until TIME` | `18:30`, `6:30pm`, `2026-09-28 07:00`, or `@EPOCH` |
| `--indefinite` | No end time |
| `-w PID`, `-- COMMAND` | Unchanged, except that without a time option they now have **no time limit**. In 2.0.0 the limit is 9 hours. |

Rules:

- **Combining.**
  - At most one of `--duration-seconds`, `--duration`, `--until` and `--indefinite`.
  - With `-w` or `--`, `--duration*` and `--until` set a time limit. `--indefinite` with them is refused as redundant.
- **Past times.** `--until` with a full date or `@EPOCH` that isn't later than now is rejected when the options are parsed: `The end time … has already passed.`
- **Session options.** All four are session options, like `--duration-seconds`.
  - They never stop a running session, and conflict with `--stop`, `--status` and maintenance.
  - They skip the picker or prompt, and `-t` accepts them without a TTY.
  - One flag, `END_CONDITION_GIVEN`, replaces every `DURATION_OVERRIDE_SECONDS` test: `bin/awake:399`, `:403`, `:3961`, `:4142`, `:4328`, `:4447` and `:4464`.

### 4.8 Requests while a session runs

| Request | Session with an end time | Session without an end time | Process session without a limit |
|---|---|---|---|
| A length: `--duration*`, the add-time prompt or list, `Add 1 hour` | Adds time, at most 365 days from now: `Added 1 hour.` | `Awake already runs until you stop it.` | `Awake already runs until make (PID 4242) exits.` |
| A clock time: `--until TIME`, or at the add-time prompt | Moves the end to TIME: `Awake now runs until 19:00.` If TIME isn't later: `Awake already runs until 19:00. Run awake --stop first to end it sooner.` | Same as the cell above | Same as the cell above |
| `--indefinite`, or `i` at the add-time prompt | Removes the end: `Awake now runs until you stop it.` | Same as the cell above | Same as the cell above |

- **Exit codes and passwords.**
  - Each result is followed by the status sentence.
  - "Nothing to do" outcomes exit 0, with no password and no helper call.
  - Exit 1 is kept for real refusals: a backend mismatch, or `-w`/`--` while a session runs, as in 2.0.0.
- **GUI mode** (not verbose): the message is posted with `notify_gui "Awake is already on"`, or `Awake extended`, as at `bin/awake:4345`.
- **Process session without a limit.** To add a limit, stop it and start it again with `-w PID --duration …`.
- **Caffeine sessions started by 2.0.0** have no `end_mode`. For them, `--indefinite` is refused with the existing `started by an older version of Awake. Stop it and start a new one.` Lengths and a later `--until` still work, because their runner re-reads a numeric `deadline_at`.

### 4.9 Status texts

The CLI (`build_status_text`) and the app (`StatusDescription`) must match. The CLI adds a final period, the app does not.

| Session | Text |
|---|---|
| Length | `Awake is on and has 2 hours 5 minutes left` (unchanged) |
| Until | `Awake is on until 18:30, with 2 hours 5 minutes left` |
| No end time | `Awake is on until you stop it` |
| Process, no limit | `Awake is on until make (PID 4242) exits` |
| Process with a limit | `Awake is on until make (PID 4242) exits, with at most 2 hours left` (unchanged) |
| Leftover settings | `Sleep is still turned off, but no Awake session is running` |

- **The clock label** is computed by bash as `deadline_label` (6.5) and used unchanged by the app, so the two can't differ:
  - `HH:MM` when the deadline's local date is today;
  - `tomorrow HH:MM` when it is tomorrow;
  - `YYYY-MM-DD HH:MM` otherwise.
- **The leftover sentence** replaces 2.0.0's `Awake is on with no end time`, which would read like an indefinite session. The CLI's second line (`bin/awake:1771`) becomes `Run awake --stop to restore normal sleep.`
- **Caffeine suffixes** (`(keep the lid open)` …) are unchanged.
- **Remaining time.**
  - First round up to whole minutes.
  - Under a day: hours and minutes, as today.
  - From a day on: days and hours, with the hours rounded up and carried. Examples: 86,399 s → `1 day`; 90,060 s → `1 day 2 hours`; 108,300 s → `1 day 7 hours`; 172,799 s → `2 days`.
  - The app's `remainingText` follows the same rule.

### 4.10 Messages and notifications

**Start lines**, used both for the `Starting …` lines (`bin/awake:4535`, `:4537`) and the `… activated …` lines (`:4572`, `:4576`, `:4609`, `:4613`):

- Until: `until [tomorrow ]HH:MM (LENGTH)`, always with the length.
- No end time: `until you stop it`.
- Process: `until rsync (PID 4812) exits`, plus ` (at most LENGTH)` only when there is a limit.
- Length: unchanged.

For sessions without an end time, `:4583` and `:4615` say `Run awake --stop (or just awake) to stop it.`

The process-session start line goes to stderr only when verbose or with `--`. A non-verbose GUI run (the app's case) prints only a refusal, if there is one, so the app's failure notification stays clean.

**Started notification.** The app's `postStarted` keeps 2.0.0's lid clause and replaces only the ending:

- `The Mac will stay awake with the lid closed until 18:30.`
- `… with the lid closed until you stop it.`
- `… while the lid remains open until rsync exits.`
- Length sessions keep `… until the chosen session ends.`
- The CLI's own start notification (`:4623`) gets the same body. Today it has none.

**Stopped, `process_exited`.** The process is named, taken from the last active status (`previousStatus` / `outcome.before`), because the inactive status has no `watch_*`. The Caffeine failure text (`StatusBarController.swift:354`) drops "timed".

**Refusals** (6.2):

- `The end time 18:30 has already passed.`
- `rsync has already exited.`
- `Battery is at 4%. …` (2.0.0 text)
- `Awake already runs until you stop it.` (4.8)

**Forced SleepDisabled.** When the saved `SleepDisabled` was 1 and a guardrail ended the session, `--status` adds: `Awake turned off pmset disablesleep, which was on before the session, so the Mac could sleep.` (4.11).

### 4.11 Low battery at 5 %, and sleeping after an unattended end

**Default.** The default changes in three places:

- `LOW_BATTERY_PERCENT` 10 → 5 (`bin/awake:72`, help text `:182` and `:211`);
- `DEFAULT_MIN_BATTERY_PERCENT` 10 → 5 (`bin/awake-helper:52`);
- `defaultMinBatteryPercent` 10 → 5 (`InstallSupport.swift:73`).

The menu choices stay the same (Never, 5 %, 10 % … 30 %). Users who explicitly picked a level keep it.

**Check interval.** The helper and the Caffeine runner check every 60 s, and every 20 s once the charge is at or below 15 %. A fast-draining Mac loses about 1 % a minute, and 5 % leaves less margin.

**Guardrail ends clear SleepDisabled.** When a session ends for `low_battery` or `overheated`, the helper restores `sleep` from the saved value but sets `SleepDisabled` to 0 even when the saved value was 1. The kernel's `checkSystemSleepAllowed` checks the user's disable-sleep flag before its low-battery exception, so while it is 1 macOS refuses every sleep, even its own emergency sleep. `finish_session` records `disablesleep_forced=1` in `last`, and status shows the line in 4.10.

**Sleeping after an unattended end.** Clearing `SleepDisabled` doesn't make a Mac with a closed lid sleep. The kernel (xnu `IOPMrootDomain`) only records the change and re-evaluates clamshell sleep on lid, power, display or boot events. So:

- **When.** After an unattended end, the helper puts the Mac to sleep. Unattended ends are `timeout`, `low_battery`, `overheated` and `process_exited`, including the end of `awake -- COMMAND` (6.10).
- **Conditions.** `ioreg -r -k AppleClamshellState -d 4` must show both `"AppleClamshellState" = Yes` and `"AppleClamshellCausesSleep" = Yes`. The second key leaves closed-display mode with an external display alone.
- **The step.** The helper runs `pmset sleepnow`, and retries once after 2 s if that fails, because the kernel applies the flag asynchronously.
- **Where it runs.** The step runs inside `finish_session`, only on the path that actually ended the session (the token matched), after `write_last` and `release_lock`, and not when the restore failed. A caller that finds the session already ended never forces sleep. Neither does a user stop (`stopped`).
- **Dry-run.** `lid_is_closed` also reads `clamshell_causes_sleep=yes|no` from `mock-thermal` (default `yes`), and the step appends a line to `mock-sleepnow`.
- Phase 0 confirms this on a Mac (10.4, item 1).

## 5. Helper changes (`bin/awake-helper`, protocol 8)

**Versions.**

- `HELPER_VERSION` and `HELPER_PROTOCOL_VERSION` (`bin/awake:89`) go from 7 to 8 together.
- The line stays exactly `readonly HELPER_VERSION=8`, because the CLI parses it as text.

**Bound.** `MAX_DURATION_SECONDS` becomes 31536000. The messages at `:582-583` and `:744` say `365 days`, not `$((MAX/3600)) hours`.

**`start UID END MIN_BATTERY THERMAL [WATCH_PID]`.**

- END replaces DURATION in the same position, so the arity check (3, 5 or 6 arguments) is unchanged. A plain number is still valid, so the existing command-shape tests keep working.
- END is `N` (`^[1-9][0-9]{0,7}$`, at most 365 days), `@EPOCH` (`^@[1-9][0-9]{9,10}$`), or `none`.
- UID is `^[0-9]{1,10}$`, and WATCH_PID is `^[1-9][0-9]{0,6}$`. Digit lengths are bounded before any arithmetic, because `is_uint` accepts any length and bash arithmetic wraps.
- `@EPOCH` is checked against the post-lock `now` (`:647`). If it isn't later, the helper exits 10, "the end time has passed". If it is more than 365 days away, it exits 64.
- `none` without WATCH_PID is an indefinite session. With it, a process session without a limit.

**Session record** (`write_session_file`, `:484-503`).

- New key `end_mode=duration|until|none`.
- `deadline_at` is stored explicitly: `started_at + N`, `E`, or empty for `none`. It is no longer derived as `started_at + $3`.
- `duration_seconds` is `deadline - started_at`, or empty for `none`.
- `write_last` records `end_mode` and, when it applies, `disablesleep_forced=1`.
- Records from v7 have no `end_mode` and are read as `duration`.

**Session end.**

- `finish_session timeout` (`:527-534`) returns 2 (not due) for `end_mode=none`. A missing deadline on a `duration` or `until` session still counts as damaged.
- The timer (`:810-885`) and guard (`:887-952`) re-read `end_mode` together with `deadline_at` on every pass, and skip every deadline branch for `none`. Today the timer's start-up check fails such a session, and the guard exits or times it out within about 2 s.
- The timer and guard also end the session as `process_exited` when `/tmp/keep-awake-lid-closed-UID/command-finished` exists. This file is only tested for existence, like `stop-request` (6.10).

**Heartbeat.** Without a deadline, the guard's only takeover (deadline + 30 s while the timer lives) never fires, and a stuck timer would leave the guardrails dead.

- Every 10 s the timer writes `token=<token>` and `at=<epoch>` to `STATE_DIR/heartbeat`, using builtin `printf` followed by `|| true`.
- The guard reads the file with `read_kv` and ignores it when the token differs.
- It treats the timer as stuck when `at` is more than 60 s old (5 s in dry-run), counting from its own start until the first beat.
- It then applies its dead-timer checks: stop request, command-finished, deadline, battery, process and thermal.
- `finish_session` and `restore` remove the file.

**`extend UID ADD`** (`:670-750`).

- ADD is one of:
  - `N` (1..MAX, keeps `end_mode`);
  - `@EPOCH` (same pattern as `start`, at most now + 365 days, else exit 64). It sets the end to EPOCH and `end_mode=until`. If EPOCH isn't later than `deadline_at`, nothing changes, and it exits 0 with `added_seconds=0`.
  - `none`: removes the end and sets `end_mode=none`.
- On a `none` session every ADD exits 11, "the session has no end time to change". The CLI checks this first (4.8), so the user never sees a password prompt for it.
- The v7-session refusal (exit 6) stays.
- The cap stays "at most 365 days from now".

**Guardrail ends** force `SleepDisabled` to 0, and unattended ends run the sleep step (4.11).

**Process start time.** `process_start_time` runs `TZ=UTC0 LC_ALL=C /bin/ps -o lstart= -p PID`, the same as the CLI's copy (6.2). Otherwise a time-zone change during a long process session would read as a new process.

**Documentation.** Update the command docs (`:14-30`) and the usage strings (`:961`, `:965`, `:981`).

## 6. CLI changes (`bin/awake`)

### 6.1 End condition and parsing

- **New globals**, which the self-test's `reset_main_flags` must reset:
  - `END_MODE` (duration, until or none)
  - `END_DEADLINE_EPOCH`
  - `END_CONDITION_GIVEN`
  - `WATCH_STARTED`
- **One END token** (`N`, `@E` or `none`) carries the end condition to the helper, to `--caffeinate-start` and `--caffeinate-runner`, to `--notify-wait` and to `extend_running_session`.
- **`validate_duration_seconds` (`:707-711`)** checks `^[1-9][0-9]{0,7}$` and ≤ MAX. Its callers (`:3285`, `:3352`, `:3388`, `:3514`) validate the END token instead.
- **`--duration-seconds` (`:271-289`)** checks the digit length before `10#`. Today `18446744073709551617` wraps to 1.
- **Process-tied sessions** no longer default to MAX (`:4146`, `:4150-4151`). Without a time option they use `END_MODE=none`.
- **Bash 3.2 only.** No `${x,,}`, `declare -A`, `mapfile` or fractional `read -t`. Lowercase with a `case` table or `/usr/bin/tr`.

### 6.2 Starting a session

**Process start time.**

- The CLI records the watched process's start time (`WATCH_STARTED`) when `-w` is parsed and right after the picker returns a process.
- Both copies of `process_start_time` (`bin/awake:1330-1339` and the helper's) run `TZ=UTC0 LC_ALL=C /bin/ps -o lstart= -p PID`.
- After `wait_for_helper_session_start` or `wait_for_session_start`, the CLI compares `WATCH_STARTED` with `watch_started` in the helper record or the Caffeine state file. The runner writes it there, and `write_state_file` keeps it on rewrites, as it keeps `keep_display` and `watch_pid`.
- If they differ, the CLI writes the stop request (no password) and reports `rsync has already exited.`
- The app's custom-password path sends only `-w PID` (7). Its second CLI run records the start time when it parses `-w`, so the seconds spent in the app's password dialog are not covered (13).

**Process from the picker** (phase 2).

- `bound_session` and `WATCH_PID` are set **after** `prompt_start_gui` (`:4472`), not only from `-w` or `--` before it.
- The PID then gets the same existence and ownership checks as `-w` (`:4166-4176`). Failures go through `report_start_failure`, so GUI users see them.

**Until** reaches the helper and the Caffeine worker as an epoch, so time spent in a password prompt can't make the session end late.

**Helper exit codes reach the CLI.** Today every transport turns a helper failure into `return 1` (`:2429-2448`, `:2469-2471`, `:2481`, `:2487-2489`).

- `run_helper` and `run_as_admin` store the helper's exit status in `HELPER_LAST_RC`, using `cmd || rc=$?` in each branch: dry-run, password-free `sudo -n`, terminal `sudo -p`, gui-custom `sudo -n`, and the install-and-run `/bin/sh -c`. sudo and sh pass the status through.
- In the gui transport, the AppleScript (`:2379-2391`) returns `"EXIT:" & errNum & linefeed & errMsg` when errNum isn't -128, instead of re-raising. `do shell script`'s error number is the command's exit status (TN2065). `run_as_admin` writes the message part to stderr, so the helper texts that `extend_running_session` and the app show today stay the same.
- The start (`:4593`) and extend (`:3914`) call sites map codes 9, 10 and 11 to the 4.10 texts through `report_start_failure`.
- If `HELPER_LAST_RC` is empty or 1, the CLI works the cause out itself: the start time is gone or changed, the epoch has passed, or the session's `end_mode` is now `none`. If none of these applies, it shows the helper's stderr and the generic text.

**Caffeine refusals.**

- Before launching the worker, the CLI removes any old status file.
- If `wait_for_session_start` sees reason `process_exited`, it returns 4 at once, and main prints `rsync has already exited.`

**Start lines and messages** follow 4.10. The hints at `:404`, `:4347` and `:4450` name `--duration`, `--until` and `--indefinite` too.

### 6.3 Adding time and changing the end

- The extend path (`:4309-4370`) follows the table in 4.8.
- It reads the running session's `end_mode` and watch state before `prompt_add_time`, and before any helper call that could ask for a password.
- `extend_running_session` takes the END token.
- Its result messages are `Added 1 hour.`, `Awake now runs until 19:00.` or `Awake now runs until you stop it.`, each followed by the status sentence.
- The maximum message (`:3995`, `:3997`) says `the maximum of 365 days from now`, for lengths only.
- The "session ended meanwhile" restart (`:4361`) carries the end mode.

### 6.4 Caffeine backend

**Arguments.** The DURATION argument of `--caffeinate-start` and `--caffeinate-runner` becomes the END token, keeping 9 and 7 arguments.

- Running 2.0.0 sessions keep their own command lines.
- The matchers check only the script path, the flag and the state file, so they don't change.

**State file.**

- It gains `end_mode` and `watch_started`, and writes `deadline_at` empty for `none`.
- `write_state_file` (`:3686-3708`) accepts that. `update_state_runtime_metadata` keeps both keys. `caffeinate_stop` (`:3642-3644`) doesn't fall back to 1200 for open-ended sessions.
- `write_state_file` and `write_session_file` write a `mktemp` file in the runtime folder (umask 077), then `chmod 600` and `mv -f`, as `write_status_file` does. A reader never sees a half-written file.
- Rewrites keep `end_mode` as they find it, so a 2.0.0 file stays without it (4.8).

**Runner.**

- **One assertion for the whole session.** The runner starts one `caffeinate FLAGS -w $$` and never restarts it. There is no `-t`: caffeinate's timer uses the uptime clock and doesn't count time asleep (`dispatch_time(DISPATCH_TIME_NOW, …)` in caffeinate.c). `-w $$` makes caffeinate exit if the runner is killed.
- **The 1 s loop.** On each pass it re-reads `end_mode` and `deadline_at` and acts only on a complete record; with no `session_token`, it tries again next pass.
- **Ending at the deadline.**
  - The runner ends only when `end_mode` is `duration` or `until` and the wall clock has passed a numeric `deadline_at`.
  - Before ending, it takes `STATE_DIR/deadline-lock` (`mkdir`, validated like `lock/`) and re-reads the record.
  - If the deadline moved, it carries on. Otherwise it writes `ending=1` atomically, releases the lock, and exits 0; the EXIT trap ends caffeinate, and `caffeinate_start` records `timeout`.
- **Adding time from the CLI** takes the same lock. If `ending=1` is set or the runner is gone, it returns 3, so the existing restart path starts a new session instead of reporting added time.
- **Failures.** If the child dies on its own, the runner exits 1, recorded as `failed`.
- **Dry-run child.** For every end mode, `( while /bin/kill -0 $$ 2>/dev/null; do /bin/sleep 1; done ) &`. Like `caffeinate -w`, it exits when the runner dies, and it has no bound of its own. The runner also writes the argv it would pass to caffeinate to `dry-run-caffeinate-args`, next to the existing `dry-run-caffeinate-flags`.
- **Guardrail checks** follow 4.11.
- **Keep-alive for `/tmp`.** Every 6 hours the runner runs `/usr/bin/touch -c -h` on `state` and `session`. `/etc/periodic/daily/110.clean-tmps` deletes files whose access, change and modification times are all more than 3 days old.

### 6.5 Status and JSON

**Remaining time** never comes from `$SESSION_FILE`.

- Caffeine status, extend and JSON read the state file; lid-closed ones read the helper record. Remaining time is `deadline_at - now`, or empty without a deadline.
- The callers at `:3975`, `:4251` and `:4313` drop `get_session_remaining_seconds ||`, and that function is removed.
- `write_session_file` (`:1652-1675`) keeps only `session_mode`, `session_backend`, `sound_notifications` and `session_token`. The session-file rewrites in `extend_running_session` (`:3965-3972`, `:3981-3990`) go.

**Telling states apart.**

- `build_status_text` reads the end mode, deadline, watch label and `keep_display` itself from the running backend's record, so all four callers (`:1767`, `:1999`, `:3993`, `:4318`) print the 4.9 sentences.
- An indefinite session and leftover settings are told apart by the helper state (`running` against `stale`) and the end mode, not by an empty remaining time.
- `print_status` prints its recovery line only for leftovers.

**`--status-json`** stays `schema_version: 1`. The new fields are additive, as `keep_display` and `watch_*` were, and `"error":null` stays last.

- `end_mode`: `duration`, `until`, `none`, or `null`.
- `deadline_at`: an integer or `null`.
- `deadline_label`: the 4.9 clock label, or `null`.
- `leftover_settings`: `true` only in the leftover case.
- `disablesleep_forced`: true after the forced clear in 4.11.
- `remaining_seconds` and `duration_seconds` are `null` without a deadline. `active: true` with `remaining_seconds: null` no longer implies leftovers (open decision 5).

**Clock seam.** `deadline_label` is computed from `current_epoch` (6.7) on every status call.

### 6.6 Completion notifier (`--notify-wait`, `:3273-3338`)

- It takes the END token and no longer rejects durations over MAX.
- On each 30-check pass it re-reads `end_mode` from the helper record or the state file.
  - While `end_mode` is `none`, there is no give-up time.
  - Otherwise it gives up at the current deadline + 2 h.
- It exits when the session ends: for lid-closed sessions when the helper token changes (existing), for Caffeine when the state file's token is gone (new).
- For lid-closed sessions it touches `SESSION_FILE` every 6 hours. If that file is gone anyway, status still works from the helper record, without the sound setting.

### 6.7 Clock times and formatting

- **One reading of the clock.** `current_epoch` wraps `/bin/date +%s`. The parser, the start line and the status labels read `now=$(current_epoch)` once, and derive every calendar value from it with `/bin/date -j -r "$now" …`.
- **Clock times.**
  - Today's candidate: `/bin/date -j -r "$now" -v${H}H -v${M}M -v0S +%s`, used only when it is later than now.
  - Otherwise tomorrow: `/bin/date -j -r "$now" -v+1d -v${H}H -v${M}M -v0S +%s`.
  - BSD `date -v` moves a time skipped by DST forward an hour and gives a repeated time its first occurrence. This matches the picker's Calendar policies.
  - `date -j -f` is not used here, because macOS `mktime` fails for a time that doesn't exist.
- **Full dates.** `YYYY-MM-DD HH:MM` uses `/bin/date -j -f '%Y-%m-%d %H:%M:%S' "$d $t:00" +%s`, formatted back with `-r`. If `date` fails or the round trip differs, for example `2026-09-31` or a time in a DST gap, the input is rejected with a hint.
- **Labels.** `format_duration_label` gives exact labels with every non-zero part: `1 hour 30 minutes`, `2 days`. `format_remaining_duration` follows the remaining-time rule in 4.9.

### 6.8 Terminal reader (`read_terminal_response_line`, `:965-1014`)

- **Input.** It accepts `[0-9A-Za-z:. ]`, echoes letters in lowercase, and takes up to 20 characters.
- **`q`** still cancels at any position; no grammar token contains a `q`.
- **Escape sequences.** After Esc, the reader sets `stty -icanon -echo min 0 time 1`, reads what is pending with one `/bin/dd bs=16 count=1`, and restores `min 1 time 0`.
  - Nothing pending means a lone Esc, which cancels.
  - Bytes starting with `[` or `O` are an escape sequence and are ignored, so an arrow key no longer cancels.
- **Parsing** stays in `parse_end_spec` and `set_duration_from_terminal_input`, so tests can mock the reader.

### 6.9 Settings in the CLI

- **One store.** The app's UserDefaults domain `net.kaenmaki.awake.statusbar` holds everything. The CLI reads with `/usr/bin/defaults read net.kaenmaki.awake.statusbar KEY`. That goes through `cfprefsd`, so it sees the app's latest values; the plist file is never read directly.
- **Keys.** All values are strings on both sides. The app uses `set(String, forKey:)` and `string(forKey:)`; the CLI and README use `defaults write … -string`.

  | Key | Written by | Value |
  |---|---|---|
  | `pickerDurations` | App | For example `600 1200 1800 2400 3000 3600 7200 10800 14400 21600 28800 indefinite` |
  | `pickerDefault` | App | Seconds or `indefinite` |
  | `customLastSeconds`, `customLastUntil` (`HH:MM`) | CLI | The last Custom… values |

- **Validation.**
  - A length token is a multiple of 60 from 60 to 31536000. The other token is `indefinite`.
  - Lengths are deduplicated, sorted numerically and cut to 15. `indefinite`, if present, is appended last, so the picker shows at most 16 rows.
  - A value with no valid length counts as bad and gives the built-in list.
  - A bad value never stops the picker.
- **Default rule**, shared with Settings (8): `pickerDefault` if it is listed; otherwise 1200 if listed; otherwise the first entry. The terminal prompt's Enter uses the same default.
- **When the CLI writes.** The CLI writes `customLast*` after a Custom… choice, including through `--prompt-gui-selection`. Explicit options never change them.
- **Test seam.** In dry-run only, `AWAKE_TEST_SETTINGS_DOMAIN` replaces the domain name. It must match `^net\.kaenmaki\.awake\.selftest$`. The self-test writes values with real `defaults write` and deletes the domain in `cleanup_state`. Without the variable, dry-run uses the built-ins and never touches the real domain.
- **CLI-only users** set the keys with `defaults write`. The README gives the commands.

### 6.10 `awake -- COMMAND`

- **How a lid-closed session ends.** When the command finishes, `run_bound_command` (`:2643-2693`) ends a lid-closed session through a new file in the user's runtime folder, `command-finished`, instead of the stop request.
  - The file is validated like `stop-request` and only tested for existence.
  - The helper records `process_exited`, so the sleep step in 4.11, the notification and the stop waiter all see a process end.
- **The stop call.** `request_helper_session_stop` takes the file name as a parameter. Its success check already ignores the reason (`:2583-2592`).
- **Leftovers.** The start path removes a leftover `command-finished`, as it does the stop request (`:4586`).
- **Caffeine** sessions keep using the stop request.

### 6.11 Other

- **Stop waiter.** `wait_for_requested_stop_completion` (`:2242-2256`) accepts `low_battery`, `overheated` and `process_exited` as completed. Today a stop that coincides with one of these waits 30 s and falls back.
- **`show_usage`.**
  - The intro says `Keep a MacBook awake for a while, until a time, or until you stop it, also with the lid closed.`
  - It lists `--duration SPEC` (`Length with a unit, e.g. 90m, 2h30m, 1d`), `--until TIME` (`e.g. 18:30, 6:30pm, "2026-09-28 07:00"`) and `--indefinite` (`No end time; stop with awake --stop`).
  - `--duration-seconds` loses `(up to 9 hours left)`, and the `-w` line says `(add --duration or --until for a time limit)`.
  - Every line stays within 80 columns.
- **Main-lock exclusions.** No new long-running internal mode is added, so they don't change.

## 7. Picker helper (`tools/awake-gui-picker.swift`)

- **One file.** It stays a single, self-contained Swift file. The installer and CI compile it on its own, and the CLI can also run it from source with `/usr/bin/swift`.
- **Input.** The two positional arguments stay: lid `true|false`, display `on|off`. Flags follow them:
  - `--entry SECONDS|indefinite LABEL`, repeated (bash sends the labels, so bash owns the formatting)
  - `--default-index N`
  - `--custom-seconds N`
  - `--custom-until HH:MM`

  An old picker ignores the flags and answers with a label, which the CLI still maps with the old table.
- **Output.** `key=value` lines replace `label|backend|display`:
  - `result=start|cancelled`
  - `backend`
  - `display`
  - `end_mode=duration|until|none|process`
  - `duration_seconds`
  - `until_epoch`
  - `watch_pid`
  - `custom_seconds`, `custom_until`

  Bash validates every value. The CLI keeps accepting the 2- and 3-field forms from older pickers. A process name is never sent back; the CLI builds the label from the PID (`watched_process_label`, which names an executable under `*.app/Contents/MacOS/` after its .app bundle).
- **`--prompt-gui-selection` JSON**, used by the app's custom-password path.
  - It adds `start_arguments`, which always holds exactly one end option: `["--duration-seconds","N"]`, `["--until","@E"]`, `["--indefinite"]` or `["-w","PID"]`.
  - `duration_seconds` stays for compatibility (the remaining seconds for until choices, `null` for the others), and the new app ignores it.
- **AppleScript fallback** (`:2974-3052`).
  - It shows the configured list, "Indefinitely" and "Custom…". Custom… is a text field parsed by `parse_end_spec`.
  - It drops `empty selection allowed`.
  - It has no While option; the README says so instead of "functionally equivalent".

## 8. App changes

**`AwakeStatus`.**

- New optional fields: `endMode`, `deadlineAt`, `deadlineLabel`, `leftoverSettings` and `disablesleepForced`. Each is declared `var …: T? = nil` **and gets a case in `AwakeStatus.CodingKeys`**, for example `case endMode = "end_mode"`.
- A defaulted property that is missing from CodingKeys compiles but is never decoded, like `fetchedAt`.

**`AwakeStartSelection`.**

- `durationSeconds` becomes `let durationSeconds: Int?`.
- `startArguments: [String]` is added, with `case startArguments = "start_arguments"`. A selection without it is `invalidPromptOutput`.
- `CustomStartSelection` carries `startArguments` instead of `durationSeconds`, and `startAwake` passes `durationSeconds: nil` with it. The start therefore never gets two end options.
- `Add 1 hour` keeps `durationSeconds: 3600`.

**Status and menu.**

- **Leftover detection.** `maybeNotifyStuckStatus` (`StatusBarController.swift:327-338`) uses `leftoverSettings == true` instead of `remainingSeconds == nil`. Otherwise every session without an end time would be reported as stuck after 20 s.
- **`Add 1 hour`** (`:427-438`, `:157-189`) shows only when `deadlineAt != nil`.
- **`StatusDescription`** has the 4.9 sentences and the remaining-time rule. It uses `deadlineLabel` and has no date formatter. The countdown prefers `deadlineAt`.

**Notifications** follow 4.10. `refreshStatus` suppresses transition and stuck notices only while a start, extend or stop is pending, not while maintenance runs (`.configuring`). `completionIdentifier` already prevents duplicates.

**`PreferencesStore`** (`InstallSupport.swift:56-150`).

- `soundEnabled`, `useCustomPasswordDialog`, `thermalGuardEnabled` and `minBatteryPercent` become in-memory stored properties: the current values, loaded from the existing keys at launch.
- New `defaultSoundEnabled`, `defaultUseCustomPasswordDialog`, `defaultThermalGuardEnabled` and `defaultMinBatteryPercent` are backed by those keys, keeping the inversion and the range check.
- Setting a default also sets the current value.
- No existing read site changes.
- Menu toggles assign only the current value, through one StatusBarController method. That method also clears the cached password whenever the custom dialog ends up off.

**Real values.**

- StatusBarController gets `setPasswordless(_:)`, which uses `runMaintenance` and clears the password cache when turning off, and `setLaunchAtLogin(_:) throws`.
- The menu and Settings both call these.
- An `onStateChange` callback fires after every `currentStatus` change and every preference change. It redraws an open Settings window.

**`PickerSettings`** (new, small).

- It mirrors 6.9: the built-in list, token checks, the cap and the default rule. A comment in each file points at the other.
- Labels use the same exact rule as `format_duration_label`.
- A bad stored value shows as the built-ins.
- Restore Defaults calls `removeObject(forKey:)` for `pickerDurations` and `pickerDefault`.

**`SettingsWindowController.swift`** (new).

- It is built in code like `ReadmeWindowController`: created once, `isReleasedWhenClosed = false`, centered once, then `makeKeyAndOrderFront` and `NSApp.activate`.
- `build-awake-app.sh` compiles every `Sources/*.swift`, so the new file needs no build change.
- The menu gets `Settings…` with ⌘,.

**Minimal main menu.** `main.swift` sets one after the `--notify` branch.

- It has Close ⌘W and an Edit menu (Undo, Cut, Copy, Paste, Select All), so the popover field and ⌘W work.
- It has no ⌘Q/`terminate:` item.
- The accessory app never shows this menu.

## 9. Install, uninstall and compatibility

**Installer.**

- It already stops the session, quits and relaunches the app, and runs `--install-helper`, which installs protocol 8 with one password prompt.
- New: before stopping, it runs `--status`. If a session is active, it prints `Installing stops the running session: <status text>`, which shows in the Install app's result.
- The README and the CHANGELOG say that installing or updating stops a running session.

**Uninstaller.** It quits only the app at `${APP_PATH}` from install-info, before `defaults delete`:

1. Find the app with `pgrep -u UID -f "${APP_PATH}/Contents/MacOS/AwakeStatusBar"`.
2. Send TERM.
3. Wait up to 5 s, then send KILL.

It no longer sends a bundle-id quit event, which in the self-test would quit the developer's real app. The self-test's stub order (`--gui --stop`, then `--gui --uninstall-helper`) stays.

**Running v7 sessions when only `bin/awake` is replaced** (no installer):

- They keep working. Their records have no `end_mode`, so they read as `duration`.
- The new helper recognises their processes by path and token.
- Adding time is refused with the existing exit 6 text. Caffeine sessions follow 4.8.

**Mixed copies.** Two Awake copies at protocol 7 and 8 reinstall each other's helper on every lid-closed start, as they do today. The CHANGELOG upgrade note says so.

**Password-free mode.** The sudoers rule allows any helper arguments, so any program running as the user can start an indefinite session without a password. `README.md:80` and the Security Notes must say so.

## 10. Tests

### 10.1 New self-test checks (dry-run)

**Helper.**

- `start UID 31536000` is accepted, and the session is stopped afterwards. `31536001` and 20-digit values are rejected.
- `start UID @<past>` exits 10.
- `start UID none` stays on for more than 3 s and stops on request.
- `extend` with `@E` (later and earlier) and with `none`. `extend` on a `none` session exits 11.
- `kill -9` the timer of a `none` session: after 3 s the session is still on, and `--stop` ends it through the guard.
- `kill -STOP` the timer of a `none` session (record the PID for `cleanup_state`) and write a low mock battery. The session is still on at about 2 s, and ends with `low_battery` within the 5 s heartbeat limit plus one guard poll plus a margin. Then `kill -KILL` the stopped timer.

**Sleep step.**

- With the mock lid closed and `clamshell_causes_sleep=yes`, a timeout, a `low_battery` end, and `awake -- /usr/bin/true` each write exactly one `mock-sleepnow` line.
- `--stop`, a `restore` that races a due timeout, and `clamshell_causes_sleep=no` write none.

**SleepDisabled.**

- `write_mock_pmset_state 5 1`, start a lid-closed session, set a low mock battery: afterwards `disablesleep=0`, and status shows the forced line.
- The same with `--stop` gives `disablesleep=1`.

**Parsing.**

- `--duration`, `--until` and `--indefinite`, with the conflicts and combinations in 4.7.
- The bounds 31536000 and 31536001, a huge wrapped number, `--until @past`, and `--until '2026-02-30 07:00'`.
- `-w <live pid> --indefinite` is refused.

**Grammar table**, with an exported `TZ=Europe/Helsinki`, fixed epochs and a mocked `current_epoch`:

- `18:30` at 17:00 gives today; at 19:00, or at exactly 18:30, it gives tomorrow.
- `00:00` at 23:59 gives tomorrow.
- `12am` and `12pm`.
- `03:30` on 2026-03-29 (skipped by DST) gives 04:30. `03:30` on 2026-10-25 (repeated) gives the first occurrence.
- `24:00`, `13pm`, `1.5h`, `0m`, `0h0m`, `366d` and `1230` are rejected.
- `45s` is rejected at the prompt but accepted by `--duration`.
- Spaces, uppercase, words and `i`.

**Lifecycles, both backends:**

- `--indefinite`: still on after 3 s, then `--stop`.
- `--until @now+4` ends with `timeout`.
- `-w PID` without a limit ends with `process_exited` and shows `until sleep (PID n) exits.` with no "at most".
- `--duration-seconds 60` and `--indefinite` against an indefinite session, and against a `-w` session without a limit, print the 4.8 text and make no helper call.
- `--until` on a running length session moves the end, and `--indefinite` removes it.
- Rapid repeated `--duration 60s` on a Caffeine `--until` session never ends it early.
- A sourced extend with `ending=1` set returns 3.

**Caffeine dry-run:**

- `dry-run-caffeinate-args` has `-w <runner pid>` and no `-t`.
- After `kill -9` of the runner, the stand-in exits within 3 s.

**Refusals and messages:**

- A mocked `run_helper` with `HELPER_LAST_RC` 9, 10 and 11 prints the three texts.
- A stubbed `run_with_admin_prompt` returning `EXIT:6` still prints the helper's message.
- `--gui -w <dead PID>` leaves exactly the refusal on stderr.
- A mismatching `watch_started` leads to a stop and `rsync has already exited.`

**Status and JSON:**

- Every row of 4.9.
- The remaining-time examples, 172,799 s and 90,061 s.
- A deadline two days away, and a mocked midnight for `tomorrow`.
- The JSON fields in 6.5, and the leftover sentence.
- `TZ=Asia/Tokyo process_start_time $$` equals `TZ=America/Los_Angeles process_start_time $$`.

**Stop waiter.** Status files with `low_battery`, `overheated` and `process_exited` all count as completed.

**Picker:**

- Parsing of the `key=value` answer, including malformed input and the old 2- and 3-field answers.
- A process choice sets `WATCH_PID` and runs the ownership check (phase 2).
- `print_prompt_start_gui_selection_json` gives exactly one end option in `start_arguments` for each end mode.

**Settings**, through `AWAKE_TEST_SETTINGS_DOMAIN`:

- built-ins when the domain is missing;
- garbage, duplicates, 16 lengths plus `indefinite`, a list holding only `indefinite`, out-of-range values, and one `-int` value;
- the default rule;
- `customLast*` is written for Custom… choices but not for explicit options.

**Low battery at 5 %.** Update `:1729`, where lid-closed ends at 10 %, to 5 %, and `:1870-1871`, where Caffeine ends at 8 %, to 4 %.

**`--help`** stays within 80 columns (`:2056`).

### 10.2 Existing tests that change

- **`:455` and `:2027`** assert the new leftover sentence.
- **`:977` and `:981`** get the new prompt texts.
- **`:996-1006` and `:1331-1363`** gain the new picker answer and keep the old-format cases.
- **`:1729` and `:1870-1871`**: the 5 % default.
- **`:1963`**: the pattern becomes `…exits.`, and the test asserts there is no "at most".
- **`reset_main_flags` (`:1043-1057`)** also resets the new globals, plus `WATCH_PID`, `RUN_COMMAND`, `MIN_BATTERY_PERCENT`, `KEEP_DISPLAY` and `THERMAL_GUARD`.
- **`cleanup_state`** removes `mock-sleepnow`, `dry-run-caffeinate-args`, `command-finished`, `deadline-lock` and the test domain.
- **Unchanged:**
  - `:450-451`, which passes an explicit 32400 as the remaining time;
  - the helper command shapes, because a number is still a valid END;
  - `:1236-1242`, which uses `MAX_DURATION_SECONDS` by name.
- **New parameters** to `build_status_text` and `write_state_file` are appended after the existing positional ones.

### 10.3 CI (optional)

- **Swift target.** Build the app and the picker with `-target arm64-apple-macos11`, the minimum that README Requirements then names, so an API newer than the minimum fails CI rather than a user's install.
- **Status-text parity.** Keep the 4.9 sentences in `tests/fixtures/status-texts.tsv`. `expect_status_text` reads that file, and a small Swift check compares `StatusDescription.text` against the same file.

### 10.4 macOS QA checklist

1. (Phase 0) Lid closed, once on battery and once on AC, with another process holding `caffeinate -i`. After a `--duration-seconds 60` session times out, the Mac sleeps within seconds (`pmset -g log`). Repeat without the sleep step to confirm it is needed.
2. (Phase 1) Indefinite lid-closed session: `pmset -g` shows `SleepDisabled 1` throughout. `--stop` restores it. After `kill -STOP` of the timer, the guard takes over after 60 s.
3. (Phase 1) An Until session that spans system sleep ends within seconds of waking.
4. (Phase 1) Caffeine indefinite: after `kill -9` of the runner, the assertion is gone within seconds (`pmset -g assertions`).
5. (Phase 1) Low battery (`--min-battery 50`, lid closed): the session ends, `SleepDisabled` is 0, and the Mac sleeps.
6. (Phase 1) With 2.0.0 lid-closed and Caffeine sessions running, replace only `bin/awake`, then check `--status`, `--status-json`, `--duration-seconds 60` and `--stop`. Lid-closed: one password prompt that updates the helper, then the exit 6 text. Caffeine: time is added.
7. (Phase 1) Restart during an indefinite lid-closed session: status shows the leftover sentence, `leftover_settings` is true, the app notifies once, and `--stop` restores the pre-session values.
8. (Phase 1) Change the time zone during `-w` sessions on both backends: they keep running. The menu and `awake --status` show the same Until clock time.
9. (Phase 1) With no stored battery key, the menu shows 5 %. A stored 10 % stays 10 %.
10. (Phase 2) Picker:
    - 1 and 16 rows without clipping;
    - three buttons side by side on macOS 11 and later;
    - double-click starts;
    - keyboard-only use and VoiceOver;
    - Custom… For (the 365-day limit), Until (the hint, the minute rollover, 12- and 24-hour systems) and While (apps, terminal commands, shells excluded, a process that exits before Start);
    - Back keeps the state.
11. (Phase 2) Custom-password mode with each end mode, including a password dialog left open past the Until time.
12. (Phase 3) Settings:
    - add, remove, Include Indefinitely and Restore Defaults;
    - a menu toggle compared with the default after relaunch;
    - Launch at login and Start without password in both places, including a cancelled prompt;
    - `defaults write` from Terminal is picked up by the next picker;
    - ⌘W closes Settings and About, and the `+` field supports ⌘C and ⌘V;
    - a session that ends while the password-free prompt is open gives one Stopped notification.
13. (Phase 3) `Add 1 hour` appears and disappears correctly for each end mode.
14. (Phase 4) Installing over a running 2.0.0 app with an active session shows the stop line. The helper updates to protocol 8 with one password prompt.
15. (Phase 1) `awake -- vim`, then Ctrl+Z and `fg`: the session keeps counting. With the lid closed on battery, `awake -- sleep 30` ends and the Mac sleeps.

## 11. Docs, changelog and release

**README format.** The About window renders:

- headings and paragraphs;
- `- ` bullets that fit on one line (nest with two spaces per level);
- column-0 fences and inline code.

It doesn't render tables, numbered lists, `**` emphasis or links, and a wrapped bullet continuation becomes a paragraph. The grammar, options and status texts go in bullet lists.

**README passages to update:**

- `:3`, `:24` and `:38`: "a chosen duration".
- `:34`: Caffeine without `-t`.
- `:41`, `:59`, `:216` and `:285`: 5 %.
- `:53`: the menu sets current values; Settings… holds defaults.
- `:63`: the leftover sentence.
- `:74`: helper arguments.
- `:80` and Security Notes: password-free now allows sessions without an end time.
- `:174`: the uninstaller also removes the picker settings.
- `:197` and `:322`: the fallback has no While option.
- `:203`, `:207-217`: the menu, Settings…, tooltips, and current versus default.
- `:206`: status examples.
- `:208`, `:229`, `:278` and `:286-288`: the 9-hour texts.
- `:277`: `-t` works with the new options.
- Options: entries for `--duration`, `--until` and `--indefinite`.
- `:297-322`: Terminal Input and GUI Input.
- Examples: until, indefinite, `--duration 2h30m`, and the settings keys for CLI-only use.
- Safety Warnings:
  - sessions without an end time;
  - the forced `SleepDisabled` clear;
  - the sleep step after an unattended end;
  - that a restart leaves sleep disabled until you stop the session (open decision 6).
- Runtime Files: `end_mode`, `heartbeat`, `command-finished`, `deadline-lock`.
- `:456-467`: self-test coverage.

**CHANGELOG `## [Unreleased]`,** added in the same commits as the features.

- **Added:**
  - until, indefinite and custom sessions;
  - process sessions from the picker;
  - the configurable picker list and default;
  - the Settings window.
- **Changed:**
  - the 365-day bound;
  - process sessions without a time limit by default;
  - the 5 % default;
  - "Menu toggles now last until Awake quits; set lasting defaults in Settings.";
  - the Mac sleeps after an unattended lid-closed end;
  - "(helper protocol version 8)".
- **Security:**
  - password-free mode now also allows sessions without an end time;
  - the helper bounds numeric arguments before doing arithmetic on them.
- **Fixed:**
  - OK with nothing selected in the add-time list reported a failure;
  - a huge `--duration-seconds` wrapped to a small value;
  - `--stop` waited 30 s when a session ended at the same moment for low battery, heat or process exit;
  - a time-zone change could end a process session;
  - arrow keys cancelled the terminal prompt.
- **Upgrade notes:**
  - run the installer again, which stops a running session, or let the next lid-closed start update the helper;
  - your current menu choices become the Settings defaults;
  - the two behaviour changes in open decision 5, with their migrations: pass `--duration-seconds 32400` to keep the old cap for `-w`/`--`, and read `leftover_settings` in `--status-json`.

**Release.**

- For 2.1.0: `tools/release.sh minor`, which updates `bin/awake`, README, the three plists and CHANGELOG. It accepts an explicit level even when its suggestion differs.
- The helper protocol constants are changed by hand in the feature commits.

## 12. Phases

Every phase ends with the self-test green on CI and its QA items done.

- **Phase 0: facts.** QA item 1 on a Mac confirms the sleep step and how quickly the Mac sleeps.
- **Phase 1: engine.**
  - Helper protocol 8 (section 5).
  - The CLI's end condition, options, start and extend paths, Caffeine runner, status and JSON, notifier, clock times, terminal reader and `--` end (6.1–6.8, 6.10, 6.11). The process-from-picker step of 6.2 waits for phase 2.
  - The 5 % default and the sleep step (4.11).
  - The prompt uses the built-in 20-minute default.
  - The app's `AwakeStatus` fields, leftover detection, `Add 1 hour` visibility, `StatusDescription` and notifications (section 8), so the app shipped with it never flags a session without an end time as stuck.
- **Phase 2: picker.**
  - Settings keys in the CLI (6.9).
  - Picker v2 with Custom… and While (4.1, 4.2 and 7), including the process-from-picker step of 6.2.
  - The add-time prompt and list (4.3) and the fallback.
  - `--prompt-gui-selection` with `start_arguments`, together with the app's `AwakeStartSelection` change.
- **Phase 3: app.** `PreferencesStore` defaults and current values, the real-value methods, `PickerSettings`, the Settings window, the `Settings…` item, the main menu, the tooltips, and the uninstaller change.
- **Phase 4: release.** README sweep, CHANGELOG, the installer's stop line, the version (open decision 5), and the full QA checklist.

## 13. Risks and open points

- **Sessions without an end time.** An indefinite lid-closed session with `--min-battery off` and `--thermal-guard off` ends only on stop or when the watched process exits. A restart doesn't end it: sleep stays disabled, with no guardrails, even at the login window, until someone runs `awake --stop` or clicks the icon after logging in (open decision 6). The Safety Warnings say so.
- **The 5 % margin.** It relies on the sleep step (4.11) and on the battery reading, which is imprecise near empty on worn batteries.
- **PID reuse in the app's custom-password path.** The seconds between the picker and the second CLI run, which include the password dialog, aren't covered by the start-time check (6.2).
- **Password-free mode** now also allows indefinite sessions without a password (9).
