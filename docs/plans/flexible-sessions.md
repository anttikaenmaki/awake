# Plan: flexible session lengths for Awake

> **Outdated draft.** This version was written against Awake 1.0.0. Awake 2.0.0 (merged since) already fixes several items below (for example the `SleepDisabled` read, the `launchctl submit` start, and process-tied sessions from the terminal), and it moves lid-closed sessions into a root-owned helper. The plan is being rewritten against 2.0.0; don't implement from this version.

- Status: proposed, not yet implemented
- Target version: 1.1.0
- Written: 2026-09-27
- Scope: `bin/awake`, `tools/awake-gui-picker.swift`, `app/AwakeStatusApp`, `scripts/`, `tests/cli/awake-self-test`, `README.md`

## How this plan was checked

The first draft was reviewed against the code by six independent reviewers, each looking from one angle: code accuracy, safety and privileges, macOS platform facts, UX, app integration, and completeness with tests. An adversarial verifier then checked each reviewer's findings, and a final critic looked for gaps and contradictions. This version includes the findings that held up.

The review ran on Linux, so claims about macOS behavior come from source code and documentation, not from running them. Every such claim is marked **verify on a Mac**, and all of them are collected in the macOS QA checklist (section 11.3).

The review also found three problems that already exist and that this plan depends on (section 3). The most important one: the failsafe that should restore sleep settings never does so on a real Mac.

## 1. Goals

1. Remove the 9-hour limit on session length.
2. "Until a clock time" sessions from the GUI and the terminal.
3. Indefinite sessions from the GUI and the terminal.
4. Custom-length sessions from the GUI and the terminal.
5. Sessions tied to a process from the GUI, and as managed Awake sessions from the terminal. Today the only option is plain `caffeinate -w` or `caffeinate COMMAND`.
6. Configure which durations the GUI picker shows, and choose the default.
7. Keep the picker as simple as it is today.

Not in scope: changing or extending a running session, scheduled sessions, automatic triggers.

## 2. Decisions

| # | Question | Decision |
|---|---|---|
| 1 | Menu toggles or Settings window | Both. The menu keeps its toggles, and the Settings window shows them too. Settings holds the **default**. The menu changes the **current** value until Awake.app quits. |
| 2 | Upper bound for timed sessions | 365 days (31,536,000 s). This catches typos and overflow; it is not a policy limit. Indefinite sessions have no bound. |
| 3 | Indefinite at the terminal prompt | `i` |
| 4 | Low-battery protection | Stop lid-closed (`Awake` backend) sessions at 5 % battery so the Mac can sleep instead of shutting down. |

What decision 1 means for each control:

- **Sound on** and **Use custom password dialog.**
  - The existing UserDefaults keys (`soundEnabled`, `useCustomPasswordDialog`) become the defaults, so no migration is needed.
  - At launch, the current value is set from the default.
  - A menu toggle changes only the current value. It resets when Awake.app quits.
  - Changing a default in Settings also sets the current value.
- **Launch at login** has only one real value: the LaunchAgent either exists or it doesn't. Both controls change it directly.
- **The picker's lid-closed checkbox** follows the same rule: Settings sets its default, and the checkbox is the choice for this one start.

## 3. Problems that already exist (fix first)

These are in the current code. The new features rely on them, so they come first, in phase 0.

### 3.1 The "sleep disabled" setting is never read (blocker)

- **Where it's read today.** `get_battery_setting disablesleep` (`bin/awake:1320`) looks for a `disablesleep` key in the `Battery Power:` section of `pmset -g custom` and in `Currently in use:` of `pmset -g` (`:1289-1307`).
- **Where pmset actually prints it.** `pmset` prints the flag only as `SleepDisabled`, under `System-wide power settings:` in `pmset -g`. The setting is system-wide, not per power source.
- **What happens instead.** The lookup fails and falls back to 0 (`get_default_battery_setting`).
- **Consequences on a real Mac:**
  - `keep_awake_is_enabled` (`:1608`) is never true.
  - `failsafe_restore` takes its "already restored" shortcut (`:3775`, `:3794`). It writes `stopped` and exits **without restoring**.
  - main's "awake-like settings without a session" recovery (`:4016`) never runs.
  - `original_disablesleep` is always recorded as 0.
- **Why the tests miss it.** In dry-run the mock pmset file does contain `disablesleep`.

Fix:

- Add `get_sleep_disabled`. It reads `SleepDisabled` from the `System-wide power settings:` block of `pmset -g`.
  - A missing line or a missing block means 0. pmset prints the block only when a system-wide setting exists.
  - The read fails only when `pmset -g` itself fails.
- Use it for every read of disablesleep: in main, root_start, root_stop and the failsafe. `sleep` is still read from the Battery Power profile.
- Once any trigger fires and the control-state token still matches, the failsafe always calls `restore_settings_with_fallback`. Restoring is idempotent, so the shortcut goes.
- Pair this with section 5.10. Once the flag is read correctly, pmset values alone must no longer count as an Awake session. Otherwise settings made by another tool or by hand (`sleep 0` with `SleepDisabled 1`) would be treated as Awake's and "restored" to the defaults.
- Documentation: `README.md:59` and the terminal warning say the settings apply on battery only. That is true for `sleep` but not for `SleepDisabled`, so a lid-closed session also keeps the Mac awake on AC power. Fix both texts.
- Verify on a Mac:
  - During a session, `pmset -g | grep SleepDisabled` shows 1.
  - After `sudo kill -9 <worker>`, both values come back within grace + a few seconds.

### 3.2 GUI sessions start as a `launchctl submit` job (major, verify on a Mac)

- **How GUI sessions start today.** Without the custom password dialog, a GUI start runs root_start through `launchctl submit` (`build_launchctl_submit_command`, `:2115`; `run_gui_privileged_background_command`, `:2150`).
- **What launchd does with such a job.**
  - `launchctl submit` asks launchd to keep the job alive. Old launchctl sources set `OnDemand=false`. The man page says "in the event of failure".
  - launchd also kills the job's process group when the job's main process exits.
- **Consequences.**
  - When a session ends, launchd may start `--root-start` again with the same arguments. The label is removed only by root_stop (`:3650`), not by root_start's normal cleanup.
  - A killed worker takes its failsafe down with it.

Fix:

- Stop using a launchd job for `--root-start`.
  - Preferred: inside `do shell script … with administrator privileges`, run `/usr/bin/nohup /usr/bin/env … /bin/bash SCRIPT --root-start … </dev/null >/dev/null 2>&1 &`. This is the background pattern from Apple's TN2065.
  - Fallback, if that proves unreliable: bootstrap a generated root-owned plist with `KeepAlive=false` and `AbandonProcessGroup=true`, and `bootout` it in the worker's final cleanup.
- Keep a one-time `launchctl remove` of the old label for upgrades.
- Verify on a Mac:
  1. After a GUI session ends, `sudo launchctl print system/net.kaenmaki.awake.<uid>.root-start` finds no job, and no new session starts within 30 s.
  2. After `sudo kill -9 <worker>`, the failsafe survives and restores.

### 3.3 Root can adopt and write through a prepared control-state folder (major)

- **What root does today.** `ensure_control_state_dir_for_state_file` (`:479`) chowns an existing `/tmp/keep-awake-lid-closed-control-<uid>` to root, whoever created it. `write_control_state_file` then writes with `>` to `…/state` before anything checks for a symlink.
- **Why that's dangerous.** Another local user can prepare that folder with a `state` symlink, and root will then overwrite the symlink's target.

Fix:

- Root never adopts a folder it didn't create.
  - If the folder exists and is not a real directory owned by the expected owner with mode 700, root_start refuses with a clear reason. The expected owner comes from `control_state_expected_owner_uid_from_path`: root normally, the user in dry-run.
  - Otherwise root creates it with `mkdir -m 700`.
- The control-state file is written through `mktemp` inside the verified folder and then `mv -f`, as `write_status_file` already does.
- root_start validates SLEEP and DISABLESLEEP from argv with `^[0-9]{1,4}$` before writing them.

### 3.4 Long sessions and the `/tmp` cleaner (new with this plan)

