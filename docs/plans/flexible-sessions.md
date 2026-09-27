# Plan: flexible session lengths for Awake

- Status: draft under review; not yet implemented
- Target version: 2.1.0 (helper protocol 8)
- Written: 2026-09-27, against `dev` at 2.0.0 (commit `4716771`)
- Scope: `bin/awake`, `bin/awake-helper`, `tools/awake-gui-picker.swift`, `app/AwakeStatusApp`, `scripts/`, `tests/cli/awake-self-test`, `README.md`, `CHANGELOG.md`

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

| # | Question | Decision |
|---|---|---|
| 1 | Menu or Settings window | Both. The menu keeps its items, and a Settings window shows them too. Settings holds the **default**; the menu changes the **current** value until Awake.app quits. |
| 2 | Upper bound for timed sessions | 365 days (31,536,000 s). This is a sanity check against typos and overflow, not a policy limit. Sessions without an end time have no bound. |
| 3 | Indefinite at the terminal prompt | `i` |
| 4 | Low battery | Stop at 5 % by default. |

How decision 1 maps onto the 2.0.0 menu:

| Menu item | Kind | Behaviour |
|---|---|---|
| Launch at login | One real value (the LaunchAgent) | Both places change it. |
| Start without password | One real value (the sudoers rule; needs the admin password) | Both places change it. |
| Use custom password dialog, Sound on, Stop when too hot, Stop at low battery | Default plus current | The existing UserDefaults keys become the defaults, so nothing needs migrating. At launch, current = default. The menu changes only current. Settings changes both. |
| Install Helper… | Action | Stays in the menu only. |

The picker's remembered lid and display choices (`lastBackend`, `lastKeepDisplay`) stay as they are.

Scope of decision 4: in 2.0.0 one setting serves both modes. This plan changes that one default from 10 % to 5 %, so it applies to Caffeine as well as lid-closed sessions. The reason, enough charge left to sleep rather than shut down, holds for both, and it keeps a single setting. Keeping Caffeine at 10 % would need a second setting; say if you want that. Users who explicitly picked a level keep it.

## 3. What 2.0.0 already provides

These pieces are reused rather than rebuilt:

- **A wall-clock deadline that can move.**
  - The helper's timer and guard re-read `deadline_at` on every pass and compare it to wall-clock time (`bin/awake-helper:842-857`, `:913-936`). `finish_session` re-checks under the lock (`:527-534`).
  - The Caffeine runner re-reads `deadline_at` after each `caffeinate -t` (`bin/awake:3473-3487`).
  - An "until" session is therefore a start with an absolute deadline.
- **Adding time.** Helper `extend`, which is lock-ordered against the timeout; `--start`, `--duration-seconds` and `--backend` while a session runs; the `Add 1 hour` menu item (`bin/awake:3886-4006`, `bin/awake-helper:670-750`).
- **Process-tied sessions for both backends.**
  - `-w PID` and `-- COMMAND`.
  - PID identity via `lstart` (`bin/awake:1330-1346`, `bin/awake-helper:302-333`).
  - The reason `process_exited`, `watch_pid`/`watch_command` in JSON, and the status sentence.
  - `awake -- CMD` exits with the command's status (`bin/awake:2643-2693`).
- **Guardrails.** `--min-battery 5..50|off` and `--thermal-guard`, applied by the helper and the Caffeine runner, with menu items.
- **Leftover recovery.** Sleep settings left behind are detected (`helper_session_state`, pmset `SleepDisabled`), and the pre-session values survive a restart (`/var/db/net.kaenmaki.awake/saved`).
- **Installer.** It stops a running session, quits the app, installs, and relaunches. The CLI updates the helper in the same password prompt when protocol versions differ.
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

- **The list** shows the configured entries. "Indefinitely" is included by default and can be removed in Settings. There are no separator or special rows.
- **Custom…** is the alert's third button (`.alertThirdButtonReturn`). Return still means Start and Esc still means Cancel.
- **Double-clicking a row** is the same as Start.
- **List height** is min(rows, 12) × 30 pt, capped so the alert fits the screen's visible frame. The scroller shows only when the list is capped, and the selected row is scrolled into view. In 2.0.0 the list shows about 9.7 of its 11 rows with no scroller.
- **Selected row** comes from the Settings default (6.7).
- **Checkboxes and tooltips** behave as in 2.0.0.

### 4.2 Picker, step 2 (Custom…)

```
┌ Awake ────────────────────────────────────────┐
│ Keep the Mac awake:                           │
│ ◉ For    [ 1 ]⇅ h  [ 30 ]⇅ min                │
│ ○ Until  [ 18:30 ]⇅   today, in 2 h 5 min     │
│ ○ While  [ Safari                ▾] runs      │
│ ☑ Keep laptop awake with lid closed           │
│ ☐ Keep the display on                         │
│                [Back]  [Cancel]  [Start]      │
└───────────────────────────────────────────────┘
```

- **Layout and state.** Step 2 is a second modal shown after step 1 closes. Back returns to step 1 with its state kept. The two checkboxes are the same state as in step 1. Editing a control selects its radio button.
- **For:** digit-only hour (0–8760) and minute (0–59) fields with steppers. A total of 0 disables Start.
- **Until:** an `NSDatePicker` with hours and minutes, following the system's 12/24-hour setting.
  - The hint `today, in 2 h 5 min` or `tomorrow, in 23 h 30 min` updates on every change.
  - The epoch is computed only when Start is pressed, with `Calendar.current.nextDate(after:matching:matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first)`.
