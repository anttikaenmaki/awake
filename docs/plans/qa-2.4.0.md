# QA for 2.4.0: one Mac session before the release

- Status: reviewed draft, not run yet. The owner follows it top to bottom on the Mac, then releases 2.4.0 (12). The quick pass below is the minimum before the release.
- Written: 2026-10-04, against `dev` at `29e53db` ("Menu bar: the app plays the start sound itself"). Every expected result was checked against the code at that commit, README.md and CHANGELOG.md `[Unreleased]`.
- Covers: all the Mac QA still open before 2.4.0, and the release steps. For this session it replaces:
  - plan-2.3.0.md phase 3: its 6 (the macOS QA checklist), the QA of the addenda 11, 12, 13, 14, 16 and 17, and 15 (QA carried over from the 2.1.0 and 2.2.0 plans);
  - plan-2.4.0.md 6 (notifications off by default, `--notifications`);
  - faster-start-stop.md 7 (timing on the Mac, before and after the update) and 8 (items 1 to 40 with 8a, 11a, 12a and 25a).
  The plans keep their own lists as the reference. The appendix maps every item of those lists to an item here.
- How to record results: tick the box when the expected result holds. For a failure, write the item number and what happened in "Results" at the end. Every fix goes into 2.4.0, with a `### Fixed` entry in CHANGELOG.md (12.1). After a fix, reinstall from `dev` (2.1, step 6), rerun the self-test (3.1) and the items the fix touches.
- Optional items say **Optional** in their title. Skipping them does not block the release.

## What changed since the plans were written

Apply this to every item. The items below already say it; this is the summary.

- **Notifications from the command line are off by default** (plan-2.4.0). A session started in Terminal posts no `Awake started` or end banner unless it was started with `--notifications`, wherever it is stopped from. Without a terminal, only `Awake failed` is posted by default. A 2.1.0, 2.2.0 or 2.3.0 step that expects a banner for a Terminal session now expects none.
- **The app announces only its own sessions** (`isAppSession`). A Terminal session stopped from the app posts nothing from the app and plays no sound.
- **The icon changes at once** (faster-start-stop A). The bold A means on, the regular A off.
  - A lid-open start or stop changes the icon at the click, key press or menu choice.
  - A lid-closed start shows the bold A dimmed until the session runs.
  - While the CLI's picker or a macOS password dialog is open, the current icon is dimmed.
  - While Awake's own picker or password dialog is open, the icon does not change.
  - A press while a command runs only beeps, so wait about a second between presses.
- **The app plays the start sound itself** (E, `29e53db`), and passes no `--sound` to the CLI. There is still exactly one Tink per start and per stop when Sound is on.
- **Lid-open stops are faster** (B): no fixed 1 s pause.
- **The helper is unchanged since 2.2.0** (protocol 9). Installing over 2.2.0 or 2.3.0 asks for no password. Over 2.1.0 it asks once.
- **The dev build reports 2.3.0** in `awake --version` and in the Help window until `tools/release.sh` runs (12.3). That is not a bug. To tell the builds apart, use `awake --help | grep -c -- --notifications` (0 on 2.3.0, 1 or more on the dev build).
- **A Terminal session is lid-closed by default.** It asks for the password unless password-free mode is on. Items that need a lid-open Terminal session add `--backend caffeinate`.
- **The Homebrew tap is already set up.** The plans and the task said it waits for the owner's one-time setup. But the public tap `anttikaenmaki/homebrew-awake` has commit `da497a3` "Awake 2.3.0" by github-actions[bot] (2026-09-30), published by the by-hand run 36744054640. Only the token's expiry needs checking (0.4). So the Homebrew items can run, and 2.3.0 to 2.4.0 is tested as a real upgrade (12.6).

## Conventions

- "Ctrl-click" means Control-click or right-click on the menu bar icon. "Click" means a left-click on it.
- Unless an item says otherwise, start it with Awake off: `awake --status` prints `Awake is off.`. Stop a session with `awake --stop`.
- The debug log is `/tmp/keep-awake-lid-closed-$UID/awake-debug.log`.
- The settings domain is `net.kaenmaki.awake.statusbar`. Quit Awake (Ctrl-click > Quit) before editing it with `defaults`, then reopen with `open ~/Applications/Awake.app`.
- "Password-free mode" is Settings > Start without password. "Custom dialog" is Settings > Use custom password dialog; it can only be turned on while password-free mode is off.
- Times are rough, from the plans' estimates. Every Mac duration in an expected result is an estimate until 10.3 is filled in.

## Safety

- 6.12 is a forced power-off. Save all work first.
- 7.8 and 7.10 put a full CPU load on the Mac. Keep it on a hard surface.
- 5.8 brings up macOS's Log Out dialog on Shift-Command-Q. Press Cancel.
- The lid-closed tests on battery put the Mac to sleep at their end.
- 11.1, 11.6 and 12.7 uninstall Awake, with its settings, helper and password-free rule. 0.5 backs the settings up, and 11.6 and 12.7 export them again first.

## Time

| Section | What | Time |
|---|---|---|
| 0 | Preparation (6 items) | 40 min |
| 1 | Before updating (2.3.0) (4 items) | 50 min |
| 2 | Install the dev build (1 item) | 15 min |
| 3 | Automated checks (4 items) | 35 min |
| 4 | Command line in a terminal (14 items) | 1 h 15 min |
| 5 | Menu bar app and shortcut (35 items) | 4 h 55 min (+5 min optional) |
| 6 | Lid-closed sessions (12 items) | 2 h 25 min |
| 7 | Guardrails (16 items) | 2 h 45 min (+30 min optional), plus 7.11a's drain |
| 8 | Process-bound and timed sessions (4 items) | 1 h 30 min |
| 9 | Shortcuts, no terminal (2 items) | 15 min |
| 10 | Timing after the update (3 items) | 50 min |
| 11 | Old versions, uninstall, Homebrew (7 items) | 1 h 5 min (+1 h 15 min optional) |
| 12 | Release and post-release (7 items) | 1 h 55 min |
| | **Total** (115 items) | **about 19 h 10 min** (+1 h 50 min optional) |

The total includes about 2.5 hours of mostly unattended waiting (4.14, 7.11, 7.14 and 8.4). On top come the frame reading of 1.3 and 10.2, and 7.11a's battery drain (about 1 to 3 hours, unattended, or none if the charge is already low). That is two to three working days. Run it as one session in stages: the natural break points are after 5 (the dev build is installed and the app is checked), at 7.11a (start the next stage unplugged with a low charge), after 7, and after 10. 1.1 to 2.1 must run in one go, as they need the installed 2.3.0. Optional items are counted separately.

## Quick pass: the minimum before the release

The full list takes two to three days. If the owner releases 2.4.0 before all of it has run, as with 2.3.0, run at least these items, in this order. They cover what 2.4.0 changes, what is most likely to break, and what can only be done before the update. About 5 hours, of which about 1.5 hours is the release itself and about 30 minutes is waiting.

| When | Items | Why |
|---|---|---|
| Before updating (only possible now) | 0.2, 0.3, 0.5, 0.6, 1.1, 1.2 | Backups, CI, and the "before" timing with 2.3.0 |
| Install and automated checks | 2.1, 3.1, 3.3, 3.4 | The upgrade over a running session, the self-test on this Mac, a release rehearsal, and the launcher fix |
| The command line | 4.1, 4.2, 4.3, 4.5, 4.8, 4.12 | Notifications off by default, `--notifications`, `--sound`, `--gui --stop`, the quick lid-open start and stop |
| The app and the shortcut | 5.2, 5.10, 5.14, 5.16, 5.17, 5.18, 5.21, 5.22 | The icon that changes at once, the sounds, and the app keeping the CLI quiet |
| Lid-closed sessions | 6.2, 6.8, 7.11 | A start with the macOS dialog and without a password, and the main use: lid closed on battery |
| Without a terminal | 9.1 | The one notification still posted by default |
| After the update | 10.1 | The "after" timing, to compare with 1.2 |
| Release | 12.1 to 12.6 | The release, the tap and `brew upgrade` |

With the quick pass, 12.2's gate applies to these items. Record the others as still open in "Results", as plan-2.3.0 did for its QA, and run them after the release; their fixes go into 2.4.1.

## 0. Preparation

- [ ] **0.1 What to have** (5 min)
  - A MacBook (Apple silicon) with its charger. Several items need battery power: 7.12 at 30% or less, 7.13 and 7.13a at 50% or less. Start the day fully charged; section 7 drains the battery on purpose (7.11a).
  - The installed Awake 2.3.0, idle, and the checkout at `~/awake`.
  - The admin password. Note whether the owner normally uses password-free mode (0.5 records it).
  - The Shortcuts app (9.1, 9.2).
  - Homebrew, for 0.4, 11.6 and 12.6 to 12.7.
  - For the timing films (1.3, 10.2): QuickTime Player and a phone with 240 fps slow motion.
  - For some items: Safari; the French (AZERTY) and Finnish or German input sources (5.8); VoiceOver (Command-F5); Accessibility Inspector if Xcode is installed (5.35); a small display or a scaled resolution about 800 points high (5.31).
  - Optional: an external display (7.7), a second display (5.32), a dock (7.2), a launcher that uses a global shortcut such as Raycast, Alfred or Rectangle (5.7), a Mac or VM with macOS 12.5 (11.5).