macOS's daily periodic job deletes files in `/tmp` that haven't been accessed for 3 days. Before, the 9-hour cap made that irrelevant. With 365-day and indefinite sessions, the state, session and control-state files could disappear mid-session. The waiter's keep-alive in section 6.4 handles this.

## 4. Current code that shapes the design

- **The cap.**
  - `MAX_DURATION_SECONDS=32400` (`:62`).
  - `validate_duration_seconds` (`:830`) enforces it in `write_state_file`, `write_control_state_file`, `root_start`, `caffeinate_start`, `start_caffeinate_runner`, `caffeinate_runner` and `wait_for_gui_completion`.
  - `validate_deadline_timestamp` (`:1594`) applies it again for the failsafe.
  - `parse_cli_args` rejects larger values (`:201`).
- **"Skip the prompt" is tied to one variable.** `DURATION_OVERRIDE_SECONDS` decides at `:246` (conflict with `--stop`/`--status`), `:3961` (`--terminal` without a TTY), `:4172` and `:4213` (skip the prompt or picker).
- **Sessions are countdowns.**
  - The lid-closed worker waits on `/bin/sleep "$duration_seconds"` (`:3598`).
  - The caffeine runner runs `caffeinate -i -t N` (`:3065`).
  - `/bin/sleep` doesn't advance while the Mac sleeps, but status and the failsafe use wall-clock `date +%s`.
  - `sleep_until_epoch` (`:1569`) already does a wall-clock wait but is unused. `sync_state_timing` (`:2786`) is unused and can be deleted.
- **The failsafe is time-based** (`failsafe_restore`, `:3709`): deadline + 30 s, or a stop request. It doesn't notice a dead worker earlier, and see 3.1.
- **Arguments after `--`.**
  - The top-level prescan (`:42-52`) scans all arguments, including those after `--`.
  - `parse_cli_args` rejects anything after `--` (`:215`).
- **The picker list is hardcoded twice.** Once in `tools/awake-gui-picker.swift:80`, once in the AppleScript fallback (`:2615`).
  - Bash maps labels back to seconds with a fixed `case` in `set_duration_from_gui_label` (`:1248`).
  - The helper prints `label|backend` (`:163`).
  - Its list shows 11 rows of 30 px in 292 px with the scroller hidden (`:122-130`), so the last rows need blind scrolling.
- **Terminal input** accepts at most two digits (`read_terminal_response_line`, `:1092`).
- **Status reads the session file first** (main, `:4028`: `get_session_remaining_seconds || get_state_remaining_seconds`). The remaining time comes from `started_at + duration_seconds`.
- **`update_state_runtime_metadata` (`:3387`)** rewrites the state file from a fixed list of keys, so any new key would be lost.
- **The app.**
  - In custom-password mode it asks for a selection with `--prompt-gui-selection`, decoding it into `AwakeStartSelection` with a non-optional `duration_seconds` (`AwakeCLI.swift:100`). It then starts with `--duration-seconds N --backend X` (`:251`).
  - Otherwise it runs `awake --gui`, and the CLI shows the picker.
- **Polling.**
  - The stop-request monitor (`:2408`) forks subshells, `dirname`, `stat` and `/bin/kill` every 0.2 s for the whole session.
  - `--notify-wait` (`:2970`) forks `/bin/sleep` every 0.2 s.
  - The failsafe polls every second.
- **The in-app About window** renders only headings, `- ` bullets, fenced code and inline code (`ReadmeWindowController.swift`, from about `:143`). README changes must not use tables.

## 5. User-facing design

### 5.1 Picker, step 1

The window stays the same except for one row and one button:

```
┌ Awake ────────────────────────────────────┐
│ WARNING: Keeping the lid closed …         │
│ Choose the duration.                      │
│ ┌───────────────────────────────────────┐ │
│ │ 10 minutes                            │ │
│ │ 20 minutes                       ◀sel │ │
│ │ …                                     │ │
│ │ 8 hours                               │ │
│ │ Indefinitely                          │ │
│ └───────────────────────────────────────┘ │
│ ☑ Keep laptop awake with lid closed       │
│             [Custom…]  [Cancel]  [Start]  │
└───────────────────────────────────────────┘
```

- **The list** holds only the configured entries. "Indefinitely" is on by default and can be removed in Settings. There are no separator or special rows.
- **Custom…** is the alert's third button (NSAlert returns `.alertThirdButtonReturn` for it). It opens step 2. Return still means Start and Esc still means Cancel.
- **Double-clicking** a row means Start.
- **List height** is min(rows, 12) × 30 px, and never so tall that the alert overflows the screen's visible frame. The scroller appears only when the list is capped, and the selected row is scrolled into view.
- **The preselected row** is the configured default (section 8). "Last used" picks the matching row, or falls back as described in section 8.
- **The checkbox** starts in the state set in Settings.
- **Keyboard:** after `alert.layout()`, `alert.window.initialFirstResponder` is the table.

### 5.2 Picker, step 2 (Custom…)

```
┌ Awake ────────────────────────────────────────┐
│ Keep the Mac awake:                           │
│ ◉ For    [ 1 ]⇅ h  [ 30 ]⇅ min                │
│ ○ Until  [ 18:30 ]⇅   today, in 2 h 5 min     │
│ ○ While  [ Safari                ▾] runs      │
│ ☑ Keep laptop awake with lid closed           │
│                [Back]  [Cancel]  [Start]      │
└───────────────────────────────────────────────┘
```

- **Shown as a second modal** after step 1 closes. **Back** returns to step 1 with its state kept.
- **The lid checkbox** is the same one as in step 1 (shared state), so it stays visible.
- **Editing a control selects its radio button.**
- **For:** digit-only hour (0–8760) and minute (0–59) fields with steppers. A total of zero disables Start.
- **Until:** an `NSDatePicker` with hours and minutes, following the system's 12/24-hour setting.
  - The hint next to it shows the day and length, for example `today, in 2 h 5 min` or `tomorrow, in 23 h 30 min`. It is recomputed on every change.
  - The time is turned into an epoch only when Start is pressed, using `Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: h, minute: m, second: 0), matchingPolicy: .nextTimePreservingSmallerComponents, repeatedTimePolicy: .first)`.
- **While:** a pop-up that is rebuilt each time it opens. It has two groups:
  - **Apps:** running apps with `activationPolicy == .regular`, with icons, excluding Awake.
  - **Terminal commands:** the user's own processes that have a terminal.
    - Source: `ps -x -o pid=,tty=,ucomm=`, keeping rows whose tty isn't `??`.
    - Excluded: the helper's own PID and its ancestors; shells, matched on the name with any leading `-` removed (`bash`, `zsh`, `sh`, `fish`, `tcsh`, `csh`, `ksh`, `dash`); and `login` and `ps`.
    - Shown as `rsync (PID 4812)`.
  - While nothing is chosen, Start is disabled.
  - At Start, the helper checks that the PID still exists. If it doesn't, the dialog stays open with the note `rsync has exited.`
- **Remembered values:**
  - For: hours and minutes.
  - Until: the clock time as HH:MM, never an epoch.
  - While: never remembered; it always starts with nothing selected.
- **First-run values:** For 1 h 0 min; Until the next full hour.
- **Accessibility:**
  - Labels: `Hours`, `Minutes`, `Until time`, `Process to wait for`.
  - The date picker's accessibility value includes the today/tomorrow hint.
  - The first responder is the first enabled field.

### 5.3 Menu

The current items plus one:

```
Awake is on until 18:30 (2 hours 5 minutes left).
──────────
About / Instructions…
Settings…                    ⌘,
──────────
Launch at login
Use custom password dialog
Sound on
──────────
Quit                         ⌘Q
```

The toggles change the current value only (decision 1). Launch at login changes the one real value.

### 5.4 Settings window

```
┌ Awake Settings ─────────────────────────────┐
│ General                                     │
│   ☑ Launch at login                         │
│                                             │
│ Defaults when Awake starts                  │
│   ☐ Sound on                                │
│   ☐ Use custom password dialog              │
│   The menu can change these until Awake     │
│   quits.                                    │
│                                             │
│ Picker                                      │
│   ┌──────────────────────────┐              │
│   │ 10 minutes               │              │
│   │ …                        │              │
│   │ 8 hours                  │              │
│   └──────────────────────────┘              │
│   [+] [−]              [Restore Defaults]   │
│   ☑ Include Indefinitely                    │
│   Default selection  [20 minutes       ▾]   │
│   ☑ Keep laptop awake with lid closed       │
│     (checked by default)                    │
└─────────────────────────────────────────────┘
```