- **While:** a pop-up rebuilt each time it opens.
  - **Apps:** running apps with `activationPolicy == .regular`, excluding Awake.
  - **Terminal commands:** the user's own processes that have a terminal.
    - Source: `ps -x -o pid=,tty=,ucomm=`, keeping rows whose tty isn't `??`.
    - Excluded: the picker's own PID and its ancestors, shells (`bash`, `zsh`, `sh`, `fish`, `tcsh`, `csh`, `ksh`, `dash`, matched after removing a leading `-`), `login` and `ps`.
    - Shown as `rsync (PID 4812)`.
  - Only the user's own processes are listed, because the helper refuses other users' processes (`bin/awake-helper:601-603`).
  - Start stays disabled until a process is chosen.
  - If the process is gone when Start is pressed, the dialog stays open with `rsync has exited.`
- **Remembered values:** For (hours and minutes) and Until (the clock time, never an epoch). While is never remembered. First-run values: For 1 h 0 min; Until the next full hour.
- **Accessibility:** labels `Hours`, `Minutes`, `Until time`, `Process to wait for`. The first responder is the first enabled field.

### 4.3 Adding time from the GUI

When a session started elsewhere is running, `awake --gui --start` shows the add-time list instead of the picker (`prompt_add_time`, `bin/awake:3853-3869`). That list uses the configured lengths without "Indefinitely".

It also drops `empty selection allowed`. Today, OK with nothing selected makes AppleScript fail and the CLI report a failure.

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

- The toggles change the current value (decision 1).
- `Add 1 hour` is shown for length and until sessions, and for process sessions that have a time limit. It is hidden for sessions without an end time.

### 4.5 Settings window

```
┌ Awake Settings ───────────────────────────────┐
│ General                                       │
│   ☑ Launch at login                           │
│   ☐ Start without password                    │
│                                               │
│ Defaults when Awake starts                    │
│   ☐ Sound on                                  │
│   ☐ Use custom password dialog                │
│   ☑ Stop when too hot                         │
│   Stop at low battery        [ 5%        ▾]   │
│   The menu can change these until Awake quits.│
│                                               │
│ Picker                                        │
│   ┌──────────────────────────────┐            │
│   │ 10 minutes                   │            │
│   │ …                            │            │
│   │ 8 hours                      │            │
│   └──────────────────────────────┘            │
│   [+] [−]                  [Restore Defaults] │
│   ☑ Include Indefinitely                      │
│   Default selection     [ 20 minutes     ▾]   │
└───────────────────────────────────────────────┘
```

- **Labels** match the menu exactly. `Use custom password dialog` is dimmed while `Start without password` is on, as in the menu.
- **Start without password** runs the same maintenance command as the menu (`runMaintenance(["--passwordless", …])`), which asks for the password.
- **`+`** opens a popover `[ 90 ] [minutes ▾] [Add]`: a digit-only field with a stepper, units of minutes, hours or days, Return adds, maximum 365 days.
- **The list** sorts itself, removes duplicates, and holds 1–15 entries. `−` is disabled at one entry.
- **Include Indefinitely** controls the `indefinite` entry, which is always shown last.
- **Default selection** lists every entry, plus "Indefinitely" (if included) and "Last used". If the default's entry is removed, or Indefinitely is unchecked while it is the default, the default becomes the first remaining entry.
- **Restore Defaults** resets only the Picker group.
- **When changes apply.** Changes apply at once. The window re-reads everything each time it is shown, and refreshes when a menu toggle changes.
- **Launch at login** is re-read when the window becomes key. If `LaunchAgentManager.setEnabled` throws, the checkbox reverts.

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
- **Case and spaces.** Case-insensitive; spaces between parts are ignored.
- **Length units:** `d`, `h`, `m`, and the words `day(s)`, `hour(s)`, `hr`, `min`, `minute(s)`. `s` is accepted only by `--duration`.
- **Clock forms.**
  - `H:MM` and `HH:MM`, plus `H.MM` and `HH.MM`, from 0:00 to 23:59, with exactly two digits after the separator.
  - `H[:MM]am|pm` with H from 1 to 12. `12am` is 00:00 and `12pm` is 12:00.
- **Rejected with a hint:** `24:00`, `13pm`, `1.5` and `1.5h` (use `1h30m`), and 3 or more bare digits (`1230` could mean 12:30 or 1,230 minutes). Anything over 365 days is rejected too.
- **What a clock time means.** Today at HH:MM:00 if that is strictly later than now, otherwise the next calendar day at HH:MM:00 (6.6).
- **The start line** shows the interpretation, for example `Starting awake until tomorrow 07:00 (8 hours 12 minutes).` or `Starting awake until you stop it.` Length sessions keep today's wording.

Reader changes (`read_terminal_response_line`, `bin/awake:965-1014`):

- It accepts `[0-9A-Za-z:. ]`, echoes letters in lowercase, and takes up to 20 characters.
- `q` still cancels at any position; no grammar token contains a `q`.
- After Esc it reads the bytes that arrive within 0.1 s and discards an escape sequence, so an arrow key no longer cancels. A lone Esc cancels.