- [ ] **0.2 Mac prerequisites and the checkout** (5 min)
  Sources: release procedure (README Requirements, Quick installation; scripts/install-awake.sh `check_build_tools`).
  Steps:
  1. `xcode-select -p`. If it prints no path, run `xcode-select --install` and wait.
  2. `/usr/bin/swiftc --version`. Note the version: this Mac is the only build with it (CI's swiftc is newer).
  3. `/usr/bin/python3 --version` (the self-test needs it) and `/bin/bash --version | head -1`.
  4. `git config user.name; git config user.email`. Both must be set, as `tools/release.sh` commits.
  5. Optional: `gh auth status`, for the CI, PR and release commands.
  6. `cd ~/awake; git status --short; git fetch origin --tags; git checkout dev; git pull --ff-only origin dev; git log -1 --format='%h %s'`
  7. `awake --version; awake --status`
  Expected: a Command Line Tools path; Swift 5.7 or later; a python3 version; `GNU bash, version 3.2.57`. `git status` prints nothing, and `dev` is at the commit CI tested (now `29e53db`). `awake 2.3.0` and `Awake is off.`.

- [ ] **0.3 CI is green on the commit under test** (3 min)
  Sources: release procedure (.github/workflows/ci.yml); plan-2.4.0 9 (the "unverified" list).
  Steps:
  1. `gh run list --repo anttikaenmaki/awake --workflow ci.yml --branch dev --limit 5`
  2. Check that the newest run is for the commit from 0.2 (now `29e53db`, run 37156641914): `gh run view 37156641914 --repo anttikaenmaki/awake`.
  3. Check again after each commit that lands during the QA.
  Expected: success, every step green, about 6.5 to 8 minutes. The job runs the Bash 3.2 syntax checks, `tools/release.sh --check`, the app build and `codesign --verify`, a macOS 12.5 target build, the three app checks in `tests/app/`, the cask template, the Homebrew uninstall step, the dry-run self-test and `tools/measure-latency.sh --dry-run`. CI does not cover real pmset, banners, sounds, the UI, a terminal (TTY), or Swift 5.7. This session covers those.

- [ ] **0.4 Homebrew tap token** (10 min)
  Sources: release procedure (tap readiness, steps 1 to 3); plan-2.3.0 17 (the one-time setup).
  Needs: the owner's GitHub account; Homebrew. Do it now, so a renewed token is in place before the release.
  Steps:
  1. GitHub > Settings > Developer settings > Personal access tokens > Fine-grained tokens. Find the token for `anttikaenmaki/homebrew-awake`. Check that it does not expire before the release (the default lifetime is 30 days) and has Contents: Read and write. Regenerate it if needed.
  2. `gh secret list --repo anttikaenmaki/awake`. If the token was renewed: `gh secret set HOMEBREW_TAP_TOKEN --repo anttikaenmaki/awake`.
  3. `brew update; brew info --cask anttikaenmaki/awake/awake`
  Expected: `HOMEBREW_TAP_TOKEN` is listed and its token is valid. `brew info` shows `awake: 2.3.0`. If the token expires before the release, the tap job fails after the GitHub release is out (12.4 says how to recover).

- [ ] **0.5 Save the starting state and the old versions** (10 min)
  Sources: faster-start-stop 8.29 (preparation); plan-2.4.0 6.10 (2.3.0 sources); plan-2.3.0 6.8, 15.1 item 8, 15.4 item 6 (older versions).
  Steps:
  1. Settings backup: `defaults export net.kaenmaki.awake.statusbar ~/awake-prefs-start.plist`. Write down Sound, Shortcut, Mode, password-free mode, Custom dialog, Stop when unplugged and Launch at login.
  2. `pmset -g > ~/awake-pmset-start.txt`
  3. Copies of the installed 2.3.0 for 5.24: `cp "$HOME/Library/Application Support/Awake/bin/awake" ~/awake-2.3.0-cli; ditto ~/Applications/Awake.app ~/Awake-2.3.0.app`
  4. The 2.3.0 sources for 11.1: `mkdir -p ~/awake-qa; git -C ~/awake worktree add ~/awake-qa/awake-2.3.0 v2.3.0` (or commit `6420ad3`). The worktrees go under `~/awake-qa`, not `/tmp` as the plans write, because 6.12 restarts the Mac and macOS empties `/tmp` at startup.
  5. Optional, only for 11.2 to 11.4: `git -C ~/awake worktree add ~/awake-qa/awake-2.2.0 6be3ad8`, `... ~/awake-qa/awake-2.1.0 3d1ca9b`, `... ~/awake-qa/awake-2.0.0 e8ea1ab`.
  Expected: the files and worktrees exist. `grep -c AWAKE_STATUS_JSON_FILE ~/awake-2.3.0-cli` prints 0 (the old CLI).

- [ ] **0.6 Settings for the session** (5 min)
  Sources: faster-start-stop 7.2 and 8 (preconditions); plan-2.4.0 6 (global preconditions).
  Steps:
  1. System Settings > Notifications > Awake: Allow notifications on, style Banners. Focus and Do Not Disturb off. Sound volume up.
  2. In Awake's Settings: Sound on off for now (1.3 needs it off). Keyboard shortcut > Shortcut on (off by default since 2.3.0), Mode `Lid-open, display on`. Default session 20 minutes. Time to add 1 hour. Use custom password dialog off.
  3. Password-free mode: on for sections 1 to 5 saves typing, as Terminal sessions are lid-closed by default. Section 6 turns it off and on as it needs. 11.7 puts it back to the owner's choice.
  Expected: the settings as listed.

## 1. Before updating: with the installed 2.3.0

The install in 2 replaces 2.3.0 and stops any session, so these must run first.

- [ ] **1.1 2.3.0 ignores the new option and variable** (2 min)
  Sources: release procedure (dev-build install, step 1); plan-2.4.0 6.10 (step 1 check).
  Steps: `awake --notifications --status; echo $?`, then `AWAKE_NOTIFICATIONS=true awake --status`.
  Expected: `Unknown option: --notifications`, the usage text and `1`. With the variable, the normal status prints. This is what the CHANGELOG's Upgrade note says about older versions.

- [ ] **1.2 Timing script, before** (12 min)
  Sources: faster-start-stop 7.1 + 8.1 (before the update).
  Needs: no session; plugged in; heavy apps closed.
  Steps:
  1. `cd ~/awake`. Check the installed CLI is still the old one: `grep -c AWAKE_STATUS_JSON_FILE "$HOME/Library/Application Support/Awake/bin/awake"` prints 0.
  2. Quit Awake.app (Ctrl-click > Quit), so its 10 s polls add no noise.
  3. `tools/measure-latency.sh --rounds 5` (add `--lid-closed` if password-free mode is on). Run it twice and keep the second output.
  4. `tools/measure-latency.sh --rounds 5 --sound` (with `--lid-closed` if used). Run it twice, keep the second. Tink plays at each start.
  5. Three times: `awake --start --backend caffeinate --duration 10m; sleep 3; time awake --stop`. Note the `total`.
  6. Paste the kept outputs and the times into a note labelled "before". The raw times are in `./awake-latency-YYYYMMDD-HHMMSS.tsv` (git-ignored in the checkout root only).
  7. `open ~/Applications/Awake.app`
  Expected: the first line reads `awake 2.3.0, <model>, macOS <version>, 5 rounds` (`, --sound` on the second run). Then min, median and max in ms for the lid-open start and stop (and the lid-closed rows), and "The app waits (ms)" with the columns today, with C, with C and H. For 2.3.0, read "today". With `--sound` the lid-open start is longer by about Tink's length. Without `--lid-closed` there are no lid-closed rows. If `--lid-closed` is passed without password-free mode, it prints `Skipping lid-closed: sudo would ask for a password, and the prompt would be timed too.` and times only the lid-open rows.

- [ ] **1.3 Timing on screen, before** (30 min, plus frame reading)
  Sources: faster-start-stop 7.2 + 8.1 (before the update).
  Needs: the 2.3.0 app running with the settings of 0.6 (Sound off, Shortcut on, Mode `Lid-open, display on`, banners on, Focus off); plugged in; QuickTime; the phone at 240 fps.
  Steps:
  1. QuickTime Player > File > New Screen Recording, Options > Show Mouse Clicks. Record an area with the menu bar icon and the banner corner.
  2. Five times: Ctrl-click > Start default session and wait for `Awake started`; then click the icon to stop and wait for `Awake stopped`. Leave a few seconds between steps.
  3. Film the keyboard and the screen with the phone: five ⇧⌘A starts and five ⇧⌘A stops, waiting for each banner.
  4. Step frame by frame. t0 is the release of the click or menu choice (the app acts on mouse-up, StatusBarController.swift:104 and :123), or the key press. t1 is the first frame the icon changes, t2 the first frame of the banner. Keep the medians of t1-t0 and t2-t0 for menu start, click stop, ⇧⌘A start and ⇧⌘A stop. QuickTime records at up to 60 fps; check the rate in the Movie Inspector.
  Expected: with 2.3.0, t1 is about t2, about 1.5 to 3.5 s. Compare t2-t0 with the "today" sum of 1.2: a gap above about 0.2 s is app overhead the script cannot see.

- [ ] **1.4 The new CLI stops an old lid-open session** (5 min)
  Sources: faster-start-stop 8.23; faster-start-stop 8.22 (optional 2.3.0 baseline).
  Steps:
  1. `awake --start --backend caffeinate --duration 10m` (the 2.3.0 CLI).
  2. Optional baseline for 8.4: after about a minute, `pid=$(awk -F= '$1=="sleep_pid"{print $2}' /tmp/keep-awake-lid-closed-$UID/state); ps -o rss=,%cpu=,etime= -p "$pid"`. Note the numbers.
  3. `cd ~/awake; time bin/awake --stop`
  4. `bin/awake --status-json | grep -o '"active":[a-z]*\|"last_completion_reason":"[a-z_]*"'`, then `pgrep -lx caffeinate`.
  Expected: the session stops. The stop can take up to about a second longer than a new one, as the old runner finishes its 1 s pause: `total` up to about 1.3 s. Step 4 prints `"active":false` and `"last_completion_reason":"stopped"`; pgrep prints nothing.

## 2. Install the dev build

- [ ] **2.1 Install over a running 2.3.0 session** (15 min)
  Sources: plan-2.4.0 6.10 (installer, steps 2 to 4); plan-2.3.0 15.4 item 14, 15.2 item 7 (install during a session), 15.1 item 8 (from 2.3.0), 6.8 (no helper password); release procedure (dev-build install).
  Needs: the 2.3.0 app running; 1.1 to 1.4 done.
  Steps:
  1. In Terminal: `awake --duration 30m` (2.3.0, lid-closed; the password unless password-free mode is on). Then `pgrep -fl -- '--notify-wait'` (one notifier: 2.3.0 always starts one) and `awake --status-json | grep -o '"session_token":"[^"]*"'`. Note the token.
  2. `cd ~/awake; git log -1 --format='%h %s'; git status --short`
  3. `bash install-awake.sh`
  4. In a new Terminal window:
     - `awake --status; pgrep -fl -- '--notify-wait'`
     - `cmp "$HOME/Library/Application Support/Awake/bin/awake" ~/awake/bin/awake && echo same`
     - `awake --help | grep -c -- --notifications`
     - `pgrep -fl AwakeStatusBar; command -v awake; awake --version`
     - `defaults read net.kaenmaki.awake.statusbar | grep -A8 lastSessionHeat; defaults read net.kaenmaki.awake.statusbar sessionHeatInProgress`
  5. Start and stop one lid-closed session from the menu bar (click, check `Keep laptop awake with lid closed`, Start; then click to stop).
  6. After any QA fix later: commit, wait for green CI, `git pull --ff-only origin dev`, then repeat steps 2 to 4.
  Expected:
  - Step 3 prints, in this order: `Building Awake.app ...`, `Building Awake GUI picker ...` (30 to 90 s), then `Installing stops the running session: Awake is on ...`, `Quitting the running Awake.app ...`, the install lines, `Installing the privileged helper ...` and `Awake's helper is already installed and up to date.` with no password prompt, `Launching Awake.app ...` and `Awake installation complete.`. The session keeps running until the two builds are done.
  - The session stops. At most one `Awake stopped` banner, from the old 2.3.0 notifier. No `Awake is off`.
  - Step 4: `Awake is off.`, no notifier, `same`, a count of 1 or more, the app running from `~/Applications/Awake.app`, and `awake 2.3.0` (the dev build still says 2.3.0). `lastSessionHeat` holds the token from step 1 with `endedAt` at the install, and `sessionHeatInProgress` does not exist.
  - Settings, password-free mode, Stop when unplugged and Launch at login are unchanged.
  - Step 5 asks for nothing new: the password only if password-free mode is off.

## 3. Automated checks on the Mac

- [ ] **3.1 Self-test** (10 min)
  Sources: release procedure (self-test); plan-2.4.0 9 (the optional local run).
  Needs: a normal user, not root; plugged in. While it runs, do not use `awake --dry-run`, `tools/measure-latency.sh --dry-run` or a session from `~/awake/bin/awake`. The installed Awake may keep running.
  Steps:
  1. `cd ~/awake; time /bin/bash tests/cli/awake-self-test 2>&1 | tee ~/Desktop/awake-self-test.log` (`/bin/bash` is the Bash 3.2 CI uses; README's plain `bash` may be a Homebrew Bash 5).
  2. If a step fails that CI passes, run it again without a terminal on stdin, as on CI: `/bin/bash tests/cli/awake-self-test </dev/null`. Keep both logs.
  Expected: the section lines run 1, 1a, 2 ... 12l, then `13. Verifying that --help fits in 80 columns and lists --notifications`. It ends with `All dry-run lifecycle and regression checks passed.` and exit 0, in about 6 minutes. It changes no real pmset setting and leaves the settings alone (it uses `net.kaenmaki.awake.selftest` and deletes it). This is its first run in a real terminal.

- [ ] **3.2 The app checks with this Mac's Swift** (5 min)
  Sources: release procedure (the CI steps "Check the heat report", "Check the start shortcut", "Check the menu bar icon" and the macOS 12.5 build).
  Steps (in `~/awake`, `T=$(mktemp -d)`):
  ```
  swiftc -target arm64-apple-macos12.5 -parse-as-library app/AwakeStatusApp/Sources/HeatReport.swift tests/app/heat-report-check.swift -o "$T/heat" && "$T/heat"
  swiftc -target arm64-apple-macos12.5 -parse-as-library -framework AppKit -framework Carbon app/AwakeStatusApp/Sources/StartShortcut.swift app/AwakeStatusApp/Sources/PickerSettings.swift tests/app/start-shortcut-check.swift -o "$T/shortcut" && "$T/shortcut"
  swiftc -target arm64-apple-macos12.5 -parse-as-library app/AwakeStatusApp/Sources/StatusIcon.swift tests/app/status-icon-check.swift -o "$T/icon" && "$T/icon"
  swiftc -target arm64-apple-macos12.5 -framework AppKit -framework Carbon -framework WebKit -framework UserNotifications app/AwakeStatusApp/Sources/*.swift -o "$T/AwakeStatusBar-macos12"
  ```
  Expected: each check builds and reports no failures; the last build succeeds. If this Mac's Swift is older than CI's, this is the only proof that the new `StatusIcon.swift` builds with it.

- [ ] **3.3 Version check and a release rehearsal** (5 min)
  Sources: release procedure (`tools/release.sh`).
  Steps:
  1. `/bin/bash tools/release.sh --check; /bin/bash tools/release.sh --version`
  2. On a throwaway clone:
     `git clone -q ~/awake /tmp/awake-release-rehearsal && cd /tmp/awake-release-rehearsal && git checkout -q dev && /bin/bash tools/release.sh minor && /bin/bash tools/release.sh --check && git show --stat HEAD | tail -8 && /bin/bash tools/release.sh --notes | head -3`
  3. `cd ~ && rm -rf /tmp/awake-release-rehearsal`
  Expected: `Version 2.3.0 is consistent in bin/awake, README.md, the 3 Info.plist files and CHANGELOG.md.` and `2.3.0`. The rehearsal prints `Committed "Version 2.4.0" on dev.`, changes six files (CHANGELOG.md, README.md, bin/awake and three Info.plist files), then `Version 2.4.0 is consistent ...`; the notes start with `### Upgrade notes`. `~/awake` is not touched.

- [ ] **3.4 Rebuild the installer and uninstaller launchers** (15 min)
  Sources: plan-2.3.0 14 QA (Install Awake.app after rebuilding the launchers).
  Needs: Apple silicon, the Command Line Tools. This is a fix, not only a check: 2.3.0 shipped with the old binaries (commit 518a288 changed only `tools/gui-app-launcher.swift`).
  Steps:
  1. `cd ~/awake; for f in 'Install Awake.app/Contents/MacOS/Install Awake' 'Uninstall Awake.app/Contents/MacOS/Uninstall Awake'; do echo "$f:"; strings "$f" | grep -iE 'installation complete|uninstall complete'; done`. Both binaries come from one source and hold both titles. Today each prints `Awake Installation Complete`, `Awake installation complete.` and `Awake Uninstall Complete`.
  2. `tools/build-gui-launchers.sh`, then run the step 1 loop again.
  3. Double-click `Install Awake.app` in Finder and let it finish.
  4. The uninstall dialog without uninstalling: `printf '#!/bin/bash\nexit 0\n' > /tmp/noop.sh; chmod +x /tmp/noop.sh; AWAKE_GUI_LAUNCHER_SCRIPT=/tmp/noop.sh ~/awake/'Uninstall Awake.app/Contents/MacOS/Uninstall Awake'`
  5. Commit the two rebuilt binaries on `dev`, with a `### Fixed` entry (the launchers' result windows now use sentence case). Wait for CI (0.3).
  Expected: after the rebuild each binary shows `Awake installation complete`, `Awake installation complete.` and `Awake uninstall complete` (sentence case), and no title-case `Installation Complete` or `Uninstall Complete`. Step 3's result window is titled `Awake installation complete` (no password dialog, as the helper is up to date). Step 4 shows `Awake uninstall complete` with `Awake has been uninstalled.`, and nothing is removed.

## 4. The command line in a terminal

Run these with the dev build installed and Awake.app running. Password-free mode on saves typing for the lid-closed starts.

- [ ] **4.1 No notifications by default** (2 min)
  Sources: plan-2.4.0 6.1.
  Steps:
  1. `awake --debug --duration 1m`
  2. While it runs: `pgrep -fl -- '--notify-wait'`
  3. After about 70 s: `awake --status`
  4. `grep start_gui_completion_notifier /tmp/keep-awake-lid-closed-$UID/awake-debug.log; rm -f /tmp/keep-awake-lid-closed-$UID/awake-debug.log`
  Expected: no banner and no Tink at the start or the end; the start is printed (`Awake activated for 1 minute.`, `You can now close the lid.`). Step 2 prints nothing. Step 3: `Awake is off.`. The log shows `start_gui_completion_notifier suppressed` and no `wait_for_gui_completion` line.

- [ ] **4.2 `--notifications`** (3 min)
  Sources: plan-2.4.0 6.2.
  Steps:
  1. `awake --debug --notifications --duration 1m`
  2. While it runs: `pgrep -fl -- '--notify-wait'`
  3. After about 70 s: `grep -E 'post_notification|notify_gui (success|start) message=Awake finished' /tmp/keep-awake-lid-closed-$UID/awake-debug.log`, then remove the log.
  Expected: no start banner (the start is printed). One notifier, whose command line ends in `false` (no sound). A few seconds after the minute, one `Awake finished` banner with the Awake icon, not Script Editor's. The log has `post_notification app title=Awake finished` and `notify_gui success message=Awake finished` (posted through `AwakeStatusBar --notify`, not osascript).

- [ ] **4.3 `--sound` alone** (2 min)
  Sources: plan-2.4.0 6.3.
  Steps: `awake --sound --duration 1m`; while it runs `pgrep -fl -- '--notify-wait'`; wait about 70 s.
  Expected: Tink at the start, before the prompt returns, and Tink at the end. No banner. One notifier, ending in `true`: it runs only for the end sound.

- [ ] **4.4 `--notifications --sound` with a command** (2 min)
  Sources: plan-2.4.0 6.4.
  Needs: Awake allowed to post (4.2 done), or the first post may wait up to about 120 s for the permission prompt.
  Steps: `awake --notifications --sound -- sleep 20`, and watch how soon `sleep` starts.
  Expected: at the start, Tink and an `Awake started` banner, `The Mac will stay awake with the lid closed until sleep exits.`. `sleep` starts within about a second. About 20 s later, `sleep finished (exit status 0). Awake stopped.` on stderr, Tink, and a banner titled `Awake finished: the process it waited for exited`. A wait of several seconds before `sleep` starts is a failure.

- [ ] **4.5 `--gui --stop` typed in a terminal** (1 min)
  Sources: plan-2.4.0 6.5.
  Steps: `awake --gui --stop; echo exit=$?`, then `awake --gui --stop --notifications; echo exit=$?`.
  Expected: both print `Awake mode is not active.` and `exit=0`, and post no banner.

- [ ] **4.6 Piped output: a failure still posts** (2 min)
  Sources: plan-2.4.0 9 (risk "A visible stderr can still come with a banner"; README.md:58).
  Steps:
  1. `awake --backend caffeinate --duration 10m`
  2. `awake -- /bin/sleep 5 2>&1 | tee /tmp/awake-tee.log`
  3. `awake --no-notifications -- /bin/sleep 5 2>&1 | tee /tmp/awake-tee.log`
  4. `awake -t -- /bin/sleep 5 2>&1 | tee /tmp/awake-tee.log`
  5. `awake --stop; rm -f /tmp/awake-tee.log`
  Expected: each prints `A session is already running. Stop it with awake --stop first, then start one tied to the process.` through tee. Step 2 also posts one `Awake failed` banner, as the README documents. Steps 3 and 4 post nothing.

- [ ] **4.7 A killed runner: a failed end** (6 min)
  Sources: plan-2.4.0 decision 14 (CHANGELOG Fixed: `--sound` on a failed session); plan-2.3.0 15.4 item 4.
  Steps:
  1. `awake --sound --backend caffeinate --duration 10m` (Tink at the start). `pmset -g assertions | grep -i caffeinate` shows the assertion.
  2. `kill -9 $(awk -F= '$1=="sleep_pid"{print $2}' /tmp/keep-awake-lid-closed-$UID/state)` (sleep_pid is the runner).
  3. Over the next 5 s: `pmset -g assertions | grep -i caffeinate`. After about 3 s: `awake --status; pgrep -fl -- '--notify-wait'`.
  4. Repeat with `awake --notifications --sound --backend caffeinate --duration 10m`.
  5. Optional: start a lid-open session from the app (picker, lid box unchecked) and do step 2.
  Expected: the caffeinate assertion is gone within seconds (`caffeinate -w` follows the runner). Step 3: no Tink, no banner, `Awake is off.`, no notifier. Step 4: one `Awake failed` banner and no Tink. Step 5: the app posts `Awake failed`, `Awake stopped unexpectedly before the session finished.`.

- [ ] **4.8 The quick lid-open start and stop** (8 min)
  Sources: faster-start-stop 8.18, 8.19, 8.40.
  Steps:
  1. Start with ⇧⌘A, then Ctrl-click > Stop session. Right after: `pgrep -lx caffeinate; pmset -g assertions | grep -i caffeinate`
  2. `rm -f /tmp/keep-awake-lid-closed-$UID/awake-debug.log`. Five times: `awake --debug --start --backend caffeinate --duration 10m; sleep 3; awake --debug --stop`
  3. `grep -E 'wait_for_session_start|request_active_session_stop|wait_for_requested_stop_completion' /tmp/keep-awake-lid-closed-$UID/awake-debug.log`, then delete the log.
  Expected: step 1 prints nothing. Each start in step 3 logs `wait_for_session_start ready ... checks=N` with N under 20 (a check every 0.05 s). Each stop logs `request_active_session_stop signal worker_pid=... state_file=.../state`, then `wait_for_requested_stop_completion ready ... reason=stopped checks=N` with N above 0 and under 10. No `worker_gone` or `timed_out` line. An `ignoring_mismatched_status` line is harmless. (The Terminal stop time for 10.3 comes from 10.1.)

- [ ] **4.9 A lid-open bound command exits without a pause** (2 min)
  Sources: faster-start-stop 8.20.
  Steps: `time awake --backend caffeinate -- sleep 3`, then `awake --status-json | grep -o '"last_completion_reason":"[a-z_]*"'`.
  Expected: `sleep finished (exit status 0). Awake stopped.`, exit 0 about 3 s after sleep starts, with no extra pause of about 1 s. Then `"last_completion_reason":"process_exited"`.

- [ ] **4.10 A stop right at the deadline** (6 min)
  Sources: faster-start-stop 8.21.
  Steps:
  ```
  for d in 4.4 4.7 5.0 5.3 4.8 4.9; do awake --backend caffeinate --duration-seconds 5 >/dev/null; sleep $d; time awake --stop; awake --status-json | grep -o '"active":[a-z]*\|"last_completion_reason":"[a-z_]*"\|"session_token":"[^"]*"'; ls /tmp/keep-awake-lid-closed-$UID/state 2>/dev/null; sleep 2; done
  ```
  Expected: every run ends with `"active":false` and reason `timeout` or `stopped`. `ls` prints nothing, and no stop takes about 30 s. Now and then `stopped` with an empty `session_token` is an older race (faster-start-stop 6.11 M); count how often.

- [ ] **4.11 The thermal-state variable in the CLI** (4 min)
  Sources: faster-start-stop 8.34, 8.35.
  Needs: a cool Mac.
  Steps:
  1. `AWAKE_APP_THERMAL_STATE=3 awake --start --backend caffeinate --duration 1m; echo $?`
  2. `AWAKE_APP_THERMAL_STATE=9 awake --start --backend caffeinate --duration 1m; awake --stop`
  3. `rm -f /tmp/keep-awake-lid-closed-$UID/awake-debug.log; awake --debug --start --backend caffeinate --duration 1m; grep -c 'source=app' /tmp/keep-awake-lid-closed-$UID/awake-debug.log; awake --stop`, then delete the log.
  Expected: 1 refuses at once with `The Mac is overheating, too hot for a lid-open session. Let it cool down first.` and `1`. 2 starts (9 is ignored and the real state is read). 3 starts and grep prints `0`.

- [ ] **4.12 Terminal sessions stopped from the app** (5 min)
  Sources: plan-2.4.0 6.6 (with section 3 and decision 12).
  Needs: Sound on in Awake's Settings for this item.
  Steps:
  1. `awake --duration 10m`. Click the icon to stop it.
  2. `awake --notifications --duration 10m`. Click the icon to stop it.
  3. `awake --notifications --backend caffeinate --duration 10m`. Click the icon to stop it.
  4. `awake --duration 10m`, then `awake --notifications --stop`.
  5. Turn Sound on off again.
  Expected: the icon turns regular at once at each click. 1: no banner and no Tink from anyone. 2 and 3: exactly one `Awake stopped`, from the CLI's notifier, within about a second; the app posts nothing and plays no Tink. 4: Terminal prints `Awake mode is already active.`, `Restoring normal mode.` and `Normal sleep mode restored.`, and no banner appears (the end follows the command that started the session).

- [ ] **4.13 The CLI help text** (3 min)
  Sources: plan-2.4.0 6.13 (part 1).
  Steps: `awake --help | less`, and `awake --help | awk 'length > 80'`.
  Expected: the help shows `--sound` (`... also without --notifications`), `--notifications` (`... (default off)`) and `--no-notifications` (`... not even for a failure no terminal shows`). The awk prints nothing.

- [ ] **4.14 Heat record for Terminal sessions** (28 min, mostly waiting)
  Sources: plan-2.3.0 15.2 item 5, 15.2 item 8.
  Steps:
  1. Ctrl-click > Quit. `awake --duration 10m` (lid-closed). Then `open ~/Applications/Awake.app` and wait for the end. `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`
  2. With the app running: `awake --duration 15m`, and let it end. `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`
  Expected: 1: `watchedFromStart = 0`; the heat note, if shown, begins `Last session (from HH:MM):`. 2: lastSessionHeat holds this session's token. No end banner in either case: the sessions were started without `--notifications`, and the app does not announce sessions it did not start.

## 5. The menu bar app and the shortcut

Lid-open, plugged in. Keep password-free mode as in 0.6 and Use custom password dialog off unless an item says otherwise. Sound on is off unless an item turns it on.

### 5A. The shortcut

- [ ] **5.1 The shortcut is off in a fresh state** (3 min)
  Sources: plan-2.3.0 6.4.
  Steps:
  1. Ctrl-click > Quit.
  2. `defaults delete net.kaenmaki.awake.statusbar startShortcut; defaults delete net.kaenmaki.awake.statusbar startShortcutEnabled` (an error for a missing key is fine).
  3. `open ~/Applications/Awake.app`, then Ctrl-click > Settings….
  4. In Finder press Shift-Command-A.
  Expected: the Shortcut box is unchecked, the button shows `⇧⌘A` dimmed, and the note is grey. The Mode pop-up and its label are not dimmed. Shift-Command-A opens the Applications folder.

- [ ] **5.2 First start and stop with the shortcut** (5 min)
  Sources: plan-2.3.0 6.5, 15.3 items 2 and 3; faster-start-stop 8.2.
  Needs: right after 5.1. Mode `Lid-open, display on`, Default session 20 minutes. A US, Finnish, Swedish, German, UK, Dvorak or Colemak layout. Safari open with a text field focused.
  Steps:
  1. Check the Shortcut box.
  2. With Safari in front, press ⇧⌘A and hover over the icon at once. Run `awake --status`.
  3. Press ⇧⌘A again and hover.
  4. `defaults read net.kaenmaki.awake.statusbar`
  Expected:
  - The bold A appears with the key press, not dimmed. The tooltip reads `Starting Awake…` briefly, then `Awake is on and has 20 minutes left (keep the lid open)`. `Awake started` reads `The Mac will stay awake while the lid remains open for 20 minutes.`. Nothing is typed into Safari, and no picker appears. `awake --status` shows about 20 minutes left `(keep the lid open)`.
  - The second press shows the regular A at once with `Stopping Awake…`, then `Awake stopped`.
  - defaults shows `startShortcut = { keyCode = 0; keyLabel = A; modifiers = 12; };` and `startShortcutEnabled = 1;`.

- [ ] **5.3 Recording rules** (8 min)
  Sources: plan-2.3.0 6.6, 6.7, 15.3 item 1.
  Steps:
  1. Click the shortcut button and press Control-Option-Command-A.
  2. Click it again and press, one at a time: Command-W, Command-D, Option-Shift-A, A alone, Shift-Command-3, Delete alone, Forward Delete alone (fn-Delete). Then press Esc.
  3. Start a recording and click outside the window.
  4. Uncheck the Shortcut box. In another app press Control-Option-Command-A, then Shift-Command-A.
  5. Check the box again. Press Control-Option-Command-A twice, a second or two apart.
  6. Record Shift-Command-A again.
  Expected:
  - 1: the button shows `⌃⌥⌘A`.
  - 2: Command-W does not close the window. Command-W, Command-D, Option-Shift-A, A, Delete and Forward Delete each show `Use two or more modifier keys, including ⌃ or ⌘.` in red, and recording goes on (`Type the shortcut…`). Shift-Command-3 shows `macOS uses ⇧⌘3. Choose another shortcut.`. Esc ends recording and shows the old shortcut.
  - 3: clicking outside ends the recording.
  - 4: neither combination does anything in Awake (Shift-Command-A reaches the front app), and the button shows `⌃⌥⌘A` dimmed.
  - 5: the first press starts a session and the second stops it, the icon changing at each press.

- [ ] **5.4 Other modes and an indefinite Default session** (5 min)
  Sources: plan-2.3.0 15.3 items 5 and 6.
  Needs: Include Indefinitely on (Settings).
  Steps:
  1. Mode `Lid-open, display can sleep`. Press ⇧⌘A, hover, run `awake --status`, then press ⇧⌘A to stop.
  2. Default session > `Indefinitely`. Read the shortcut note. Press ⇧⌘A, then stop.
  3. Set Default session back to 20 minutes and Mode back to `Lid-open, display on`.
  Expected: 1: the status ends `(keep the lid open; the display may sleep)`. 2: the note says `...starts a session without an end time, or stops the running one...`, and the notification says `... until you stop it.`.

- [ ] **5.5 The shortcut while a menu or a password field is open** (6 min)
  Sources: plan-2.3.0 12 QA 2, 15.3 item 10.
  Steps:
  1. Ctrl-click to open Awake's menu, then press ⇧⌘A while it is open. Stop the session.
  2. Open Finder's File menu and press ⇧⌘A. Stop again.
  3. Focus a password field in Safari and press ⇧⌘A. Stop again.
  Expected: 1: the menu closes and one session starts (one `Awake started`), with no second action (no stop, no `Awake is already on`). 2 and 3: write down whether it fires. Nothing else may happen: no character typed, no menu action.

- [ ] **5.6 The shortcut across quit, relaunch and reinstall** (12 min)
  Sources: plan-2.3.0 15.3 item 13, 6.12 (parts 1 and 2).
  Steps:
  1. Box on: Ctrl-click > Quit and press ⇧⌘A. Reopen Awake, open Settings and press ⇧⌘A (then stop).
  2. Box off: quit, reopen, open Settings and press ⇧⌘A. Turn the box on again.
  3. `cd ~/awake && bash install-awake.sh`, then press ⇧⌘A (then stop).
  Expected: 1: while Awake is quit the shortcut does nothing in Awake; after reopening the box is still on and the shortcut works without a new recording. 2: the box stays off and the shortcut does nothing in Awake. 3: it still works, with no permission prompt (no Accessibility or Input Monitoring request).

- [ ] **5.7 The shortcut taken by another app** (20 min)
  Sources: plan-2.3.0 6.10, 6.12 (part 3), 15.3 item 9 (optional part).
  Needs: Shortcut box on.
  Steps:
  1. `cd ~/awake && tools/build-awake-app.sh --output-app /tmp/Awake2.app`
  2. Quit the installed Awake. Run `/tmp/Awake2.app/Contents/MacOS/AwakeStatusBar &`: the copy takes ⇧⌘A.
  3. `open ~/Applications/Awake.app`. The newest icon is leftmost.
  4. In the installed copy's Settings, uncheck and check the box. Then record Control-Option-Command-A, and record ⇧⌘A again.
  5. Quit the installed Awake. `defaults write net.kaenmaki.awake.statusbar startShortcutEnabled -bool false`, then open the installed app.
  6. Quit the copy from its menu (the left icon), `rm -rf /tmp/Awake2.app`, and turn the box on again.
  7. Optional: with a launcher that uses a global shortcut (Raycast, Alfred, Rectangle, BetterTouchTool), record its combination in Awake, then quit and reopen Awake while the launcher holds it.
  Expected:
  - 3: the launch posts `Awake needs attention`: `The keyboard shortcut ⇧⌘A is not available, as another app uses it. Choose another in Awake's Settings.`.
  - 4: the box stays on, and the note reads `Another app uses ⇧⌘A. Choose another shortcut.` in red. Recording another combination clears it (grey). If no red note appears, write that down (kEventHotKeyExclusive may not report it, plan-2.3.0 9).
  - 5: with the box off, no `Awake needs attention` is posted.
  - 7: write down whether Awake refuses (`Another app uses ...`) or both apps react, and whether `Awake needs attention` appears at launch.

- [ ] **5.8 Other keyboard layouts** (14 min)
  Sources: plan-2.3.0 6.9, 15.3 item 12.
  Needs: the French (AZERTY) and Finnish or German input sources. CAUTION: Shift-Command-Q asks to log out.
  Steps:
  1. Quit Awake and delete startShortcut and startShortcutEnabled (as in 5.1).
  2. Select the French layout, open Awake and Settings, and check Shortcut.
  3. In Finder press Shift-Command with the key labelled A on AZERTY (the US Q position), twice.
  4. Press Shift-Command-Q (the AZERTY Q, at the US A position). When the Log Out dialog appears, click Cancel.
  5. `defaults read net.kaenmaki.awake.statusbar startShortcut`
  6. Switch to US/ABC and press Shift-Command with the same physical key.
  7. Switch to Finnish or German and record Control-Option-Command with the key right of L.
  8. Clean up: back to your layout, quit Awake, delete startShortcut, reopen, check the box (⇧⌘A).
  Expected: 3: the key toggles Awake (start, then stop). 4: Shift-Command-Q still brings the Log Out dialog. 5: `keyCode = 12`. 6: the same physical key still toggles Awake, so Awake takes Shift-Command-Q on US. This is documented in the README and accepted (plan-2.3.0 9). 7: the label shows `Ö`.

- [ ] **5.9 The shortcut rule for an update from 2.2.0 (simulated)** (5 min)
  Sources: plan-2.3.0 6.8 (quick path; the real path is 11.2).
  Steps:
  1. Record Control-Option-Command-A. Quit Awake. `defaults delete net.kaenmaki.awake.statusbar startShortcutEnabled` (keeping startShortcut). Reopen, open Settings, press the shortcut in another app.
  2. Quit. Also `defaults delete net.kaenmaki.awake.statusbar startShortcut`. Reopen and open Settings.
  3. Check the box and record ⇧⌘A again.
  Expected: 1: the box is on, the button shows `⌃⌥⌘A`, and it starts and stops Awake. 2: the box is off, with `⇧⌘A` dimmed.

### 5B. The menu and the icon

- [ ] **5.10 Menu start and stop, and the menu's items** (8 min)
  Sources: faster-start-stop 8.3; plan-2.3.0 12 QA 1, 12 QA 3, 14 QA (Ctrl-click menu, steps 1 and 2).
  Steps:
  1. Awake off: Ctrl-click and read every item.
  2. Choose Start default session. Then Ctrl-click with the session running and read the items.
  3. Choose Stop session.
  4. Uncheck the Shortcut box. Ctrl-click, hover over Start default session for its tooltip, choose it, check `awake --status`, then stop. Check the box again.
  Expected:
  - Sentence case throughout.
  - 1: `Awake is off` or `Awake has been off for ...`, `Start default session` with `⇧⌘A` at the right, `Help`, `Settings…` (Command-comma), `Quit`.
  - 2: the bold A at once with `Starting Awake…`, one `Awake started`. The menu reads: the status line `Awake is on and has ...`, `Add 1 hour`, `Stop session` (with `⇧⌘A`), a separator, `Help`, `Settings…`, `Stop Awake and quit`.
  - 3: the regular A at once with `Stopping Awake…`, one `Awake stopped`.
  - 4: no key equivalent while the box is off. The tooltip reads `Starts a session of 20 minutes, in the mode set under Keyboard shortcut in Settings.`. It starts a 20-minute lid-open session, the icon bold at once.

- [ ] **5.11 Starts from the CLI's picker** (27 min)
  Sources: faster-start-stop 8.7 (steps 1 and 2); plan-2.3.0 15.4 item 10, 15.3 item 14, 15.4 item 12 (step 5: `defaults write` picked up by the next picker).
  Needs: Use custom password dialog off (the CLI shows the picker).
  Steps:
  1. Click the icon and watch it as the picker opens. Click Cancel.
  2. Click again and choose 20 minutes with `Keep laptop awake with lid closed` checked. Stop it. Then start with ⇧⌘A (lid-open Mode), stop, and click the icon again: look at the lid checkbox. Cancel. Then start with Ctrl-click > Start default session, stop, and click the icon again: look at the lid checkbox. Cancel.
  3. Click again and choose 20 minutes with the lid box unchecked. Stop it.
  4. Go through the picker:
     - 1 row (one length, Include Indefinitely off) and 16 rows (15 lengths plus Indefinitely), without clipping;
     - three buttons side by side (Start, Cancel, Custom…; in Custom…: Start, Cancel, Back);
     - a double-click on a row starts;
     - keyboard-only use, and VoiceOver;
     - Custom… For: 365 days is accepted, more is refused;
     - Custom… Until: the hint, the minute rollover, and 12- and 24-hour time (System Settings > General > Date & Time);
     - Custom… While: apps, terminal commands, shells excluded, and a process that exits before Start;
     - Back keeps the state.
  5. Run `defaults write net.kaenmaki.awake.statusbar pickerDurations '300 1200 3600 indefinite'` and click the icon. Then Settings > Restore defaults.
  Expected:
  - 1: the icon dims (regular A, dimmed) at the click, before the picker appears. After Cancel: regular, not dimmed, nothing posted.
  - 2: both times the lid box is still checked, as last chosen in the picker; neither the shortcut start nor Start default session changed it.
  - 3: regular and dimmed while the picker is open, bold once the session runs.
  - 4: as listed.
  - 5: the picker lists 5 minutes, 20 minutes, 1 hour and Indefinitely.

- [ ] **5.12 Add time and Time to add** (8 min)
  Sources: faster-start-stop 8.8 (lid-open part); plan-2.3.0 13 QA 1, 13 QA 2, 13 QA 3.
  Steps:
  1. Settings > Time to add > `30 minutes`. Start default session.
  2. Ctrl-click: read the Add item and choose it. Hover over the icon while it runs.
  3. In the session lengths list select `30 minutes` and click minus. Look at Time to add. Choose 1 hour there, and open the pop-up again.
  4. Click Restore defaults. Stop the session.
  Expected: 2: the menu reads `Add 30 minutes`. The icon stays bold, not dimmed, with the tooltip `Adding time…` (brief on a lid-open session). One `Awake extended` with the new status line, about 50 minutes left, and no Tink. 3: Time to add still shows `30 minutes` until another time is chosen; then `30 minutes` is gone from it. 4: Time to add is `1 hour`, the session lengths are the built-in list again (with 30 minutes) and the default 20 minutes; the other settings are unchanged. (6.3 checks Add with a password dialog open.)

- [ ] **5.13 The Add item for each end mode** (8 min)
  Sources: plan-2.3.0 15.4 item 13.
  Steps: start each in turn and Ctrl-click: For (`awake --backend caffeinate --duration 20m`), Until (`awake --backend caffeinate --until HH:MM`), Indefinitely (`awake --backend caffeinate --indefinite`), `sleep 600 & awake --backend caffeinate -w $!` without a time option, and `awake --backend caffeinate -w $! --duration 1h`. Stop each. If leftover settings happen later (6.4), Ctrl-click then too.
  Expected: `Add 1 hour` (the Time to add) appears for For, Until, and a process-bound session with a time limit. It is hidden for Indefinitely, a process-bound session without an end time, and leftover settings. It disappears once the session ends.

- [ ] **5.14 Already on** (3 min)
  Sources: faster-start-stop 8.10, 8.38 (step 2); plan-2.3.0 15.3 item 7.
  Needs: Sound on (to hear that nothing plays).
  Steps: `awake --start --backend caffeinate --duration 10m`. Within about 10 s, before the icon turns bold on its own, press ⇧⌘A. Then `awake --status` and `awake --stop`.
  Expected: the icon turns bold at once and stays bold. One banner, `Awake is already on`, with the status line. No Tink, and no time is added (about 10 minutes left). The Terminal start posts no banner.

- [ ] **5.15 A refused start: the CLI missing** (3 min)
  Sources: faster-start-stop 8.9 (part 2), 8.38 (step 3). The low-battery refusal is 7.12.
  Needs: Sound on.
  Steps: `chmod -x "$HOME/Library/Application Support/Awake/bin/awake"`; press ⇧⌘A; then at once `chmod +x "$HOME/Library/Application Support/Awake/bin/awake"`.
  Expected: bold, then regular. Exactly one `Awake failed`: `Awake is not installed at /Users/<you>/Library/Application Support/Awake/bin/awake. Run the installer again.`. No Tink.

- [ ] **5.16 Stop and quit** (4 min)
  Sources: faster-start-stop 8.12; plan-2.3.0 15.2 item 7 (part 1).
  Steps: start a lid-open session from the app and note the token (`awake --status-json | grep -o '"session_token":"[^"]*"'`). Ctrl-click > Stop Awake and quit. Then `open ~/Applications/Awake.app` and `defaults read net.kaenmaki.awake.statusbar | grep -A8 lastSessionHeat`.
  Expected: the regular A at once, one `Awake stopped`, then the app quits and its icon disappears. After reopening, lastSessionHeat holds that token with `endedAt` at the stop, and `sessionHeatInProgress` is gone.

- [ ] **5.17 Clicks while a command runs** (2 min)
  Sources: faster-start-stop 8.14.
  Steps: click the icon so the CLI's picker opens. While it is open: click the icon again, press ⇧⌘A, and Ctrl-click. Then Cancel the picker.
  Expected: the click does nothing, and ⇧⌘A beeps. Ctrl-click opens the menu with `Starting Awake…` first. Start default session, Install helper… (if shown) and Quit are disabled; Help and Settings… stay enabled.

- [ ] **5.18 Twenty start-stop cycles** (8 min)
  Sources: faster-start-stop 8.15.
  Steps: 20 times: ⇧⌘A to start, watch the icon for 10 s, ⇧⌘A to stop, watch for 10 s.
  Expected: the icon never flips back to the previous state between presses.

- [ ] **5.19 One status read per action, no polls while the picker is open, and no `--sound`** (7 min)
  Sources: faster-start-stop 8.25, 8.25a (part 1), 8.39.
  Needs: Sound on. A second Terminal window.
  Steps:
  1. Watch every awake run, one line per process:
     ```
     while :; do pgrep -lf 'Awake/bin/awake'; sleep 0.05; done | awk '!seen[$1]++ { "date +%T" | getline t; close("date +%T"); print t, $0; fflush() }'
     ```
  2. Right after a poll line appears, press ⇧⌘A. Wait about 5 s and press it again.
  3. With Awake off, click the icon and leave the CLI's picker open for 30 s. Note the time, then click Cancel.
  4. Start with a click through the picker, and stop with a click.
  5. Keep the watch running for 5.24.
  Expected: each action shows exactly one `--status-json` just before its `--gui --start ...` or `--gui --stop` line, and none right after. The start also shows `--caffeinate-start` and `--caffeinate-runner`. A `--status-json` poll appears about every 10 s, none during a start or stop. 3: no `--status-json` line while the picker is open (30 s, so about three polls are skipped); the polls come back within about 10 s of Cancel. No action line contains `--sound`.

- [ ] **5.20 The thermal state from the app** (10 min)
  Sources: faster-start-stop 8.31, 8.32, 8.36.
  Steps:
  1. `launchctl setenv AWAKE_DEBUG true`; Ctrl-click > Quit; `open ~/Applications/Awake.app`.
  2. Press ⇧⌘A (lid-open). `grep foreground_thermal_state /tmp/keep-awake-lid-closed-$UID/awake-debug.log`
  3. With the session running: `for p in $(pgrep -f -- '--caffeinate-(start|runner)'); do ps -E -ww -o command= -p "$p" | grep -c AWAKE_APP_THERMAL_STATE; done`
  4. Stop. `launchctl unsetenv AWAKE_DEBUG`; quit and reopen the app; `rm /tmp/keep-awake-lid-closed-$UID/awake-debug.log`.
  5. Settings > Stop when too hot on: 5 starts and stops with ⇧⌘A. Then off: 5 more. Turn it back on.
  Expected: 2: a line ending `foreground_thermal_state source=app state=0 age=0` (state is the current thermal state; age rarely 1). 3: only `0` lines, one per process. 5: it feels as fast with the setting on as off.

- [ ] **5.21 Sounds from the app** (8 min)
  Sources: faster-start-stop 8.24, 8.37, 8.38 (step 1).
  Steps:
  1. Sound on: start with ⇧⌘A, stop with Ctrl-click > Stop session. Start with ⇧⌘A, stop with ⇧⌘A. Start with a click through the picker, stop with Stop session.
  2. During one session: Ctrl-click > Add 1 hour.
  3. Sound off: start and stop once with ⇧⌘A and once through the picker.
  Expected: 1: each start plays Tink once as `Awake started` appears, and each stop once as `Awake stopped` appears. 2: `Awake extended`, no Tink. 3: no Tink.

- [ ] **5.22 The app keeps the CLI quiet, also with AWAKE_NOTIFICATIONS set** (7 min)
  Sources: plan-2.4.0 6.9 (and 10, "Awake.app with any CLI").
  Needs: Sound on.
  Steps:
  1. Start from the app (Start default session). While it runs: `pgrep -fl -- '--notify-wait'`. Click to stop.
  2. `launchctl setenv AWAKE_NOTIFICATIONS true; launchctl setenv AWAKE_DEBUG true`. Ctrl-click > Quit, then `open ~/Applications/Awake.app`.
  3. Repeat 1.
  4. `grep -E 'notify_gui|start_gui_completion_notifier|play_notification_sound|post_notification' /tmp/keep-awake-lid-closed-$UID/awake-debug.log`
  5. `launchctl unsetenv AWAKE_NOTIFICATIONS; launchctl unsetenv AWAKE_DEBUG`. Quit and reopen the app. `rm -f /tmp/keep-awake-lid-closed-$UID/awake-debug.log`
  Expected: at each start exactly one Tink and one `Awake started`, and at each stop one Tink and one `Awake stopped`, all from the app (plan-2.4.0 6.9 still says the start Tink comes from the CLI; since `29e53db` it comes from the app, still one). pgrep prints nothing. Step 3 gives the same. Step 4 shows `notify_gui gui_only_suppressed message=Awake started` and `start_gui_completion_notifier gui_only_suppressed`, and no `play_notification_sound` or `post_notification` line.

- [ ] **5.23 Notifications turned off in System Settings** (4 min)
  Sources: plan-2.3.0 15.3 item 15.
  Needs: Sound on.
  Steps: System Settings > Notifications > Awake > Allow notifications off. Press ⇧⌘A to start and again to stop. Turn notifications back on.
  Expected: each press still starts and stops. No banners. The icon changes at each press, and Tink plays at the start and at the stop (both from the app).

- [ ] **5.24 Mixed versions: old CLI with the new app, old app with the new CLI** (12 min)
  Sources: faster-start-stop 8.29.
  Needs: the copies from 0.5; Sound on; the watch of 5.19.
  Steps:
  1. `install -m 755 ~/awake-2.3.0-cli "$HOME/Library/Application Support/Awake/bin/awake"`. Start and stop with ⇧⌘A and with a click.
  2. `install -m 755 ~/awake/bin/awake "$HOME/Library/Application Support/Awake/bin/awake"`
  3. Quit the app. `open ~/Awake-2.3.0.app`. Start and stop with ⇧⌘A and with a click. Quit it, then `open ~/Applications/Awake.app`.
  4. Stop the watch (Ctrl-C).
  Expected: 1: start and stop work. The icon changes at once (that is in the app). The watch shows a `--status-json` after each action, as the old CLI writes no report. One banner and one Tink per start and stop. 3: start and stop work. The icon changes only when the command ends (the old app). The old app passes `--sound`, so the new CLI plays the start Tink and the old app the stop Tink: one each.

- [ ] **5.25 No temporary files left** (1 min)
  Sources: faster-start-stop 8.30.
  Steps: `ls "$TMPDIR" | grep awake-statusbar`
  Expected: prints nothing.

### 5C. The Settings and Help windows

- [ ] **5.26 Esc and Command-period close Settings** (12 min)
  Sources: plan-2.3.0 6.1, 6.2, 6.3.
  Needs: for step 2, System Settings > Keyboard > Keyboard navigation on.
  Steps:
  1. Ctrl-click > Settings…, press Esc.
  2. With Keyboard navigation on, reopen Settings (Command-comma), Tab to each control in turn and press Esc, reopening each time: a checkbox (Sound on), the Mode pop-up, the session lengths list, the Default session pop-up, the Time to add pop-up, the Stop at low battery level pop-up. The pop-ups are focused, not open.
  3. Reopen and press Command-period.
  4. Click the shortcut button and press Esc once. Click it again, hold Esc for about 2 s, release. Press Esc again.
  5. Reopen, click the shortcut button, then uncheck the Shortcut box. Press ⇧⌘A in Finder. Check the box again.
  6. Click `+` under the session lengths (the popover opens) and press Esc. Click the Mode pop-up so its menu is open, press Esc. Press Esc once more.
  Expected: 1 to 3: Esc closes the window (title `Awake settings`) whatever has focus; Command-period too. 4: the first Esc ends recording, showing the old shortcut, and the window stays; a held Esc also only ends recording; the next Esc closes the window. If a held Esc closes the window, record it as a bug. 5: recording ends and the shortcut is off at once: the button shows it dimmed, and ⇧⌘A opens Applications in Finder. 6: Esc closes only the popover, then only the Mode menu, then the window.

- [ ] **5.27 Labels, Select all and alignment** (8 min)
  Sources: plan-2.3.0 14 QA (Settings window), 6.11, 13 QA 4, 15.4 item 12 (step 2: the `+` field supports ⌘C and ⌘V).
  Needs: light and dark appearance (System Settings > Appearance).
  Steps:
  1. Read the title and every label and button.
  2. Click `+`, type in the field, press Command-A, then Command-C and Command-V.
  3. In light mode, then dark mode, compare the left edges: the shortcut button with the Mode pop-up; the `Mode` label with the checkbox title `Shortcut`; the `Default session` pop-up with the `Time to add` pop-up. Take a screenshot of each (Shift-Command-4, Space, click the window).
  Expected: 1: the title is `Awake settings`. Labels include `Restore defaults`, `Default session` (not `Default selection`), `Time to add`, `Start without password`, `Use custom password dialog`, `Stop at low battery`, `Stop when unplugged`, and `Include Indefinitely`. 2: Command-A selects all the text, and copy and paste work. 3: each pair lines up in both appearances. Keep the screenshots.

- [ ] **5.28 Stop at low battery settings** (9 min)
  Sources: plan-2.3.0 11 QA 1, 11 QA 2, 15.4 item 9.
  Steps:
  1. Quit Awake. `defaults delete net.kaenmaki.awake.statusbar lowBatteryGuardEnabled; defaults write net.kaenmaki.awake.statusbar minBatteryPercent -int 0` (2.2.0's `Never`). Open the app and Settings.
  2. Quit. `defaults delete net.kaenmaki.awake.statusbar lowBatteryGuardEnabled; defaults write net.kaenmaki.awake.statusbar minBatteryPercent -int 10`. Reopen.
  3. Quit. `defaults delete net.kaenmaki.awake.statusbar minBatteryPercent; defaults delete net.kaenmaki.awake.statusbar lowBatteryGuardEnabled`. Reopen.
  4. Choose 15%. Uncheck `Stop at low battery`, check it again. Uncheck it and try to open the level pop-up. Then check it and choose 5%.
  Expected: 1: unchecked, the pop-up dimmed at `5%`. 2: checked at `10%`. 3: checked at `5%`. 4: the level stays at 15% across the toggle; with the box off the pop-up is dimmed and does not open.

- [ ] **5.29 Settings that persist, Launch at login and Start without password** (20 min)
  Sources: plan-2.3.0 15.4 item 12 (the `defaults write` sub-item is 5.11 step 5; the ⌘C and ⌘V sub-item is 5.27 step 2); faster-start-stop 8.28.
  Needs: the admin password.
  Steps:
  1. Add and remove lengths, toggle Include Indefinitely, and click Restore defaults.
  2. Change every setting, quit and reopen. Then put them back as in 0.6.
  3. Launch at login on, then off: `ls ~/Library/LaunchAgents/net.kaenmaki.awake.statusbar.plist` each time.
  4. Start without password: click it and cancel the prompt. Then click it and enter the password. Do it twice, to turn it on and off, then leave it as in 0.6.
  5. Command-W closes Settings, and Help (Ctrl-click > Help).
  6. Open Settings. Start a 1-minute lid-open session from the app: click the icon, Custom…, For, Hours 0 and Minutes 1, `Keep laptop awake with lid closed` unchecked, Start. Note the time. Before it ends, click Start without password in Settings so its macOS password dialog is open. Leave the dialog open until at least 15 s after the session's end, then click Cancel. (Do not use `awake --stop` here: `--passwordless on|off` holds awake's state-change lock while its dialog is open, so a Terminal stop would wait about 10 s and fail with `Another awake command is already changing the session state. Please try again.`.)
  Expected: 1: Restore defaults also sets Time to add to 1 hour. 2: each setting survives the relaunch. 3: the plist exists only while Launch at login is on. 4: a cancelled prompt leaves the box as it was. With the password, the box shows the new state as soon as the command ends, without waiting for the 10 s poll. Use custom password dialog is dimmed while Start without password is on. 5: Command-W works. 6: while the dialog is open the tooltip shows `Updating Awake’s helper…` and the icon stays bold, not dimmed. At the end, exactly one `Awake finished` (`The timed session finished.`) appears while the dialog is still open, from the app's poll, and the icon turns regular within about 12 s of the end. Nothing more is posted after Cancel, and the box stays as it was.

- [ ] **5.30 The heat note's layout** (5 min)
  Sources: plan-2.3.0 15.2 item 9.
  Needs: a summary with a report (from 7.8 or 7.10, if the Mac got hot; otherwise come back to this after section 7), and none.
  Steps:
  1. Open Settings with a report.
  2. Quit, `defaults delete net.kaenmaki.awake.statusbar lastSessionHeat`, reopen and open Settings.
  3. Keep Settings open while a session with a report ends.
  Expected: the note appears under Stop when too hot, lined up with its title. The window grows and shrinks with it, without clipping or a blank strip, and the right margin stays. On a screen too short for the window, it stays capped and scrolls.

- [ ] **5.31 Settings on a small display** (14 min)
  Sources: plan-2.3.0 12 QA 5, 16 QA 1, 16 QA 2, 16 QA 5, 16 QA 6.
  Needs: a 1280x800 display, or a scaled resolution about 800 points high. Keyboard navigation on.
  Steps:
  1. Open Settings, scroll to the bottom, press Esc.
  2. Reopen. Tab through every control.
  3. Scroll with the pointer over the session lengths list, then elsewhere.
  4. System Settings > Appearance > Show scroll bars `Always`, open Settings. Switch the setting back while Settings is open.
  Expected: 1: the window reaches from below the menu bar to the Dock, scrolls down to the `Session lengths` note, and Esc closes it. 2: the focused control scrolls into view. 3: over the list it scrolls the list; elsewhere the window. 4: the scroll bar does not cover the content's right edge, and switching the setting resizes the window.

- [ ] **5.32 Optional: Settings on a large display and across two** (7 min)
  Sources: plan-2.3.0 16 QA 3, 16 QA 4.
  Needs: a large display, and a small one connected.
  Steps: open Settings on the large display. Drag it to the small one, then back.
  Expected: on the large display, no scroll bar, as in the owner's screenshots. On the small one it shrinks to fit and scrolls; back on the large one it grows again.

- [ ] **5.33 The Help window** (14 min)
  Sources: plan-2.3.0 6.3 (Help window sub-item), 14 QA (Help); plan-2.4.0 6.13 (part 2); release procedure (README and Help window).
  Steps:
  1. Ctrl-click: the item reads `Help`, without an ellipsis. Open it. Press Esc without clicking.
  2. Reopen, click into the page text, press Esc.
  3. Reopen, enter full screen (Control-Command-F), press Esc.
  4. Reopen and read: the opening (two paragraphs, three comparison bullets, `Install it with Homebrew:` and a code block); `Current version: 2.3.0`; the notifications bullet under "What it does"; the Menu bar app paragraph; the `--stop` sentence; the "Notifications" section; the Options bullets for `--sound`, `--notifications` and `--no-notifications`; the examples `awake --notifications -- make build` and `awake --gui-custom --notifications --sound`; the "Dry-run and self-test" bullets.
  5. Optional, the plain-text fallback (5 more minutes):
     `cd ~/awake && tools/build-awake-app.sh --output-app /tmp/AwakeNoGuide.app && rm /tmp/AwakeNoGuide.app/Contents/Resources/README.md && codesign --force --sign - /tmp/AwakeNoGuide.app`
     Quit the installed Awake, run `/tmp/AwakeNoGuide.app/Contents/MacOS/AwakeStatusBar &`, Ctrl-click > Help, press Esc. Quit that copy, `rm -rf /tmp/AwakeNoGuide.app`, `open ~/Applications/Awake.app`.
  Expected:
  - The window is titled `Awake help` and shows the whole README. It closes on Esc before and after clicking in. In full screen it closes and leaves the space; if Esc only leaves full screen, write that down.
  - The version line says 2.3.0 on the dev build (not a bug).
  - Each changed bullet is one bullet, not split, with no stray `- `, and the code spans render. The opening has no stray paragraph line.
  - Known and accepted: under Installation > With Homebrew, `[Homebrew](https://brew.sh)` shows literally (the renderer has no links; the same in 2.3.0).
  - 5: the window shows `The bundled Awake guide could not be found.`. Note whether Esc closes it; it may not (plan-2.3.0 9). Normal installs never show this view, so it does not block the release.

- [ ] **5.34 VoiceOver in Settings** (5 min)
  Sources: plan-2.3.0 6.13.
  Needs: VoiceOver (Command-F5).
  Steps: open Settings and move VoiceOver (VO-Right) to the Shortcut box and the shortcut button, once with the box on and once off. Start a recording and listen to the button.
  Expected: the box reads `Use keyboard shortcut, checkbox` (checked or unchecked). The button reads `Keyboard shortcut, Shift Command A`, and is announced as dimmed or unavailable while the box is off. While recording, its value is `Recording`.

- [ ] **5.35 VoiceOver and the icon** (8 min)
  Sources: faster-start-stop 8.17 (the lid-closed case is in 6.8).
  Needs: Accessibility Inspector (Xcode > Open Developer Tool) or VoiceOver (VO-M, then M, then the arrow keys to Awake).
  Steps: inspect the icon idle; click while off and leave the CLI picker open (regular, dimmed); then cancel the picker.
  Expected: idle `Awake is off`. With the picker open the description reads `Starting Awake…`; note whether VoiceOver adds "dimmed" or reads the button as unavailable. After Cancel `Awake is off`.

## 6. Lid-closed sessions: with a password, then password-free

Plugged in. The helper must be installed. 6.1 needs the password twice. 6.2 to 6.5 run with password-free mode off and the macOS dialog (Use custom password dialog off). 6.6 and 6.7 use Awake's own dialog. 6.8 to 6.12 run with password-free mode on. The app keeps a password entered in its own dialog for 2 minutes; turning Use custom password dialog off and on clears it.

- [ ] **6.1 The helper removed and reinstalled** (12 min)
  Sources: plan-2.3.0 14 QA (Ctrl-click menu, steps 3 and 4); faster-start-stop 8.13, 8.25a (part 2; part 1 is 5.19).
  Needs: the admin password; the watch of 5.19 in a second window; Use custom password dialog off.
  Steps:
  1. `awake --uninstall-helper` (password in Terminal; this also removes the password-free rule).
  2. Within about 12 s, Ctrl-click. Look at where `Install helper…` is.
  3. `awake --start --backend caffeinate --duration 1m`, and wait until the icon turns bold.
  4. Ctrl-click > Install helper…. Leave its macOS password dialog open until at least 15 s after the 1-minute session ends. Watch the icon, the tooltip and the watch. Click Cancel.
  5. Ctrl-click > Install helper… again and enter the password. Look at the icon and the tooltip.
  6. Settings: check Start without password. While its dialog is open, look at the icon and the checkbox. Enter the password. (Leave it on or off as 6.2 needs: off.)
  Expected:
  - 2: `Install helper…` appears after `Settings…`, before the separator above Quit.
  - 4: polls go on about every 10 s while the dialog is open, and the icon turns regular within about 12 s of the session's end. Nothing is posted (a Terminal session). The icon neither changes nor dims for the install itself (tooltip `Updating Awake’s helper…`).
  - 5: the same, and `Install helper…` disappears afterwards.
  - 6: the icon neither changes nor dims; Start without password is dimmed while the command runs, then shows on.
  - Changed from faster-start-stop 8.25a part 2: the plan ran `awake --stop` while the Install helper dialog was open. `--install-helper` holds awake's state-change lock during its dialog, so that stop would wait about 10 s and fail with `Another awake command is already changing the session state. Please try again.`. A session that ends on its own replaces it.

- [ ] **6.2 Lid-closed start with the macOS dialog** (12 min)
  Sources: faster-start-stop 8.5, 8.27 (part 2), 8.38 (step 4); plan-2.3.0 12 QA 4, 15.3 item 4 (first set-up), 15.3 item 8.
  Needs: password-free mode off, Use custom password dialog off, Mode `Lid-closed`, Sound on.
  Steps:
  1. Press ⇧⌘A. While the macOS dialog is open, look at the icon and press ⇧⌘A again. Click Cancel.
  2. Press ⇧⌘A and enter the password. Then press ⇧⌘A to stop.
  3. Ctrl-click > Start default session. Cancel. Choose it again and enter the password. Stop with Ctrl-click > Stop session.
  Expected:
  - The macOS administrator dialog comes to the front with keyboard focus. While it is open the icon is the regular A, dimmed. The second press beeps, and no second dialog follows.
  - Cancel: regular, not dimmed, nothing posted, no second dialog.
  - Password: the bold A (solid) once the session runs, `Awake started` reads `The Mac will stay awake with the lid closed for 20 minutes.`, and Tink plays once, after the dialog.
  - The stop needs no password (the helper's timer runs): the regular A at once, `Awake stopped` with `Normal sleep settings were restored.`, and Tink.

- [ ] **6.3 Add time while the session ends** (8 min)
  Sources: faster-start-stop 8.8a, 8.8 (lid-closed variant).
  Needs: as 6.2; Time to add 1 hour; Sound on.
  Steps:
  1. Click the icon, choose Custom…, select For, and set Hours 0 and Minutes 2 (two number fields with steppers). Check `Keep laptop awake with lid closed`, click Start, and enter the password. Note the time.
  2. Right away, Ctrl-click > Add 1 hour. With the dialog open, look at the icon and hover (`Adding time…`). Enter the password. Then Stop session.
  3. Start a 2-minute session again as in 1 (Custom…, For, Hours 0, Minutes 2, lid box checked). When about 30 s are left, Ctrl-click > Add 1 hour, and leave the dialog open until at least 15 s after the original end. Watch the icon and Notification Center, then click Cancel.
  4. `pmset -g | grep SleepDisabled`
  Expected: 2: the icon stays bold, not dimmed, with `Adding time…`; then one `Awake extended`, no Tink. 3: the icon turns regular within about 12 s of the end while the dialog is still open, and nothing is posted while it is open. After Cancel it stays regular, and the end is announced exactly once: `Awake finished`, `The timed session finished and normal sleep settings were restored.`, with one Tink. 4: `SleepDisabled 0`.

- [ ] **6.4 Sleep left off: restore, and Stop and quit cancelled** (8 min)
  Sources: faster-start-stop 8.11, 8.12a.
  Needs: as 6.2; no session.
  Steps:
  1. `sudo pmset -b disablesleep 1`, and wait until the icon turns bold (12 s at most). Wait about 20 s more.
  2. Ctrl-click: check the Add item is hidden (5.13). Click the icon. While the macOS dialog is open, look at the icon. Cancel.
  3. Click again and enter the password. `pmset -g | grep SleepDisabled`
  4. `sudo pmset -b disablesleep 1` again, wait for bold. Ctrl-click > Stop Awake and quit. While the dialog is open, look at the icon. Cancel.
  5. Ctrl-click > Stop session and enter the password. `pmset -g | grep SleepDisabled`
  Expected: 1: bold, and about 20 s later (two polls) one `Awake needs attention`: `Sleep is still turned off, but no Awake session is running. Click the Awake icon to restore normal sleep.`. 2: bold and dimmed while the dialog is open (`Stopping Awake…`); after Cancel solid bold, nothing posted. 3: regular, nothing posted (not an app session), `SleepDisabled 0`. 4: bold and dimmed while open; after Cancel bold, not dimmed. The app stays and posts `Quit cancelled`: `Awake is still running because the stop command did not finish.`. 5: regular and `SleepDisabled 0`.

- [ ] **6.5 How the dimmed icon looks** (15 min)
  Sources: faster-start-stop 8.16.
  Needs: as 6.2; macOS 26 for the last case.
  Steps: hold each dimmed state. Regular and dimmed: click while off and leave the CLI picker open. Bold and dimmed: `sudo pmset -b disablesleep 1`, wait for bold, click, and leave the macOS dialog open (Cancel afterwards; at the end, Stop session with the password brings SleepDisabled back to 0). For each, compare with the solid bold and regular A under: Appearance Light and Dark; Accessibility > Display > Increase contrast; Reduce transparency; a busy wallpaper; macOS 26's transparent menu bar (System Settings > Menu Bar).
  Expected: the dimmed icon stays visible in every combination, and its bold and regular A can be told apart. If it is too faint, note the combination (the fallback is a third template image, faster-start-stop 11).

- [ ] **6.6 Awake's own password dialog and picker** (22 min)
  Sources: faster-start-stop 8.6, 8.7 (step 3); plan-2.3.0 15.3 item 4 (custom dialog set-up), 15.4 item 11.
  Needs: password-free mode off, Use custom password dialog on, Mode `Lid-closed`.
  Steps:
  1. With another app in front, press ⇧⌘A. Awake's dialog opens (`Awake needs your password to change the sleep settings.`). Check that it is in front with the keyboard focus in the password field, and look at the icon. Click Cancel. Then press ⇧⌘A again and enter the password. Stop with ⇧⌘A.
  2. Click the icon and choose 20 minutes lid-open in Awake's picker. Stop it.
  3. Click the icon. In Awake's picker choose each end mode in turn, lid-closed: For, Until, Indefinitely, While. Enter the password when asked, and stop after each. (Within 2 minutes of a password no dialog appears; toggle the setting off and on to see it again.)
  4. Choose Until 1 to 2 minutes ahead, lid-closed, and leave Awake's password dialog open past that time, then enter the password.
  Expected: 1: Awake's dialog comes to the front, and typing goes into its password field at once. Nothing changes on the icon while it is open. Cancel starts nothing: the icon is unchanged and nothing is posted. After the password and OK, the bold A dimmed, then solid, and `Awake started`. 2: nothing changes while the picker is open; bold as soon as it closes. 3: each starts, with the icon unchanged while the picker and dialog are open, then bold and dimmed, then solid. 4: the start fails: the icon goes back to regular, and `Awake failed` reads `The end time HH:MM has already passed.`.

- [ ] **6.7 Sleep left off with Awake's dialog** (4 min)
  Sources: faster-start-stop 8.11a.
  Needs: as 6.6; no session.
  Steps:
  1. `sudo pmset -b disablesleep 1`, wait for bold.
  2. Click the icon: Awake's dialog appears. Look at the icon. Cancel.
  3. Click again and enter the password. `pmset -g | grep SleepDisabled`
  4. Turn Use custom password dialog off. Turn Start without password on (password).
  Expected: the icon does not change while Awake's dialog is open (bold, not dimmed). After Cancel bold, nothing posted. With the password regular at once, not dimmed, and `SleepDisabled 0`.

- [ ] **6.8 Lid-closed start without a password** (10 min)
  Sources: faster-start-stop 8.4, 8.33, 8.17 (lid-closed case); plan-2.3.0 15.3 item 4 (password-free set-up).
  Needs: password-free mode on, Mode `Lid-closed`, Sound on.
  Steps:
  1. In Terminal: `while :; do pmset -g | grep SleepDisabled; sleep 0.2; done`
  2. Press ⇧⌘A and watch the icon and the loop.
  3. With the session running: `sudo ps -E -ww -p "$(sudo awk -F= '$1=="timer_pid"{print $2}' /var/run/net.kaenmaki.awake/session)" | grep -c AWAKE_APP_THERMAL_STATE`. Optionally the same with `guard_pid`.
  4. Press ⇧⌘A to stop. Ctrl-C the loop.
  5. With VoiceOver on the icon (5.35), start again with ⇧⌘A and listen until the icon is solid. Stop.
  Expected: 2: the press alone starts the session: the bold A dimmed at once, then solid. The loop shows `SleepDisabled 1` no later than the icon turns solid. Tink once. 3: `0`. 4: the regular A at once, and SleepDisabled goes back to 0. 5: VoiceOver never says `Awake is on` before the start is done, and says it once the icon is solid.

- [ ] **6.9 Notification and sound matrix** (25 min)
  Sources: faster-start-stop 8.26.
  Needs: Sound on, Shortcut on. Run it with password-free mode on, then off (macOS dialog), then set it back on.
  Steps: for lid-open and for lid-closed (Mode, and the picker's lid box), do each of: ⇧⌘A start; Ctrl-click > Start default session; a click start through the picker; Ctrl-click > Add 1 hour; Ctrl-click > Stop session; Ctrl-click > Stop Awake and quit (then `open ~/Applications/Awake.app`).
  Expected: one `Awake started` per start and one `Awake stopped` per stop (lid-closed: `Normal sleep settings were restored.`). Add 1 hour posts `Awake extended` with no Tink. Exactly one Tink per start and per stop, both from the app. Lid-closed with password-free mode off: starts and Add 1 hour ask for the password; stops do not.

- [ ] **6.10 Sleep at the end despite another assertion** (10 min)
  Sources: plan-2.3.0 15.4 item 1.
  Needs: password-free mode on. Do one run plugged in now, and the battery run with section 7 (or unplug now).
  Steps:
  1. In one window: `caffeinate -i`.
  2. In another: `awake --duration-seconds 60`, and close the lid.
  3. After about 90 s open it: `pmset -g log | grep -E 'Sleep  |Wake  ' | tail`
  4. Repeat on the other power source. Ctrl-C the caffeinate.
  Expected: after the timeout the Mac sleeps within seconds (the helper runs `pmset sleepnow` with the lid closed). No end banner (a Terminal session).

- [ ] **6.11 The guard takes over from a stopped timer** (5 min)
  Sources: plan-2.3.0 15.4 item 2.
  Needs: password-free mode on; sudo.
  Steps:
  1. `awake --indefinite`; `pmset -g | grep SleepDisabled` a few times; `awake --stop`; check again.
  2. `awake --indefinite`. `pid=$(sudo awk -F= '$1=="timer_pid"{print $2}' /var/run/net.kaenmaki.awake/session); sudo kill -STOP $pid`
  3. Wait more than 60 s. `awake --stop; pmset -g | grep SleepDisabled; awake --status-json | grep -o '"last_completion_reason":"[a-z_]*"'`
  4. `sudo kill -CONT $pid`, then `ps -p $pid`.
  Expected: 1: `SleepDisabled 1` throughout, 0 after `--stop`. 3: once the timer's heartbeat is over 60 s old the guard takes over: `--stop` ends the session within a few seconds, `SleepDisabled 0`, reason `stopped`. (Before 60 s the guard ignores the stop request, so wait.) 4: the timer exits.

- [ ] **6.12 A forced power-off during a session** (15 min)
  Sources: plan-2.3.0 15.4 item 7.
  Needs: CAUTION: save all work. Password-free mode on; sudo.
  Steps:
  1. `pmset -g > ~/awake-pmset-before.txt` (also note the values on paper). `awake --indefinite`.
  2. Hold the power button until the Mac turns off, then start it.
  3. `pmset -g`, `awake --status`, `awake --status-json`, and hover over the icon.
  4. `sudo launchctl disable system/net.kaenmaki.awake.boot-restore`. `awake --indefinite`. Force the power-off again and start the Mac.
  5. `awake --status`, `awake --status-json`; wait for the app. Then `awake --stop` and `pmset -g`.
  6. `sudo launchctl enable system/net.kaenmaki.awake.boot-restore`
  Expected: 3: pmset shows the values from before the session. `awake --status` prints `Awake is off.`, the tooltip `Awake has been off for ...`, and `--status-json` has `"last_completion_reason":"restart"`. 5: `awake --status` prints `Sleep is still turned off, but no Awake session is running.` and `Run awake --stop to restore normal sleep.`; `leftover_settings` is true. The app posts `Awake needs attention` once. `awake --stop` restores the values from before the session. (Changed from the plan: `Awake has been off` is only the app's tooltip; and `launchctl disable` replaces "unloaded", which the next boot undoes.)

## 7. Guardrails: battery, heat and unplugging

Start this section fully charged. It runs the plugged-in items first (7.8 needs AC), then 7.11 on battery. 7.11 alone does not bring a full charge down far enough, so 7.11a drains it to 30% or less for the low-battery items 7.12, 7.13 and 7.13a. 7.14 then charges the Mac. Settings > Stop when unplugged is on unless an item says off. App sessions post the end banners; Terminal sessions only with `--notifications`.

- [ ] **7.1 The power source as pmset reports it** (3 min)
  Sources: plan-2.3.0 15.1 item 1.
  Steps: `pmset -g batt` on the adapter and after unplugging. Optional: on an Intel MacBook, and on a desktop with a USB UPS running on its battery.
  Expected: `Now drawing from 'AC Power'`, then `Now drawing from 'Battery Power'`. On the UPS's battery: `'UPS Power'`.

- [ ] **7.2 Short unplugs do not stop a session** (5 min)
  Sources: plan-2.3.0 15.1 item 3.
  Steps: start a session plugged in. Pull the MagSafe connector and put it back within a second or two. Optional: the same with a dock.
  Expected: the session goes on each time (two checks 5 s apart must both find the Mac unplugged).

- [ ] **7.3 A session started unplugged** (5 min)
  Sources: plan-2.3.0 15.1 item 4.
  Steps: unplug, then start a session from the app. Wait 20 s. Plug in, wait 10 s, then unplug.
  Expected: it goes on while unplugged from the start. After plugging in and unplugging, it ends within about 10 s with `Awake stopped: the Mac was unplugged`.

- [ ] **7.4 Stop when unplugged off** (3 min)
  Sources: plan-2.3.0 15.1 item 5.
  Steps: turn Stop when unplugged off. Start a session plugged in, unplug, wait 20 s. Turn the setting back on.
  Expected: nothing changes; the session goes on.

- [ ] **7.5 Unplugged with the lid open** (5 min)
  Sources: plan-2.3.0 15.1 item 6.
  Steps: plugged in, start a lid-open session from the app (picker with the lid box unchecked). Unplug with the lid open.
  Expected: the session ends within about 10 s (maybe a little sooner than in 2.3.0), with `Awake stopped: the Mac was unplugged`. The Mac is not put to sleep.

- [ ] **7.6 Unplugged with the lid closed** (15 min)
  Sources: plan-2.3.0 15.1 item 2.
  Needs: no external display.
  Steps:
  1. Plugged in, click the icon and pick 30 minutes with `Keep laptop awake with lid closed` checked.
  2. Close the lid, wait about 5 s, unplug. After about 30 s open the lid.
  3. `pmset -g log | grep -E 'Using (AC|Batt)|Sleep  |Wake  ' | tail -20` and `awake --status-json`.
  Expected: the Mac sleeps within about 10 s of unplugging (the switch to battery, then a Sleep 5 to 10 s later). After waking, `Awake stopped: the Mac was unplugged` from the app, the regular A, and `last_completion_reason` `unplugged`.

- [ ] **7.7 Optional: unplugged in clamshell mode** (10 min)
  Sources: plan-2.3.0 15.1 item 7.
  Needs: an external display and the adapter.
  Steps: start a lid-closed session, close the lid with the external display in use, then unplug. Afterwards `awake --status-json`.
  Expected: the session ends (`unplugged`). Awake does not run `pmset sleepnow` (AppleClamshellCausesSleep is No with an external display); macOS does what it does on its own.

- [ ] **7.8 Heat recorded under load** (25 min)
  Sources: plan-2.3.0 15.2 item 1.
  Needs: on AC. CAUTION: a full CPU load; keep the Mac on a hard surface.
  Steps:
  1. Start a 20-minute lid-open session from the app.
  2. In another window: `while :; do printf '%s %s\n' "$(date +%T)" "$(osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState')"; sleep 5; done`
  3. Load every core for 10 minutes: `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`, then `killall yes`.
  4. After the end: `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`
  Expected: the seconds at each level, `secondsAtLeastFair` included, match the log to within a poll or two. Unless the log reached serious (2), the heat note stays hidden. A MacBook Pro may never leave nominal.

- [ ] **7.9 The app killed during a session** (12 min)
  Sources: plan-2.3.0 15.2 item 6.
  Steps: start a 10-minute session from the app. `killall AwakeStatusBar`. Wait two minutes, `open ~/Applications/Awake.app`. After the end: `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`.
  Expected: `watchedFromStart` is still 1, and `secondsWatched` is about 2 to 3.5 minutes short of 600. The app still announces the end (`Awake finished`).

- [ ] **7.10 Optional: the overheating guard ends a session** (20 min)
  Sources: plan-2.3.0 15.2 item 4.
  Needs: only if it can be done safely (a MacBook Air with the lid closed under 7.8's load is likeliest). Otherwise tests/app/heat-report-check covers it.
  Steps: start a lid-closed session from the app with Stop when too hot on, close the lid, run the load until the guard ends the session, `killall yes`, wake the Mac. Open Settings; `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`.
  Expected: the note reads `Last session: hot for N minutes, so Awake ended it.`, or, if the Mac reached critical, `Last session: hot for N minutes, very hot for M minutes, so Awake ended it.` (`Last session: the Mac got too hot, so Awake ended it.` if the app missed the heat). `endedOnOverheating = 1`, and the app posted `Awake stopped: the Mac got too hot`.

- [ ] **7.11 Thirty minutes lid-closed on battery** (35 min, mostly waiting)
  Sources: plan-2.3.0 15.2 item 3.
  Needs: battery power.
  Steps: start a 30-minute lid-closed session from the app, close the lid and leave it. The Mac sleeps at the end. Wake it: `defaults read net.kaenmaki.awake.statusbar lastSessionHeat`. Also do 6.10's battery run now if it is still open.
  Expected: `samples` about 180 and `secondsWatched` about 1800 (App Nap did not stop the recording). `Awake finished` from the app. The note appears only if the Mac got hot.

- [ ] **7.11a Bring the charge down to 30% or less** (about 1 to 3 h, unattended; not counted in the total)
  Sources: none; an order step for 7.12, 7.13 and 7.13a.
  Needs: battery power. CAUTION: step 2 is a full CPU load; keep the Mac on a hard surface.
  Steps:
  1. `pmset -g batt`. At 30% or less, go on to 7.12.
  2. Otherwise, unplugged and with no Awake session: `caffeinate -di &` (keeps the Mac and the display awake), then `for i in $(seq $(sysctl -n hw.ncpu)); do yes > /dev/null & done`. Check `pmset -g batt` every 15 minutes. Normal work on the Mac, unplugged, drains it too, only more slowly.
  3. At 30% or less: `killall yes; kill %1` (the caffeinate), then `pgrep -lx caffeinate` prints nothing and `awake --status` prints `Awake is off.`.
  Expected: `pmset -g batt` shows `'Battery Power'` and 30% or less; no `yes` or `caffeinate` left running. If the wait does not fit the stage, take the break here and start the next stage unplugged with 7.12, once the charge is low.

- [ ] **7.12 Starts refused at low battery** (12 min)
  Sources: plan-2.3.0 11 QA 3; faster-start-stop 8.9 (part 1), 8.27 (part 1).
  Needs: battery power at 30% or less (`pmset -g batt`). Settings > Stop at low battery on at 30% (a level equal to the charge also refuses). Sound on.
  Steps:
  1. Mode lid-open: Ctrl-click > Start default session. Then press ⇧⌘A.
  2. Click the icon and pick a length (lid-open).
  3. Mode `Lid-closed`, password-free mode off: press ⇧⌘A.
  4. Uncheck Stop at low battery, start a session, stop it. Check it again at 5%.
  Expected: 1: bold at once, then regular, and one `Awake failed`: `The battery is at N%, too low for a lid-open session. Connect the charger first.`. No Tink. 2: regular and dimmed while the picker is open, then the same failure. 3: no password dialog (the battery check comes first); the icon dims during the command, then is the regular A, not dimmed; `Awake failed` with `... too low for a lid-closed session. Connect the charger first.`, in plain text with no JSON. 4: the session starts.

- [ ] **7.13 Low battery ends a running session** (10 min)
  Sources: plan-2.3.0 15.4 item 5.
  Needs: charge below 50%, the adapter; password-free mode on.
  Steps: plugged in, `awake --min-battery 50 --duration 30m` (lid-closed). Close the lid and unplug. Wait 1 to 2 minutes. Open the lid: `pmset -g | grep SleepDisabled` and `pmset -g log | grep -E 'Sleep  |Wake  ' | tail`.
  Expected: the session ends (`low_battery`), `SleepDisabled 0`, and the Mac slept. No banner (a Terminal session without `--notifications`).

- [ ] **7.13a launchd: `Awake failed` without a terminal** (10 min)
  Sources: plan-2.4.0 6.12.
  Needs: battery power at 50% or less (`pmset -g batt`), as 7.13 leaves the Mac: unplugged, with the charge from 7.11a. If the charge is above 50% (for example when this item is run again later), use the fallback in step 5. Nothing running.
  Steps:
  1. Create and run the agent:
     ```
     AWAKE_BIN="$(command -v awake)"; PLIST=~/Library/LaunchAgents/net.kaenmaki.awake.qa.plist
     cat > "$PLIST" <<EOF
     <?xml version="1.0" encoding="UTF-8"?>
     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
     <plist version="1.0"><dict><key>Label</key><string>net.kaenmaki.awake.qa</string>
     <key>ProgramArguments</key><array><string>$AWAKE_BIN</string><string>--duration</string><string>1h</string><string>--min-battery</string><string>50</string><string>--backend</string><string>caffeinate</string></array>
     <key>StandardOutPath</key><string>/tmp/awake-qa.out</string><key>StandardErrorPath</key><string>/tmp/awake-qa.err</string></dict></plist>
     EOF
     launchctl bootstrap gui/$(id -u) "$PLIST"; launchctl kickstart gui/$(id -u)/net.kaenmaki.awake.qa
     ```
  2. `cat /tmp/awake-qa.err`
  3. Add `--no-notifications`: `/usr/libexec/PlistBuddy -c 'Add :ProgramArguments: string --no-notifications' "$PLIST"; launchctl bootout gui/$(id -u)/net.kaenmaki.awake.qa; launchctl bootstrap gui/$(id -u) "$PLIST"; launchctl kickstart gui/$(id -u)/net.kaenmaki.awake.qa`
  4. Replace it with `-t`: `/usr/libexec/PlistBuddy -c 'Set :ProgramArguments:7 -t' "$PLIST"`, then the same bootout, bootstrap and kickstart.
  5. Fallback above 50%: `awake --backend caffeinate --duration 10m` in Terminal. Set the agent's arguments to `-- /bin/sleep 5`, then `--no-notifications -- /bin/sleep 5`, then `-t -- /bin/sleep 5`, and kickstart after each.
  6. `launchctl bootout gui/$(id -u)/net.kaenmaki.awake.qa; rm -f "$PLIST" /tmp/awake-qa.out /tmp/awake-qa.err`; stop any session.
  Expected: 1: one `Awake failed`, `The battery is at N%, too low for a lid-open session. Connect the charger first.`; step 2 shows the same text. 3: no banner; the text is in the file. 4: no banner; the text is written. Fallback: `Awake failed` with `A session is already running. ...` for the first run, nothing for the other two.

- [ ] **7.14 No heat note after an idle session and after charging** (25 min, mostly waiting)
  Sources: plan-2.3.0 15.2 item 2.
  Needs: a low charge for part 2; Stop when unplugged off for part 2.
  Steps: run a 10-minute idle session from the app; open Settings. Then run a session while charging from the low charge, unplugging and plugging in between; open Settings. Turn Stop when unplugged back on.
  Expected: the heat note stays hidden both times.

## 8. Process-bound and timed sessions

- [ ] **8.1 A suspended command, and a command that exits** (5 min)
  Sources: plan-2.3.0 15.4 item 15.
  Needs: password-free mode on (lid-closed by default); battery and a closable lid for step 2.
  Steps:
  1. `awake -- vim`. Ctrl-Z, `awake --status` in another window, wait a minute, `fg`, quit vim.
  2. On battery: `awake -- sleep 30`, close the lid.
  Expected: 1: the session keeps counting while vim is suspended, and ends when vim exits. 2: when sleep exits the session ends (`process_exited`) and the Mac sleeps. No banners.

- [ ] **8.2 A time-zone change** (8 min)
  Sources: plan-2.3.0 15.4 item 8.
  Steps:
  1. `sleep 3600 & awake -w $! --until HH:MM` (lid-closed), HH:MM an hour ahead.
  2. Change the time zone (System Settings > General > Date & Time: automatic off, another city; or `sudo systemsetup -settimezone Europe/London`).
  3. `awake --status` and the tooltip. Stop.
  4. Repeat with `--backend caffeinate`. Restore the time zone.
  Expected: both sessions keep running, and the menu and `awake --status` show the same Until clock time.

- [ ] **8.3 An Until time passing while the Mac sleeps** (10 min)
  Sources: plan-2.3.0 15.4 item 3.
  Steps: `awake --backend caffeinate --until HH:MM`, 3 minutes ahead. Apple menu > Sleep. Wake it after HH:MM. `awake --status`.
  Expected: the session ends within seconds of waking, and `awake --status` shows `Awake is off.`.

- [ ] **8.4 The runner over an hour** (65 min, 5 min of work)
  Sources: faster-start-stop 8.22.
  Needs: an unattended hour (a lunch break). The 2.3.0 baseline from 1.4, if taken.
  Steps:
  1. `awake --start --backend caffeinate --duration 70m`
  2. At about 1, 30 and 60 minutes: `pid=$(awk -F= '$1=="sleep_pid"{print $2}' /tmp/keep-awake-lid-closed-$UID/state); ps -o rss=,%cpu=,etime= -p "$pid"`. Also note the runner's %CPU in Activity Monitor (search `bash`).
  3. `awake --stop`
  Expected: RSS is steady, and %CPU near 0, as with 2.3.0.

## 9. Shortcuts: runs without a terminal

- [ ] **9.1 Shortcuts: Run Shell Script** (12 min)
  Sources: plan-2.4.0 6.7 (with the section 3 table, "No terminal").
  Needs: Shortcuts > Settings > Advanced > Allow Running Scripts on. Password-free mode on. The full path from `command -v awake` (Shortcuts' PATH may lack it).
  Steps: make a shortcut with one Run Shell Script action (zsh, no input) and a Show Result. Its first line is `AW="$HOME/.local/bin/awake"` (your path). Change the second line for each step and run it:
  1. `"$AW" --duration 1h`; then in Terminal `awake --status` and `pgrep -fl -- '--notify-wait'`.
  2. `"$AW" --duration 30m` (adds time).
  3. `"$AW" -- /bin/sleep 5`. Write down how Shortcuts shows exit status 1 and the stderr text.
  4. `"$AW" --no-notifications -- /bin/sleep 5`
  5. `"$AW" --stop`, then `"$AW" --stop` again with nothing running.
  6. `"$AW" --notifications --duration 1m`; wait about 70 s.
  7. `"$AW" --notifications --stop` with nothing running.
  Expected: 1: starts with no banner; status on; pgrep prints nothing. 2: no `Awake extended` (2.3.0 posted one). 3: one `Awake failed`, `A session is already running. Stop it with awake --stop first, then start one tied to the process.`, and Shortcuts reports the error. 4: no banner; Shortcuts still reports it. 5: both silent. 6: `Awake started` naming the length, then `Awake finished` about a minute later. 7: one `Awake is off`.

- [ ] **9.2 Shortcuts and AWAKE_NOTIFICATIONS in ~/.zshenv** (5 min)
  Sources: plan-2.4.0 6.8 (and 9, "Unverified: whether Run Shell Script reads ~/.zshenv").
  Needs: the shortcut from 9.1; nothing running.
  Steps:
  1. Shortcut line: `echo "AWAKE_NOTIFICATIONS=${AWAKE_NOTIFICATIONS-unset}"`. It prints `unset`.
  2. `echo 'export AWAKE_NOTIFICATIONS=true' >> ~/.zshenv`
  3. Run the echo shortcut again.
  4. Shortcut: `"$AW" --duration 1m`; wait about 70 s.
  5. `sed -i '' '/^export AWAKE_NOTIFICATIONS=true$/d' ~/.zshenv`. Close Terminal windows opened since step 2; in a new one `echo ${AWAKE_NOTIFICATIONS-unset}` prints `unset`.
  Expected: 3 prints `AWAKE_NOTIFICATIONS=true`. 4 posts `Awake started`, then `Awake finished`. If 3 prints `unset`, Shortcuts does not read ~/.zshenv: reword the README hint ("for shells and Shortcuts, for example in ~/.zshenv", README.md:344) in 2.4.0.

## 10. Timing after the update

Same Mac, same conditions and same options as 1.2 and 1.3.

- [ ] **10.1 Timing script, after** (12 min)
  Sources: faster-start-stop 7.1 + 8.1 (after the update); faster-start-stop 8.18 (the Terminal stop time).
  Steps:
  1. `grep -c AWAKE_STATUS_JSON_FILE "$HOME/Library/Application Support/Awake/bin/awake"` prints more than 0. The script's header still says `awake 2.3.0`, but after it the CLI's path, which tells the builds apart.
  2. Quit Awake.app. `cd ~/awake`
  3. `tools/measure-latency.sh --rounds 5` (with `--lid-closed` if used before), twice; keep the second. Then, straight after, for a comparison in one sitting: `tools/measure-latency.sh --rounds 10 --lid-closed --cli ~/awake-qa/awake-2.3.0/bin/awake`, then `tools/measure-latency.sh --rounds 10 --lid-closed` (without `--lid-closed` if password-free mode is off). Keep both.
  4. `tools/measure-latency.sh --rounds 5 --sound` (likewise), twice; keep the second. It shows only the CLI's afplay cost; the new app passes no `--sound`.
  5. Three times: `awake --start --backend caffeinate --duration 10m; sleep 3; time awake --stop`. Note the `total`.
  6. `open ~/Applications/Awake.app`
  Expected: compare 1.2's "today" with this run's "with C", step by step, for the large changes; runs at different times differ by up to a third (faster-start-stop 7.3), so for the smaller ones compare the two 10-round runs of step 3, which share a sitting. The lid-open stop's action drops by about a second (B). The lid-open start's action drops by the osascript time (D, about 0.15 to 0.45 s). The stop's "status before" is a little faster (no pmset while a session runs). For E, 1.2's `--sound` "today" against this plain "with C" for the lid-open start drops by Tink's length too. Terminal stop: about 0.3 to 0.6 s.

- [ ] **10.2 Timing on screen, after** (30 min, plus frame reading)
  Sources: faster-start-stop 7.2 + 8.1 (after the update).
  Needs: the settings and recording set-up of 1.3 (Sound off, Shortcut on, Mode `Lid-open, display on`, banners on, Focus off, plugged in).
  Steps: repeat 1.3 exactly: five menu starts and five click stops on a screen recording, five ⇧⌘A starts and stops filmed at 240 fps. Read t0, t1 and t2 the same way and keep the medians.
  Expected: t1 - t0 under 0.1 s for all four (bold for the start, regular for the stop, neither dimmed). t2 - t0 is about the "with C" sum of 10.1. A gap above about 0.2 s is app overhead worth noting.

- [ ] **10.3 Fill in faster-start-stop 7.3** (10 min)
  Sources: faster-start-stop 7.3 + 8.1.
  Steps: fill in the table in faster-start-stop.md 7.3 with medians in ms. For the script, "before" is 1.2's "today" sum and "after" 10.1's "with C" sum. Add two rows the plan lacks: the lid-open start with Sound on (before: `--sound` "today"; after: plain "with C"), and the Terminal `time awake --stop` (1.2 and 10.1). The lid-closed rows stay empty without password-free mode.
  The script rows were filled in on 2026-10-04 from runs of `e9a1490`, before J1, and the row "Lid-open start after J1" from a run of `63b982a` in a later sitting, which ran faster overall. The same-sitting 10-round runs of 10.1 step 3 (2.3.0, then the installed build) were added on 2026-10-04: they give the fair before and after, including the lid-closed stop, which the earlier runs timed at one fixed point of the helper's once-a-second check. Still open: the Terminal stop and the stopwatch rows (10.2).
  Expected: every Mac figure in the plan is an estimate until this is filled in. Any figure in the CHANGELOG comes from here.

## 11. Old versions, uninstall and Homebrew

These change the installed version, so they come last. 11.1 ends with the dev build reinstalled. 11.6 ends with Homebrew's 2.3.0 installed, ready for 12.6.

- [ ] **11.1 Install and uninstall without a terminal over 2.3.0** (25 min)
  Sources: plan-2.4.0 6.10 (step 5), 6.11.
  Needs: `~/awake-qa/awake-2.3.0` (0.5); the admin password. The launchers rebuilt in 3.4.
  Steps:
  1. `bash ~/awake-qa/awake-2.3.0/install-awake.sh`, with nothing running. `awake --help | grep -c -- --notifications` prints 0.
  2. Double-click `Install Awake.app` in `~/awake` (or `bash ~/awake/install-awake.sh </dev/null 2>&1 | cat`). Then `awake --help | grep -c -- --notifications`.
  3. `bash ~/awake-qa/awake-2.3.0/install-awake.sh` again, with nothing running.
  4. Double-click `Uninstall Awake.app` in `~/awake` (or `bash ~/awake/uninstall-awake.sh </dev/null 2>&1 | cat`). Not plainly in Terminal: from a terminal it passes `--stop`, not `--gui --stop`.
  5. Optional: reinstall 2.3.0, start `awake --duration 30m`, and repeat step 4.
  6. `bash ~/awake/install-awake.sh` (password for the helper). `defaults import net.kaenmaki.awake.statusbar ~/awake-prefs-start.plist`, quit and reopen Awake, and turn password-free mode on again in Settings if it was on (the uninstall removed the rule).
  Expected: 2: no `Awake is off` banner; afterwards the count is 1 or more. 4: no `Awake is off` banner, the macOS password dialog for the helper removal, and Awake removed. 5: the session stops, with at most one `Awake stopped` (the old notifier) and no `Awake is off`. 6: the dev build installed with the owner's settings.

- [ ] **11.2 Optional: a real update from 2.2.0** (20 min)
  Sources: plan-2.3.0 6.8 (real path), 11 QA 1 (real path).
  Needs: `~/awake-qa/awake-2.2.0` (0.5).
  Steps:
  1. `bash ~/awake-qa/awake-2.2.0/install-awake.sh`. In 2.2.0's Settings record Control-Option-Command-A, and set the low-battery level to `Never`.
  2. `bash ~/awake/install-awake.sh`. Open Settings; press the shortcut in another app.
  3. Reinstall 2.2.0, press `Clear` in its Settings, reinstall the dev build, open Settings.
  4. Restore the settings as in 11.1 step 6.
  Expected: 2: no helper password (`Awake's helper is already installed and up to date.`). The Shortcut box is on with `⌃⌥⌘A`, which starts and stops Awake. `Stop at low battery` is unchecked, its pop-up dimmed at `5%`. 3: the box is off with `⇧⌘A` dimmed.

- [ ] **11.3 Optional: update from 2.1.0 with password-free mode** (15 min)
  Sources: plan-2.3.0 15.1 item 8 (the 2.1.0 path).
  Needs: `~/awake-qa/awake-2.1.0` (0.5).
  Steps: install 2.1.0, turn password-free mode on, install the dev build, start a lid-closed session, and look at Settings > Stop when unplugged. Restore the settings afterwards.
  Expected: the installer asks for the password once, for the helper (protocol 8 to 9). The lid-closed start asks for nothing (password-free mode). Stop when unplugged is off.

- [ ] **11.4 Optional: a 2.0.0 session with the new CLI** (30 min)
  Sources: plan-2.3.0 15.4 item 6.
  Needs: `~/awake-qa/awake-2.0.0` (0.5). Low priority: four releases back.
  Steps:
  1. Install 2.0.0. Start a lid-closed session; separately, later, a lid-open one.
  2. For each: `cp ~/awake/bin/awake "$HOME/Library/Application Support/Awake/bin/awake"`, then `awake --status`, `awake --status-json`, `awake --duration-seconds 60`, `awake --stop`.
  3. Reinstall the dev build and restore the settings.
  Expected: `--status` and `--status-json` describe the running session. Lid-closed: one password prompt that updates the helper, then `the running session was started by an older version of Awake. Stop it and start a new one.` (exit 6). Lid-open: time is added. `--stop` stops both.

- [ ] **11.5 Optional: other macOS versions** (10 min each)
  Sources: plan-2.3.0 15.3 item 11.
  Needs: macOS 15, or a 12.5 Mac or VM.
  Steps: `bash install-awake.sh` from a checkout of the same commit. Record ⇧⌘A and Control-Option-Command-A and use them.
  Expected: the app builds (on 12.5 with Swift 5.7, which also compiles the new StatusIcon.swift), and both combinations register and work.

- [ ] **11.6 Homebrew: over the git install, reinstall, uninstall and a fresh install** (33 min)
  Sources: plan-2.3.0 17 QA 5, 17 QA 2, 17 QA 4, 17 QA 1; release procedure (tap readiness, step 4).
  Needs: all dev-build items done (this puts the released 2.3.0 back). Homebrew; the admin password. Steps 6 to 9 remove Awake's settings, helper and password-free rule, and put them back. Skip only if the owner does not want a brew-managed install; 12.6 needs it.
  Why before the release: the Homebrew path (the cask, `scripts/homebrew-uninstall.sh`, the installer and uninstaller) is unchanged since v2.3.0 apart from comments, so a fault found here is also in 2.4.0 and can be fixed before it ships.
  Steps:
  1. Note the settings: `defaults read net.kaenmaki.awake.statusbar > ~/awake-settings-before-brew.txt`. Make sure Sound on, password-free mode and Launch at login are on.
  2. `brew install anttikaenmaki/awake/awake`
  3. In a new window: `awake --version; xattr ~/Applications/Awake.app; defaults read net.kaenmaki.awake.statusbar | diff ~/awake-settings-before-brew.txt -`
  4. `brew reinstall awake`
  5. `defaults read net.kaenmaki.awake.statusbar | diff ~/awake-settings-before-brew.txt -; ls /private/etc/sudoers.d | grep awake; ls ~/Library/LaunchAgents/net.kaenmaki.awake.statusbar.plist`
  6. `defaults export net.kaenmaki.awake.statusbar ~/awake-prefs-before-uninstall.plist`
  7. `brew uninstall awake`. Then, in a new window: `ls ~/Applications/Awake.app; command -v awake; defaults read net.kaenmaki.awake.statusbar; ls /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper; ls /private/etc/sudoers.d | grep awake`
  8. `brew install anttikaenmaki/awake/awake`. Then, in a new window: `awake --version; awake --status; xattr ~/Applications/Awake.app`. Open the app's Help once.
  9. `defaults import net.kaenmaki.awake.statusbar ~/awake-prefs-before-uninstall.plist`, quit and reopen Awake. In Settings, turn password-free mode and Launch at login on again if they were on (the uninstall removed the rule and the login item). `rm ~/awake-prefs-before-uninstall.plist`
  Expected: 2: brew downloads `awake-2.3.0.tar.gz` and runs `awake-2.3.0/install-awake.sh`; the installer's output appears. 3: `awake 2.3.0`, no `com.apple.quarantine`, and no settings difference. 4: `Keeping Awake installed for brew reinstall: the new version's installer updates it in place, with its settings.`, then the installer runs again. 5: no difference; the sudoers rule and the Launch at login plist are there. 7: the uninstaller's output appears and the macOS dialog asks for the password to remove the helper; then the app, the command (`command -v` prints nothing), the settings (`Domain net.kaenmaki.awake.statusbar does not exist`), the helper and the sudoers rule are gone. 8: the installer's output appears, the macOS dialog asks for the password to install the helper, and Awake.app starts; `awake 2.3.0` and `Awake is off.` in the new window; no `com.apple.quarantine`, and the app and its Help open without a Gatekeeper warning. 9: the owner's settings are back, with password-free mode and Launch at login as before.
  If a QA fix later needs a retest on the dev build: `bash ~/awake/install-awake.sh`, retest, then `brew reinstall --cask awake` before 12.6 (`brew install` would only say the cask is already installed).

- [ ] **11.7 Clean up** (5 min)
  Sources: plan-2.4.0 6 (cleanups); faster-start-stop 8 (cleanups).
  Steps:
  1. `launchctl getenv AWAKE_NOTIFICATIONS; launchctl getenv AWAKE_DEBUG` print nothing (else `launchctl unsetenv` them).
  2. `grep AWAKE_NOTIFICATIONS ~/.zshenv` prints nothing. `ls ~/Library/LaunchAgents | grep awake.qa` prints nothing.
  3. `rm -f /tmp/keep-awake-lid-closed-$UID/awake-debug.log`. Keep `~/awake-2.3.0-cli`, `~/Awake-2.3.0.app` and the worktrees under `~/awake-qa` until 12.7: a late fix may need 1.4, 2.1, 5.24 or 11.1 again (12.2 step 3).
  4. `test -x "$HOME/Library/Application Support/Awake/bin/awake" && echo ok`; `pmset -g | grep SleepDisabled` shows 0; `sudo launchctl print-disabled system | grep awake` shows nothing disabled.
  5. `cd ~/awake; git status --short` prints nothing (move any stray `awake-latency-*.tsv` away).
  6. Settings as the owner had them in 0.5 (password-free mode, Sound, Mode, Launch at login).
  Expected: as listed.

## 12. Release and post-release checks

- [ ] **12.1 Read the CHANGELOG and the README opening** (15 min)
  Sources: release procedure (CHANGELOG read-through; README opening).
  Steps:
  1. `/bin/bash tools/release.sh --notes Unreleased`. This becomes the GitHub release notes.
  2. Read each entry against what the QA saw. Upgrade notes (1); Added (1): `--notifications` and `AWAKE_NOTIFICATIONS`; Changed (8): no notifications by default except `Awake failed` without a terminal, `--sound` without `--notifications`, `awake --gui --stop` prints `Awake mode is not active.`, the icon changes at once, the quicker lid-open stop, the status report, the app's thermal state, the app plays the start sound; Fixed (5): the icon switching back, the 30 s wait when the worker died during a stop, `--sound` on a failed session, the Caffeine start's 30 s wait, a runner left unrecorded.
  3. Add a `### Fixed` bullet for each fix from this QA (for example the launcher titles of 3.4), in the same style, wrapped at 79 columns. Keep `**Breaking` and `### Removed` out: either makes release.sh suggest 3.0.0.
  4. `/bin/bash tools/release.sh --notes Unreleased | awk 'length > 79'`
  5. On GitHub, read README.md on `dev`. Check the comparison bullets (Amphetamine, KeepingYouAwake, Caffeine) against the three tools' current sites: Amphetamine works with the lid closed, is closed source and has no command-line tool; KeepingYouAwake and Caffeine need the lid open; none documents an overheating cut-off.
  Expected: every entry matches what the QA saw. Step 4 prints nothing. The comparison is still true.

- [ ] **12.2 Record the results and pass the gate** (15 min)
  Sources: release procedure (pre-release gate).
  Steps:
  1. Each failure in "Results" is fixed on `dev` with a Fixed entry, or written down as accepted.
  2. Update the Status lines of plan-2.3.0.md, plan-2.4.0.md and faster-start-stop.md (QA done, with the date), and plan-2.3.0's note that the tap waits for setup. Or retire the finished plans as cf8517b did. Commit this file as docs/plans/qa-2.4.0.md with its results. Push to `dev`.
  3. If code changed since the QA build: reinstall from `dev` (2.1 step 6), rerun 3.1 and the items the fix touches. The 2.3.0 copies and the worktree from 0.5 are still there for 1.4, 2.1, 5.24 and 11.1 (12.7 removes them). Then `brew reinstall --cask awake` to put Homebrew's 2.3.0 back before 12.6.
  4. CI green on the `dev` HEAD (0.3).
  5. `git status --short; git fetch origin --tags; git tag -l v2.4.0; git status -sb; /bin/bash tools/release.sh --check`
  Expected: `dev` is clean, up to date with `origin/dev`, at a green commit that holds every fix and the results. No `v2.4.0` tag yet. `Version 2.3.0 is consistent ...`.

- [ ] **12.3 Release** (25 min)
  Sources: release procedure (`tools/release.sh`, release.yml, the 2.3.0 flow).
  Needs: the gate passed; a terminal; gh; the token checked in 0.4.
  Steps:
  1. `cd ~/awake; git checkout dev; /bin/bash tools/release.sh` and answer `y`.
  2. `/bin/bash tools/release.sh --check; git show --stat HEAD`
  3. `git push origin dev`, and wait for CI.
  4. `gh pr create --repo anttikaenmaki/awake --base main --head dev --title 'Version 2.4.0' --body "$(/bin/bash tools/release.sh --notes)"`. Wait for the PR's CI.
  5. Merge with a merge commit, as PR #6 was: `gh pr merge <number> --repo anttikaenmaki/awake --merge` (not `--squash` or `--rebase`).
  6. `gh run list --repo anttikaenmaki/awake --workflow release.yml --limit 1; gh run watch <id> --repo anttikaenmaki/awake`
  Expected: 1: `The Unreleased section suggests a minor release: 2.3.0 -> 2.4.0.`, `Release 2.4.0? [y/N]`, then `Committed "Version 2.4.0" on dev.`. 2: `Version 2.4.0 is consistent ...`; one commit touching bin/awake, README.md, CHANGELOG.md and the three Info.plist files; CHANGELOG has an empty `## [Unreleased]`, `## [2.4.0] - <today>`, and the compare links. 3 and 4: CI green. 6: the job "Tag and publish the release" pushes the tag `v2.4.0` ("Awake 2.4.0") on the merge commit and creates the GitHub release; the job "Publish to the Homebrew tap" attaches `awake-2.4.0.tar.gz` and pushes the cask.

- [ ] **12.4 Check the release and the tap** (10 min)
  Sources: release procedure (post-release verification); plan-2.3.0 17 QA 6.
  Steps:
  1. `git fetch origin --tags; git tag -n1 v2.4.0; git log -1 --format='%h %s' 'v2.4.0^{commit}'`
  2. `gh release view v2.4.0 --repo anttikaenmaki/awake`; `gh api repos/anttikaenmaki/awake/releases/tags/v2.4.0 --jq '.assets[] | .name + " " + .digest'`
  3. `gh run view <release run id> --repo anttikaenmaki/awake --log | grep -E 'SHA-256|Published|HOMEBREW_TAP_TOKEN|error'`
  4. Open `https://github.com/anttikaenmaki/homebrew-awake/blob/main/Casks/awake.rb`. `brew update; brew info --cask anttikaenmaki/awake/awake`
  5. `gh workflow run homebrew-tap.yml --repo anttikaenmaki/awake --ref main -f version=2.4.0`, and read its log.
  6. CI on `main` for the merge commit is green, and README on `main` says `Current version: 2.4.0`.
  Expected: 1: `v2.4.0  Awake 2.4.0`, on `Merge pull request #<n> from anttikaenmaki/dev`. 2: the title `Awake 2.4.0`, the body the 2.4.0 section starting `### Upgrade notes`, and `awake-2.4.0.tar.gz` with a sha256 digest. 3: `The archive's SHA-256 checksum is <the same digest>.` and `Published Awake 2.4.0 to anttikaenmaki/homebrew-awake.`. 4: version `"2.4.0"` with that sha256; brew info shows 2.4.0. 5: `anttikaenmaki/homebrew-awake already has Awake 2.4.0.`. If the token had expired, the tap job fails with an authentication error after the release is out: renew the token (0.4), update the secret, and step 5 publishes 2.4.0.

- [ ] **12.5 Bring `dev` up to `main`** (10 min)
  Sources: release procedure (after 2.3.0, main's merge commit is on dev).
  Steps: `cd ~/awake; git fetch origin; git checkout dev; git merge --ff-only origin/main; git push origin dev`, then `git rev-list --left-right --count origin/main...origin/dev`, and wait for CI on `dev`.
  Expected: `dev` fast-forwards to the merge commit; `0	0`; CI green.

- [ ] **12.6 brew upgrade from 2.3.0 to 2.4.0** (15 min)
  Sources: release procedure (brew upgrade); plan-2.3.0 17 QA 3; plan-2.4.0 6.10 (the Homebrew part).
  Needs: Homebrew's 2.3.0 from 11.6 (after a later dev-build reinstall, put back with `brew reinstall --cask awake`, 12.2 step 3); the tap at 2.4.0 (12.4); notifications allowed; password-free mode on (step 1 checks its rule).
  Steps:
  1. `defaults read net.kaenmaki.awake.statusbar > ~/Desktop/awake-settings-before.txt; ls /private/etc/sudoers.d/awake-$(id -u)`
  2. `awake --duration 30m` in Terminal (2.3.0 starts its end notifier).
  3. `brew update; brew outdated --cask`
  4. `brew upgrade --cask awake`
  5. In a new window: `awake --version; awake --status; pgrep -fl -- '--notify-wait'; awake --help | grep -c -- --notifications`, `defaults read net.kaenmaki.awake.statusbar | diff ~/Desktop/awake-settings-before.txt -`, `ls /private/etc/sudoers.d/awake-$(id -u)`, `xattr ~/Applications/Awake.app`, `brew list --cask --versions awake`.
  6. Open Settings and Help.
  Expected: 3: awake is outdated, 2.3.0 to 2.4.0. 4: `Keeping Awake installed for brew upgrade: the new version's installer updates it in place, with its settings.`, then the 2.4.0 installer: `Building Awake.app ...`, `Building Awake GUI picker ...`, `Installing stops the running session: Awake is on ...`, `Quitting the running Awake.app ...`, `Awake's helper is already installed and up to date.` (no password), `Awake installation complete.`. At most one `Awake stopped` (the old notifier), and no `Awake is off`. 5: `awake 2.4.0`, `Awake is off.`, no notifier, a count of 1 or more. The settings diff shows only `lastStoppedAt`, the `lastSessionHeat` block and the `sessionHeatInProgress` block changing: the new app records the stop time of the session that step 2 started and the upgrade stopped, and finishes its heat recording, at its first poll. Every user setting is unchanged. The sudoers rule is kept, no quarantine, `awake 2.4.0`. 6: Launch at login still on, no Gatekeeper warning, Help shows `Current version: 2.4.0`.

- [ ] **12.7 A fresh install from the release, and the last clean-up** (25 min)
  Sources: release procedure (fresh install); plan-2.3.0 17 QA 1, 17 QA 4 (repeated with 2.4.0; the pre-release run is 11.6); plan-2.4.0 6 and faster-start-stop 8 (cleanups).
  Needs: 12.4 done. Part B removes Awake's settings, helper and password-free rule; back up first. Part C optionally in a second macOS account; do not uninstall there, as the helper is shared by all accounts.
  Steps:
  A. `cd /tmp; curl -fsSLO https://github.com/anttikaenmaki/awake/releases/download/v2.4.0/awake-2.4.0.tar.gz; shasum -a 256 awake-2.4.0.tar.gz; tar -tzf awake-2.4.0.tar.gz | grep -cE '^awake-2\.4\.0/(install-awake\.sh|scripts/homebrew-uninstall\.sh|uninstall-awake\.sh|tools/homebrew/awake\.rb)$'`
  B. 1. `defaults export net.kaenmaki.awake.statusbar ~/Desktop/awake-settings.plist`
     2. `brew uninstall awake`. Then `ls ~/Applications/Awake.app`, `command -v awake` (new shell), `defaults read net.kaenmaki.awake.statusbar`, `ls /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper`.
     3. `brew install anttikaenmaki/awake/awake`
     4. New window: `awake --version; awake --status; xattr -r ~/Applications/Awake.app | grep -c quarantine`
     5. Start and stop a lid-open and a lid-closed session from the menu bar.
     6. `defaults import net.kaenmaki.awake.statusbar ~/Desktop/awake-settings.plist`, relaunch the app, and turn password-free mode and Launch at login back on in Settings if they were on.
  C. Optional, without Homebrew: `cd ~; git clone https://github.com/anttikaenmaki/awake.git awake-fresh; cd awake-fresh; git log -1 --format=%s; /bin/bash tools/release.sh --check; bash install-awake.sh`
  D. Remove the QA copies of 2.3.0: `rm -f ~/awake-2.3.0-cli; rm -rf ~/Awake-2.3.0.app; git -C ~/awake worktree remove ~/awake-qa/awake-2.3.0` (and the optional ones from 0.5), then `rmdir ~/awake-qa; git -C ~/awake worktree prune`.
  Expected: A: the checksum equals the asset's digest and the cask's sha256; grep counts 4. B2: the uninstaller asks for the password (dialog) to remove the helper; the app, the command, the settings (`Domain ... does not exist`) and the helper are gone. B3: brew downloads `awake-2.4.0.tar.gz`, runs its installer, the macOS dialog asks for the password to install the helper, and Awake.app starts. B4: `awake 2.4.0`, `Awake is off.`, `0`; no Gatekeeper warning. B5: the sessions start and stop. C: `Merge pull request #<n> from anttikaenmaki/dev`, `Version 2.4.0 is consistent ...`, and the installer runs as in 2.1 (in a second account the shared helper is up to date, so no prompt). D: `git -C ~/awake worktree list` shows only `~/awake`.

## Results

Write each failure or note here: the item number, what happened, and the fix (commit) or why it is accepted.

| Item | What happened | Fix or decision |
|---|---|---|
| | | |

Timing (10.3) goes into faster-start-stop.md 7.3.

## Appendix: source item -> checklist item

Every QA item of the three plans, and every release step, maps to an item above. "Merged" means another source tests the same thing in that item. "Superseded" means the item as written is not run; the reason says what replaces it.

### plan-2.3.0

| Source | Checklist | Status and note |
|---|---|---|
| 6.1 | 5.26 | Merged with 6.2, 6.3. Adds the Time to add and low-battery pop-ups to the controls. |
| 6.2 | 5.26 | Merged. |
| 6.3 | 5.26 | Merged. |
| 6.3 (Help window sub-item) | 5.33 | Merged. The item is now `Help`, the window `Awake help`. |
| 6.4 | 5.1 | As written. |
| 6.5 | 5.2 | Merged with 15.3 items 2, 3 and faster-start-stop 8.2. The icon changes at the key press. |
| 6.6 | 5.3 | Merged with 6.7, 15.3 item 1. |
| 6.7 | 5.3 | Merged. Forward Delete added. |
| 6.8 | 5.9 (defaults simulation), 11.2 (real 2.2.0, optional), 2.1 (no helper password) | Adjusted: the target is the 2.4.0 build over 2.2.0. |
| 6.9 | 5.8 | Merged with 15.3 item 12. Cancel the Log Out dialog. |
| 6.10 | 5.7 | Merged with 6.12 part 3, 15.3 item 9. |
| 6.11 | 5.27 | Merged with 13 QA 4, 14 QA (Settings window). |
| 6.12 | 5.6 (parts 1, 2), 5.7 (part 3) | Split. |
| 6.13 | 5.34 | As written. |
| 11 QA 1 | 5.28 (simulation), 11.2 (real 2.2.0, optional) | Merged with 11 QA 2, 15.4 item 9. |
| 11 QA 2 | 5.28 | Merged. |
| 11 QA 3 | 7.12 | Merged with faster-start-stop 8.9 part 1, 8.27 part 1. Icon: bold, then regular. |
| 12 QA 1 | 5.10 | Merged with 12 QA 3, 14 QA menu, faster-start-stop 8.3. |
| 12 QA 2 | 5.5 | Merged with 15.3 item 10. |
| 12 QA 3 | 5.10 | Merged. |
| 12 QA 4 | 6.2 | Merged with faster-start-stop 8.5. Tink now from the app. |
| 12 QA 5 | 5.31 | Merged with 16 QA 1. |
| 13 QA 1 | 5.12 | Merged with 13 QA 2, 13 QA 3, faster-start-stop 8.8. |
| 13 QA 2 | 5.12 | Merged. |
| 13 QA 3 | 5.12 | Merged. |
| 13 QA 4 | 5.27 | Merged. |
| 14 QA (Ctrl-click menu) | 5.10 (steps 1, 2), 6.1 (steps 3, 4) | Split. |
| 14 QA (Settings window) | 5.27 | Merged. |
| 14 QA (Install Awake.app after rebuilding the launchers) | 3.4 | A fix to commit: 2.3.0 shipped with the old launcher binaries. |
| 14 QA (Help) | 5.33 | Merged. The dev build still shows 2.3.0. |
| 15.1 item 1 | 7.1 | As written. |
| 15.1 item 2 | 7.6 | Adjusted: start from the app (a Terminal session posts no end banner by default). |
| 15.1 item 3 | 7.2 | As written. |
| 15.1 item 4 | 7.3 | Adjusted: app session for the banner. |
| 15.1 item 5 | 7.4 | As written. |
| 15.1 item 6 | 7.5 | Adjusted: app session; the end may come sooner (B). |
| 15.1 item 7 | 7.7 | Optional (external display). |
| 15.1 item 8 | 2.1 (from 2.3.0), 11.3 (from 2.1.0, optional) | Adjusted: target 2.4.0; no password from 2.2.0 or 2.3.0. |
| 15.2 item 1 | 7.8 | As written. |
| 15.2 item 2 | 7.14 | As written. |
| 15.2 item 3 | 7.11 | As written. |
| 15.2 item 4 | 7.10 | Optional (safety). |
| 15.2 item 5 | 4.14 | Merged with 15.2 item 8. Adjusted: no end banner. |
| 15.2 item 6 | 7.9 | As written. |
| 15.2 item 7 | 5.16 (Stop and quit), 2.1 (install during a session) | Split. |
| 15.2 item 8 | 4.14 | Merged. No end banner. |
| 15.2 item 9 | 5.30 | As written, with the scrolling cap. |
| 15.3 item 1 | 5.3 | Merged. |
| 15.3 item 2 | 5.2 | Merged. |
| 15.3 item 3 | 5.2 | Merged. |
| 15.3 item 4 | 6.2 (macOS dialog), 6.6 (custom dialog), 6.8 (password-free) | Split by set-up. |
| 15.3 item 5 | 5.4 | Merged with 15.3 item 6. |
| 15.3 item 6 | 5.4 | Merged. |
| 15.3 item 7 | 5.14 | Merged with faster-start-stop 8.10, 8.38 step 2. |
| 15.3 item 8 | 6.2 | Merged. |
| 15.3 item 9 | 5.7 (step 7) | Optional (needs a launcher). |
| 15.3 item 10 | 5.5 | Merged. |
| 15.3 item 11 | 11.5 (other macOS), 3.2 (this Mac's Swift) | Optional for other machines. |
| 15.3 item 12 | 5.8 | Merged. |
| 15.3 item 13 | 5.6 | Merged with 6.12 parts 1, 2. |
| 15.3 item 14 | 5.11 (step 2: after a ⇧⌘A start and a Start default session start) | Merged. |
| 15.3 item 15 | 5.23 | Adjusted: both Tinks from the app. |
| 15.4 item 1 | 6.10 | Adjusted: no end banner. |
| 15.4 item 2 | 6.11 | As written, with commands. |
| 15.4 item 3 | 8.3 | As written. |
| 15.4 item 4 | 4.7 | Merged with plan-2.4.0's failed-end check. |
| 15.4 item 5 | 7.13 | Adjusted: no banner. |
| 15.4 item 6 | 11.4 | Optional (2.0.0). |
| 15.4 item 7 | 6.12 | Partly superseded: "repeat with the LaunchDaemon unloaded" replaced by `launchctl disable` (a bootout is undone at the next boot); the `awake --status` text corrected to `Awake is off.`. |
| 15.4 item 8 | 8.2 | As written. |
| 15.4 item 9 | 5.28 | Merged. |
| 15.4 item 10 | 5.11 | Merged with faster-start-stop 8.7, 15.3 item 14. |
| 15.4 item 11 | 6.6 | Merged with faster-start-stop 8.6, 8.7 step 3. |
| 15.4 item 12 | 5.29, 5.11 (step 5: `defaults write` picked up), 5.27 (step 2: ⌘C and ⌘V) | Merged with faster-start-stop 8.28. Changed: the last sub-item lets a 1-minute app session end on its own while the Start without password dialog is open (5.29 step 6); the end is `Awake finished`, as the session times out. A Terminal `awake --stop` cannot replace it, as `--passwordless` holds the state-change lock during its dialog. |
| 15.4 item 13 | 5.13 | As written. |
| 15.4 item 14 | 2.1 | Merged with plan-2.4.0 6.10. |
| 15.4 item 15 | 8.1 | As written. |
| 16 QA 1 | 5.31 | Merged. |
| 16 QA 2 | 5.31 | Merged. |
| 16 QA 3 | 5.32 | Optional (two displays). |
| 16 QA 4 | 5.32 | Optional (two displays). |
| 16 QA 5 | 5.31 | Merged. |
| 16 QA 6 | 5.31 | Merged. |
| 17 QA 1 | 11.6 (steps 8, 9: fresh `brew install` of 2.3.0, before the release), 12.7 (B3 to B5: again with 2.4.0) | As written, before the release: the Homebrew path is unchanged since v2.3.0 apart from comments, so a fault found in 11.6 is also in 2.4.0 and is fixed before the release, under Fixed. 12.7 repeats it after the release. |
| 17 QA 2 | 11.6 | Merged with 17 QA 5, 17 QA 4, 17 QA 1. |
| 17 QA 3 | 12.6 | Merged with plan-2.4.0 6.10 (Homebrew). Post-release; now a real 2.3.0 to 2.4.0 upgrade. |
| 17 QA 4 | 11.6 (step 7: `brew uninstall` of 2.3.0, before the release), 12.7 (B2: again with 2.4.0) | As written, before the release, for the same reason as 17 QA 1. |
| 17 QA 5 | 11.6 | Merged. Leaves 2.3.0 from brew for 12.6. |
| 17 QA 6 | 12.4 | Superseded for 2.3.0: run 36744054640 already published 2.3.0 to the tap. Run by hand for 2.4.0 in 12.4. |

### plan-2.4.0

| Source | Checklist | Status and note |
|---|---|---|
| 6.1 | 4.1 | As written, with a debug-log check. |
| 6.2 | 4.2 | As written. |
| 6.3 | 4.3 | As written. |
| 6.4 | 4.4 | Adjusted: the end title is `Awake finished: the process it waited for exited`. |
| 6.5 | 4.5 | As written. |
| 6.6 | 4.12 | Adds a lid-open variant and `--notifications --stop`. |
| 6.7 | 9.1 | Adjusted: `--duration 1m`; adds add-time and stop runs. |
| 6.8 | 9.2 | Adds a direct echo check. |
| 6.9 | 5.22 | Adjusted: the start Tink now comes from the app (still one). |
| 6.10 (installer part) | 1.1 (step 1), 2.1 (steps 2 to 4), 11.1 (step 5) | Split by when it can run. |
| 6.10 (brew upgrade part) | 12.6 | Merged with plan-2.3.0 17 QA 3. Post-release. |
| 6.11 | 11.1 | Merged with 6.10 step 5. |
| 6.12 | 7.13a | As written. Moved into section 7, right after 7.13, so its low-charge path runs in order. |
| 6.13 | 4.13 (help text), 5.33 (Help window) | Split. |
| 9 (piped stderr risk), extra | 4.6 | As written. |
| decision 14 (failed end with `--sound`), extra | 4.7 | Merged with plan-2.3.0 15.4 item 4. |
| 9 (unverified on Linux: Bash 3.2, self-test), extra | 0.3 (CI), 3.1 (local run) | Merged with the release CI and self-test steps. |

### faster-start-stop

| Source | Checklist | Status and note |
|---|---|---|
| 7.1 + 8.1 (before) | 1.2 | As written. |
| 7.2 + 8.1 (before) | 1.3 | As written. |
| 8.23 | 1.4 | Must run before the install. |
| 7.1 + 8.1 (after) | 10.1 | As written. |
| 7.2 + 8.1 (after) | 10.2 | As written. |
| 7.3 + 8.1 | 10.3 | Two rows added. |
| 8.2 | 5.2 | Merged. |
| 8.3 | 5.10 | Merged. |
| 8.4 | 6.8 | Merged with 8.33, 8.17 (lid-closed case). |
| 8.5 | 6.2 | Merged. |
| 8.6 | 6.6 | Merged. |
| 8.7 | 5.11 (steps 1, 2), 6.6 (step 3) | Split by setting. |
| 8.8 | 5.12 (lid-open), 6.3 (with a password dialog) | Split. |
| 8.8a | 6.3 | Adjusted: the session must start from the app; the banner is `Awake finished`. |
| 8.9 | 5.15 (CLI missing), 7.12 (low battery) | Split. |
| 8.10 | 5.14 | Merged. `--backend caffeinate` added. |
| 8.11 | 6.4 | Merged with 8.12a. |
| 8.11a | 6.7 | As written. |
| 8.12 | 5.16 | Merged with plan-2.3.0 15.2 item 7 part 1. |
| 8.12a | 6.4 | Merged. |
| 8.13 | 6.1 | Merged with 8.25a part 2. |
| 8.14 | 5.17 | As written. |
| 8.15 | 5.18 | As written. |
| 8.16 | 6.5 | As written. |
| 8.17 | 5.35, 6.8 (lid-closed case) | Split. |
| 8.18 | 4.8 (step 1), 10.1 and 1.2 (the Terminal stop time) | Split. |
| 8.19 | 4.8 | Merged. |
| 8.20 | 4.9 | `--backend caffeinate` added. |
| 8.21 | 4.10 | As written. |
| 8.22 | 8.4 (and an optional baseline in 1.4) | As written. |
| 8.24 | 5.21 | Merged with 8.37, 8.38 step 1. |
| 8.25 | 5.19 | Merged with 8.25a part 1 and 8.39 (one watch). |
| 8.25a | 5.19 (part 1: no polls while the CLI picker is open), 6.1 (part 2) | Part 1 as written. Part 2 partly superseded: `awake --stop` during the Install helper dialog would fail on the state-change lock, so a 1-minute session that ends on its own replaces it. |
| 8.26 | 6.9 | As written. |
| 8.27 | 7.12 (part 1), 6.2 (part 2) | Split. |
| 8.28 | 5.29 | Merged. |
| 8.29 | 5.24 (copies saved in 0.5) | As written. |
| 8.30 | 5.25 | As written. |
| 8.31 | 5.20 | Merged with 8.32, 8.36. |
| 8.32 | 5.20 | Merged. |
| 8.33 | 6.8 | Merged. |
| 8.34 | 4.11 | Merged with 8.35. |
| 8.35 | 4.11 | Merged. |
| 8.36 | 5.20 | Merged. |
| 8.37 | 5.21 | Merged. |
| 8.38 | 5.21 (step 1), 5.14 (step 2), 5.15 (step 3), 6.2 (step 4) | Split. |
| 8.39 | 5.19 | Merged. |
| 8.40 | 4.8 (steps 2 and 3) | Merged. |

### Release procedure

| Source | Checklist | Status and note |
|---|---|---|
| CI (.github/workflows/ci.yml) | 0.3, 3.2 (the app checks run locally) | As written. |
| Mac prerequisites (README Requirements, `check_build_tools`) | 0.2 | As written. |
| Self-test | 3.1 | Uses `/bin/bash`, as CI does. |
| `tools/release.sh --check` and rehearsal | 3.3 | As written. |
| Install the dev build | 1.1 (step 1), 2.1 | Merged with plan-2.4.0 6.10 and plan-2.3.0 15.4 item 14. |
| README and Help window | 5.33 (Help window), 12.1 (README opening on GitHub) | Split. |
| CHANGELOG read-through | 12.1 | As written. |
| Homebrew tap readiness | 0.4 (steps 1 to 3), 11.6 (step 4) | Split. The tap is already set up. |
| Pre-release gate | 12.2 | As written. |
| Release | 12.3 | As written. |
| Post-release verification | 12.4 | Merged with plan-2.3.0 17 QA 6. |
| `dev` up to `main` | 12.5 | As written. |
| brew upgrade | 12.6 | Merged with plan-2.3.0 17 QA 3, plan-2.4.0 6.10. |
| Fresh install from the release | 12.7 | Merged with plan-2.3.0 17 QA 1, 17 QA 4 (their pre-release run is 11.6). |