- **Labels** match the menu exactly.
- **Adding and removing entries.**
  - `+` opens a popover: `[ 90 ] [minutes ▾] [Add]`. The field accepts digits only and has a stepper; the unit is minutes, hours or days; Return adds; the maximum is 365 days.
  - The list sorts itself, removes duplicates, and holds 1–15 entries.
  - `−` removes the selected row and is disabled when only one entry is left.
- **Include Indefinitely** controls the `indefinite` entry, which is always shown last.
- **Default selection** offers every entry, "Indefinitely" if included, and "Last used".
  - If the default's entry is removed, or Indefinitely is unchecked while it is the default, the default becomes the first remaining entry.
- **Restore Defaults** resets only the Picker group.
- **Changes apply immediately.** Settings goes through the CLI (section 8.2), re-reads its values each time it is shown, and refreshes when a menu toggle changes.
- **Launch at login** is re-read whenever the window becomes key. If `LaunchAgentManager.setEnabled` throws, the checkbox reverts.

### 5.5 Terminal prompt

| Input | Meaning |
|---|---|
| Enter | The default from Settings (20 minutes out of the box) |
| `1`–`9` | Hours (unchanged) |
| `01`–`99` | Minutes (unchanged) |
| `2h30m`, `90m`, `1d`, `2h 30m`, `2 hours` | A custom length |
| `18:30`, `18.30`, `6:30pm`, `7am` | Until the next time the clock shows that time |
| `i` | Indefinitely |
| Esc, `q`, Ctrl+C | Cancel (unchanged) |

Rules:

- **One shared parser.** A single function, `parse_end_spec`, serves the prompt, `--duration`, `--until` and the AppleScript fallback's Custom… field. The bare-number rules and `i` apply only at the prompt.
- **Letters and spaces.** Input is case-insensitive, and spaces between parts are ignored.
- **Length units.** `d`, `h`, `m`, and also written out (`day`, `days`, `hour`, `hours`, `hr`, `min`, `minute`, `minutes`). `s` is accepted only by `--duration`.
- **Clock forms.**
  - `H:MM` / `HH:MM` and `H.MM` / `HH.MM`, from 0:00 to 23:59, with exactly two digits after the separator.
  - `H[:MM]am|pm` with H from 1 to 12. `12am` is 00:00 and `12pm` is 12:00.
  - Without am/pm, the 24-hour clock applies.
- **Rejected, with a short hint:** `24:00`, `13pm`, `1.5` or `1.5h` (use `1h30m`), and 3 or more bare digits (`1230` could mean 12:30 or 1,230 minutes).
- **How a clock time resolves.** Today at HH:MM:00 if that is strictly later than now, otherwise the next calendar day at HH:MM:00 (see section 6.15).
- **Upper bound.** Results over 365 days are rejected.
- **The start line** shows how the input was understood. It is printed before any password prompt, for example:
  - `Starting awake until tomorrow 07:00 (8 hours 12 minutes).`
  - `Starting awake until you stop it.`
  - `Starting awake for 7 hours.`

  Length sessions keep today's wording.

Reader changes (`read_terminal_response_line`, `:1092`):

- Accepts `[0-9A-Za-z:. ]`, echoes letters in lowercase, and takes up to 20 characters.
- `q` as the first key cancels immediately, as today.
- After Esc it reads any bytes that arrive within 0.1 s. An escape sequence, such as an arrow key, is discarded. A lone Esc cancels.

The instruction lines in the warning block (`:2580-2582`) and the "Terminal duration input" block in `show_usage` become:

```
- Press Enter for the default (20 minutes)
- Type 1-9 for hours, 01-99 for minutes, or a length like 2h30m or 1d
- Type a clock time like 18:30 or 6:30pm to stay awake until then
- Type i to stay awake until you stop it
- Press Esc, q, or Ctrl+C to cancel
```

- The prompt shows the effective default in brackets, for example `[20 minutes]` or `[until you stop it]`.
- Invalid input prints `Not understood. Examples: 2 (hours), 45 (minutes), 2h30m, 18:30, i.`
- The terminal always uses the lid-closed backend unless `--backend caffeinate` is given. The picker's checkbox default doesn't apply to it.

### 5.6 Command-line options

| Option | Meaning |
|---|---|
| `--duration-seconds N` | Unchanged, up to 365 days |
| `--duration SPEC` | `90m`, `2h30m`, `1d`, `45s` (a unit is required) |
| `--until TIME` | `18:30`, `6:30pm`, `2026-09-28 07:00`, or `@EPOCH` (used by the app) |
| `--indefinite` | No end time |
| `--while-pid PID[:START]` | Ends when that process exits. `START` is the process start time as an epoch; if given and it doesn't match, the start is refused. |
| `-- COMMAND [ARGS…]` | Runs the command in the foreground; the session lasts as long as it runs |

Rules:

- **Combining options.**
  - At most one of `--duration-seconds`, `--duration`, `--until` and `--indefinite`.
  - `--while-pid` or `--` may be combined with `--duration` or `--until`, which then act as an upper limit. They can't be combined with `--indefinite` or with each other.
- **Skipping the prompt.** Any of these options sets `END_CONDITION_GIVEN`, which replaces `DURATION_OVERRIDE_SECONDS` at `:246`, `:3961`, `:4172` and `:4213`. So every end-condition option skips the prompt or picker, works with `--terminal` without a TTY, and conflicts with `--stop`, `--status` and `--status-json`.
- **When a session is already active.**
  - Plain `awake`, `--duration-seconds`, `--duration`, `--until` and `--indefinite` stop it, as today.
  - `--while-pid` never stops a session. It prints `Awake is already on (…). Stop it first with 'awake --stop'.` and exits 1 before any password prompt.
  - `awake -- COMMAND` does the same, but exits 125 and does not run the command.
- **`awake -- COMMAND` specifics** are in section 6.13.

### 5.7 Status texts

| Session | Text |
|---|---|
| Length | `Awake is on (2 hours 5 minutes left).` (unchanged) |
| Until | `Awake is on until 18:30 (2 hours 5 minutes left).`, or `until tomorrow 07:00`, or `until 2026-10-02 07:00` |
| Indefinite | `Awake is on until you stop it.` |
| Process | `Awake is on while rsync is running.` |
| Process with a limit | `Awake is on while rsync is running (at most 2 hours left).` |
| Leftover settings (5.10) | `Awake's sleep settings are still active from an interrupted session.` |

Caffeine sessions add "lid must stay open" as they do today, for example `Awake is on until you stop it (lid must stay open).`

### 5.8 Notification texts

Start notifications:

| Session | Text |
|---|---|
| Length | Unchanged |
| Until | `The Mac will stay awake until 18:30.` |
| Indefinite | `The Mac will stay awake until you stop it.` |
| Process | `The Mac will stay awake while rsync is running.` |

End notifications:

| Reason | Text |
|---|---|
| `process_exited` (lid closed) | `rsync finished. Normal sleep settings were restored.` |
| `process_exited` (caffeine) | `rsync finished. Awake stopped.` |
| `low_battery` | `Battery at 5%. Awake stopped and restored normal sleep settings.` |
| `interrupted` | `Awake stopped unexpectedly. Normal sleep settings were restored.` (posted as a failure) |

Start refusals:

| Reason | Text |
|---|---|
| `low_battery_refused` | `Battery is at 4%. Plug in, or keep the lid open (uncheck 'Keep laptop awake with lid closed').` |
| `end_time_passed` | `The end time 18:30 has already passed.` |
| `process_gone` | `rsync has already exited.` |

The CLI's own `notify_completion_from_status_file` gets a default `*)` branch that posts "<Backend> stopped". The app's Caffeine failure text (`StatusBarController.swift:207`) drops the word "timed".

### 5.9 Low-battery stop (lid-closed only)