The help lines (`:2933-2936`, and "Terminal duration input" in `show_usage`, `:199-203`) become:

```
- Press Enter for the default (20 minutes)
- Type 1-9 for hours, 01-99 for minutes, or a length like 2h30m or 1d
- Type a clock time like 18:30 or 6:30pm to stay awake until then
- Type i to stay awake until you stop it
- Press Esc, q, or Ctrl+C to cancel
```

- The prompt shows the effective default in brackets, for example `[20 minutes]` or `[until you stop it]`.
- Invalid input prints `Not understood. Examples: 2 (hours), 45 (minutes), 2h30m, 18:30, i.`
- The add-time prompt (`:3839-3849`) uses the same parser and the rules in 4.7.

### 4.7 Command-line options

| Option | Meaning |
|---|---|
| `--duration-seconds N` | Unchanged, up to 365 days |
| `--duration SPEC` | `90m`, `2h30m`, `1d`, `45s` (a unit is required) |
| `--until TIME` | `18:30`, `6:30pm`, `2026-09-28 07:00`, or `@EPOCH` |
| `--indefinite` | No end time |
| `-w PID`, `-- COMMAND` | Unchanged, except that without a time option they now have **no time limit**. In 2.0.0 the limit is 9 hours. |

Rules:

- **Combining.** At most one of `--duration-seconds`, `--duration`, `--until` and `--indefinite`. With `-w` or `--`, `--duration*` and `--until` set a time limit; `--indefinite` is refused as redundant.
- **Session options.** All four are session options, like `--duration-seconds`: they never stop a running session, they conflict with `--stop`, `--status` and maintenance, and they skip the picker or prompt. One flag, `END_CONDITION_GIVEN`, replaces the `DURATION_OVERRIDE_SECONDS` checks at `bin/awake:399`, `:403`, `:4142`, `:4447` and `:4464`.
- **While a session runs:**

  | Request | Session with an end time | Session without an end time |
  |---|---|---|
  | `--duration*`, a length from the add-time prompt, `Add 1 hour` | Adds time, as in 2.0.0, but at most 365 days from now | Prints `Awake already runs until you stop it.` and does nothing; exit 0, no password |
  | `--until TIME`, or a clock time at the add-time prompt | Moves the end to TIME if that is later; otherwise `Awake already runs until 19:00.` and exit 1 | Same message as the left column |
  | `--indefinite`, or `i` at the add-time prompt | Removes the end time | Same message as the left column |

- **Unchanged from 2.0.0:**
  - `-w` and `--` are refused while a session runs.
  - A `--backend` that doesn't match the running session is refused.

### 4.8 Status texts

The CLI (`build_status_text`) and the app (`StatusDescription`) must match. The CLI adds a final period, the app does not.

| Session | Text |
|---|---|
| Length | `Awake is on and has 2 hours 5 minutes left` (unchanged) |
| Until | `Awake is on until 18:30, with 2 hours 5 minutes left` (or `tomorrow 07:00`, or `2026-10-02 07:00`) |
| No end time | `Awake is on until you stop it` |
| Process, no limit | `Awake is on until make (PID 4242) exits` |
| Process with a limit | `Awake is on until make (PID 4242) exits, with at most 2 hours left` (unchanged) |
| Leftover settings | `Awake is on with no end time`, plus the CLI's recovery line (unchanged; it now means only this case) |

- Caffeine suffixes (`(keep the lid open)` …) are unchanged.
- Remaining time gains days: `1 day 6 hours`.
- Clock times use 24-hour `HH:mm` in both the CLI and the app. The app uses a fixed `en_US_POSIX` formatter, so the texts stay identical.

### 4.9 Notifications