- **Constant.** `LOW_BATTERY_STOP_PERCENT=5`.
- **What counts as low.** The `-InternalBattery` line of `pmset -g batt` shows 5 % or less, and a state other than `charging`, `charged` or `finishing charge`.
  - So `discharging` and `AC attached; not charging` both count, whatever the first line says.
  - With no InternalBattery line (a desktop Mac, or only a UPS), the check does nothing.
  - Output that can't be parsed means "unknown". It is logged once and never counts as low.
- **At start.**
  - The CLI checks in user context after the picker or prompt and before any password prompt. `--prompt-gui-selection` checks too, so the app never asks for a password first.
  - root_start checks again as a backstop and refuses with reason `low_battery_refused`.
- **During a session.**
  - The waiter checks every 60 s. When the battery is low, the session ends with reason `low_battery`.
  - The worker restores `sleep` from the saved value, but forces `SleepDisabled` to 0 even if the recorded original was 1. While `SleepDisabled` is 1, macOS refuses every sleep request, including its own critical-battery sleep (verify on a Mac). The worker logs that it did this.
  - It confirms with `get_sleep_disabled` that the value now reads 0.
  - It then applies the lid-closed end rule (6.7), so the Mac sleeps.
- **Order of steps.** Restore, write the status file, remove state and control state, notify, and put the Mac to sleep last. `sleep_result=ok|failed|skipped` goes into the status file and the log.
- **Why 5 % is enough.** Laptops normally use `hibernatemode 3`, which also writes memory to disk, so sleeping at 5 % leaves room before macOS would shut down. This is typical but not guaranteed, so the plan doesn't depend on it.
- **Caffeine (lid-open) sessions** aren't affected. `caffeinate -i` doesn't block macOS's own low-battery sleep.

### 5.10 Leftover settings after a restart

`SleepDisabled` is stored in the power-management preferences and survives a restart; the files in `/tmp` do not (verify on a Mac). After a crash, forced restart or OS update during an indefinite lid-closed session, closing the lid would no longer put the Mac to sleep.

- **Backup file.**
  - Before launching root for an `Awake`-backend start, the CLI writes a user-owned backup: `<settings dir>/sleep-settings-backup`, holding `session_token`, `sleep`, `sleep_disabled` and `started_at`.
  - User-context runs of `awake` (not `--status`) delete it once no session is live and `SleepDisabled` reads 0, or after they stop a session themselves. Root never touches the user's home folder.
- **Leftover detection.** A backup file, plus no live session, plus `SleepDisabled` = 1.
  - Status reports this as active with the text in 5.7. `--status-json` adds `leftover_settings: true`.
  - A toggle or `--stop` restores the backed-up values; this needs an administrator password, as there is no root process left.
  - The app posts one notification when it first sees leftover settings: `Awake's sleep settings are still active from an interrupted session. Click the menu bar icon to restore them.`
- **Without a backup file**, `sleep 0` with `SleepDisabled 1` is not an Awake session.
  - Status says `Awake is off.` and adds `(Sleep is currently disabled by another setting.)`. JSON adds `sleep_disabled_externally: true`.
  - A new session saves the current values as its originals.
- **Security.** Values from the backup file pass through the same `^[0-9]{1,4}$` checks as any root argument.
- **Dry-run** uses `$STATE_DIR/sleep-settings-backup`, unless `AWAKE_SETTINGS_DIR` is set.

## 6. Engine changes (`bin/awake`)

### 6.1 Parsing

- The top-level prescan (`:42-52`) stops at the first `--`.
- The `--)` branch of `parse_cli_args` (`:215`) stores the rest in `WRAPPED_COMMAND=("$@")` and stops parsing. An empty command is an error.
- The wrapped command's own options (`--dry-run`, `--debug`, `--no-notifications`, `--stop` …) never reach awake.
- `END_CONDITION_GIVEN` plus the parsed end mode, deadline and watch replace `DURATION_OVERRIDE_SECONDS` (section 5.6).

### 6.2 End-condition model and internal signatures

Two tokens replace the numeric duration argument of the internal subcommands:

- **`DEADLINE`:** `+SECONDS` (length), `@EPOCH` (until), or `none`.
- **`WATCH`:** `PID:START_EPOCH`, or `none`.

| End mode | DEADLINE | WATCH |
|---|---|---|
| duration | `+N` | `none` |
| until | `@E` | `none` |
| indefinite | `none` | `none` |
| process | `none`, or a limit | `PID:START` |

The CLI generates the session token and passes it in, so refusals can be matched to the start that caused them (6.3). The new signatures:

- `--root-start STATE TOKEN SLEEP DISABLESLEEP DEADLINE WATCH MODE SOUND`
- `--caffeinate-start STATE TOKEN DEADLINE WATCH MODE SOUND`
- `--caffeinate-runner STATE DEADLINE WATCH WORKER_PID`
- `--failsafe-restore STATE DEADLINE_AT TOKEN WORKER_PID`
- `--notify-status STATUS_FILE` **stays unchanged**, because old workers call the new script with it when their session ends.

Root argument validation, done before any arithmetic and always with `10#`:

| Argument | Pattern |
|---|---|
| TOKEN | `^[0-9]{9,11}-[0-9]{1,7}-[0-9]{1,5}$` (the shape `build_session_token` produces) |
| SLEEP, DISABLESLEEP | `^[0-9]{1,4}$` |
| DEADLINE | `none`, `^\+[1-9][0-9]{0,8}$` or `^@[1-9][0-9]{9,10}$` |
| WATCH | `none` or `^[1-9][0-9]{0,6}:[1-9][0-9]{9,10}$` |

Also update main's argument-count checks for each internal subcommand, and the self-test's fake command lines.

### 6.3 Refusals at start

- **When refusals happen.** Every refusal happens before the state and control-state files are written and before any pmset change.
- **What they write.** A status file with the CLI's token and one reason from a fixed set:
  - `low_battery_refused`
  - `end_time_passed`: the `@E` deadline is not in the future, for example because the password dialog took too long. There is no rollover to the next day.
  - `process_gone`: the watched PID is gone, or its start time differs.
  - `unsafe_control_dir` (see 3.3)
  - `already_started`: a status file already carries this token.
- **How main learns about them.** `wait_for_session_start` (`:2518`) matches the token. On a refusal reason it returns 3 at the next poll, instead of waiting 30 s and printing the generic failure.
- **What the user sees.** main prints the text from 5.8 to stderr and exits 1, or 125 for `awake -- COMMAND`.
- **The app** shows that text, because it posts stderr as the failure message.
- **`caffeinate_start`** uses the same path.

### 6.4 The waiter

`/bin/sleep N` (`:3598`) and the runner's `-t` countdown are replaced by one waiter loop. In the lid-closed backend it is a subshell of root_start, and its PID stays in `sleep_pid`. In the caffeine backend the runner itself runs the loop (6.5). Each tick does the following:

- **Deadline.** Waits on wall-clock time (`date +%s`), not a monotonic sleep, so "until 18:30" holds even if the Mac slept in between. It reuses the chunking logic of `sleep_until_epoch`.
- **Watched process.** Every 2 s it runs `TZ=UTC0 LC_ALL=C ps -o lstart=,stat= -p PID` (6.14).
  - The process counts as gone only after **two consecutive** checks find it missing, a zombie (`stat` starting with `Z`), or with a different start time.
  - It never uses `kill -0`, which fails with EPERM for other users' processes, such as a `sudo` job.
- **Battery.** Every 60 s, lid-closed backend only (5.9).
- **Worker liveness.** Each tick it reads its real parent with `/bin/ps -o ppid= -p "$BASHPID"`, and exits when that is no longer the worker's PID. It never uses `$PPID`, which bash sets once and never updates. It also exits when the session token no longer matches: the control state for the lid-closed backend, the state file for caffeine.
- **Keep-alive for `/tmp`.** Once at start and every 6 hours, it runs `/usr/bin/touch -c -h` on the state, session and control-state files. `-c` never creates a file, and `-h` never follows a symlink.
- **Tick length.** min(2 s when watching a process, 30 s, the time left to the deadline).
- **Exit status.**

  | Status | Meaning |
  |---|---|
  | 0 | `timeout` |
  | 80 | `process_exited` |
  | 81 | `low_battery` |
  | anything else, or a signal | `failed`, as today |

  root_start (around `:3616`) and caffeinate_start (around `:3188`) check for 80 and 81 before the existing `-ne 0` check. The existing tests that expect a nonzero status to become `failed` stay valid.
- **Stopping it.** `terminate_recorded_session_processes` terminates `sleep_pid` for both backends. The lid-closed waiter is recognized by `session_pid_matches`, because a subshell keeps root_start's command line.
- **Logging.** Only changes are logged (battery source or percentage, the watched process lost), never every poll.

### 6.5 Caffeine backend

- **The runner is the waiter.**
  - `--caffeinate-runner` runs the loop above and holds `caffeinate -i -w $$` as its child, adding `-t <remaining + 60>` when there is a deadline.
  - Because caffeinate watches the runner, the power assertion can't outlive a killed runner.
- **Knowing when the worker is gone.** The runner receives `WORKER_PID`.
- **`sleep_pid` still names the runner**, so `caffeinate_runner_pid_matches`, `state_session_is_active` and `terminate_recorded_session_processes` keep working.
- **In dry-run**, the runner runs the same loop without a caffeinate child.

### 6.6 Failsafe

`--failsafe-restore STATE DEADLINE_AT TOKEN WORKER_PID`. While the worker is alive, the worker owns the process-exit and battery conditions. If the failsafe acted on them itself, its SIGTERM would turn those reasons into `stopped`. So the failsafe has only three triggers:

1. **A stop request.** Checked every second. The reason is `stopped`.
2. **A finite deadline plus the grace period** (`FAILSAFE_GRACE_SECONDS=30`). The reason is `timeout`.
3. **The worker gone for at least the grace period** while the control-state token still matches. Checked every 10 s with `session_pid_matches`, using the root-owned control-state values, never the user-owned state file.
   - It then terminates the recorded `sleep_pid` and restores the settings.
   - It then checks the battery. If it is low and the lid is closed, it records `low_battery` and puts the Mac to sleep. Otherwise it records `interrupted`.

After restoring, the failsafe applies the lid-closed end rule (6.7).

`validate_deadline_timestamp` accepts 0 (no deadline) or a value no later than now + 365 days + grace + 300 s. The failsafe must not be killable together with the worker (3.2).

### 6.7 Lid-closed end rule

When a lid-closed session ends without the user asking, the process that restored the settings checks the lid after the restore succeeds. Unattended ends are `timeout`, `process_exited`, `interrupted` and `low_battery`.

- **The check.** `ioreg -r -k AppleClamshellState -d 1` shows both `"AppleClamshellState" = Yes` and `"AppleClamshellCausesSleep" = Yes`.
- **When it passes,** the process runs `pmset sleepnow`, logs the exit status, and records `sleep_result`.
- **Why this is needed.** macOS evaluates clamshell sleep on lid, power-source and boot events, so clearing `SleepDisabled` alone may leave the Mac awake with the lid shut (verify on a Mac). `pmset sleepnow` does what closing the lid would have done.
- **Why the second key.** Requiring `AppleClamshellCausesSleep` leaves closed-display mode with an external display alone.
- **Why user stops are excluded.** `stopped` and `cancelled` are left out on purpose, so a user who runs `awake --stop` over SSH isn't cut off.

### 6.8 Cap

- **The constant.** `MAX_DURATION_SECONDS=32400` becomes `MAX_TIMED_SESSION_SECONDS=31536000`. It applies to `--duration-seconds`, `--duration`, `--until`, the prompt and the picker.
- **Validation of open-ended sessions.** Call sites of `validate_duration_seconds` that store or wait on a session accept open-ended sessions (duration 0 with end mode `indefinite` or `process`). A timed session still needs 1 to 31,536,000 seconds.
- **Help text.** `show_usage` (`:116`) is updated together with the constant.

### 6.9 State, session and status files

- **State and control-state files** gain `end_mode`, `watch_pid` and `watch_started_at`.
  - `deadline_at` is 0 when there is no deadline, and `duration_seconds` is 0 for open-ended sessions.
  - New keys are appended as trailing optional parameters of the writers, so existing positional calls keep working.
  - Writers fill in `deadline_at` themselves only when `end_mode` is missing.
- **`update_state_runtime_metadata` (`:3387`)** replaces only the `pid`, `sleep_pid` and `guard_pid` lines and keeps every other key.
- **The session file** (`write_session_file`, `:1799`; user-owned) also stores `end_mode`, `deadline_at`, `watch_pid` and `watch_label`. The label never passes through root.
- **`write_status_file` (`:3421`, 13 callers)** gains `end_mode`. root_stop, caffeinate_stop and the failsafe take it from the control-state or state file.
- **Where status gets its values.** Status reads `end_mode` and `deadline_at` from the state file, which root writes. The session file supplies `watch_label`, and is the fallback for old sessions that have no state `end_mode`.
- **Remaining time** is `deadline_at - now`, and is empty (not 0) when there is no deadline. Files without `end_mode` (sessions from 1.0.0) are treated as length sessions; their `deadline_at` is already present.

### 6.10 Status output and JSON

- **`build_status_text` and `print_status`** take the end mode, deadline and label, and produce the texts in 5.7.
- **`--status-json`** moves to `schema_version: 2`. The change is additive.
  - New fields: `end_mode`, `deadline_at`, `watch_pid`, `watch_label`, `leftover_settings`, `sleep_disabled_externally`, `battery_percent`.
  - `remaining_seconds` and `duration_seconds` are `null` for sessions with no deadline.

### 6.11 Completion reasons and the notifier

- **New end reasons:** `process_exited`, `interrupted`, `low_battery`.
- **New refusal reasons:** `low_battery_refused`, `end_time_passed`, `process_gone`, `unsafe_control_dir`, `already_started`.
- **Where they're handled.** Each new reason is handled in `wait_for_requested_stop_completion` (`:2436`) and in `notify_completion_from_status_file` (`:2837`), in the same phase that first writes it.
- **The notifier (`--notify-wait`, `:2970`).**
  - It polls once a second.
  - It exits after 3 consecutive checks with no active session, even if no status file appeared.
  - Only sessions with a deadline keep an upper bound on its waiting time.
  - It reads `watch_label` from the session file before `notify_completion_from_status_file` removes it.

### 6.12 Polling

- **Stop-request monitor and failsafe.** They validate their paths once at start, then loop with the builtin `kill -0` on their own children and `[[ -f ]]`, once a second. The token is compared only when the stop-request file exists.
- **Notifier.** It checks the status file every second and the session token every 30 s.

### 6.13 `awake -- COMMAND`

1. **Find the command.** Use `type -P`, or `-x` for a path containing `/`.
   - Not found: exit 127.
   - Found but not executable: exit 126.
   - Builtins, functions and aliases are not accepted, because `exec` can't run them.
2. **Refuse when a session is already active** (5.6): exit 125.
3. **Choose the UI mode.** Terminal authentication whenever `/dev/tty` can be opened, even if stdin or stdout is redirected, so `awake -- make > log` still asks in the terminal. Without a TTY, it falls back to the GUI prompt as today. `--gui` and `--terminal` override.
4. **Choose the backend.** Lid-closed, unless `--backend` is given. The picker and prompt are never shown.
5. **Print to stderr.** In `--` mode, all of awake's own messages go to stderr, so the command's stdout stays clean.
6. **Check the battery** in user context (5.9).
7. **Start a session that watches `$$`** with its own start time, and a label taken from the resolved command path. The label is never taken from `ps`, which would say `bash` at this point.
8. **Detach every background helper.** This covers the root or caffeine worker and the notifier.
   - Each gets its own process group (for example `set -m` in a subshell around the launch) and `</dev/null >/dev/null 2>&1`.
   - This way the command doesn't inherit them as children, and Ctrl+C or Ctrl+Z in the command only reach the command.
   - As a second guard, the internal subcommands start with `trap '' TSTP TTIN TTOU`.