- **Started** (app `postStarted`, and the CLI's own notification):
  - `The Mac will stay awake until 18:30.`
  - `… until you stop it.`
  - `… until rsync exits.`
  - Length sessions keep their text.
- **Stopped, reason `process_exited`:** names the process, taken from the last active status (`previousStatus` / `outcome.before`), because the inactive status has no `watch_*`.
- **Failure text for Caffeine** (`StatusBarController.swift:354`): drop "timed".
- **New refusals** (6.2):
  - `The end time 18:30 has already passed.`
  - `rsync has already exited.`

### 4.10 Low battery at 5 %

- **The default changes in three places:** `LOW_BATTERY_PERCENT` 10 → 5 (`bin/awake:72`), `DEFAULT_MIN_BATTERY_PERCENT` 10 → 5 (`bin/awake-helper:52`), and `defaultMinBatteryPercent` 10 → 5 (`InstallSupport.swift:73`). The menu choices stay the same (Never, 5 %, 10 % … 30 %).
- **Check interval.** The helper and the Caffeine runner check every 60 s, and every 20 s once the charge is at or below 15 %. At 5 % there is less margin, and a fast-draining Mac loses about 1 % a minute.
- **Guard ends clear SleepDisabled.** When a session ends for `low_battery` or `overheated`, the helper restores `sleep` from the saved value but always sets `SleepDisabled` to 0, even if the saved value was 1, and logs it. macOS refuses every sleep, including its own low-battery sleep, while `SleepDisabled` is 1 (verify on a Mac).
- **Does the Mac actually sleep?** Check on a Mac whether clearing `SleepDisabled` with the lid closed makes it sleep. 2.0.0 relies on this for the "ends … so it can sleep and cool down" promise, and the review couldn't confirm it (phase 0). If it doesn't, the helper runs `pmset sleepnow` after an unattended end (`timeout`, `low_battery`, `overheated`, `process_exited`) when `ioreg -r -k AppleClamshellState -d 1` shows both `AppleClamshellState = Yes` and `AppleClamshellCausesSleep = Yes`. The second key leaves closed-display mode with an external display alone. Ends the user asked for (`stopped`) never force sleep.

## 5. Helper changes (`bin/awake-helper`, protocol 8)

- **Versions.** `HELPER_VERSION` and `HELPER_PROTOCOL_VERSION` (`bin/awake:89`) go from 7 to 8 together. The line stays exactly `readonly HELPER_VERSION=8`, because the CLI parses it as text.
- **Bound.** `MAX_DURATION_SECONDS` becomes 31536000. The messages at `:744` and `:582-583` say `365 days`, not `$((MAX/3600)) hours`.
- **`start UID END MIN_BATTERY THERMAL [WATCH_PID]`.**
  - END replaces DURATION in the same position, so the arity check (3, 5 or 6 arguments) is unchanged.
  - END is `N` (`^[1-9][0-9]{0,7}$`, at most 365 days), `@EPOCH` (`^@[1-9][0-9]{9,10}$`), or `none`.
  - Digit lengths are bounded before any arithmetic, because `is_uint` accepts any length and bash arithmetic wraps. The same applies to the UID (`^[0-9]{1,10}$`).
  - `@EPOCH` is checked against the post-lock `now` (`:647`). If it isn't later, the helper exits 10, "the end time has passed". If it is more than 365 days away, it exits 64.
  - `none` without a `WATCH_PID` is an indefinite session. With one, it is a process session without a limit.
- **Session record** (`write_session_file`, `:484-503`).
  - New key `end_mode=duration|until|none`.
  - `deadline_at` is stored explicitly and is empty for `none`; it is no longer derived as `started_at + $3`.
  - `duration_seconds` is `deadline - started_at`, or empty for `none`.
  - `write_last` also records `end_mode`.
  - Records from v7 have no `end_mode` and are read as `duration`.
- **`finish_session timeout`** (`:527-534`) returns 2 (not due) for `end_mode=none`. A missing deadline on a `duration` or `until` session still counts as damaged.
- **Timer** (`:810-885`) and **guard** (`:887-952`) skip every deadline branch for `none`. Today the timer's start-up check fails such a session, and the guard exits, or times the session out within about 2 s.
- **Heartbeat backstop.** Without a deadline, the guard's only takeover (deadline + 30 s while the timer lives) never fires, so a stuck timer would leave the guardrails dead.
  - Each timer pass touches `STATE_DIR/heartbeat` with a builtin `: >`.
  - The guard treats the timer as dead when the heartbeat is more than 60 s old, and then applies its dead-timer checks: stop request, deadline, battery, process and thermal.
  - In dry-run the heartbeat limit is 5 s.
- **`extend UID ADD`** (`:670-750`).
  - ADD is `N` (1..MAX), `@EPOCH` (move the end to EPOCH if that is later; `end_mode` becomes `until`), or `none` (remove the end time; `end_mode` becomes `none`).
  - On a `none` session, any ADD exits 11, "the session has no end time". The CLI checks this first, so the user never sees a password prompt for it.
  - The v7-session refusal (exit 6) stays.
  - The cap stays "at most 365 days from now".
- **Low-battery and thermal ends.** They force `SleepDisabled` to 0 (4.10). Add `pmset sleepnow` only if phase 0 shows it is needed.
- **Process start time.** Pin `TZ=UTC0 LC_ALL=C` for `ps -o lstart=` (`:302-313`), so a time-zone change during a long process session isn't mistaken for a new process.
- **Documentation.** Update the command docs at `:14-30` and the usage strings at `:961`, `:965` and `:981`.

## 6. CLI changes (`bin/awake`)

### 6.1 End condition

- **New globals**, which `reset_main_flags` in the self-test must also reset:
  - `END_MODE` (duration, until or none)
  - `END_DEADLINE_EPOCH` (for until)
  - `END_CONDITION_GIVEN`
- **The helper token** is built from these: `N`, `@E` or `none`.
- **`validate_duration_seconds` (`:707-711`)** bounds `^[1-9][0-9]{0,7}$` and ≤ MAX. Callers that accept open-ended sessions (the notifier `:3285`, the runner `:3352` and `:3388`, `caffeinate_start` `:3514`) take the end mode alongside it.
- **Parse bounds (`:271-289`).** Check digit length before `10#`. Today `18446744073709551617` wraps to 1.
- **Process-tied sessions.** They no longer default to MAX (`:4150-4151`). Without a time option they use `END_MODE=none`.

### 6.2 main flow

- **Process from the picker.** Set `bound_session` and `WATCH_PID` **after** `prompt_start_gui` (`:4472`), not only from `-w` or `--` before it. Then run the same checks as for `-w`: the PID exists and belongs to the user (`:4166-4176`).
  - Right after the picker returns, record the PID's start time with the shared `process_start_time`. The helper re-checks it at start and refuses with exit 9 if the process is gone. The CLI turns that into `rsync has already exited.`
- **Until.** It reaches the helper and the Caffeine worker as an epoch, so time spent in a password prompt doesn't make the session end late. Helper exit 10 becomes `The end time 18:30 has already passed.`
- **The extend path (`:4309-4370`)** follows the table in 4.7.
  - It checks the running session's `end_mode` before `prompt_add_time`, and before any helper call that could ask for a password.
  - The "session ended meanwhile" restart (`:4361`) carries the end mode.
- **Messages.**
  - `Starting awake until 18:30.`
  - `Starting awake until you stop it.`
  - `Starting awake until rsync (PID 4812) exits.` (process sessions still write to stderr)
  - Replace the `(at most <label>)` suffix at `:4572` and `:4609` when there is no limit.
- **Refusals** that the helper reports with exit codes 9, 10 and 11 are mapped to those texts instead of the generic "Failed to …".

### 6.3 Caffeine backend

- **Arguments.** The `--caffeinate-start` argument DURATION becomes the END token (`N`, `@E` or `none`), keeping the count at 9. `--caffeinate-runner` does the same, keeping 7.
  - Old running sessions keep their own command lines. The matchers check only the script path, the flag and the state file, so nothing else changes.
- **State file.** Gains `end_mode`, and writes `deadline_at` empty for `none`.
  - `write_state_file` (`:3686-3708`) accepts that.
  - `update_state_runtime_metadata` keeps the key.
  - `caffeinate_stop` (`:3642-3644`) doesn't fall back to 1200 for open-ended sessions.
- **Runner.**
  - With `none` it runs `caffeinate FLAGS -w $$`, with no `-t`.
  - With a deadline it runs `caffeinate FLAGS -w $$ -t REMAINING`, and its 1 s loop also compares the wall clock with `deadline_at`, ending the child at the deadline. `caffeinate -t` probably doesn't count time the Mac spends asleep (verify on a Mac), so a clock-time end could otherwise run late.
  - `-w $$` makes caffeinate exit if the runner is killed, so the assertion can't outlive it once there is no timeout.
  - A deadline that changes to empty with `end_mode=none` (after `--indefinite`) keeps the session running instead of ending it (`:3480-3487`).
- **Guardrail checks** follow 4.10: every 60 s, and every 20 s at 15 % or below.
- **Keep-alive for `/tmp`.** Every 6 hours the runner runs `/usr/bin/touch -c -h` on the `state` and `session` files. macOS's daily cleaner removes `/tmp` files that haven't been used for 3 days (verify on a Mac).

### 6.4 Status and JSON

- **Remaining time** is `deadline_at - now` from the state file (Caffeine) or the helper record (lid-closed). It is empty when there is no deadline.
  - `get_remaining_seconds_from_file` (`:1610-1634`) prefers `deadline_at` over `started_at + duration`.
  - The session file is written after `wait_for_session_start`, so the old calculation ran slightly late.
- **Telling "no end time" apart from leftovers.** Use the helper state (`running` against `stale`) and the end mode, not an empty remaining time.
  - `print_status` prints the "No Awake session is running…" line only for leftovers.
- **`--status-json`** stays `schema_version: 1`. The new fields are additive, as `keep_display` and `watch_*` were.
  - `end_mode`: `duration`, `until`, `none`, or `null`.
  - `deadline_at`: an integer or `null`.
  - `leftover_settings`: `true` only in the leftover case.
  - `remaining_seconds` and `duration_seconds` are `null` without a deadline.
  - `"error":null` stays last.

### 6.5 Completion notifier (`--notify-wait`, `:3273-3338`)

- It accepts the END token.
- It no longer rejects durations over MAX.
- It gives up at deadline + 2 h only when there is a deadline.
- Without a deadline it waits while the session runs:
  - lid-closed: until the helper token changes (existing);
  - Caffeine: until the state file's token is gone (new).

### 6.6 Clock times and formatting

- **Parsing.** Regexes in bash pick out H and M.
- **Choosing the day.** Today if HH:MM:00 today is strictly later than now; otherwise the next calendar day from `date -v+1d +%Y-%m-%d`.
- **Converting to an epoch.** `date -j -f '%Y-%m-%d %H:%M:%S' "$day $HH:$MM:00" +%s`. Always give the seconds, because BSD `date -j -f` takes unspecified fields from the current time. Never add 86,400.
- **Full dates.** `YYYY-MM-DD HH:MM` is parsed the same way.
- **DST.** A time skipped by DST is normalized by `mktime`. A repeated time uses the first occurrence.
- **A test seam for "now".** A `current_epoch` function wraps `/bin/date +%s` for the parser and status, so tests can mock the time.
- **Duration labels.**
  - `format_duration_label` and `format_remaining_duration` gain days (`1 day 6 hours`).
  - Mixed values read `1 hour 30 minutes`.
  - The app's `remainingText` does the same (`StatusDescription.swift:45-60`).

### 6.7 Settings in the CLI

- **One store for app and CLI.** The app's UserDefaults domain `net.kaenmaki.awake.statusbar` holds everything. The CLI reads it with `/usr/bin/defaults read net.kaenmaki.awake.statusbar KEY`. That goes through `cfprefsd`, so it sees the app's latest values; the plist file itself is never read.
- **Keys:**

  | Key | Written by | Value |
  |---|---|---|
  | `pickerDurations` | App | A string, for example `600 1200 1800 2400 3000 3600 7200 10800 14400 21600 28800 indefinite` |
  | `pickerDefault` | App | Seconds, `indefinite`, or `last` |
  | `pickerLastChoice` | CLI (`defaults write`) | Seconds or `indefinite`, after a choice at the picker or prompt |
  | `customLastSeconds`, `customLastUntil` (`HH:MM`) | CLI | The last Custom… values |

- **Validation.** Bash validates every value.
  - Tokens must be `^[1-9][0-9]{0,7}$` (≤ 365 days) or `indefinite`. Duplicates are dropped, the list is sorted, and it is cut to 15 entries.
  - A missing or bad value falls back to the built-in list and 20 minutes. A bad value never stops the picker.
- **What changes last-used.** Explicit options never change the last-used keys. `--prompt-gui-selection` does record the choice, because the app then starts with explicit options.
- **Where the default applies.** It applies to the GUI picker and the terminal prompt.
  - With `last`: the last choice if it is in the list, else 20 minutes if listed, else the first entry.
  - The terminal uses the last length even when it isn't in the list.
- **Tests and dry-run.** Dry-run never reads or writes the real domain. If `AWAKE_TEST_SETTINGS_FILE` is set (dry-run only), a `key=value` file replaces `defaults`; otherwise dry-run uses the built-ins.
- **CLI-only users** can set the keys with `defaults write`. The README gives the commands.
- **Uninstall.** The uninstaller already deletes the domain. It needs to wait for the app to quit first (9).

### 6.8 Other

- `wait_for_requested_stop_completion` (`:2242-2256`) must accept every reason that can land during a stop request: `low_battery`, `overheated` and `process_exited` today. Otherwise the stop waits 30 s and falls back.
- `--help` stays within 80 columns. The `--duration-seconds` line with `31536000` is 79 columns.

## 7. Picker helper (`tools/awake-gui-picker.swift`)

- **One file.** It stays a single, self-contained Swift file. The installer and CI compile it on its own, and the CLI can also run it from source with `/usr/bin/swift`.
- **Input.** The two positional arguments stay (lid `true|false`, display `on|off`). Flags follow them:
  - `--entry SECONDS|indefinite LABEL`, repeated (bash sends the labels, so bash owns the formatting)
  - `--default-index N`
  - `--custom-seconds N`
  - `--custom-until HH:MM`
  - An old picker ignores the extra arguments and answers with a label, which the CLI still maps with the old table.
- **Output.** `key=value` lines replace `label|backend|display`:
  - `result=start|cancelled`
  - `backend`
  - `display`
  - `end_mode=duration|until|none|process`
  - `duration_seconds`
  - `until_epoch`
  - `watch_pid`
  - `custom_seconds`, `custom_until`

  Bash validates every value. The CLI keeps accepting the 2- and 3-field forms from older pickers. A process name is never sent back; the CLI builds the label from the PID. That also avoids the `|` problem.
- **`--prompt-gui-selection` JSON** (used by the app's custom-password path) keeps its current fields.
  - `duration_seconds` stays an integer for length and until choices (for until, the seconds remaining), and is `null` otherwise.
  - It adds `start_arguments`: the resolved and validated options, such as `["--until","@1790000000"]`, `["--indefinite"]` or `["-w","4812"]`.
  - The app appends `start_arguments` and doesn't need to understand end modes.
- **AppleScript fallback** (`:2974-3052`).
  - It shows the configured list, plus "Indefinitely" and "Custom…". Custom… is a text field parsed by `parse_end_spec`.
  - It drops `empty selection allowed`.
  - It has no While option. The README says so instead of "functionally equivalent".

## 8. App changes

- **`AwakeStatus`** gains the optional fields `endMode`, `deadlineAt` and `leftoverSettings`, each as `var …: T? = nil`. A synthesized Decodable skips a `let` that has an initial value.
- **`AwakeStartSelection`.** `durationSeconds` becomes `Int?`, and `startArguments` is added as `[String]?`.
  - `CustomStartSelection` carries `startArguments`.
  - `performStart` and `startArguments(…)` append them after `--gui-custom --start`.
- **Leftover detection.** `maybeNotifyStuckStatus` (`StatusBarController.swift:327-338`) uses `leftoverSettings == true` instead of `remainingSeconds == nil`. Otherwise every session without an end time would be reported as stuck after 20 s.
- **`Add 1 hour`** (`:427-438`, `:157-189`) shows only when `deadlineAt != nil`.
- **`StatusDescription`** has the sentences in 4.8, days in `remainingText`, and a fixed `HH:mm` clock format. The countdown prefers `deadlineAt`.
- **Notifications** as in 4.9.
- **`PreferencesStore`** (`InstallSupport.swift:56-150`).
  - Defaults keep the existing keys: `soundEnabled`, `useCustomPasswordDialog`, `thermalGuardDisabled` and `minBatteryPercent` (default 5).
  - Current values live in memory, set from the defaults at launch.
  - `snapshot()` and every read site (menu states, `AwakeCLI.startArguments`, the Tink stop sound) use the current values.
  - All changes go through one StatusBarController method, which also clears the cached password whenever the current custom-dialog value ends up off.
  - Picker keys (6.7) are read and written only by the Settings window.
- **Menu.** Add `Settings…` with ⌘,.
- **`SettingsWindowController.swift`** is new.
  - It is built in code like `ReadmeWindowController`: created once, `isReleasedWhenClosed = false`, centered once, then `makeKeyAndOrderFront` and `NSApp.activate`.
  - It reuses `runMaintenance` for `Start without password`, and `LaunchAgentManager` for Launch at login.
  - `build-awake-app.sh` compiles every file in `Sources/*.swift`, so the new file needs no build change.
- **Minimal main menu.** `main.swift` sets one after the `--notify` branch, with Close ⌘W and an Edit menu (Undo, Cut, Copy, Paste, Select All), so the popover's field and ⌘W work. It has no ⌘Q/`terminate:` item. The accessory app never shows this menu.

## 9. Install, uninstall and compatibility

- **Installer.** No change is needed: it already stops the session, quits and relaunches the app, and runs `--install-helper`, which installs protocol 8 with one password prompt.
- **Uninstaller.**
  - Replace its single `osascript quit` (`scripts/uninstall-awake.sh:137-138`) with the installer's quit-wait-pkill step before `defaults delete`. Otherwise the running app can write the preferences back.
  - The self-test's stub-CLI order (`--gui --stop`, then `--gui --uninstall-helper`) must be kept or updated.
- **Running v7 sessions** keep working.
  - Their records have no `end_mode`, so they read as `duration`.
  - The new helper recognises their processes by path and token.
  - Adding time is refused with the existing exit 6 message ("started by an older version…").
- **Old and new copies.** Two Awake copies at protocol 7 and 8 reinstall each other's helper on every lid-closed start, as they do today. The CHANGELOG upgrade note says so.
- **Password-free mode.** The sudoers rule allows any helper arguments, so any program running as the user can start an indefinite session without a password. `README.md:80` must say this instead of "for up to 9 hours at a time".

## 10. Tests

### 10.1 New self-test checks (dry-run)

- **Helper.**
  - `start UID 31536000` is accepted; `31536001` and 20-digit values are rejected.
  - `start UID @<past>` exits 10.
  - `start UID none` stays on beyond 3 s and stops on request.
  - Kill -9 the timer of a `none` session: the guard neither times it out nor stops it, and it takes over after the dry-run heartbeat limit.
  - `extend` with `@E` and `none`; `extend` on a `none` session exits 11.
- **Parsing.**
  - `--duration`, `--until` and `--indefinite`, with conflicts and combinations.
  - The bounds 31536000 (accepted) and 31536001 (rejected).
  - A wrapped huge number is rejected.
- **Grammar table** with a mocked `current_epoch`:
  - `18:30` at 17:00 gives today; at 19:00, or at exactly 18:30, it gives tomorrow.
  - `12am` and `12pm`.
  - `24:00`, `13pm`, `1.5h` and `1230` are rejected.
  - Spaces, uppercase, words, and `i`.
- **Lifecycles, both backends:**
  - `--indefinite` (still on after 3 s, then `--stop`).
  - `--until @now+4`, which ends with `timeout`.
  - `-w PID` without a limit ends with `process_exited` and shows `until sleep (PID n) exits`.
  - Adding time to an indefinite session prints the "already runs until you stop it" message and makes no helper call.
  - `--until` on a running length session moves the end.
  - `--indefinite` on a running session removes it.
- **Status and JSON.** Every row of 4.8, including the days format. The JSON fields `end_mode`, `deadline_at` and `leftover_settings`, and the leftover case still reading `Awake is on with no end time.`
- **Picker.**
  - Parsing of the `key=value` answer, including malformed and old 2- and 3-field answers.
  - A process choice sets `WATCH_PID` and runs the ownership check.
  - `print_prompt_start_gui_selection_json` with `start_arguments` for each end mode.
- **Settings.** Through `AWAKE_TEST_SETTINGS_FILE`:
  - built-ins when the file is missing;
  - garbage, duplicates, more than 15 entries, and out-of-range values;
  - `last` with and without a last choice;
  - last-used is written for picker and prompt choices, but not for explicit options.
- **Low battery at 5 %.** Update `:1729`, where lid-closed ends at 10 %, to 5 %, and `:1870-1871`, where Caffeine ends at 8 %, to 4 %.
- **`--help`** stays within 80 columns (`:2056`).

### 10.2 Existing tests that change

- **Status table.** `:450-451` and `:1963` (`with at most 9 hours left`) become the new process sentences.
- **Maximum message.** `:1236-1242` gets the "365 days" wording.
- **Prompt texts.** `:977` and `:981` get the new wording.
- **Picker fixtures.** `:996-1006` and `:1331-1363` gain the new answer format, and keep the old-format cases.
- **Helper command shapes.** `:1093`, `:1221`, `:1249`, `:1827-1829` and `:1953-1954` get the END token.
- **`reset_main_flags` (`:1043-1057`)** also resets the new globals, plus `WATCH_PID`, `RUN_COMMAND` and `MIN_BATTERY_PERCENT`.
- **`cleanup_state`** removes the new mock and test files.

### 10.3 macOS QA checklist

1. (P0) With the lid closed on battery, does clearing `SleepDisabled` make the Mac sleep? This decides the `sleepnow` step in 4.10 and 5.
2. (P0) Does `caffeinate -t` count time the Mac spends asleep? Does `/tmp` lose files after 3 days?
3. (P1) Indefinite lid-closed session: `pmset -g` shows `SleepDisabled 1` for its whole length. `--stop` restores it. `kill -9` of the timer: the guard takes over and the guardrails still work.
4. (P1) An Until session that spans system sleep ends within seconds of waking.
5. (P1) Caffeine indefinite: after `kill -9` of the runner, the caffeinate assertion is gone within seconds (`pmset -g assertions`).
6. (P1) Low battery at 5 % (use `--min-battery 50` to trigger it): the session ends and the Mac sleeps with the lid closed.
7. (P2) Picker:
   - 1 and 15 entries without clipping;
   - three buttons side by side on macOS 11 and later;
   - double-click starts;
   - keyboard-only use;
   - Custom… For, Until (today/tomorrow hint, 12- and 24-hour systems) and While (apps, terminal commands, shells excluded, a process that exits before Start);
   - Back keeps the state;
   - VoiceOver.
8. (P2) Custom-password mode with each end mode, including a password dialog left open past the Until time.
9. (P3) Settings:
   - add, remove, Include Indefinitely, Restore Defaults, and Last used;
   - a menu toggle compared with the default after relaunch;
   - Launch at login and Start without password in both places;
   - `defaults write` from Terminal is picked up by the next picker.
10. (P3) Add 1 hour appears and disappears correctly for each end mode.
11. (all) Installing over a running 2.0.0 app with an active session, and the helper updating to protocol 8 with one password prompt.

## 11. Docs, changelog and release

- **README format.** README.md must use only headings, single-line `- ` bullets, column-0 fences and inline code, because the About window renders nothing else. No tables. The grammar, options and status texts go in bullet lists.
- **README passages to update:**
  - `:3`, `:24` and `:38`: "a chosen duration".
  - `:34`: Caffeine without `-t`.
  - `:41`, `:59`, `:216` and `:285`: 5 %.
  - `:63` and `:206`: status examples.
  - `:74`: helper arguments.
  - `:80`: password-free.
  - `:197` and `:322`: the fallback.
  - `:203`, `:207-217`: the menu, Settings…, and current versus default.
  - `:208`, `:229`, `:278` and `:286-288`: the 9-hour texts.
  - `:297-322`: Terminal Input and GUI Input.
  - Examples: until, indefinite, `--duration 2h30m`, and the settings keys for CLI-only use.
  - Runtime Files: `end_mode` and `heartbeat`.
  - `:456-467`: self-test coverage.
- **CHANGELOG `## [Unreleased]`,** in the same commits as the features.
  - **Added:** until, indefinite and custom sessions; process sessions from the picker; the configurable picker list and default; the Settings window.
  - **Changed:** the 365-day bound, process sessions without a time limit by default, the 5 % default, and "(helper protocol version 8)".
  - **Upgrade notes:** run the installer again, or let the next lid-closed start update the helper.
  - Don't mark anything `**Breaking**` and don't add `### Removed`, which would make `tools/release.sh` suggest a major version.
- **Release.** `tools/release.sh minor` produces 2.1.0 and updates `bin/awake`, README, the three plists and CHANGELOG. The helper protocol constants are changed by hand in the feature commits.

## 12. Phases

Every phase ends with the self-test green on CI and its QA items done.

- **Phase 0: facts.** QA items 1 and 2 on a Mac. Their answers decide the `sleepnow` step and the runner's wall-clock check.
- **Phase 1: engine.**
  - Helper protocol 8 (section 5).
  - CLI end condition, options, extend rules, Caffeine runner and notifier (6.1–6.5, 6.8).
  - Formatting and clock times (6.6).
  - The terminal prompt (4.6).
  - The 5 % default (4.10).
  - Also, so the app shipped with it doesn't flag sessions without an end time as stuck: the app's status fields, leftover detection, `Add 1 hour` visibility and status sentences (the first four bullets of section 8).
- **Phase 2: picker.**
  - Settings keys in the CLI (6.7).
  - Picker v2 with Custom… and While (4.1, 4.2 and 7).
  - The add-time list (4.3) and the fallback.
  - `--prompt-gui-selection` with `start_arguments`, and the app's decoding.
- **Phase 3: app.** Current and default values in `PreferencesStore`, the Settings window, the `Settings…` menu item, the main menu, notifications (4.9), and the uninstaller's quit-and-wait.
- **Phase 4: release.** README sweep, CHANGELOG, `tools/release.sh minor`, and the full QA checklist.

## 13. Risks and open points

- **Sessions that only you can end.** An indefinite lid-closed session with `--min-battery off` and `--thermal-guard off` ends only on stop, a restart, or the watched process exiting. That is intended, but the Safety Warnings should say so.
- **The 5 % margin.** It depends on the Mac actually sleeping after the guard ends the session (phase 0) and on battery readings, which are imprecise near empty on worn batteries.
- **Scope of the 5 % default.** It now covers Caffeine too (decision 4 note). Keeping Caffeine at 10 % would need a per-mode setting.
- **Password-free mode.** It now also allows indefinite sessions without a password (9).