9. **Wait until the session is ready.** A refusal or failure exits 125 and doesn't run the command.
10. **Do main's normal post-start steps.** Write the session file, remove the stale status file, start the notifier, and play the optional start sound.
11. **Release the main lock explicitly.** The EXIT trap doesn't run on `exec`.
12. **Unset the `AWAKE_*` variables** that main exported.
13. **`exec "${WRAPPED_COMMAND[@]}"`.**

`exec` keeps the PID and start time, so the watch follows exactly the command, and its exit status passes straight through. If the session ends first (stop, low battery, time limit), the command keeps running.

### 6.14 PID identity and labels

- **Start time.**
  - One shared function reads `TZ=UTC0 LC_ALL=C /bin/ps -o lstart= -p PID`, trims it, and converts it with `TZ=UTC0 LC_ALL=C /bin/date -j -f "%a %b %d %T %Y" "$s" +%s`. Pinning UTC makes the result independent of the time zone and DST.
  - It is used by the CLI, the waiter, the runner and the failsafe, and has 1-second resolution.
  - For a picker result, bash reads the start time as soon as the picker returns. The picker doesn't send one.
- **PIDs.** PIDs of 1 or less, or that don't exist, are rejected.
- **Labels,** computed by the CLI in user context:
  - If `ps -o comm= -p PID` contains `/X.app/Contents/MacOS/`, the label is `X`. Otherwise it is the basename of `comm` without a leading `-`.
  - `lsappinfo` is optional and never required.
  - For `--`, the label is the basename of the resolved command.
- **Cleaning up a label.**
  - Delete bytes 0x00–0x1F and 0x7F, replace `=` and `|` with spaces, and drop invalid UTF-8 (`iconv -f UTF-8 -t UTF-8 -c`).
  - Truncate to 64 characters, not bytes: in bash under a UTF-8 locale, and in Swift for picker labels.
  - An empty result becomes `PID <n>`.

### 6.15 Clock times and formatting

- **Parsing.** Regexes in bash pick out H and M.
- **Resolving to a date.**
  - First decide the calendar day: today if HH:MM:00 today is strictly later than now, otherwise `date -v+1d +%Y-%m-%d`.
  - Then run `date -j -f '%Y-%m-%d %H:%M:%S' "$day $HH:$MM:00" +%s`.
  - Always include the seconds, because BSD `date -j -f` takes unspecified fields from the current time.
  - Never add 86,400 seconds to get the next day.
- **DST.** A time skipped by DST resolves as `mktime` normalizes it. A time that occurs twice uses the first occurrence.
- **Full dates.** `YYYY-MM-DD HH:MM` is parsed the same way, with `:00` appended.
- **"Now" is mockable.** `current_epoch` is a function that tests can replace.
- **Time zone.** "Until" is resolved to an absolute moment at start, so a time-zone change mid-session doesn't move it.
- **Duration labels.** `format_duration_label` prints mixed values as `1 hour 30 minutes`, and days above 24 hours (`1 day 6 hours`). `format_remaining_duration` also gets days. Clock times use `%H:%M`.

### 6.16 Platform probes and dry-run mocks

All platform probes go through four functions:

- `read_battery_state`: parses `pmset -g batt` text.
- `lid_state`: closed or open, and whether closing causes sleep.
- `request_system_sleep`
- `get_sleep_disabled`

In dry-run they never call pmset or ioreg:

| Probe | Dry-run source | When the file is missing |
|---|---|---|
| Battery | `$STATE_DIR/mock-battery`, raw `pmset -g batt` text, so the real parser runs | AC power, 100 % |
| Lid | `$STATE_DIR/mock-lid` (`closed=Yes\|No`, `causes_sleep=Yes\|No`) | Open |
| Sleep request | Appends a line to `$STATE_DIR/mock-sleepnow` | — |
| SleepDisabled | The mock pmset file, as today | — |

Dry-run-only test knobs, which are ignored outside dry-run and never forwarded to root:

- `AWAKE_TEST_GRACE_SECONDS` (the 30 s grace)
- `AWAKE_TEST_LIVENESS_SECONDS` (the 10 s liveness check)
- `AWAKE_TEST_BATTERY_POLL_SECONDS` (the 60 s battery check)

## 7. Picker helper interface

- **One file.** The helper stays a single self-contained Swift file. The installer compiles it on its own, and `prompt_start_gui_native_helper` falls back to running it from source with `/usr/bin/swift`.
- **Input.** The helper never reads the settings file. Bash passes it arguments:
  - the entries as seconds or `indefinite`, with their labels;
  - the index of the default entry;
  - the checkbox default;
  - the remembered Custom… values.
- **Output.** `key=value` lines replace `label|backend`, and bash validates every value. The keys are:
  - `result=start|cancelled`
  - `backend`
  - `end_mode`
  - `duration_seconds`
  - `until_epoch`
  - `watch_pid`
  - the Custom… values to remember

  The hardcoded label table in `set_duration_from_gui_label` goes away.
- **`--prompt-gui-selection`** returns `schema_version: 2`:

  ```json
  {"schema_version":2,"session_backend":"awake","keep_lid_closed":true,
   "start_arguments":["--until","@1790000000"],"duration_seconds":8100}
  ```

  - `start_arguments` holds the end-condition options that bash has already resolved and validated: `["--duration-seconds","5400"]`, `["--until","@E"]`, `["--indefinite"]` or `["--while-pid","4812:1790001234"]`.
  - `duration_seconds` stays an integer for length and until choices (for until it holds the seconds remaining), and is `null` otherwise.
  - It records last-used (8.1) and applies the low-battery refusal before returning.
- **AppleScript fallback.** It shows the configured list plus "Custom…". Its Custom… is a text field parsed by `parse_end_spec`. It has no process option; the README says so instead of calling the fallback "functionally equivalent".

## 8. Settings files

The folder is `${AWAKE_SETTINGS_DIR:-$HOME/Library/Application Support/Awake}`. The app always uses the default path.

### 8.1 Files

`settings`, the user's choices, written only through the CLI:

```
# picker_durations: seconds, plus "indefinite"
picker_durations=600 1200 1800 2400 3000 3600 7200 10800 14400 21600 28800 indefinite
# picker_default: seconds | indefinite | last
picker_default=1200
keep_lid_closed_default=true
```

`last-used`, written by the CLI:

- **When it changes.** After a picker choice (including through `--prompt-gui-selection`, because the app then starts with explicit options) or a prompt answer.
- **What it holds.** The last length or `indefinite`, plus the Custom… step's last values.
- **What never changes it.** Until and While choices, and explicit command-line options.
- **In dry-run** it is written only when `AWAKE_SETTINGS_DIR` is set.

`sleep-settings-backup` is described in 5.10.

Rules:

- **Comments** are allowed only on whole lines starting with `#`.
- **Bad values never block anything.**
  - Invalid values, entries outside 1 s–365 days, duplicates and unsorted lists are normalized.
  - More than 15 entries: the list is cut to 15.
  - An empty or unreadable file gives the built-in defaults.
- **The effective default.**
  - If `picker_default=last`, it is the last-used entry when that is listed; otherwise 20 minutes when that is listed; otherwise the first entry.
  - A `picker_default` that isn't listed also falls back to the first entry.
  - The terminal uses the same default. With `last`, it uses the last length even when that isn't in the list.
- **Precedence for the backend.** `--backend` beats `keep_lid_closed_default`, which beats the built-in default. `keep_lid_closed_default` affects only the GUI picker.
- **Writing.** A temp file with permissions 0600 in the same folder, then a rename. The folder gets mode 700 when the CLI creates it.
- **Why plain files and not UserDefaults.** Bash and CLI-only users must be able to read and edit them without the app. Hand-editing a UserDefaults plist is unreliable because `cfprefsd` caches it.

### 8.2 One parser, owned by bash

Bash is the only reader, writer and duration formatter for these files. Two internal commands serve the app:

- **`awake --settings-json`** prints the normalized settings: the entries with their `format_duration_label` labels, the default, the effective default, and the lid default.
- **`awake --settings-set KEY VALUE`** validates, normalizes and writes atomically, then prints the new `--settings-json`.

The Settings window calls these off the main thread and shows what comes back. "Add" sends seconds only, so Swift never parses duration text.

## 9. App changes (Swift)

- **`AwakeStartSelection`** decodes `durationSeconds` as `Int?` and `startArguments` as `[String]`.
  - `CustomStartSelection` becomes `(startArguments, backend)`.
  - `AwakeCLI.startArguments` appends `startArguments` after the GUI-mode flag.
  - Swift has no end-condition enum; bash owns that logic.
- **`AwakeStatus`** gets the new optional fields, declared as `var …: T? = nil`. A synthesized Decodable skips a `let` that has an initial value.
- **`PreferencesStore`.**
  - The existing UserDefaults keys hold the defaults (`defaultSoundEnabled`, `defaultUseCustomPasswordDialog`).
  - In-memory `soundEnabled` and `useCustomPasswordDialog` are set from them at launch.
  - The menu toggles (`StatusBarController.swift:305`, `:313`) change only the in-memory values; Settings changes both.
  - `snapshot()` and the sound reads (`:136`, `:212`) use the in-memory values.
  - Every change goes through one StatusBarController method, which also clears the cached password whenever the custom dialog ends up off. Today only the menu path does this (`:306-308`).
  - Launch at login is always read from `LaunchAgentManager.isEnabled()` and set through one `setLaunchAtLogin(_:)`.
- **`SettingsWindowController.swift`** is new.
  - It is built in code like `ReadmeWindowController`: created once, `isReleasedWhenClosed = false`, centered once, `makeKeyAndOrderFront`, then `NSApp.activate`.
  - It re-reads everything each time it is shown and talks to the CLI (8.2).
- **Minimal main menu.** `main.swift` sets one (an accessory app never shows it) with Close ⌘W and an Edit menu (Undo, Cut, Copy, Paste, Select All), so fields and ⌘W work in the Settings window. It has no ⌘Q/`terminate:` item.
- **`showContextMenu` (`:235`)** gets "Settings…" with ⌘,.
- **Notifications** (texts in 5.8).
  - Stop notifications take their details (`end_mode`, `watch_label`, `deadline_at`) from the last active status: `previousStatus` in `maybeNotifyCompletionTransition`, and `outcome.before` in `handleCommandResult`. The inactive status comes from a status file that root wrote, which has no label.
  - `interrupted` goes through `postFailure`.
  - Start notifications use the new status fields.
  - The first status showing `leftover_settings` posts the notification from 5.10, once per app launch.

## 10. Installer, uninstaller, upgrade and compatibility

- **Quitting the app safely.** `install-awake.sh` and `uninstall-awake.sh` share a `quit_running_app` step:
  1. If `pgrep -x -U "$(id -u)" AwakeStatusBar` finds the app, send `quit` by bundle id inside `with timeout of 5 seconds`.
  2. Wait up to 10 s for the process to exit.
  3. If it hasn't, send `kill -TERM` and wait again.

  Neither path runs the menu's stop-then-quit (the app has no `applicationShouldTerminate`), so sessions keep running.
- **Installer.**
  - It quits the app before replacing the bundle, so an old app can't keep running with a new CLI and a new `--prompt-gui-selection`.
  - Afterwards it runs `open -gj` if the app was running, or if `--no-launch` wasn't given. A fresh install still launches the app.
  - It keeps installing the CLI with `install(1)`, which creates a new file, so running bash workers keep their old code. Never `cp` over the CLI.
- **Uninstaller.**
  - It uses the same quit step instead of its unbounded quit (`uninstall-awake.sh:111`).
  - After the app has exited, it runs `defaults delete net.kaenmaki.awake.statusbar`.
  - It restores leftover settings if a `sleep-settings-backup` exists, before removing the folder (`:121`).
- **Sessions started by 1.0.0.**
  - Their files have no `end_mode` and count as length sessions.
  - Process matching still finds their workers.
  - The stop-request and control-state formats only gain keys.
  - `--notify-status` is unchanged.
  - Their old 3-argument failsafe command line is still matched by `failsafe_pid_matches`.
- **Status JSON** changes are additive.

## 11. Tests

### 11.1 Self-test additions (dry-run)

- **Setup.** The self-test exports `AWAKE_SETTINGS_DIR` as a `mktemp` folder, removed in cleanup. It adds the mock battery, lid and sleepnow files to its constants and to `cleanup_state`.
- **Parsing.**
  - A sourced check: `parse_cli_args -- cmd --debug --dry-run --stop` leaves `DEBUG_LOG_ENABLED` and `STOP_ONLY` unchanged and yields `WRAPPED_COMMAND=(cmd --debug --dry-run --stop)`. Sourcing with the same arguments leaves the prescan's flags at their defaults.
  - Conflicts and combinations from 5.6.
  - Bounds: 31,536,000 is accepted and 31,536,001 rejected; `--until` more than 365 days ahead is rejected; `--duration 0m` is rejected; `validate_deadline_timestamp 0` is accepted.
- **Grammar table,** with a mocked `current_epoch`:
  - `18:30` at 17:00 gives today; at 19:00 gives tomorrow; equal to now gives tomorrow.
  - `12am` and `12pm`.
  - `24:00`, `25:00`, `13pm`, `1.5h` and `1230` are rejected.
  - Spaces, uppercase, written-out units, and `i`.
- **Lifecycles, for both backends:**
  - `--indefinite`
  - `--until @now+3` (sessions that must be seen as on last at least 4 s)
  - `--while-pid` against a background `sleep 3`, ending in `process_exited`
- **`awake -- COMMAND`:**
  - `run_awake --terminal -- /bin/sh -c 'exit 3'` exits 3; status then shows off with `last_completion_reason=process_exited`.
  - `run_awake --terminal -- /bin/echo --debug` prints `--debug` and creates no debug log.
  - `-- /nonexistent` exits 127.
  - With a session active, `-- /usr/bin/touch $marker` exits 125 and the marker file isn't created.
  - `--status` during `-- /bin/sleep 3` shows `while sleep is running`.
- **`--while-pid $$` while a session is active** returns 1, and the session stays active.
- **Failsafe,** run with the test knobs at 3/1/1:
  - kill -9 of the worker: the mock pmset is restored, the reason is `interrupted`, and the waiter is gone.
  - SIGSTOP the worker and waiter with the mock battery at 4 % on battery: the reason is `low_battery` and mock-sleepnow gets exactly one line.
  - A sourced check that the production values apply when `DRY_RUN=false`.
- **Low battery.**
  - Refused at 5 % when discharging and when "AC attached; not charging".
  - Allowed on AC while charging or charged, allowed for caffeine at 5 %, and never low without a battery.
  - mock-sleepnow is written only when the lid is closed and closing causes sleep.
  - Parser tests over captured `pmset -g batt` text: AC charged, AC not charging, battery discharging, no battery, a UPS.
- **pmset parsing.** Captured `pmset -g` text with `SleepDisabled 1`, with `SleepDisabled 0`, and without the system-wide block, which must read as 0.
- **Refusals.** A status file with the matching token and `low_battery_refused` makes `wait_for_session_start` return 3 within one poll, and the message names the battery level.
- **PID identity.** Mocked start-time function; a single-digit day (`Sep  7`); a reused PID; a zombie; the two-check rule.
- **Labels.** A multi-byte label crossing the 64-character cut gives valid UTF-8 and JSON that parses.
- **Status and JSON v2** for every row of 5.7, including nulls, and for an old session file without `end_mode`.
- **State files.** New keys survive `update_state_runtime_metadata`.
- **Settings.**
  - A missing file gives the built-in defaults.
  - Garbage, out-of-range values, more than 15 entries, duplicates and unsorted lists are normalized.
  - `last` with and without a last-used file.
  - last-used is written for picker, prompt and `--prompt-gui-selection` choices, but not for explicit options.
  - `--settings-set` round trips.
- **Picker output.** Parsing of the helper's `key=value` output, including malformed input. `print_prompt_start_gui_selection_json` for each end mode.
- **Leftover settings.** A backup file with no live session and mock `SleepDisabled=1`: status shows the leftover text, JSON has `leftover_settings: true`, and `--stop` restores the backed-up values. Without the backup, status is off with the note, and `awake --dry-run` starts.
- **No stray processes.** After each lifecycle test, `pgrep -f "$DRY_RUN_STATE_DIR"` finds nothing once the grace period has passed.
- **Upgrade block.** Tag the current commit `v1.0.0`. In a git checkout, the self-test writes `git show v1.0.0:bin/awake` to a temporary copy, and skips with a message otherwise.
  - It starts dry-run sessions with the old copy: lid-closed, caffeine and gui-custom.
  - With the new script it checks: `--status` shows a positive remaining time; JSON has `end_mode=duration`; `--stop` restores through the managed path; and starting while the old session is active stops it.

### 11.2 Existing tests to update

- **Positional writers** (`write_control_state_file` at self-test `:525`; `write_state_file` at `:540` and `:688`): unchanged, because the new keys are trailing optional parameters.
- **Direct calls** to `caffeinate_start` (`:750`) and `root_start` (`:797`), and their mocks, including `start_root_failsafe_restore`: new arguments. They must still return nonzero and record `failed`.
- **Fake command lines** (`:257-287`, `:681`, `:1135`): new internal signatures, plus 1.0.0-shaped lines for the upgrade case.
- **Prompt and invalid-input texts** (`:943`, `:947`) and the default (`:951`): new texts, read through the test settings folder.
- **Helper fallback output** (`:963-966`): becomes `key=value` lines.

### 11.3 macOS QA checklist

Each item is tagged with the phase that needs it.

1. **(P0)** `SleepDisabled` reads correctly. `sudo kill -9 <worker>` → both values restored.
2. **(P0)** No launchd job remains after a GUI session ends (timeout, stop, kill -9), and pmset stays restored for 60 s.
3. **(P0)** A prepared `/tmp/keep-awake-lid-closed-control-<uid>` owned by another user is refused.
4. **(P1)** Caffeine: `pmset -g assertions` shows the caffeinate assertion. After `kill -9` of the runner it is gone within seconds.
5. **(P2)** A lid-closed indefinite session shows `sleep 0` and `SleepDisabled 1`, and stop brings back the saved values.
6. **(P2)** An Until session that spans system sleep ends within 30 s of waking, with reason `timeout`.
7. **(P2)** Low battery (with the constant raised in a local copy):
   - settings are restored and the Mac sleeps with the lid closed;
   - the notification appears after wake;
   - `ioreg` lid detection works on the target models;
   - clearing SleepDisabled with the lid closed does or doesn't sleep on its own (confirms 6.7).
8. **(P2)** Restart during an indefinite session → leftover notification → one click restores the original values.
9. **(P3)** `awake -- cmd`:
   - Ctrl+C ends the command and the session;
   - Ctrl+Z and `fg` don't freeze the session (`awake --status` in another terminal still counts down);
   - `awake -- vim` stays fully usable;
   - the exit status passes through;
   - the sudo prompt comes before the command's output;
   - `awake -- make > log` asks in the terminal.
10. **(P3)** A process session ending with the lid closed on battery → the Mac sleeps. Closed-display mode on AC with an external display → the Mac stays awake.
11. **(P4)** Picker:
    - 1 and 15 entries without clipping; three buttons side by side on macOS 11 and later;
    - double-click starts;
    - keyboard-only use;
    - Custom… For, Until (today/tomorrow hint, 12- and 24-hour systems) and While (apps, terminal commands, shells excluded, a process that exits before Start);
    - Back keeps the state;
    - VoiceOver.
12. **(P4)** Custom-password mode with each end mode, including a password dialog left open past the Until time.
13. **(P5)** Settings:
    - add, remove, Include Indefinitely, Restore Defaults, Last used;
    - a menu toggle compared with the default after a relaunch;
    - Launch at login in both places;
    - hand edits to the file are picked up.
14. **(P5)** Notifications for every reason, with the app running and with it quit.
15. **(P4)** Installing over a running old app and an active 1.0.0 session.
16. **(all)** `swiftc -typecheck` for the app and the picker.

## 12. Documentation

- **README rules.** README.md uses only headings, `- ` bullets, fenced code and inline code, because the About window renders nothing else. The prompt grammar, options and status texts are written as bullet lists, not tables.
- **Change the docs in the same phase as the code:**
  - `show_usage` (`:98-137`) and the Options and Terminal Input sections change with each new option, with examples for `--until`, `--indefinite`, `--while-pid` and `awake -- cmd`.
  - Phase 0: the failsafe description (`README.md:47`, `:48`, `:59`), the AC-power statement (3.1), and the recovery behaviour (5.10).
  - Phase 2: Safety Warnings (indefinite sessions, low-battery stop).
  - Phases 4 and 5:
    - GUI Input (`:234-245`: the fixed list and 9-hour cap become the configurable list, Custom… and Indefinitely);
    - Menu Bar App (the Settings window; menu toggles last until Awake quits; defaults are set in Settings);
    - Runtime Files (settings, last-used, sleep-settings-backup, the list of reasons at `:333`);
    - the fallback note at `:139`.
- **Version.** Bump `bin/awake:4` and `:58`, `README.md:19` and `Info.plist` `CFBundleShortVersionString` together, and increment `CFBundleVersion`.

## 13. Phases

Every phase ends with the self-test green and its QA items done. Each new reason is handled by the CLI's stop waiter and notifier in the phase that first writes it. The app already shows a generic text for unknown reasons, so its own texts can wait until phase 5.

- **Phase 0: fix what exists.**
  - Read `SleepDisabled` correctly; the failsafe always restores (3.1).
  - One-shot privileged start instead of `launchctl submit` (3.2).
  - Control-state hardening (3.3).
  - Documentation fixes for these.
- **Phase 1: engine refactor.**
  - End-condition parsing (`END_CONDITION_GIVEN`, the prescan stopping at `--`).
  - Internal signatures with the CLI's token, root argument validation, and refusals.
  - The wall-clock waiter with liveness and `/tmp` keep-alive.
  - The caffeine runner with `caffeinate -w`.
  - Failsafe worker-liveness (`interrupted`).
  - File key handling (6.9), polling (6.12), dry-run probes and knobs, and deleting `sync_state_timing`.
  - No new user options. The upgrade test is an exit criterion.
- **Phase 2: terminal features and safety.**
  - The 365-day bound, `--duration`, `--until`, `--indefinite`, and the prompt grammar and reader.
  - Status texts and JSON v2.
  - The low-battery stop, the lid-closed end rule, and leftover-settings detection.

  These ship together, so indefinite sessions never reach users without the low-battery stop and the restart backstop.
- **Phase 3: process sessions from the terminal.** `--while-pid`, `awake -- COMMAND`, and `process_exited`.
- **Phase 4: settings files and picker v2.**
  - `settings`, `last-used`, `--settings-json` and `--settings-set`.
  - The helper interface, the Custom… button and step 2, the Indefinitely row, and the fallback picker.
  - `--prompt-gui-selection` v2, together with the app's `AwakeStartSelection` v2 decoding.
  - The installer's quit/relaunch.

  This is the first phase that changes the contract between the app and the CLI.
- **Phase 5: app.** The Settings window, PreferencesStore defaults and current values, the menu item, the main menu, notification texts, and the leftover notification.
- **Phase 6: release.** README sweep, version 1.1.0, and the full QA checklist.

## 14. Risks and open points

- **Heat.** Indefinite lid-closed sessions can run hot. Mitigations: the warning, the low-battery stop, the worker-liveness failsafe, the lid-closed end rule, and leftover-settings detection.
- **Platform behavior not yet confirmed on a Mac:**
  - `launchctl submit` relaunching jobs (3.2);
  - `SleepDisabled` surviving a restart and blocking critical-battery sleep (5.9, 5.10);
  - whether clamshell sleep is evaluated after clearing `SleepDisabled` (6.7);
  - the combined `caffeinate -w`/`-t` behavior (6.5).

  Each has a QA item, and the design works even if the answer is the less convenient one.
- **Sleeping at the end is new.** The lid-closed end rule puts the Mac to sleep when an unattended session ends with the lid closed. Before, it stayed awake until idle sleep, or longer if an app held an assertion. This is intended, and the README should say so.
- **Battery readings.** Percentages near empty are imprecise on worn batteries. The 60 s check interval allows about one extra minute of drain.
