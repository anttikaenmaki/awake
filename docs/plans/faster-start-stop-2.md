# Plan: faster start and stop, part 2 (G, H, F and I)

- Status: the owner answered on 2026-10-05: "This should go to 2.4.0, so use the dev branch (I will update QA after this). I'm on a phone now, so cannot answer X-3; follow the recommendations. Please start implementing." So all of it goes into 2.4.0, on `dev`, and every other question takes its recommended answer. The Mac preflight (X8) has not run yet: it joins the 2.4.0 QA, and I3, which it gates, stays out unless that QA measures 100 ms or more (question I-1). Implementation follows the phases' order on `dev`, one commit per part: I2, H (the CLI side, then the app side), I1, I3d, G1, F8, then F's two commits
- Target version: 2.4.0, at the owner's request, with phase 1 (faster-start-stop.md) and plan-2.4.0.md. Each commit adds its CHANGELOG entries to 2.4.0's `[Unreleased]` (X-4's reason for one late commit was the separate branch). The helper protocol stays 9 (bin/awake:165, awake-helper:54): G1 and F8 change the helper's bytes but none of its commands or files (G1i, F8a). Because the bytes change, installer and Homebrew users are asked for the administrator password once at the update to 2.4.0 (`install_helper`'s `cmp`, bin/awake:4231), and 2.4.0's Upgrade notes get G.7's note; a manual CLI-only install keeps the old helper until `awake --install-helper`
- Written: 2026-10-05, against `dev` at `32094d1`, from the owner's request "Prepare a detailed plan for G, H, F, and I", after the same-sitting Mac timing of faster-start-stop.md 7.3. Bare line numbers are lines of `bin/awake` at `32094d1`; the line numbers in faster-start-stop.md 6 refer to the older `8ef37f3` and are re-derived here. `bin/awake-helper` is byte-identical from `v2.2.0` to `32094d1`, so its line numbers in 6 still hold
- Scope, checked against the code at `32094d1`:
  - G (phase 3): `bin/awake-helper` (the header at 40-44, `finish_session` 756-824 with `FINISHING` at 755, 770 and 782, a new `make_wake_fifo` after 824, `cmd_start` 842-981, `cmd_restore`'s `rm` at 1152, `cmd_run_timer` 1218-1336 with its `sleep 1` at 1334), `bin/awake` (the helper paths at 185-186, a new `wake_helper_timer` before `request_helper_session_stop` 3917-3968, a debug line after 3952), `tests/cli/awake-self-test` (12f), `README.md` (:93, :575, :603), `CHANGELOG.md`. No protocol change
  - H (phase 2): `app/AwakeStatusApp/Sources/AwakeCLI.swift` (`performStart` 337-379, `performStop` 381-400, `performMaintenance` 404-422, `runCommand` 424-439, `startArguments` 441-472, `runManagedCommand` 514-604, `environment()` 634-635), `StatusBarController.swift` (the calls at 179, 215, 313 and 337, `handleCommandResult` 390-476, `isAppSession` 577-582), a new `CommandResult.swift` and `tests/app/command-result-check.swift` with a CI step after `.github/workflows/ci.yml:82-87` and a second run in the timing-script step at :121-122, `bin/awake` (a new variable after 63, a new option after `--start` at 419-421 and its check after 616-619, `json_escape` and `json_string_or_null` at 2927-2948, three functions after `print_current_status` 3159-3228, main after 6798-6801), `tools/measure-latency.sh`, `tests/cli/awake-self-test` (5d, section 10, 12i, 13), `README.md:600`, `CHANGELOG.md`
  - F (CLI part in phase 4, F8 in phase 3): `bin/awake` throughout, in two commits ("programs", "subshells"); `bin/awake-helper` for F8 only (`HELPER_UID` after 94, `SELF` at 108, `write_kv_file` 184-191, optionally one `pmset -b` call at 644-645); `tests/cli/awake-self-test` (a new sourced function and section 10a); `CHANGELOG.md`
  - I (I2 and I1 in phase 2, I3d in phase 2 if question I-4 is answered (a), I3 in phase 3 only if the preflight gates it in): `bin/awake` (I1: `run_helper` 3790-3836, a new `sudo_without_password` after 3708-3711, the Terminal pre-check at 7151-7153; I2: main's `pmset` read at 6790-6797, a new `read_sleep_settings_for_main`, and one call after 6952; I3d: `wait_for_helper_session_start` 3902-3915 and main's wait after the helper start, 7232 and 7278-7281; I3: the protocol at 165, the helper start at 7226, a new `helper_extend_command` after 6272-6288), `bin/awake-helper` (I3 only: the header, 54, the start checks at 903-908, `cmd_extend` at 1059 and 1063, the dispatch at 1442-1476), `tests/cli/awake-self-test` (12f, 12h, 12l, a new 12m), `tools/measure-latency.sh` (I3f, only with the bump), `README.md` (:604, :606), `CHANGELOG.md`
  - Shared: `docs/plans/` (this plan; faster-start-stop.md's status line 3, 6.1, 6.9 and 7.1 step 5, which point here or change with these items; a `qa-2.5.0.md` written before the 2.5.0 QA), `tools/measure-latency.sh` ("Timing")
- Relation to the earlier plan: for F, G, H and I this plan replaces faster-start-stop.md 6.3 to 6.6, 6.9 and 6.10's questions 2 to 6; that plan's section 6 points here. Where the two differ, for example on I3's value or the order, this plan holds

## Questions for the owner

**Answered on 2026-10-05.** X-1 and X-2 differently from the recommendations: everything goes into 2.4.0, on `dev` (the owner reruns the 2.4.0 QA afterwards). X-4 follows from that: each commit carries its own CHANGELOG entries under 2.4.0's `[Unreleased]`. X-3: the preflight could not run yet; it joins the 2.4.0 QA, and I3 stays out unless it measures 100 ms or more. Every other question takes its recommended answer. Sections 1 and 2 still describe the separate branch and the 2.5.0 release; where they differ from this answer, the answer holds.

The questions as they were asked: the plan follows the recommended answer to each; the section named in each question explains it. X-2 (where the code goes) and X-3 (when the Mac preflight runs) decide when work can start; the preflight then answers I-1 (whether I3 goes in). Each option says what choosing it changes.

### Across items

- **X-1. Release vehicle: how do G, H, F and I ship?**
  - (a) One 2.5.0 with G, H, F and I (I3 only if the preflight gates it in): one Mac QA session; installer and Homebrew users see one password prompt at the update, for the helper's new bytes; one Upgrade note. **Recommended.**
  - (b) 2.5.0 = I2, H, I1 and F's CLI part, with no helper change, no password prompt and no Upgrade note; 2.6.0 = G1 and F8 (and I3) with one prompt and the Upgrade note. H's gain ships without a prompt, but there are two Mac QA sessions (2.4.0's takes two to three days), and G1's 0.5 s on lid-closed stops waits for 2.6.0.
  - (c) The helper release first (G1, F8), then I2, H, I1 and F. G1's gain ships first, but nothing can be released before the preflight and the helper's QA, and H, the gain on every app action, waits.

- **X-2. Where does 2.5.0 code go while 2.4.0 is in its Mac QA?**
  - (a) A branch dev-2.5 from dev now, with a draft PR into dev so CI runs on every push; dev merged into it the same day as each QA fix; merged into dev (a merge commit, as PR #4) only once 2.4.0 and any 2.4.x from the quick pass have shipped. **Recommended.**
  - (b) No code until 2.4.0 ships: simplest, no merges, but the work waits for the QA and its fixes.
  - (c) Commit to dev now: changes the build under QA, and tools/release.sh would ship the work inside 2.4.0. Not recommended.

- **X-3. When does the 15-minute Mac preflight run (G's QA 1 to 3, the /var/run checks, I's QA I-1, I-2 and I-3 in its 2.4.0 form, and optionally the first part of F's QA 9), which also decides whether I3 goes in?**
  - (a) Any time before I1's commit, for example at the end of a 2.4.0 QA day, with the installed version, password-free mode on and nothing running; no Awake build. I1 and G1 are then written on facts checked on the Mac, and question I-1 is answered before phase 3 starts. **Recommended.**
  - (b) Only in the 2.5.0 QA: I1 and G1 are written on facts checked only on Linux, a design change, if one is needed, comes after all the code is written, and I3 is decided after phase 3.

- **X-4. How are 2.5.0's CHANGELOG entries committed on the branch?**
  - (a) Item commits carry no CHANGELOG bullets (their text stays in the plan); one commit adds all of them after 2.4.0 has been merged into dev-2.5. This avoids the clean merge that moves branch bullets into 2.4.0's section (checked on a scratch clone). **Recommended.**
  - (b) Bullets in each commit, as phase 1 did, and after the 2.4.0 merge a diff check that moves misplaced bullets back under [Unreleased]. Each commit is complete on its own, but a missed check ships 2.5.0 text in 2.4.0's release notes.

- **X-5. How much Mac timing between phases?**
  - (a) Emulation A/B for every phase; one optional Mac sitting after phase 2 (about 15 minutes, no install: the branch's script with --cli on dev's 2.4.0 code, then on the branch with and without --no-status-runs, all protocol 9); the full before and after in the 2.5.0 QA. H's real gain is known after phase 2. **Recommended.**
  - (b) Mac timing only in the 2.5.0 QA: less Mac time, but H's real gain, and whether its --no-status-runs figure differs from the warm one, is known only then.
  - (c) After every phase: phase 3 needs the new helper installed during development, with one password prompt, and going back to 2.4.0's helper for the QA's before timing another.

### F: builtins

- **F-1. How much of F's CLI part goes in, and in how many commits? (F15a)**
  - (a) Two commits: 'programs' (F1a to F7a, F9a, F10a, F13a: builtins for awk, dirname, stat, id, date, chmod, ps, uname), then 'subshells' (F11a, the JSON printer; F12a, read_state_value_into at 52 hot reads). Both measured, each passed the whole self-test alone; the second gives 40 to 50% of the status reads' gain and 15 to 20% of the actions' (Linux). **Recommended.**
  - (b) Programs only: a smaller diff (205 lines added, 82 removed); status reads keep about half of their remaining cost, the subshell forks (Linux, bash 5.2: a status after a session 69 ms instead of 43, a lid-open start 299 instead of 257).
  - (c) Both in one commit: the same code, harder to bisect.

- **F-2. When does F's helper part ship (F8a: HELPER_UID read once, SELF with builtins, write_kv_file without mktemp, dirname, cat and chmod; optionally one pmset call for both settings)?**
  - (a) In phase 3, the helper release, right after G1 (and before I3, if it goes in): all helper bytes change in one phase, root code gets one review, and users see G1's one password prompt; no protocol bump. The combined pmset call only if Mac QA 9's first part (no build needed, can run with the Mac preflight) shows it works; otherwise two calls, as now. **Recommended.**
  - (b) With F's CLI part in phase 4: still one prompt if 2.5.0 ships as one release (question X-1), but the helper changes in two phases (two reviews of root code, phase 3's helper QA without it), and a second prompt if the helper release ships on its own.
  - (c) Never: the helper stays as it is, and lid-closed starts stay about 30 ms slower than they could be (Linux 220 to 189 ms with F8a).

- **F-3. The runtime folder's owner check (F4a): may a process reuse its stat for 2 to 3 s, with the -L, -d and -O builtin checks still on every call?**
  - (a) Yes: a 2 s window by SECONDS that only an owner read starts, a fresh stat for a folder the process has to make, and the builtin checks on every call. Saves 20 of 23 stat in a lid-open start (one stays in each of the command, the worker and the runner; 18 of the saved ones are in the command and in the worker before it has recorded the runner, which the start waits for) and 6 of 7 per stop. The residual race is described in F.4. **Recommended.**
  - (b) No cache: stat on every check, the most conservative; about 30 to 50 ms more per lid-open start on Linux (18 more stat before the session counts as started).
  - (c) Once per process, cleared in each long-running loop (faster-start-stop.md 6.3's version): a loop that someone forgets would keep a stale check for a whole session.
  - (d) Builtin checks only (-L, -d, -O) on every call, stat for root only: one stat fewer per process and no cache state, but every check then has a gap between -L and -O (which follows a symlink), where today's stat has none.

- **F-4. May the internal modes (--caffeinate-start, --caffeinate-runner, --notify-wait) skip require_macos's uname, since only awake starts them, after its own check? (F10a)**
  - (a) Yes: 2 programs fewer per lid-open start (worker and runner), 1 per notifier; on macOS the check always passed anyway, and on another system those modes, started by hand, fail later instead of at once. **Recommended.**
  - (b) No: keep uname in every process.

- **F-5. Where does F's CLI part go in the order?**
  - (a) Phase 4, last, after I2, H, I1, G1 and F8a: F reuses H1e's JSON helper, converts every id -u the others added, runs its byte-for-byte comparison once on settled code, and its changes to the security checks are reviewed on the final code. The gain is the same in any place. **Recommended.**
  - (b) Right after H, before I1 and the helper release (faster-start-stop.md 6.9's place): F's gain is in the branch sooner, but I1 and G1 then rebase onto F's lines in request_helper_session_stop and next to run_helper, and F's comparison has to be redone after them.
  - (c) Before H: F's gain first; H rebases its printer onto F's JSON helpers, and F carries json_escape's replacement (H1e's work) itself.

### G: the lid-closed stop

- **G-1. Keep the helper protocol at 9 for G?**
  - (a) Keep 9, and bump to 10 only if I3 goes into the same release (question I-1), whose bump then covers G with no change to G. Installer and Homebrew users get the new helper with the one password prompt any helper change brings; a manual CLI-only install keeps today's once-a-second stop until it runs awake --install-helper; the app never reports the helper as out of date; the timing script needs no protocol guard; the Upgrade note is G.7's first text. **Recommended.**
  - (b) Bump to 10 for G regardless. Manual CLI-only installs also get a password prompt, at their next lid-closed start, and the app reports the helper as out of date until then; hand-copied copies of different versions reinstall each other's helper with a prompt each time; the timing script needs its protocol guard; the Upgrade note takes 2.2.0's wording (G.7's second text).

- **G-2. Ship G1 alone, or in one helper release with the other helper changes (F8, and I3 if it goes in)?**
  - (a) Together, in phase 3 of 2.5.0 (G1, then F8, then I3 if it goes in): users see one password prompt for all of them, and the root code is reviewed as one diff of bin/awake-helper. **Recommended.**
  - (b) G1 alone, as soon as it passes Mac QA: the gain comes sooner, but users see a second password prompt when F8 (or I3) follows, since any change to the helper's bytes makes the installer ask again.

- **G-3. If the preflight or the Mac QA shows that G1 does not work as specified (for example macOS's bash or FIFOs behave unlike the evidence), what then?**
  - (a) Ship 2.5.0 without G and fix it later: lid-closed stops keep today's once-a-second look. G is one commit, so nothing else in 2.5.0 changes, and F8 still brings the helper update. **Recommended.**
  - (b) Fall back to G2: in password-free mode only, the CLI runs sudo -n helper restore for its own session. No FIFO and no helper change, but one or two sudo runs and a helper start on every stop (about 15 to 80 ms, Mac estimate), no gain in password mode, restore takes no token and ends any account's session, and awake -- records stopped instead of process_exited (a new stop command would fix the last two but needs protocol 10).

### H: no status run before each app action

- **H-1. The picker's lid mode for a click start. With H the app no longer reads the status first, so it can no longer drop --backend when a session is on, as it does today (AwakeCLI.swift:357-361). Keep passing the app's last lid mode, or add an app-only option?**
  - (a) Keep --backend from the app's last lid mode (H3e). Nothing new in the CLI. In one rare race (a Terminal session in the other lid mode started in the roughly 12 s since the last poll), a click start posts 'Awake failed: A lid-open session is running, so no time can be added to a lid-closed one. Run awake --stop first to switch.' instead of showing the add-time list; the icon then turns bold from the after report. **Recommended.**
  - (b) A new internal --picker-backend MODE that only sets the picker's first lid mode and is ignored while a session runs (bin/awake 7066-7068). That race keeps today's add-time list. Costs about 15 lines in bin/awake, one more 5d check, and the older-CLI retry (H3f) for click starts too.

- **H-2. --if-off: keep it internal, like --prompt-gui-selection, or document it for scripts?**
  - (a) Internal: not in --help or the README, and section 13 of the self-test checks that --help does not list it. It can change without notice. **Recommended.**
  - (b) Documented: one --help line and a README option bullet. Its behaviour (exit 0 without a change while Awake is on, as --status-json defines it) becomes a promise for later versions, and section 13's check is turned around.

- **H-3. An awake older than the app (a copy made by hand, or a 2.4.0 CLI next to the new app): should the app fall back when it refuses --if-off?**
  - (a) Fall back (H3f): on exit 1, no reports, and standard error starting 'Unknown option: --if-off', the app reads the status and runs the start without --if-off, as 2.4.0 did. About 15 lines in AwakeCLI.swift; one refused run (31-36 ms Linux) only with such a CLI. **Recommended.**
  - (b) No fallback: with such a CLI every shortcut start and Start default session fails with 'Awake failed: Unknown option: --if-off' and the usage text. Saves the 15 lines, but breaks the mixed-version promise of faster-start-stop.md's QA 29 and H.6 QA 7.

- **H-4. JSON strings: fold json_escape into a printf -v helper (json_string_or_null_into) as part of H, or leave that to F?**
  - (a) In H (H1e): the found report costs 1.3-2.0 ms on Linux (Mac estimate 2-10 ms), --status-json output stays byte-identical and is pinned by the new sourced check 3a, and status reads get 3-6 ms quicker (Linux). **Recommended.**
  - (b) Leave it to F: the found report costs about 8 ms on Linux (Mac estimate 10-25 ms), 6 ms of it in subshells; json_escape stays as it is, and the check 3a waits for F.

### I: lid-closed starts and the pmset reads

- **I-1. I3: may the helper skip its own battery and thermal reads at a lid-closed start (and when time is added from the app) right after awake has checked them? It removes the helper's root osascript and pmset -g batt, estimated from 7.3 at 35 to 90 ms per lid-closed start (faster-start-stop.md 6.10, question 5).**
  - (a) Gated on the Mac preflight: QA I-2 and I-3 (a) run on the installed 2.4.0 before I1's commit. I3 as specified (start-checked, extend-checked, protocol 10, the timing script's guard) goes into the phase-3 helper release only if the two programs cost 100 ms or more per lid-closed start together; otherwise it stays out and 2.5.0 keeps protocol 9. At 7.3's estimate it stays out. Costs about a minute of a preflight that runs anyway for G1 and I1. **Recommended.**
  - (b) I3 with protocol 10 regardless of the preflight: lid-closed starts and added time from the app lose an estimated 35 to 90 ms. Every CLI-only install gets a forced password prompt at its next lid-closed start (installer and Homebrew users get one prompt for G1 and F8 anyway); mixed manual copies of 2.4.0 and 2.5.0 reinstall each other's helper behind a prompt; the timing script needs its protocol guard and can no longer time 2.4.0's lid-closed rows against the new helper; the Upgrade note takes 2.2.0's protocol-10 wording.
  - (c) No new command and no bump: the helper's start and extend themselves stop checking the battery and the thermal state, and the timer's first pass ends a session at once instead. The same gain; protocol stays 9, G's Upgrade note, no timing-script guard. After a password dialog or the CLI's picker, a Mac that turned critical (or a battery that ran down) meanwhile gets a session of a fraction of a second that ends as overheated or low_battery and clears a SleepDisabled 1 set before it, instead of a refusal; D's backstop becomes an immediate end where the app's value can be 30 s old; a 2.4.0 or older awake that meets such an end waits 30 s.
  - (d) Leave I3 out: QA I-3 (a) is not needed. The helper keeps its root osascript and pmset -g batt on every lid-closed start; protocol stays 9; I1 and I2 ship in phase 2 as planned; questions I-2 and I-3 fall away.

- **I-2. If I3 goes in (question I-1, a with the gate met, or b): when may awake use start-checked instead of start?**
  - (a) Only after a fresh thermal reading (its own osascript, Awake.app's value at most a second or two old, or the thermal guard off), and never after a password prompt or in custom password mode without password-free mode. The helper keeps its own check after the CLI's picker, where D's value can be up to 30 s old, so D's backstop stays a refusal where it matters. **Recommended.**
  - (b) Whenever no password prompt came first: one condition fewer (no app_thermal_state_is_current). A picker start then relies on the timer's first pass alone, so a Mac that turned critical while the picker was open gets a session of a fraction of a second that ends as overheated and clears a SleepDisabled 1 set before it, instead of a refusal.

- **I-3. If I3 goes in: does added time get extend-checked in the same change?**
  - (a) Yes: Add 1 hour on a lid-closed session from the app loses one root osascript and one pmset -g batt (estimate 35 to 90 ms). The timer's regular checks (30 s thermal, 60 s battery, 20 s at 15% or less) go on, so a Mac that turns critical just then is caught at the next check instead of refused. From Terminal awake keeps plain extend. **Recommended.**
  - (b) Start only: added time keeps the helper's own reads; about 10 lines fewer in each file, one helper command fewer, and README.md:604 and the Changed bullet drop their added-time clause.

- **I-4. I3d (after a lid-closed start, the wait ends at once with the reason when the session has already ended): does it ship only with I3, or in phase 2 whatever question I-1 decides?**
  - (a) In phase 2, as its own CLI commit after I1, whatever question I-1 decides: a lid-closed session that ends before awake sees it running (a watched process that exits just then, or a state change between the helper's check and its timer's first pass) is reported at once with its reason, instead of after a 30 s wait and 'Failed to start the awake session.'. About 30 lines and four 12m checks, one Fixed bullet, no helper change; phase 2 gets a fifth commit (H has two). **Recommended.**
  - (b) Only with I3: if I3 stays out (the expected case at 7.3's estimate), today's 30 s wait and its generic message stay; phase 2 stays I2, H, I1.

## How this plan was checked

- Written on Linux, from the code at `32094d1`, without macOS. Bare line numbers are lines of `bin/awake` at `32094d1`; other files are named (`awake-helper:1283`, `AwakeCLI.swift:339`, `tests/cli/awake-self-test:4096`). `bin/awake-helper` has not changed since `v2.2.0`. The line numbers in faster-start-stop.md 6 refer to the older `8ef37f3`; this plan re-derives every one it uses.
- **How it was made.** One researcher per item read the code, built a prototype of its recommendation in a scratch copy, added the self-test checks it proposes, and measured. Then a second, adversarial reviewer per item re-read every cited line, re-ran the prototype and the checks, built deliberate mistakes to see whether the checks catch them, and listed what was wrong or missing. Every fix it gave was applied here; the few it could not settle are open points or Mac QA items. A separate pass planned the order, the branching and the release.
- **Measurements.** Mac figures for today are the owner's same-sitting run of faster-start-stop.md 7.3 (Mac14,2, macOS 26.6.2, 10 rounds, medians). Every other Mac figure is an estimate and says what it rests on. Linux figures come from the macOS emulation used for phase 1 (dry-run, stand-ins for `pmset`, `caffeinate`, `osascript`, `afplay`, `stat`, `date` and `uname`), with the old and the new version alternated in every round because other work shared the machine. Program counts come from `strace` and are the same on a Mac, apart from the real-mode programs each section names.
- **Bash 3.2.** Apple's bash sources (tag `bash-144`, which reports 3.2.57) were built on Linux. G's reading of the FIFO and its TERM trap, F's builtins and every prototype's whole self-test ran on that build as well as on bash 5.2. The builtins and the trap code are Apple's; the kernel under them was Linux's, so the FIFO and signal facts that depend on the kernel are checked in the Mac preflight (1, X8).
- **sudo.** I1's decision rule ran against real `sudo` 1.9.15p5 on Linux, as an unprivileged user, with eight sudoers layouts. macOS ships its own build; the preflight repeats the cases that matter.
- **Swift.** H's app changes and its new `CommandResult.swift` were type-checked against AppKit stand-ins with Swift 5.10.1, and its check's 550 checks built and ran on Linux. CI's app build and its macOS 12.5 build are the first true compile.
- **Each prototype passed the whole self-test** in the emulation, with the three changes every Linux run needs (`plutil`, and the sourced end-time and picker checks, which need BSD `date -j` and `defaults`). Each new check was shown to fail on `32094d1`, or, where it guards a rule that `32094d1` already keeps, to fail on a deliberate mistake.
- **Not run here:** macOS itself, Apple's `sudo`, `launchctl`, notifications and sounds, the real helper as root, and the end-time and picker checks. All of these are in the preflight or in each item's Mac QA.

## Where the time goes now

What the app waits for on the dev build, from faster-start-stop.md 7.3 (Mac, measured, medians):

| Action | Status read first | The action | What the app waits for | What each item removes |
|---|---|---|---|---|
| Lid-open start | 171 ms | 492 ms | 662 ms | H: the status read. F: about three quarters of the action's programs, about half its time |
| Lid-open stop | 228 ms | 315 ms | 542 ms | H, I2, F |
| Lid-closed start | 178 ms | 535 ms | 714 ms | H, I1, F, F8 (and I3, if it goes in) |
| Lid-closed stop | 214 ms | 848 ms (314 to 1268) | 1061 ms | G1: the helper's once-a-second check, about 0.5 s on average. H, I2, F |

- **The status read before each app action** (160 to 230 ms) exists because the CLI does not tell the app what it found. H has the CLI write that, under its lock, for about 2 to 10 ms (Mac estimate; 1.3 to 2.0 ms on Linux).
- **The lid-closed stop** waits for the root helper's timer, which looks for `stop-request` once a second. G1 wakes it through a FIFO.
- **Every run** starts small programs (`awk`, `dirname`, `stat`, `id`, `date`, `chmod`, `ps`) for work bash can do itself: 71 in a lid-open start's command and 57 more in its worker before the session counts as started (Linux `strace`). F replaces most of them.
- **Lid-closed starts** ask `sudo` twice per helper call (I1) and let the helper read the battery and the heat again right after the CLI did (I3, if it goes in). **Stops and added time** read the sleep settings when nothing needs them (I2).

## 1. Order and release

### Decisions

| # | Question | Decision |
|---|---|---|
| X1 | Order | Phase 2, CLI only, no helper change: I2, then H, then I1, then I3d (question I-4). The Mac preflight (X8) runs before I1's commit and before G1. Phase 3, the helper release: G1, then F8, then I3 only if the preflight gates it in (question I-1). Phase 4: F's CLI part, its two commits. Then the 2.5.0 QA and the release. One commit per item part, each with its checks and README lines (not its CHANGELOG bullets, X7); H is two commits, the CLI side and the app side (H.9). Rejected: G first, the largest single gain, as it needs Mac facts that nobody has checked yet and changes root code, while H shortens every app action and needs nothing new; F first, as F touches the functions every later item rewrites, and its byte-identical before-and-after comparisons would have to be redone after each. |
| X2 | Release vehicle | One 2.5.0 with G, H, F and I (question X-1): one Mac QA, and at most one password prompt per user at the update. Rejected: the CLI-only phases as 2.5.0 and the helper changes as 2.6.0, which ships H without a prompt but needs a second QA session (2.4.0's runs two to three days); the helper release first, which waits for the preflight and lets H wait. |
| X3 | The helper protocol | Stays 9. G1 and F8 need no bump for correctness: an older helper makes no FIFO, an older CLI writes no byte, and F8 changes no command or file (G1i, F8a). Only I3 needs 10 (I3e): a new CLI must never send `start-checked` to helper 9. If I3 goes in, the bump is in I3's commit, in both files (bin/awake:165, awake-helper:54), with the timing script's guard (I3f) in the same commit. The self-test already fails when the two numbers differ (tests/cli/awake-self-test:809-812). Rejected: a bump for G1 alone (question G-1), which would make a manual install or a cancelled prompt catch up at the next lid-closed command, but would force a password dialog on CLI-only installs, make mixed hand-copied versions reinstall each other's helper, and need the timing script's guard. |
| X4 | Helper changes together | Every change to `bin/awake-helper` for 2.5.0 is in phase 3, and no other commit touches the file, not even a comment: any change to its bytes costs installer and Homebrew users a password prompt at the update (below). The review of root code is then one diff, `git diff v2.3.0 -- bin/awake-helper` (the helper is the same in 2.2.0, 2.3.0 and, unless a 2.4.0 QA fix touches it, 2.4.0), read at the end of phase 3. G's and F's sections ask the same for their part (questions G-2 and F-2). |
| X5 | Version | 2.5.0. Upgrade notes, Changed and Fixed only; no `**Breaking` and no `### Removed`, so `tools/release.sh` (183-191) suggests minor. The release needs an Upgrade note with or without a bump, as the helper's bytes change ("CHANGELOG and Upgrade notes"). |
| X6 | Where the code goes | On `dev-2.5` until 2.4.0, and any 2.4.x, has shipped (question X-2; "Branching while 2.4.0 is in QA"). |
| X7 | CHANGELOG on the branch | Item commits carry no CHANGELOG bullets; one commit adds all of 2.5.0's entries after 2.4.0 has been merged into the branch (question X-4). Each item section holds its bullets' text. Rejected: bullets in each commit, as phase 1 did on `dev`; a merge of the released `dev` then moves them into 2.4.0's section without a conflict ("Risks across items"). |
| X8 | Mac facts first | A Mac preflight of about 15 minutes, with the installed version and no Awake build, before I1's commit and before G1 (question X-3): the FIFO and bash 3.2 facts G1 rests on, the `sudo` facts I1 rests on, and what I3 would save ("The Mac preflight"). It decides I3: I3 goes into 2.5.0 only if the helper's root `osascript` and its `pmset -g batt` together cost 100 ms or more per lid-closed start. At the estimate from 7.3 (35 to 90 ms: about 45 ms for the `osascript`, 25 to 65, plus `run_with_timeout`'s watcher and 5 to 15 ms for `pmset -g batt`) it stays out (question I-1). |

### Why this order

1. **I2 before H.** Both change main's state block (6767-6812). After I2, main reads `pmset` (6790-6797) only when no session runs, through `read_sleep_settings_for_main`, which sets `pmset_read_ok` and `pmset_session_active`; main's `current_sleep` and `current_disablesleep` locals (6550-6551) go. H's found report is written from main's own state, and must be taken between 6801 and 6803: after `LEFTOVER_SETTINGS_PRESENT` is set, and before the last session's record is cleared at 6805-6811 ("Read before the record of the last session is cleared below", 6803). H's sketch (H.3, items 5 and 6) passes `"$caffeinate_session_active" "$helper_state" "$pmset_read_ok" "$pmset_session_active"` to `write_before_report` and `state_is_active`. Both `pmset` variables exist at `32094d1` (6552-6553, set at 6790-6797) and after I2, which sets them through `read_sleep_settings_for_main` whenever no session runs and leaves them at their defaults (`true`, `false`) otherwise, the only case in which H reads them; so the sketch needs no change when it is written after I2. H's sourced check (7 states) then guards it as before.
2. **H needs A and C,** both on `dev`. A pauses polls during starts and stops (StatusIcon.swift, `pausesPolls`), which is why H must catch a session that ended on its own just before a stop (H3c). C's report file and its safety rules (decision C9) are the model for H's found file.
3. **I1 after H in phase 2** (only I3d, if question I-4 is answered (a), comes after it). It rests on how `sudo` answers, which only the Mac's own `sudo` shows (I's QA I-1). The preflight can run while I2 and H are written. I1 changes `run_helper` (3790-3836), which I3 also changes, so I3, if it comes, is written on top of it.
4. **G1, then F8, in phase 3.** Both change the helper, in different functions (G1: `cmd_start` before the spawn at awake-helper:976, `finish_session`, `cmd_restore`, `cmd_run_timer`; F8: `HELPER_UID` and its uses at awake-helper:94-117, 160 and 200, `SELF` at 108, `write_kv_file` at 184-191). G1 is the gain; F8 rides with it so that its bytes cost no second prompt. I3, if it goes in, comes last: its lines in `cmd_start` (903-908) sit next to G1's, and it builds on I1. All helper bytes stay in one phase (X4).
5. **F's CLI part last.** F replaces programs with builtins across the CLI (faster-start-stop.md 6.3). After H, I and G's CLI parts the paths are settled, and F's byte-identical comparisons (50 status reads and 33 exit paths in the prototype) run once, on the final code. F1 changes the `id -u` at 3943 and F12a the reads at 3941, 3942, 3952, 3954 and 3955 of `request_helper_session_stop`, which G1 changes first. F11a reuses H's `json_string_or_null_into` (H1e) and keeps the results of `read_state_value_into` that H's sourced check guards. I3d's new `$(/usr/bin/id -u)` (the `last` check) becomes `$CURRENT_UID`, as do the two sites I3 rewrites (6332, 7226) if I3 goes in.
6. **J2** stays out (faster-start-stop.md 6.7).

Faster-start-stop.md 6.9 put I1 into the helper release and F before it. This plan moves I1 into phase 2, as it changes only `bin/awake` (reason 3), and F's CLI part after the helper release (reason 5); F's gain is the same in either place. I's section gives the edits to 6.9.

### The Mac preflight

About 15 minutes on the owner's Mac, with the installed 2.4.0 (or 2.3.0: the helper is the same), password-free mode on, plugged in, nothing running. It needs no Awake build, so it can run before 2.4.0 ships. The commands are in G's and I's QA lists; here is what runs and why.

1. **G's QA 1:** in `/bin/bash`, `read -r -n 1 -t 1 -u 3` on a FIFO opened with `exec 3<>` times out after a second and returns a byte written with `printf x 1<>` within about 0.3 s; that write returns at once with no reader. G1d and G1g rest on these.
2. **G's QA 2:** `sysctl net.local.stream.sendspace net.local.stream.recvspace`, the FIFO buffer that G.4's blocking case depends on (8192 from XNU's source).
3. **G's QA 3:** a TERM during `read -t` in Apple's `/bin/bash`, with work in the trap and with a flag. G1e (the flag) rests on what the bash 3.2.57 build showed.
4. Also from G's QA 7, as they need no new helper: `ls -ld /private/var/run` and `id -Gn | tr ' ' '\n' | grep -x daemon`. G's CLI has no folder check outside dry-run because users cannot create entries in `/var/run`.
5. **I's QA I-1:** `sudo -V`, `sudo -n HELPER check`, `sudo -n -l HELPER`, the helper's own exit status through `sudo`, and the order of the `%admin` line and the `includedir` in `/etc/sudoers` (with `grep -nE`); then the same with password-free mode off. I1a rests on these.
6. **I's QA I-2:** 20 runs each of `sudo -n HELPER check` (I1's saving per call), `pmset -g batt`, the `pmset` pair (I2), `sudo -n true`, and the root `osascript` under `sudo`, less the `sudo -n true` loop (I3's thermal read).
7. **I's QA I-3, in a form that runs on 2.4.0:** the installed helper's `start UID 60 5 on off` against `start UID 60 0 off off`, ten of each, alternated, each followed by `restore`. A minimum battery of 0 and the thermal guard off skip exactly the two reads at awake-helper:903-908 that I3 would skip, so the difference is I3's saving per lid-closed start.

8. **Optional, F's QA 9, first part:** whether one `pmset -b sleep X disablesleep Y` call sets both values, which decides F8a's optional combined call (question F-2).

Record the figures in this plan's results table and in faster-start-stop.md 7.3. Then: if any of 1 to 5 differs from what G's and I's sections expect, fix that section before its code is written; and question I-1 is answered from 6 and 7. I3 goes in only if I-3's difference comes to 100 ms or more; the `osascript` (less `sudo -n true`) plus `pmset -g batt` from 6 is the cross-check, and if the two disagree by more than about 30 ms, I-3 counts (I's QA I-3 (a)).

### How users get the new helper

The installer runs `awake --install-helper` on every run (scripts/install-awake.sh:525), or `awake --passwordless on` when it is given `--passwordless` (:522). `--install-helper` skips the password prompt only when the installed helper speaks this CLI's protocol and is byte-identical to the new one (`helper_is_ready && cmp`, bin/awake:4231). So any change to `bin/awake-helper`, with or without a protocol bump, asks installer and Homebrew users for the password once at the update. With password-free mode on it asks too: the rule lets the user run the helper, nothing else (it is written at 4331). `--passwordless on` asks on every run anyway, as it writes the rule again, and installs a changed helper under that same prompt (4320-4328).

This corrects faster-start-stop.md 6.3's F8 row ("the installer reinstalls the helper on every run"): the installer runs `--install-helper` on every run, which reinstalls only a helper that differs, so a changed helper asks once and an identical one never.

**Without a bump (G1 and F8, protocol 9; the recommendation):**

| Who | What happens |
|---|---|
| Installer (`bash install-awake.sh`, `Install Awake.app`) | It stops the running session with the old CLI and the old helper first (scripts/install-awake.sh:384-402, called at :496), installs both files (:507-508), then runs `--install-helper`. The helper is ready (same protocol) but its bytes differ, so it is reinstalled: one prompt, in Terminal or as the macOS dialog (install-awake.sh:320-326). |
| Homebrew (`brew upgrade`, as README.md:132 documents it) | The cask runs the same installer (tools/homebrew/awake.rb:27-29) without a terminal, so the macOS dialog asks once; the cask's caveat already says it asks when it updates the helper (awake.rb:47-48). The tap gets 2.5.0 from the release workflow (.github/workflows/release.yml, job `homebrew`). |
| Manual CLI-only install | Copy both files, then run `awake --install-helper`: one prompt. Nothing asks by itself: the old helper speaks protocol 9 too, so `helper_is_ready` passes and `run_helper` (3812-3825) never reinstalls it. Until then, lid-closed sessions run on the old helper: stops wait for its once-a-second check, as today, and F8's gain is missing. |
| Cancelled prompt | The installer prints "The helper was not installed. Lid-closed mode needs it; run 'awake --install-helper' later." (install-awake.sh:527-528), as `helper_is_installed` compares the bytes (:466-468). Nothing asks again by itself; lid-closed sessions work with the old helper, as today, until `awake --install-helper`. |
| The app | `--status-json` reports `helper_installed` true for the old helper (3082, from `helper_is_ready`), so the app shows nothing out of date. |

**With a bump (only if I3 goes in, protocol 10):**

| Who | What happens |
|---|---|
| Installer, Homebrew | The same, one prompt: the installed helper is now out of date as well as different. |
| Manual CLI-only install | Copy both files. The next lid-closed start, added time or restore finds the helper out of date and installs it and runs the command in one step, under one prompt (`run_helper`, 3812-3825), with a plain `start` or `extend` (I3e). |
| Cancelled prompt | The installer prints its message. The first lid-closed command then asks once, as in the row above, and never again. |
| The app | Until the new helper is in, `--status-json` reports `helper_installed` false (3082, as `helper_is_ready` compares the version at 3629). The app then dims the icon for a lid-closed start, as the CLI may ask for the password (`cliMayAskForPassword`, StatusIcon.swift:134-144), and its menu offers `Install helper…` (StatusBarController.swift:769). |

### Old and new versions together

`helper_is_ready` (3614-3630) accepts the installed helper when its `HELPER_VERSION` equals the CLI's `HELPER_PROTOCOL_VERSION` (3629). Without a bump, every 2.4.0 and 2.5.0 mix passes that test.

**Without a bump:**

| CLI | Helper | Result |
|---|---|---|
| 2.5.0 | 2.4.0 (protocol 9, old bytes) | Works. No FIFO, so `wake_helper_timer` writes nothing (`-p` is false) and a stop waits for the old timer's 1 s check, as today; F8's gain is missing. G's check 4 runs this case (a directory in the way, so no FIFO). |
| 2.4.0 | 2.5.0 | Works, with no reinstall. The old CLI writes only `stop-request`; the new timer's `read -t 1` times out each second and finds it, as `sleep 1` did. faster-start-stop.md 7.1 step 5's `--cli` comparison runs exactly this. |
| 2.5.0 | 2.5.0, with a session started by the 2.4.0 helper still running | Only if the installer could not stop it (install-awake.sh:399-401). A stop works through `stop-request`: the old timer has no FIFO, so it waits for its next 1 s check. Added time works, as the session's `helper_version` (9) equals the helper's (awake-helper:1036-1041), and F8 writes the same record. |
| Two hand-copied versions, 2.4.0 and 2.5.0 | one helper | Neither reinstalls the other's helper at a lid-closed command (both pass `helper_is_ready`); only `--install-helper` or `--passwordless on` replaces it, when the bytes differ (4231, 4322). No reinstall loop. |

**With a bump (I3):**

| CLI | Helper | Result |
|---|---|---|
| 2.5.0 | 2.4.0 (protocol 9) | The first lid-closed command installs the 2.5.0 helper and runs in one step, one prompt (3812-3825). The CLI never sends `start-checked` or `extend-checked` to an old helper: it runs a plain `start` or `extend` after the install (I3e). Added time to a session that helper 9 started is refused after the install with exit 6, "started by an older version of Awake" (awake-helper:1037-1041), as across every bump. |
| 2.4.0 | 2.5.0 (protocol 10) | The 2.4.0 CLI finds the helper out of date and installs its own protocol-9 helper behind a prompt, a downgrade. The installer never leaves this mix. A hand-copied 2.4.0 `awake` next to the 2.5.0 copy: each reinstalls its own helper at every lid-closed command, with a prompt each time; the 2.1.0 Upgrade note describes this for two copies (CHANGELOG.md:212-215). |
| 2.5.0 | 2.5.0, with a session started by the 2.4.0 helper still running | Only if the installer could not stop it (install-awake.sh:399-401). A stop works through `stop-request` (old timer, no FIFO, up to 1 s). Added time is refused with exit 6. |
| 2.4.0 or older, stopping | 2.5.0 timer | The old CLI writes only `stop-request`. The new timer's 1 s wait on the FIFO times out and finds it: as today. |

**The app and the CLI** (either case). A new app with an older CLI (2.3.0, 2.4.0, or a copy made by hand): the found file is ignored, the older CLI refuses `--if-off`, and the app reads the status itself and starts without it (H3f). A 2.4.0 app with the new CLI sets no found file and passes no `--if-off`, so the CLI does what 2.4.0's does, with byte-identical `--status-json`. The installer and Homebrew always install both. F and H change no file format, so a session started by either version is read and stopped by the other (F's comparison ran both ways).

### Phases

| Phase | Items | Helper | Password prompt at the update | Mac work before the release |
|---|---|---|---|---|
| 1 (done) | A to E, J1 | unchanged | none | the 2.4.0 QA |
| 2 | I2, H, I1, I3d (question I-4) | unchanged | none | the preflight (X8), before I1's commit; optional: one timing sitting, no install ("Timing") |
| 3 | G1, F8; I3 only if gated in | new bytes, protocol 9 (10 with I3) | one, for installer and Homebrew users (with I3, also for CLI-only installs, at their next lid-closed command) | none beyond the preflight |
| 4 | F's CLI part, two commits | unchanged since phase 3 | (the one of phase 3) | none |
| 5 | the 2.5.0 QA and release | | | `qa-2.5.0.md` ("Shared tests and QA") |

With question X-1 answered (b), phase 2 and F's CLI part ship as 2.5.0 without a prompt, and phase 3 as 2.6.0 with it.

## 2. Branching while 2.4.0 is in QA

### How releases reach `main` today

- `tools/release.sh` commits "Version X.Y.Z" on the current branch, normally `dev` (tools/release.sh:211-252). It moves every bullet under `## [Unreleased]` into a new dated section (`date_changelog`, 136-146).
- A PR from `dev` into `main` is merged with a merge commit (PRs #1, #2, #3, #5 and #6; qa-2.4.0.md 12.3). The push to `main` runs `.github/workflows/release.yml`: it tags the merge commit `vX.Y.Z`, creates the GitHub release from the changelog section, then runs `homebrew-tap.yml`, which updates the tap's cask.
- Then `dev` is fast-forwarded to `main` (qa-2.4.0.md 12.5). `v2.3.0` is on merge commit `0502b69`.
- A feature branch has been merged into `dev` by PR before: #4, from `claude/review-2-2-0-plan-tpnsye`.
- CI runs on pushes to `main` and `dev`, on every pull request, and by hand (ci.yml:3-7). A push to another branch runs nothing by itself.
- The 2.4.0 QA builds from `dev` and reinstalls from it after each fix (qa-2.4.0.md 2.1, step 6). `dev` is 17 commits ahead of `main`.

### Decision

Code for 2.5.0 goes on a branch `dev-2.5`, made from `dev`, with a draft PR into `dev` for CI. It is merged into `dev` only when 2.4.0 has shipped and no 2.4.x is expected (question X-2).

- `dev` stays the 2.4.0 QA build plus the QA's fixes. Besides those, only documents land on `dev` meanwhile: this plan, and faster-start-stop.md's pointer to it. They change no installed file (the installer copies `bin/`, the app and the picker), and CI runs on them as on any push.
- `tools/measure-latency.sh` changes only on `dev-2.5`: the 2.4.0 QA times with the script on `dev` (qa-2.4.0.md 1.2, 10.1).
- Rejected: committing to `dev` now. It changes the build under QA, and `tools/release.sh` would ship the work as part of 2.4.0, the reason plan-2.4.0.md gave against a 2.3.1 before 2.4.0 (its question 4, plan-2.4.0.md:33). Rejected as the default, offered as option (b) of question X-2: no code until 2.4.0 ships, which is simplest but lets the work wait for two to three days of QA and its fixes.

### Steps

**Start the branch,** when the first 2.5.0 commit is ready:

```bash
git fetch origin
git switch -c dev-2.5 origin/dev
# ... commits, one per item part (X1) ...
git push -u origin dev-2.5
gh pr create --repo anttikaenmaki/awake --draft --base dev --head dev-2.5 \
    --title "2.5.0: faster start and stop, part 2 (G, H, F, I)" \
    --body "Not to be merged before v2.4.0 is tagged. Plan: docs/plans/faster-start-stop-2.md."
```

CI runs on every push to the branch through the PR's `pull_request` event, on the PR's merge with the current `dev`, so it also shows whether the branch still works on top of the QA's latest fixes. GitHub runs `pull_request` workflows for draft PRs too. Rejected: adding `dev-2.5` to ci.yml's `push` branches, which would have to be undone before the merge.

On the Mac, keep `~/awake` on `dev` during the 2.4.0 QA, as its install and timing steps run from there. Look at the branch in its own worktree: `git -C ~/awake worktree add ~/awake-2.5 dev-2.5` (not under `~/awake-qa`, which qa-2.4.0.md 12.7 removes). Do not run the branch's self-test or any `--dry-run` while the QA runs its own: all copies share the dry-run folders (qa-2.4.0.md 3.1, Needs).

**A fix from the 2.4.0 QA.** It goes on `dev` with a `### Fixed` entry in 2.4.0's `[Unreleased]`, as qa-2.4.0.md says, and the QA reinstalls from `dev`. The same day:

```bash
git switch dev-2.5
git fetch origin
git merge origin/dev        # never rebase: the branch is pushed and has a PR
git push
```

When the fix touches code an item rewrites (the lid-open stop waiter, C's report, J1's start check, main's state block at 6767-6812, `request_helper_session_stop` at 3917-3968, `run_helper` at 3790-3836), the item's checks run again on the merged code, and its line numbers are taken from the merged tree. The fix's CHANGELOG bullet stays in 2.4.0's section.

**After 2.4.0 has shipped,** once qa-2.4.0.md 12.5 has brought `dev` up to `main`:

```bash
git switch dev-2.5
git fetch origin --tags
git merge origin/dev        # brings "Version 2.4.0" and main's merge commit
diff <(git show v2.4.0:CHANGELOG.md | sed -n '/^## \[2\.4\.0\]/,/^## \[2\.3\.0\]/p') \
     <(sed -n '/^## \[2\.4\.0\]/,/^## \[2\.3\.0\]/p' CHANGELOG.md)    # prints nothing
# One commit: 2.5.0's Upgrade notes, Changed and Fixed under ## [Unreleased] (X7)
/bin/bash tools/release.sh --notes Unreleased | awk 'length > 79'      # prints nothing
git push                    # wait for green CI on the PR
gh pr ready <n> --repo anttikaenmaki/awake
gh pr merge <n> --repo anttikaenmaki/awake --merge                     # a merge commit, as PR #4
git switch dev; git pull --ff-only origin dev
git branch -d dev-2.5; git push origin --delete dev-2.5
```

Then the 2.5.0 QA runs from `dev`, and the release follows qa-2.4.0.md 12.1 to 12.7 with 2.5.0 in place of 2.4.0: `tools/release.sh` suggests minor, 2.4.0 to 2.5.0.

**If the 2.4.0 QA ends with the quick pass.** Its open items run after the release, and their fixes go into 2.4.1 (qa-2.4.0.md:85). Keep `dev-2.5` off `dev` until those items have run, so that 2.4.1 is an ordinary release from `dev` with Fixed entries only (`tools/release.sh` then suggests patch).

**A 2.4.x fix after `dev-2.5` is on `dev`.** Release it from a branch made from the tag:

```bash
git switch -c release-2.4.1 v2.4.0
git cherry-pick <fix>       # with its ### Fixed bullet under ## [Unreleased]
/bin/bash tools/release.sh patch
git push -u origin release-2.4.1
gh pr create --repo anttikaenmaki/awake --base main --head release-2.4.1 \
    --title 'Version 2.4.1' --body "$(/bin/bash tools/release.sh --notes)"
gh pr merge <n> --repo anttikaenmaki/awake --merge
git switch dev; git fetch origin; git merge origin/main
```

The push to `main` tags and publishes 2.4.1 as usual; `release.yml` does not care which branch the PR came from. The last merge is a real merge, as `dev` has moved on. It conflicts in CHANGELOG.md, where both sides added text under `## [Unreleased]`: keep 2.5.0's entries under `## [Unreleased]`, then the `## [2.4.1]` section, and check with `/bin/bash tools/release.sh --notes 2.4.1`.

## 3. Expected gains

### Basis

The Mac figures for today are the owner's same-sitting run (faster-start-stop.md 7.3: Mac14,2, macOS 26.6.2, 10 rounds, medians, `bin/awake` as at `63b982a`, which is the same as `32094d1`). The status runs before each app action took 171 ms (lid-open start), 228 (lid-open stop), 178 (lid-closed start) and 214 (lid-closed stop); the actions 492, 315, 535 and 848 ms (314 to 1268). Everything else is an estimate, built from those medians and from measurements in the macOS emulation on Linux (dry-run, old and new alternated in every round):

- **One bash run of `awake` costs about 25 ms before any work** (parsing the 7,336 lines and the top-level code: sourcing it took 23 ms, `--version` 25 ms, Linux). A status read took 86 to 92 ms with no session and 150 to 163 ms with one (three runs). So most of a status read is its work, the programs it runs, not the process.
- **Why H's found report is lean.** The same status object printed inside an already running bash took 56 to 66 ms with no session and 126 to 134 ms with one, against 86 to 92 and 150 to 163 ms for a separate run (Linux, three runs of 15 to 20 rounds). A full report written from main's state would therefore still cost 61 to 89% of the status run it replaces. H writes only the 10 keys the app reads, from main's own reads, with builtins: 1.3 to 2.0 ms (Linux, 40 calls each), 15 ms for a session tied to a process (H1c, H1d). Mac estimate: 2 to 10 ms.
- **A warm step can be quicker on the Mac.** Today's "with C and H" figures, and H's Mac estimates, time each action right after a status run. The app with H runs it after an idle gap of up to 10 s. In the emulation the order made no difference (12 rounds: start 574 against 572 ms, stop 306 against 310), but in 7.3, between two sittings, the steps right after another run sped up more (29 to 34%) than the status runs (14 to 22%), a hint that a step's place matters on the Mac. So what the app waits for after H is a lower bound, and H's gain an upper bound, until the timing script's `--no-status-runs` (H's change, "Timing") has run on the Mac.
- **What I3 would save, from 7.3.** In the same sitting the lid-closed start's action went from 441 ms (2.3.0) to 535 ms (dev). Between the two the CLI dropped its own `osascript` (the timing script passes the thermal state, tools/measure-latency.sh:107-145, and D uses it) and gained C's report, written in the same process. That report costs about 83% of a status run (117 against 141 ms, Linux, a lid-closed session running), so about 0.83 × 166 ≈ 138 ms on the Mac. The `osascript` was then about 138 − 94 ≈ 45 ms; allowing for the medians' noise, 25 to 65 ms. The helper's root `osascript` is the same program, plus `run_with_timeout`'s watcher, and `pmset -g batt` adds 5 to 15 ms. The plan's earlier 0.1 to 0.4 s (faster-start-stop.md:77) was a guess made before any Mac timing.
- **What a `sudo` costs, from 7.3.** A budget of the 535 ms lid-closed start (I's section): `awake`'s own work before the helper at least an idle status read plus the lock and `pmset -g batt` (about 190 ms), C's report (about 138), the helper's start work, `helper_is_ready`'s seven programs and the first wait check (about 160). That leaves about 45 ms (535 − 190 − 138 − 160) for the two `sudo` runs, each starting the helper's bash: about 20 ms per call, at the low end of the 15 to 40 ms that Linux's 10 and 13 ms suggest for macOS's `sudo`.
- **A builtin key reader (F3)** in place of `awk` took the in-process status object from 56 to 36 ms with no session and from 126 to 134 down to 89 to 94 ms with one (Linux, 30 to 36% less), with the same output. That was a stand-in for the measurement. F's final prototype, re-measured by its reviewer on the exact final file (10 rounds alternated, bash 5.2): lid-open start 530 → 258 ms, lid-open stop 331 → 144, lid-closed start 406 → 222, a status read with a session 158 → 82.
- **The emulation against the Mac.** `tools/measure-latency.sh --dry-run --lid-closed --rounds 10` at `32094d1` gave, as status before / action / status after: lid-open start 88 / 475 / 160, lid-open stop 162 / 262 / 88, lid-closed start 95 / 365 / 152, lid-closed stop 156 / 779 (243 to 1169) / 88. The Mac took 1.1 to 1.9 times as long for the status reads, 1.04 to 1.2 times for the lid-open actions, 1.47 times for the lid-closed start (the dry run runs no `sudo`, no `osascript` and no real `pmset`) and 1.09 times for the lid-closed stop (both wait for the helper's 1 s check). The emulation's `stat`, `date` and `uname` are bash stand-ins that cost 3.3, 3.0 and 1.9 ms against 1.8, 1.3 and 1.4 ms for the programs (200 calls each), about 30 to 35 ms of F's Linux gain on a lid-open start; F's Mac estimates take 0.7 to 1.0 times its Linux gains for that reason. An emulation difference is a guide to the direction and size of a Mac difference, not a promise.

### Per item (Mac, estimates)

| Item | Phase | What it removes | Gain | Basis |
|---|---|---|---|---|
| I2 | 2 | main's two `pmset` reads (6790-6797) while a session runs | stops and added time: 0 to 20 ms | When C6 took the same pair out of the status read, the status after a start fell from 191 to 172 ms (lid-open) and 186 to 166 ms (lid-closed) between 2.3.0 and dev in one sitting (7.3). The dry run reads a mock file, so Linux shows no change outside noise. |
| H | 2 | the status run before each app start, stop, added time and helper change; adds the found report | lid-open start about 160 to 170 ms, lid-open stop about 220, lid-closed start about 170 to 175, lid-closed stop about 205 to 210; `Add 1 hour` about 210 to 230; `Install helper…` and password-free mode on or off about 160 to 180, behind a password dialog anyway | The measured status runs (171, 228, 178, 214) less the found report (2 to 10 ms, estimate; 1.3 to 2.0 ms Linux). Upper bounds until the `--no-status-runs` timing (Basis). Linux, measured (12 rounds): the app's wait fell by 94, 176, 78 and 130 ms. ⇧⌘A while a session started elsewhere is on gets 50 to 100 ms slower (estimate; 41 to 47 ms Linux), and with an older CLI a refused run of 31 to 36 ms (Linux) is added. Status reads get 3 to 6 ms quicker (H1e, Linux). |
| I1 | 2 | one `sudo -n helper check` per helper call, in password-free mode | 15 to 40 ms per lid-closed start, added time or restore (about 20 by the budget above); 30 to 80 ms per lid-closed start from Terminal, which ran two checks (I1e) | Real `sudo` 1.9.15p5 on Linux: 10 and 13 ms per `sudo -n helper check`, widened for macOS's `sudo`, which also asks opendirectoryd and logs each run; the budget of the 535 ms run. The preflight measures it (I-2). |
| G1 | 3 | the wait for the helper's once-a-second check | lid-closed stop's action: 848 ms median (314 to 1268) → about 320 ms, at most about 450: about 530 ms on the median, and the spread of about a second goes | The Mac's old minimum (314 ms), the stop that met the check at once, and its lid-open stop (315 ms), which does about as much. On Linux the new median (256, 258 ms) was about the old minimum or below it (255, 309 ms), and the spread shrank to about 30 ms. |
| F8 | 3 | in the helper: `id -u` in every process, `dirname` and `basename` for `SELF`, `write_kv_file`'s `mktemp`, `dirname`, `cat` and `chmod` | about 30 ms per lid-closed start | Linux: the lid-closed start's action 220 → 189 ms (bash 5.2) and 224 → 194 ms (bash 3.2.57). |
| I3, only if gated in | 3 | the helper's start-time `osascript` and `pmset -g batt` (awake-helper:903-908), and the same in `extend` (1059-1066) | 35 to 90 ms per lid-closed start, and per lid-closed added time from the app; none after a password dialog or the CLI's picker (plain `start`), none in custom password mode (`run_as_admin`'s custom path always runs the plain `start`), none for added time from Terminal (plain `extend`) | The root `osascript` about 45 ms (25 to 65) from 7.3's 2.3.0 → dev change (Basis), plus `pmset -g batt` 5 to 15 ms and the watcher's fork. The preflight measures it (I-2, I-3) and decides (X8). |
| F, CLI part | 4 | small programs (`awk`, `dirname`, `stat`, `id`, `date`, `chmod`, `ps`, `uname`) and a subshell per JSON field | each status read 40 to 100 ms; actions: lid-open start 180 to 280 ms, lid-open stop 110 to 200, lid-closed start 130 to 220, lid-closed stop 40 to 100; Terminal: `awake --status` 15 to 30 ms, `awake --start` 140 to 210, `awake --stop` 60 to 100 | 0.7 to 1.0 times the Linux gains (Basis; the draft's two 14-round sittings, 522 → 257 and 510 → 262 ms for a lid-open start, and the reviewer's 10 rounds on the exact final file, 530 → 258), plus F9a's 6 programs per JSON status, report or helper call, which only a Mac with the helper installed runs (9 to 18 ms each). Programs per action, Linux `strace`: lid-open start 71 → 19 (its critical path 124 → 36), lid-open stop 53 → 12, lid-closed start 82 → 20, lid-closed stop 70 to 73 → 17. |

### What the app waits for (ms; Mac)

After H, the app waits for the action alone, which then writes both reports. Before H, it waits for the status read and the action ("with C").

| Action | Today, `dev` (measured) | After phase 2: I2, H, I1 | After phase 3: G1, F8 | After phase 4: F |
|---|---|---|---|---|
| Lid-open start (⇧⌘A, `Start default session`) | 662 | about 495 | about 495 | 210 to 310 |
| Lid-open stop | 542 | 300 to 320 | 300 to 320 | 120 to 210 |
| Lid-closed start, password-free mode | 714 | 500 to 525 | 470 to 495 | 265 to 370 |
| Lid-closed stop | 1061 (the action 0.3 to 1.3 s) | 830 to 850 (still 0.3 to 1.3 s) | 310 to 340, at most about 460 | 220 to 330 |

- From phase 2 on, these are lower bounds until H's `--no-status-runs` timing (Basis).
- With I3, if the preflight gates it in: lid-closed starts 35 to 90 ms less in phases 3 and 4.
- The owner's "with C and H" figures (492, 315, 535 and 848 ms) are the 2.4.0 actions alone, each timed right after a status run. H's found report adds only 2 to 10 ms to them; the open question is how much slower an action is after an idle gap.
- Added time from the app: H about 210 to 230 ms, I2 0 to 20 ms, and for a lid-closed session I1 15 to 40 ms (and I3 35 to 90 ms, if it goes in), then F. No Mac baseline yet.
- A lid-closed start with a password: the password dialog dominates; F8 and F still apply, I1 and I3 do not.

### Terminal commands (Mac, estimates)

H does not apply: a terminal command is one run. No 2.4.0 baseline has been measured on the Mac yet; qa-2.4.0.md 10.1 times the app's steps and, three times, `time awake --stop` after a lid-open start (step 5); the 2.5.0 QA adds `time` for the others ("Timing").

| Command | Phase 2 | Phase 3 | Phase 4 |
|---|---|---|---|
| `awake --stop`, lid-open session | I2: 0 to 20 ms less | — | F: 60 to 100 ms less |
| `awake --stop`, lid-closed session | I2: 0 to 20 ms less | G1: about 530 ms less on the median; from 0.3 to 1.3 s down to about 0.3 to 0.4 s | F |
| `awake --duration 10m`, lid-closed, password-free mode, nothing running | I1: 30 to 80 ms less (two checks) | F8: about 30 ms less; with I3, if it goes in, another 35 to 90 ms | F |
| `awake --duration 10m` on a running lid-closed session (added time) | I1: 15 to 40 ms, I2: 0 to 20 ms less | F8, not measured (from Terminal, I3 keeps the plain `extend`) | F |
| `awake --start --backend caffeinate --duration 10m` | — | — | F: 140 to 210 ms less |
| `awake --status` | — | — | F: 15 to 30 ms less |
| `awake --status-json`, and the app's 10 s polls | H1e: 3 to 6 ms (Linux) | — | F: 40 to 100 ms less |
| `awake -- COMMAND`, lid-closed | — | G1: the session ends about 0.5 s sooner on average after the command, up to 1 s | — |

A terminal start still runs `osascript` for its own heat check: D covers only the app's runs.

## 4. F: builtins in place of small programs

Bare line numbers are `bin/awake` at `32094d1`. "Linux" figures were measured in the macOS emulation (dry-run, stand-ins for `stat`, `date`, `pmset`, `caffeinate`, `osascript`, `uname`); "Mac" figures come from the owner's 10-round runs in faster-start-stop.md 7.3 or are marked as estimates. Program counts come from `strace -f -e trace=execve,clone` and are the same on a Mac, apart from the real-mode additions named in F.1.

F has two parts. The CLI part (both commits, F.3) lands last, in phase 4, after H, I and G1. The helper part (F8a) lands in phase 3, the helper release, right after G1. Neither changes the helper protocol, which stays 9 unless I3 goes in (question I-1).

### F.1 Today

Every run is a new bash that reads the 7,336-line script. On top of that, the code runs small programs for work bash can do itself: a file read with `awk` for every key, `dirname` for every runtime path, `stat` for every check of the runtime folder, `id -u` in eleven places, five `date` calls per status read of a running session, a `chmod` after every `mktemp`, and `ps` to see whether the runner lives. Each one is a fork and an exec.

**Programs per run, at `32094d1` (Linux strace, dry-run; `sleep` of the 0.05 s checks left out):**

| Run | Programs | Forks | The programs |
|---|---|---|---|
| `--status-json`, no record | 7 | 41 | `id` 3, `dirname` 2, `basename` 1, `uname` 1 |
| `--status-json`, after a lid-open session | 19 | 74 | `awk` 11 and the 7 above, `stat` 1 |
| `--status-json`, after a lid-closed session | 22 | 76 | `awk` 14 |
| `--status-json`, lid-open session running | 31 | 119 | `awk` 17, `date` 5, `ps` 1 |
| `--status-json`, lid-closed session running | 36 | 130 | `awk` 22, `date` 5, `ps` 1 |
| App lid-open start (the command) | 71 | 229 | `awk` 21, `dirname` 10, `stat` 8, `id` 6, `date` 6, `chmod` 5, `ps` 4 |
| its worker, until it has recorded the runner | 57 | 97 | `dirname` 20, `stat` 12, `id` 4, `chmod` 4 |
| its runner, until the command exits | 15 | 28 | `dirname` 6, `id` 2 |
| App lid-open stop | 53 | 153 | `awk` 22, `dirname` 8, `stat` 7, `id` 4, `ps` 3 |
| App lid-closed start (the command) | 82 | 237 | `awk` 28, `dirname` 10, `stat` 9, `id` 7, `chmod` 6, `date` 6 |
| its helper `start` / timer / guard | 32 / 13 / 12 | 43 / 17 / 13 | `id` 8, 6, 6 (3, 1, 1 in real mode: the dry-run branch at awake-helper:96-118 adds six); `write_kv_file`'s `mktemp`, `dirname`, `cat`, `chmod` and `mv` for each of 3 files; `dirname` and `basename` for `SELF` |
| App lid-closed stop | 70 to 73 | 170 to 179 | `awk` 30 to 33 (one per 0.05 s check), `id` 7, `dirname` 7, `stat` 7 |

The app runs the action with `AWAKE_STATUS_JSON_FILE` and `AWAKE_APP_THERMAL_STATE`, as `tools/measure-latency.sh` does; the counts above include the report (C). The lid-closed stop's counts vary with the number of 0.05 s checks until the helper's once-a-second check acts (two traces: 73 and 70 programs). Two paths were not traced: the terminal start's notifier (`--notify-wait`, started with `--notifications`) and added time. Where this section names a program for them (the notifier's `uname` in F10a, its `dirname` in the ranking below), it is read from the code, not counted.

**On the owner's Mac, real mode adds** (read from the code, not traced): 7 programs to every run that prints a JSON status (`--status-json`, C's report), because `helper_is_ready` (3614-3630) checks three paths with two `stat` each and a `dirname` (3622-3627) when the helper is installed; 7 more for each helper call (`run_helper`, 3812); and 2 `pmset` plus 2 `awk` each time it reads the sleep settings (`get_battery_setting`, 2089-2123, for `sleep` and `disablesleep`): twice in a stop (main's check and the report), once in a start and in a status read without a session. The text `awake --status` runs no `helper_is_ready`. Dry-run reads a mock file instead of `pmset`. F does not change the `pmset` reads (F14a).

**A lid-open start's critical path** is the command until it starts the worker, the worker until it records the runner (the command's 0.05 s check, J1, waits for that), then the command's last check and its report. At `32094d1` that is 20 + 57 + 47 = 124 programs (Linux strace, `phases.py`; 123 in the review's trace), plus the 7 of `helper_is_ready` and 4 for `pmset` on the Mac.

**The call sites, ranked by programs per app action:**

| Rank | Program | Where | Per action at `32094d1` |
|---|---|---|---|
| 1 | `awk` | `read_state_value` (2347-2356), 114 `$(read_state_value …)` calls on 112 lines | 17 to 36 per status read; 21 + 2 per lid-open start; 22 per lid-open stop; 28 per lid-closed start; 30 to 33 per lid-closed stop |
| 2 | `dirname`, `basename` | `SCRIPT_PATH` (212) and `resolve_script_file_dir` (226, 231) in every process; runtime paths (830, 2641-2642, 2679, 2698, 3483, 4371, 5246, 5314, 5409, 5484, 5524-5525, 5619, 5678, 5833, 6028) | 3 per process (main, worker, runner, notifier); 10 + 24 + 6 in a lid-open start, 20 of the worker's on the critical path |
| 3 | `stat -f %u` | `get_path_owner_uid` (718-720) from `validate_runtime_dir_path` (722-755) and `ensure_runtime_dir` (782-818), on every runtime file path | 8 + 14 + 1 in a lid-open start (12 on the worker's critical path); 7 per stop |
| 4 | `id -u` | 173 (twice), 793, 862, 1435, 1475, 3943, 6332, 6644, 6709, 7110, 7226 | 3 per run at least; 4 to 7 per start or stop |
| 5 | `date` | `current_epoch` (1043-1045) twice and `format_deadline_label` (1706-1708) three times per status with a session; 2376, 5686, 6447 | 5 per status read with a session; 6 + 2 per start |
| 6 | `chmod` | after `mktemp` (2647, 5336, 6044), the lock's pid file (1349), `ensure_runtime_dir` (816) and `set_runtime_file_permissions` (870) | 5 to 6 per start |
| 7 | `stat` and `dirname` | `helper_is_ready` (3622-3627), Mac only | 7 per JSON status, report and helper call with the helper installed |
| 8 | `uname -s` | `require_macos` (693-698), once per process | 1 per process |
| 9 | `ps -p` | `lock_pid_is_running` (1207-1215), called only at 2594 | 1 per lid-open start |
| 10 | `rm -f` of nothing | 2672, 2737, 7225 | 1 to 3 per start |
| — | subshells without a program | `print_status_json`'s 24 field `printf` (3116-3151), 18 with a `$( )`, and a nested `$(json_escape …)` for each non-empty string; `$(read_state_value …)` callers | 41 to 130 forks per status read |

**What it costs.**
- Linux, measured (300 calls each, `chk/micro2.sh`), bash 5.2: `id -u` 1.8 ms, `dirname` 1.6 ms, `ps -p` 4.2 ms, the `awk` reader in `$( )` 2.1 ms, the builtin reader in `$( )` 0.8 ms, `read_state_value_into` 0.14 ms, a `$( )` subshell alone 0.46 ms, `kill -0` 0.007 ms. Bash 3.2.57: `awk` 2.0 ms, the builtin reader in `$( )` 1.2 ms, `_into` 0.53 ms (for the 17th key of a state file; 3.2's `read` is slower), a subshell 0.42 ms.
- Mac, from 7.3: the status read before each app action costs 160 to 230 ms, and the dev build's actions take 492 ms (lid-open start), 315 ms (lid-open stop), 535 ms (lid-closed start) and 848 ms (lid-closed stop). For the same code the emulation took 510 to 522 ms for the lid-open start, 287 to 321 ms for the lid-open stop and 388 to 407 ms for the lid-closed start (the Mac adds real `sudo` and the real helper). Status reads took 147 to 165 ms with a session and 95 ms after one, against 214 to 228 and 171 to 178 ms on the Mac, which also runs 7 to 11 more programs per read (`helper_is_ready`, `pmset`). So the Mac took 0.9 to 1.1 times the emulation's time for the lid-open actions and 1.3 to 1.9 times for the lid-closed start and the status reads, and how much of that is the cost of a program is not known (estimate: 1.5 to 3 ms each). In the emulation `stat`, `date` and `uname` are bash stand-ins: 3.3, 3.0 and 1.9 ms against 1.8, 1.3 and 1.4 ms for the programs themselves (200 calls each), about 30 to 35 ms of the lid-open start's Linux gain. Programs and bash starts are most of each run.

**Why.** These checks were written for safety and clarity, one program per question. bash 3.2 can answer most of them itself: parameter expansion for paths, `read` for key=value files, `printf -v` for results, `kill -0` for liveness, `[[ -O ]]` for ownership. The places where a builtin would weaken a rule are kept (F.2).

### F.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| F1a | The user ID | One `/usr/bin/id -u` per process, in a readonly `CURRENT_UID` at 173; `AWAKE_USER_UID` comes from it as today. All eleven sites use it. | `$EUID` or `$UID`: bash takes both from the environment when they are set there. `env EUID=0 UID=0 bash -c 'echo $EUID $UID'` printed `0 0` as uid 1093 with bash 3.2.57 and 5.2.21 (Linux builds; bash's `uidset()` keeps an imported value). With it, `sudo env EUID=501 awake --start` would get past the root refusal (6644) and `env EUID=0 awake` would be refused; `AWAKE_USER_UID` (173), the uid check at 3943 and the helper's argument (7226) would follow the environment. Mac QA 1 confirms Apple's bash; Mac QA 10 runs the root paths. |
| F1b | `id -u` sites from earlier items | F lands last (phase 4), so it converts the `id -u` calls that the items before it add. I3d (question I-4; in phase 2 if it is answered (a), whatever question I-1 decides) adds one, in the check of the helper's `last` record after a start that ended on its first pass, and I3, if it goes in (question I-1), rewrites two of the eleven sites (6332, 7226); all of them become `$CURRENT_UID`. H, I1, I2 and G1 add none. | — |
| F2a | Runtime paths | `${path%/*}` at the 19 runtime-path sites. Each path is a constant under `STATE_DIR` or has matched `^/tmp/keep-awake-lid-closed(-dry-run)?-[0-9]+/NAME$` (825) first, so it has one slash before the name and `${path%/*}` is what `dirname` prints. `deadline_lock_path` (5245-5247) goes; its two callers build the path inline. | A `dirname` function called in `$( )`: still a fork. |
| F2b | The script's own path | A new `set_parent_dir VAR PATH` with `dirname`'s rules ("." without a slash, "/" for a file in the root, no trailing slash), for `SCRIPT_PATH` (212) and `resolve_script_file_dir` (226, 231); `${BASH_SOURCE[0]##*/}` and `${SCRIPT_PATH##*/}` for the file name (212, 308, 577, 4003). `SCRIPT_PATH` is still `cd … && pwd -P`, so process identity checks see the same path. | Keeping `dirname` there, as faster-start-stop.md 6.3 suggested: 3 programs in every process, 9 per lid-open start. |
| F2c | Kept | `basename` of the command after `--` (3974, 4060, 6484): a command may end in a slash, and these run once. `dirname` in `helper_install_command` (3662, 3666): constants, once per install. | — |
| F3a | The key reader | `read_state_value` (2347-2356) reads with `IFS= read -r line`, key `${line%%=*}`, value `${line#*=}`, the first match wins; it fails with 2 when the file cannot be read, as `awk` did. `read_state_value_into` (2361-2373) uses the same rules. Both matched `awk -F=` on 24 edge cases with bash 3.2.57 and 5.2.21. | `IFS='=' read -r key value`, today's `_into`: it drops one trailing `=` (`k=v=` gives `v`) and reads a line `k` without `=` as empty where `awk` gives `k`. |
| F4a | The runtime folder | Its owner (`stat -f %u`, which does not follow a symlink) is read again only when the last read in this process is more than `RUNTIME_DIR_RECHECK_SECONDS` (2) old by `SECONDS`; a negative age counts as old. Only an owner read starts a new window: `ensure_runtime_dir` keeps the time of a fresh check rather than renewing it, so one `stat` vouches for the folder for 2 to 3 s at most. The builtin checks still run on every call: the path pattern, not a symlink (`-L`), a folder (`-d`), and owned by this process's user (`-O`). A folder that `ensure_runtime_dir` has to make is read again. The command's 0.05 s waits for a start or a stop, which check the status file's path on every pass, read the owner at most every 2 to 3 s; the processes that live for a whole session (worker, runner, monitor, notifier) check the folder only when they act (a stop request, the deadline lock, the end), so they read it as before. Question F-3. | Once per process with clearing in each loop, as faster-start-stop.md 6.3 had: a loop that someone forgets would keep a stale check for a whole session. `[[ -O ]]` alone: it follows a symlink. Builtin checks only (`-L`, `-d`, `-O`) on every call, `stat` for root only: one `stat` fewer per process and no cache state, but every check would then have a gap between `-L` and `-O` (which follows a symlink), where today's `stat` has none and F4a has it only between stats, at least every 2 to 3 s. No cache (question F-3): 23 `stat` in a lid-open start (command 8, worker 14, runner 1), 20 of them in the command and in the worker before it has recorded the runner, which the start waits for. |
| F4b | The window | 2 s (`SECONDS` counts whole seconds, so 2 to 3 s). Long enough for a whole start, stop or worker start-up (0.2 to 0.6 s on Linux). | 0: the cache does nothing. 1: up to two reads per short run at a second's edge, for nothing. |
| F5a | Liveness | `lock_pid_is_running` (1207-1215) uses the builtin `kill -0`, for PIDs matching `^[1-9][0-9]*$`. Its only caller (2594, `state_session_is_ready`) asks whether the runner, one of this user's processes, still runs, after `state_session_is_active` has matched the worker or the runner by command line. Liveness only, as today's `ps -p` was. `kill -0` is never looser: a PID that another user's process reuses reads as gone, where `ps -p` read it as running. | `kill -0` for identity checks (`process_command_line` 1217-1225, `process_start_time` 2248-2258), or for the helper's timer and guard, which are root's: `kill -0` fails with EPERM for another user's process, which reads as "gone". `is_positive_integer` (1012-1014) as the guard: it takes `00`, which `kill` reads as 0, the process group. |
| F6a | `chmod 600` after `mktemp` | Dropped at 2647, 5336 and 6044: `mktemp` creates the file with `mkstemp`, mode 0600 less the umask, so never looser than 0600, and `mv` keeps it. Dropped at 1349: the pid file is written under `umask 077` into a lock folder that `mkdir -m 700` made an instant before, so it cannot have existed with another mode. | — |
| F6b | Kept | `set_runtime_file_permissions` after the `mv` (2649), `create_private_runtime_file`'s `chmod 600` after `: >` (4142, the file may exist), `log_debug`'s (1456, 1470), and `ensure_runtime_dir`'s `chmod 700` (816, now once per 2 s by F4a). | — |
| F7a | The clock | Exact reductions only. `print_current_status` (3159-3228) reads the clock once into a local `STATUS_NOW`, which `get_remaining_seconds_from_file` (2613), `get_helper_remaining_seconds` (3894) and `format_deadline_label` (1703-1705) use when it is set; a global `STATUS_NOW=""`, set when the script loads, keeps any value in the environment out (F.4). `format_deadline_label` gets the day and the time from one `date -j -r` (1706-1707); `describe_selected_end` (6447) reads the clock only for an end time; the worker's token uses its `started_at` (5713, 5686). A status read takes 3 `date` instead of 5; a "tomorrow" label 4 instead of 6. | One `date` per process plus `SECONDS`, as the helper's timer does (awake-helper:1261-1262), which faster-start-stop.md 6.3 had as F7: up to a second off at a deadline, and the self-test's `current_epoch` stand-in (tests/cli/awake-self-test:2516) would no longer see those reads. |
| F8a | The helper | In phase 3, the helper release, right after G1 (and before I3, if it goes in), specified here (F.3): `HELPER_UID` read once, `SELF` with builtins, `write_kv_file` without `mktemp`, `dirname`, `cat` and `chmod`. No protocol bump: it changes no command, argument or file, so it needs none (the protocol stays 9 unless I3 goes in). Optional, after Mac QA 9's first part: one `pmset -b sleep X disablesleep Y`. Question F-2. | Shipping it with F's CLI part in phase 4: the helper's bytes would then change in two phases, with two reviews of root code, and if the helper release ships on its own (question X-1), a second password prompt. Any changed helper makes the installer ask for the password once (`install_helper`'s `cmp`, 4231), so it rides with G1's prompt. This corrects faster-start-stop.md 6.3's F8 row (F.4). |
| F9a | The helper's admin-only paths | `helper_is_ready` checks the helper, its folder and the LaunchDaemon with one `stat -f '%u %Lp'` (a new `paths_are_admin_only`), the rule of `path_is_admin_only` (3584-3592) for each path. 7 programs become 1 in every JSON status, report and helper call on a Mac with the helper installed. | Caching `helper_is_ready`: `--install-helper` changes the answer within one run. |
| F10a | `require_macos` | Not in `--caffeinate-start`, `--caffeinate-runner` and `--notify-wait` (6579, 6591, 6603), which only `awake` starts, after its own check (6687). The picker (6613) and the foreground keep it. Question F-4. | `$OSTYPE`: bash takes it from the environment too (`env OSTYPE=darwin24 bash -c 'echo $OSTYPE'` prints `darwin24` on Linux). A file test for a macOS path: a guess about the system's layout, for one program per run. |
| F11a | The JSON printer | `print_status_json` (3029-3152) builds its fields with `printf -v` and prints them with six `printf`. H lands first (phase 2) and has already replaced `json_escape` (2927-2938) with `json_string_or_null_into` (H1e), which `json_string_or_null` calls, so the escaping rules exist once. F uses it for the strings and adds `json_integer_into` and `json_boolean_into`. The prototype, built on `32094d1` before H, adds the same function as `json_string_into` (F.3 item 19). | Leaving the 17 subshells and their nested `json_escape` ones: about 7 to 10 ms of each Linux status read (7 to 8 ms once H1e has removed the nested ones). |
| F12a | Readers without a subshell | `read_state_value_into` at 52 reads of the status read, the report, the start and stop waits and the deadline lock: `read_session_backend_from_file` 1420, `read_session_script_path` 2384, `read_lock_script_path` 2397, `state_token_matches` 2415, `status_file_token_matches` 2429, `state_session_is_active` 2567 and 2574, `get_remaining_seconds_from_file` 2608, `stop_request_token_matches` 2724, `active_end_mode` 2782, `active_deadline_at` 2800, `active_keep_display` 2812, `active_watch_pid` 2826, `last_disablesleep_forced` 2838, `last_session_record_file` 2980 and 2983, `print_status_json` 3059-3078 (11), `print_current_status` 3185 and 3197 (two each) and 3219, `wait_for_requested_stop_completion` 3497 and 3500, `request_active_session_stop` 3542 and 3548, `helper_session_is_foreign` 3857, `helper_session_state` 3875-3877, `get_helper_remaining_seconds` 3890, `request_helper_session_stop` 3941, 3942, 3952, 3954 and 3955, `release_deadline_lock` 5286, `main` 7200, 7214, 7217, 7282 and 7286. The other 62 `$(read_state_value …)` keep their subshell. | Converting all 114: churn in code that runs once per command or less. |
| F13a | `rm -f` of a file that is not there | `[[ -e ]]` first at 2672 and 2737 (the paths were validated just before, so neither is a symlink), and `[[ -e … \|\| -L … ]]` at 7225. | — |
| F14a | Deferred | The `awk` parsers of `pmset` output (CLI 2052-2085, awake-helper:341-358): real mode only, they need fixtures of real `pmset -g` and `pmset -g custom` output from several macOS versions, and C and I2 already run them less. `mktemp`, `cat` and `mv` in `write_runtime_file_atomically` (2635-2650): a builtin replacement needs `O_EXCL` semantics that bash 3.2's `noclobber` does not promise for every file type. | — |
| F15a | Scope and commits | F1a to F7a, F9a, F10a and F13a in one commit ("programs"); F11a and F12a in a second ("subshells"). Each is complete on its own and each passed the whole self-test. Question F-1. | One commit: harder to bisect. Programs only: gives up 40 to 50% of the status reads' gain and 15 to 20% of the actions' (Linux, F.8). |

### F.3 Code changes

All in `bin/awake` but F8a's helper part (phase 3) and the self-test (F.5). Bash 3.2: parameter expansion, `printf -v` (3.1), `[[ -O ]]`, `read -r`, `kill -0`, `local`; no `BASHPID`, no `mapfile`, no fractional `read -t`. The prototype is `out-f-commit1.diff` and `out-f-commit2.diff` in the prototype folder; the review's fixes (items 4 and 6 below, and three checks in F.5) are `fix-cli.diff` and `fix-selftest.diff` in the review's folder. Line numbers are those of `32094d1`; by phase 4, H, I1, I2 and G1 have moved many of them, so take them again from the branch. The prototype's patch scripts (`patch/f-c1.py`, `patch/f-c2.py`) re-apply by text and say which hunk no longer matches.

**Commit 1 (programs).**

1. **173 (F1a).** Replace the one-line `AWAKE_USER_UID` with:
   ```bash
   # This process's user ID, read once. Not bash's EUID or UID: bash takes both
   # from the environment when they are set there (env EUID=0 bash -c 'echo
   # $EUID' prints 0 for any user), which would change whom awake acts for.
   readonly CURRENT_UID="$(/usr/bin/id -u)"
   if [[ "$CURRENT_UID" == "0" && "${SUDO_UID:-}" =~ ^[0-9]+$ ]]; then
       readonly AWAKE_USER_UID="$SUDO_UID"
   else
       readonly AWAKE_USER_UID="$CURRENT_UID"
   fi
   ```
   Then `$CURRENT_UID` for `$(/usr/bin/id -u)` at 793 (`ensure_runtime_dir`), 862 (`set_runtime_file_permissions`), 1435 and 1475 (`log_debug`), 3943 (`request_helper_session_stop`), 6332 (`extend_running_session`), 6644 (the root refusal), 6709 and 7110 (`-w` owner checks) and 7226 (`helper_start_arguments`), and at I3d's new site in the `last` check (F1b). 4312 (`id -un`, the sudoers rule) stays.
2. **212 to 232 (F2b).** Before 212:
   ```bash
   # Sets variable $1 to the folder part of path $2, as dirname prints it, with
   # builtins: "." for a name without a slash, "/" for a file in the root
   # folder, and no slash at the end. Only for paths of files, which never end
   # in a slash themselves.
   set_parent_dir() {
       local parent="."

       if [[ "$2" == */* ]]; then
           parent=${2%/*}
           while [[ "$parent" == ?*/ ]]; do
               parent=${parent%/}
           done
           if [[ -z "$parent" ]]; then
               parent="/"
           fi
       fi
       printf -v "$1" '%s' "$parent"
   }
   set_parent_dir SCRIPT_SOURCE_DIR "${BASH_SOURCE[0]}"
   readonly SCRIPT_PATH="$(cd -- "$SCRIPT_SOURCE_DIR" && pwd -P)/${BASH_SOURCE[0]##*/}"
   ```
   In `resolve_script_file_dir`, `local source_dir=""`; 226 becomes `set_parent_dir source_dir "$source"; target="${source_dir}/${target}"`, and 231 `set_parent_dir source_dir "$source"; cd -- "$source_dir" && pwd -P`. The `readlink` in the loop stays (a symlinked install only).
3. **308, 577, 4003 (F2b).** `${SCRIPT_PATH##*/}` for `$(basename -- "$SCRIPT_PATH")`.
4. **After `get_path_owner_uid` (720) (F4a, F4b, F7a):**
   ```bash
   # The runtime folder this process last found to be safe, and when
   # (SECONDS); RUNTIME_DIR_ENSURED also had its mode set. It was a plain
   # folder that belongs to the user it is named after. In /tmp, which has the
   # sticky bit, only that user and root can remove or rename it, so its owner
   # is read again (stat, which does not follow a symlink) only once the check
   # is RUNTIME_DIR_RECHECK_SECONDS old: the processes that run for a whole
   # session read it as often as before. The builtin checks still run on every
   # call: not a symlink, a folder, and owned by this process's user.
   RUNTIME_DIR_CHECKED=""
   RUNTIME_DIR_CHECKED_AT=0
   RUNTIME_DIR_ENSURED=""
   readonly RUNTIME_DIR_RECHECK_SECONDS=2

   # The current time, read once by a status read: print_current_status sets it
   # as a local for get_remaining_seconds_from_file, get_helper_remaining_seconds
   # and format_deadline_label. Empty everywhere else, also when the
   # environment has a STATUS_NOW, so that they read the clock themselves.
   STATUS_NOW=""

   # True when runtime folder $1 passed the owner check in the last
   # RUNTIME_DIR_RECHECK_SECONDS. A SECONDS set back counts as old.
   runtime_dir_check_is_fresh() {
       local age=$((SECONDS - RUNTIME_DIR_CHECKED_AT))

       [[ -n "$RUNTIME_DIR_CHECKED" && "$1" == "$RUNTIME_DIR_CHECKED" && -O "$1" ]] &&
           (( age >= 0 && age <= RUNTIME_DIR_RECHECK_SECONDS ))
   }
   ```
5. **`validate_runtime_dir_path` (722-755).** The pattern (727), `-L` (732) and not-a-folder (737) checks stay first. Inside `if [[ -d "$dir_path" ]]` (742), first `if runtime_dir_check_is_fresh "$dir_path"; then return 0; fi`; after the owner matched (751-753), `RUNTIME_DIR_CHECKED=$dir_path; RUNTIME_DIR_CHECKED_AT=$SECONDS`. A foreign owner still ends in `report_foreign_runtime_dir`.
6. **`ensure_runtime_dir` (782-818).**
   - First: `if [[ "$dir_path" == "$RUNTIME_DIR_ENSURED" && -d "$dir_path" && ! -L "$dir_path" ]] && runtime_dir_check_is_fresh "$dir_path"; then return 0; fi`.
   - 793: `current_uid=$CURRENT_UID`.
   - `local owner_read=false` among the locals. 799 (the `stat` of an existing folder): `if runtime_dir_check_is_fresh "$dir_path"; then owner_uid=$expected_uid; elif ! owner_uid=$(get_path_owner_uid "$dir_path"); then …the same error…; else owner_read=true; fi`.
   - The `mkdir` branch (809-813) starts with `RUNTIME_DIR_CHECKED=""`: a folder that was gone is checked from scratch by the `validate_runtime_dir_path` at 817.
   - After `chmod 700` (816):
     ```bash
         # A new window only for an owner read here that was right: not for a
         # folder just made or given away, and not for a fresh check, which keeps
         # its time.
         if [[ "$owner_read" == "true" && "$owner_uid" == "$expected_uid" ]]; then
             RUNTIME_DIR_CHECKED=$dir_path
             RUNTIME_DIR_CHECKED_AT=$SECONDS
         fi
     ```
     after 817, `RUNTIME_DIR_ENSURED=$dir_path`.
7. **Runtime paths (F2a).** `${X%/*}` for `$(dirname -- "$X")` at 830 (`validate_runtime_file_path`), 881 (`ensure_askpass_script`), 1434 (`log_debug`), 2129 (`write_mock_pmset_state`), 2641 and 2642 (`write_runtime_file_atomically`), 2679 (`build_stop_request_file_path`), 2698 (`write_stop_request_file`), 3483 (`wait_for_requested_stop_completion`), 4371 (`wait_for_session_start`), 5314 (`rewrite_state_values`), 5409 (`record_orphaned_runner_end`), 5484, 5524, 5525 and 5619 (`caffeinate_runner`), 5678 (`caffeinate_start`), 5833 (`caffeinate_stop`) and 6028 (`write_status_file`). Remove `deadline_lock_path` (5243-5247, with its comment, which moves to 5257); 5257 and 5285 become `lock_dir="${1%/*}/deadline-lock"`. The regex check right after 5257 stays.
8. **`lock_pid_is_running` (1207-1215) (F5a):**
   ```bash
   # True while process $1, one of this user's, runs. The builtin kill -0: for
   # another user's process it fails (EPERM) as for a process that is gone, so
   # it is never used for root's (the helper's). Never 0 or 00, which kill takes
   # as the process group.
   lock_pid_is_running() {
       local pid=$1

       if [[ ! "$pid" =~ ^[1-9][0-9]*$ ]]; then
           return 1
       fi

       kill -0 "$pid" 2>/dev/null
   }
   ```
9. **F6a.** Delete 1349 (`chmod 600 "$LOCK_PID_FILE"`), 2647, 5336 and 6044 (`chmod 600` of the temporary file).
10. **`format_deadline_label` (1694-1715) (F7a).** Before 1703, `if [[ -z "$now" ]]; then now=${STATUS_NOW:-}; fi`; 1706-1707 become:
    ```bash
    # The day and the clock time from one date.
    day=$(/bin/date -j -r "$deadline" '+%Y-%m-%d %H:%M' 2>/dev/null) || return 1
    clock=${day#* }
    day=${day%% *}
    ```
11. **`read_state_value` and `read_state_value_into` (2347-2373) (F3a):**
    ```bash
    # Prints the value of key $1 in the key=value file $2: the rest of the first
    # line whose text before its first = is the key, = signs included. Prints
    # nothing when the file or the key is missing. With builtins only; the rules
    # are the ones the awk -F= reader before it had (tests/cli/awake-self-test
    # compares the two), and like it, it fails (2) when the file cannot be read.
    read_state_value() {
        local state_line__=""

        if [[ ! -f "$2" ]]; then
            return 0
        fi
        {
            while IFS= read -r state_line__ || [[ -n "$state_line__" ]]; do
                if [[ "${state_line__%%=*}" == "$1" ]]; then
                    printf '%s\n' "${state_line__#*=}"
                    return 0
                fi
            done < "$2"
        } 2>/dev/null || return 2
    }

    # Sets variable $1 to the value of key $2 in file $3, as read_state_value
    # prints it, or to nothing, without the subshell of $( ). The variable must
    # not be named state_line__. Never fails.
    read_state_value_into() {
        local state_line__=""

        printf -v "$1" '%s' ""
        [[ -f "$3" ]] || return 0
        {
            while IFS= read -r state_line__ || [[ -n "$state_line__" ]]; do
                if [[ "${state_line__%%=*}" == "$2" ]]; then
                    printf -v "$1" '%s' "${state_line__#*=}"
                    return 0
                fi
            done < "$3"
        } 2>/dev/null || true
    }
    ```
    The loop's `return 0` leaves the function from inside the braces; a missing key ends the loop with status 0, as `awk` did; a file that cannot be opened makes the braces fail, hence 2.
12. **`build_session_token` (2375-2377) (F7a):** `printf '%s' "${1:-$(/bin/date +%s)}-$$-$RANDOM"`, with the comment "`$1`, if given, is the current time, read already"; 5713 passes `"$started_at"` (read at 5686). 5918 keeps calling it without one.
13. **`get_remaining_seconds_from_file` (2613) and `get_helper_remaining_seconds` (3894) (F7a):** `now=${STATUS_NOW:-}; if [[ -z "$now" ]]; then now=$(current_epoch); fi` (3894 keeps `/bin/date +%s` as its fallback, as today).
14. **`print_current_status` (3159-3228) (F7a).** A `local STATUS_NOW=""` with its comment among the locals; before 3181 (`if [[ "$caffeinate_active" == "true" ]]`):
    ```bash
    if [[ "$caffeinate_active" == "true" || "$helper_state" == "running" ]]; then
        STATUS_NOW=$(current_epoch)
    fi
    ```
    Bash's dynamic scope makes the local visible to the three functions it calls; anywhere else they see the global, which item 4 sets empty, and read the clock as today.
15. **`remove_session_file` (2672), `remove_stop_request_file` (2737), main (7225) (F13a):** `if [[ -e "$SESSION_FILE" ]]; then rm -f -- "$SESSION_FILE"; fi`, the same for `$stop_request_file`, and `if [[ -e "$COMMAND_FINISHED_FILE" || -L "$COMMAND_FINISHED_FILE" ]]; then rm -f -- "$COMMAND_FINISHED_FILE"; fi`.
16. **After `path_is_admin_only` (3592) (F9a):**
    ```bash
    # True when only an administrator can change any of the paths: each owned
    # by root and not writable by the group or others, as path_is_admin_only
    # checks one path. One stat for all of them; like that one, it does not
    # follow a symlink. Fails when a path is missing.
    paths_are_admin_only() {
        local output=""
        local line=""
        local count=0
        local pattern='^0 ([0-7]+)$'

        output=$(/usr/bin/stat -f '%u %Lp' "$@" 2>/dev/null) || return 1
        output="${output}"$'\n'
        while [[ -n "$output" ]]; do
            line=${output%%$'\n'*}
            output=${output#*$'\n'}
            [[ "$line" =~ $pattern ]] && (( (8#${BASH_REMATCH[1]} & 8#022) == 0 )) || return 1
            count=$((count + 1))
        done
        (( count == $# ))
    }
    ```
    In `helper_is_ready`, 3622-3627 become:
    ```bash
    # The helper, its folder and the LaunchDaemon, with one stat.
    if [[ ! -f "$BOOT_RESTORE_PLIST" || -L "$BOOT_RESTORE_PLIST" ]] ||
        ! paths_are_admin_only "$helper" "${helper%/*}" "$BOOT_RESTORE_PLIST"; then
        return 1
    fi
    ```
    `helper_path` is always absolute (`HELPER_INSTALL_PATH`), so `${helper%/*}` is its folder. `path_is_admin_only` stays for the self-test (tests/cli/awake-self-test:825) and as the documented rule.
17. **`describe_selected_end` (6447) (F7a):** `if [[ "$END_MODE" == "until" ]]; then now=$(current_epoch); fi`; `now` is used only in the two `until` branches.
18. **main (6579, 6591, 6603) (F10a).** Delete the three `require_macos` lines; above the `case`, "The first three are started by awake itself, after its own macOS check (require_macos below), so they skip it."

**Commit 2 (subshells).**

19. **JSON (F11a).** H's `json_string_or_null_into` (H1e) is in by phase 4, and `json_escape` is gone with it. F adds `json_integer_into` and `json_boolean_into` next to it and uses H's function for the strings. The prototype, built on `32094d1` before H, adds all three after `json_integer_or_null` (2958), the string one as `json_string_into`:
    ```bash
    # The json_*_or_null rules, setting variable $1 instead of printing: for
    # print_status_json, without a subshell per field.
    json_string_into() {
        local json_value__=${2:-}

        if [[ -z "$json_value__" ]]; then
            printf -v "$1" '%s' "null"
            return 0
        fi
        json_value__=${json_value__//\\/\\\\}
        json_value__=${json_value__//\"/\\\"}
        json_value__=${json_value__//$'\n'/\\n}
        json_value__=${json_value__//$'\r'/\\r}
        json_value__=${json_value__//$'\t'/\\t}
        json_value__=${json_value__//$'\f'/\\f}
        json_value__=${json_value__//$'\b'/\\b}
        printf -v "$1" '"%s"' "$json_value__"
    }

    json_integer_into() {
        if is_nonnegative_integer "${2:-}"; then
            printf -v "$1" '%s' "$2"
        else
            printf -v "$1" '%s' "null"
        fi
    }

    json_boolean_into() {
        case "${2:-}" in
            true|false) printf -v "$1" '%s' "$2" ;;
            *) printf -v "$1" '%s' "null" ;;
        esac
    }
    ```
    In the prototype, `json_string_or_null` (2940-2948) becomes `local json_out=""; json_string_into json_out "${1:-}"; printf '%s' "$json_out"`, and `json_escape` (2927-2938) goes (no other caller); H1e makes the same change under its own name. The old `printf '"%s"' "$(json_escape …)"` lost trailing newlines in `$( )`, but none were left after escaping, so the bytes are the same (19 strings compared, both bashes).
20. **`print_status_json`, 3116-3151.** The 24 field `printf`, 18 of them with `$( )`, become one `json_*_into` per field into locals `j_active` … `j_other`, then six `printf`:
    ```bash
    printf '{"schema_version":1,"active":%s,"status_text":%s,"remaining_seconds":%s,"duration_seconds":%s,' \
        "$j_active" "$j_status_text" "$j_remaining" "$j_duration"
    printf '"session_mode":%s,"session_backend":%s,"sound_notifications":%s,"session_token":%s,' \
        "$j_mode" "$j_backend" "$j_sound" "$j_token"
    printf '"last_completion_reason":%s,"last_completed_at":%s,"last_restore_result":%s,' \
        "$j_reason" "$j_completed" "$j_restore"
    printf '"helper_installed":%s,"passwordless":%s,"keep_display":%s,"watch_pid":%s,"watch_command":%s,' \
        "$helper_installed" "$passwordless" "$j_keep_display" "$j_watch_pid" "$j_watch_command"
    printf '"end_mode":%s,"deadline_at":%s,"deadline_label":%s,"leftover_settings":%s,' \
        "$j_end_mode" "$j_deadline" "$j_deadline_label" "$j_leftover"
    printf '"disablesleep_forced":%s,"other_user_session":%s,"error":null}\n' "$(last_disablesleep_forced)" "$j_other"
    ```
    `keep_display` keeps its `case` (on, off, else null), `leftover_settings` is `true` only for `true`, as `normalize_boolean_flag` gave, and `other_user_session` keeps its condition (3145). `$(last_disablesleep_forced)` is the one `$( )` left of the 18.
21. **The 52 readers of F12a:** `x=$(read_state_value KEY FILE [2>/dev/null || true])` becomes `read_state_value_into x KEY FILE`. Four need a new local: `print_current_status` (`session_token`, `duration_seconds`, read before `print_status_json` at 3185, 3197, 3219), `request_helper_session_stop` (`current_token` for the test at 3952), `release_deadline_lock` (`lock_pid` at 5286) and main (`recorded_watch_started` at 7217 and 7286, the latter as `{ read_state_value_into …; [[ … ]]; }` inside the `if`). `last_disablesleep_forced` (2834-2843) reads `disablesleep_forced` first and calls `last_session_record_file` only when it is 1, with the same result. The `$(normalize_boolean_flag "$(read_state_value …)")` pairs at 3067, 3075 and 3078 read into the variable first. `ensure_runtime_dir`'s fresh-owner step (item 6) belongs to commit 1.

**F8a, the helper, in phase 3 (the helper release), right after G1 (prototype `out-f8-helper.diff`).** The `awake-helper` line numbers are those of `32094d1`, which `v2.2.0` shares; G1 moves them first (I3, if it goes in, comes after F8a and is written on top of it). G1 changes other functions (`cmd_start`, `cmd_run_timer`, `finish_session`, `cmd_restore`, the FIFO), so the two merge by text.
- After awake-helper:94: `readonly HELPER_UID="$(id -u)"` with the same comment as `CURRENT_UID`; `$HELPER_UID` at awake-helper:99, 111, 114-117, 160 and 200.
- awake-helper:108: `SELF_DIR=.; if [[ "$0" == */* ]]; then SELF_DIR=${0%/*}; SELF_DIR=${SELF_DIR:-/}; fi; SELF="$(cd -- "$SELF_DIR" && pwd -P)/${0##*/}"`. `$0` is always absolute (sudo runs `HELPER_INSTALL_PATH`; dry-run runs `helper_path`), and `process_matches` (awake-helper:664-673) compares the same `SELF`.
- awake-helper:184-191:
  ```bash
  # Replaces file $1 atomically with the key=value lines on stdin. The
  # temporary file has a fixed name, as in write_heartbeat: only root can
  # create files in the helper's folders (ensure_owned_dir), and the process ID
  # keeps two helper processes apart. The umask (022) makes it 644. One left by
  # a helper that was killed is removed first, whatever it is.
  write_kv_file() {
      local temp_file="${1%/*}/.${1##*/}.tmp.$$"
      local line=""

      if [[ -e "$temp_file" || -L "$temp_file" ]]; then
          rm -f "$temp_file"
      fi
      while IFS= read -r line || [[ -n "$line" ]]; do
          printf '%s\n' "$line"
      done > "$temp_file"
      mv -f "$temp_file" "$1"
  }
  ```
  Under `set -e`, a failed redirect or `mv` still ends the helper, as a failed `cat` did.
- Optional, only if Mac QA 9's first part shows that one call sets both values: awake-helper:644-645 become `pmset -b sleep "$sleep_value" disablesleep "$disablesleep_value" >/dev/null || rc=1`. That part needs no Awake build, so it can run with the Mac preflight; without it, F8a keeps two calls, as the prototype does.

### F.4 Security and compatibility

- **F1a.** `CURRENT_UID` comes from `/usr/bin/id`, never from the environment, and is readonly before anything runs. The root refusal (6644), the uid in the helper's arguments (6332, 7226) and the uid check of a lid-closed session (3943) see what they see today. 10a's checks fail if anyone switches to `$EUID` (mutant m7, F.5). The self-test never runs as root, and CI cannot either, so Mac QA 10 runs `SUDO_UID`'s branch and the refusal.
- **F2a, F2b.** `${p%/*}` runs only on paths that are constants or matched the runtime pattern, which allows exactly one slash before the file name. `set_parent_dir` gives what `dirname` gives for every path a script can be started by (seven cases compared with `/usr/bin/dirname` in 10a); `SCRIPT_PATH` is still normalized by `pwd -P`, so `session_pid_matches` (2514-2537), `caffeinate_runner_pid_matches` (2539-2555) and the lock's check (1248-1256) compare the same strings. Sessions started by `32094d1` were read by F and the other way round in the comparison (F.5).
- **F3a.** The reader never evaluates what it reads: `read -r`, quoted expansions, `printf '%s'` and `printf -v`. It reads the same files as before: this user's runtime files (folder mode 700) and the helper's 644 files.
- **F4a.** What the owner check guards against is another user's folder or symlink at `/tmp/keep-awake-lid-closed-UID`. In `/tmp`, which has the sticky bit, nobody but the folder's owner and root can remove or rename a folder once it is the user's, so a check that found it the user's stays true until the user or root removes it. F4a keeps the builtin checks on every call: a symlink is refused at once (10a, and mutant m2 shows the order matters), and a replacement folder made by another user fails `-O`. Only an owner read starts a window: `ensure_runtime_dir` keeps the time of a fresh check, so one `stat` vouches for the folder for 2 to 3 s at most (mutant m10). What is left: the user's own folder removed (by the user, or by root's cleanup of `/tmp`) and, within the next 2 to 3 s, another user swapping a folder for a symlink to one of the user's folders exactly between the `-L` and `-O` tests and the write. `32094d1` has the same kind of race between its `stat` and the write, with a window of milliseconds after a removal. A folder that `ensure_runtime_dir` makes is checked from scratch (mutant m4). Root (`sudo awake --status`) never takes the cache: `-O` is false for the user's folder (Mac QA 10).
- **F5a.** Only the runner's liveness moves to `kill -0`, where it was liveness only before, too. A PID that another user's process reuses reads as gone, which is right. `0`, `00`, negative and non-numeric values are refused: `kill -0 0` and `kill -0 -1` would ask about the process group or every process (mutants m1 and m9).
- **F6a.** BSD `mktemp` creates its file with `mkstemp`, mode 0600 less the umask: never looser than 0600. `mv` keeps the mode. Under a umask that removes the owner's write bit, the write into the file fails, before today's `chmod` too. 10a checks the mode of every file written under `umask 022` (mutant m5). The lock's pid file is new in a folder made 700 an instant before.
- **F7a.** No precision is lost: every value still comes from a clock read in the same run; a status reads it once instead of twice, so the time left and the end time agree. `STATUS_NOW` is set empty when the script loads, so, like `CURRENT_UID`, it never comes from the environment. Without that line, `env STATUS_NOW=1 awake --duration 10m` during a lid-closed session read the session as 56 years long and added nothing (6318, 6326-6330), and end labels outside a status read used the wrong day.
- **F9a.** The same rule per path; BSD `stat -f '%u %Lp'` prints one line per path and fails if any is missing; the count must match. In the emulation a stand-in printed GNU `stat`'s `%u %a`, so 10a's comparison with `path_is_admin_only` ran there too; CI runs it with BSD `stat`, and Mac QA 6 checks the real output for the installed paths.
- **F10a.** On macOS the check always passes; the three modes started by hand on another system fail later instead of at once.
- **F11a, F12a.** Output byte for byte the same (50 status reads and 33 exit paths, F.5). `read_state_value_into` never fails, where `$(read_state_value …)` without `|| true` could stop the run under `set -e` if a file could not be read; the files are this user's own or the helper's 644 files.
- **F8a.** Only root can create entries in `/var/run/net.kaenmaki.awake` and `/var/db/net.kaenmaki.awake` (`ensure_owned_dir`, awake-helper:193-203, checks the owner); G1's FIFO there is created by root and handed to the user, which does not let the user create files. A leftover temporary file is removed first; files keep mode 644 (compared: session, saved and last files byte for byte, modes 644, no temporary files left).
- **Mixed versions.** No file format, protocol or option changes. An old CLI with the new helper and the new CLI with an old helper work as today (helper protocol 9; F8a changes no command). An older `awake` copy stops a session F started and the other way round (the comparison started sessions with each and read them with the other).
- **Dry-run.** Same code paths; the dry-run helper is found next to the script through `set_parent_dir` (10a's symlink checks), and mock files are read with the new reader.
- **Homebrew and installer.** Both stop the running session before replacing files (scripts/install-awake.sh:384-402, :496; tools/homebrew/awake.rb:24-28), so an old worker never meets new code mid-session. F's CLI part asks for no password: it does not change the helper. F8a, in phase 3, does: the installer runs `awake --install-helper`, or `--passwordless on` (scripts/install-awake.sh:517-526), and both skip a helper that is ready and byte-identical to the new one (`install_helper`'s `cmp`, 4231; 4322 for `--passwordless on`). So an unchanged helper asks for nothing, and a changed one asks once. That is why F8a rides with G1 (and I3, if it goes in), under the same prompt. It corrects faster-start-stop.md 6.3's F8 row, which said that the installer reinstalls the helper on every run. With protocol 9 (no bump for G1 or F8a), a manual CLI-only install keeps the old helper until `awake --install-helper` runs; G's Upgrade note says so, and nothing breaks in the meantime, as F8a changes no command or file.

### F.5 Tests

**Self-test** (`tests/cli/awake-self-test`, prototype `out-f-selftest.diff`, with the review's additions in `fix-selftest.diff`):

- **A new `run_sourced_builtin_checks`** after `run_sourced_end_time_checks` ends (2679), before `trap cleanup EXIT` (2681). Like the others it sources `bin/awake` in a fresh `/bin/bash` with `AWAKE_DRY_RUN=true` and a local `fail`. Eight blocks:
  1. **Readers (F3a):** for 19 contents (`k=v=`, `k=v==`, `k=a=b`, `k=`, `k= x `, `k=v\`, `k=v` without a newline, a repeated key, `k` without `=`, ` k=1`, `k=1\r`, an empty first line, another key, an empty file, `k=*`, `k=$(id)`, `kk=1` before `k=2`, `=x`, trailing empty lines), `$(PATH=/nonexistent read_state_value k FILE)` and `PATH=/nonexistent read_state_value_into v k FILE` both equal `/usr/bin/awk -F= …`'s output; a missing file and a folder give nothing; as non-root, a mode-000 file gives status 2 and an empty `_into`.
  2. **`set_parent_dir` (F2b)** equals `/usr/bin/dirname` for `awake`, `./awake`, `bin/awake`, `bin//awake`, `/awake`, `/usr/local/bin/awake`, `a b/c d`; `CURRENT_UID` and `AWAKE_USER_UID` equal `id -u`.
  3. **Liveness (F5a):** `$$` lives; `0`, `00`, `-1`, `abc`, empty and 999999 do not; when `ps -o uid= -p 1` names another user, process 1 reads as not running.
  4. **The runtime folder (F4a):** `get_path_owner_uid` replaced by a stand-in that counts in a file (it runs in `$( )`): `validate_runtime_dir_path`, `validate_runtime_file_path` and `ensure_runtime_dir` twice read the owner once; with `RUNTIME_DIR_CHECKED_AT` set 3 s back, once more; set into the future, once more; set back again with a stand-in that returns another uid, the run exits with "belongs to another user"; a fresh check keeps its time (below); the folder replaced by a symlink right after a fresh check is refused by both validators; a folder removed and made again by `ensure_runtime_dir` is 700 and its owner is read once. The check that a fresh check keeps its time, before the symlink check:
     ```bash
     # A fresh check keeps its time: ensure_runtime_dir starts no new window
     # without reading the owner.
     validate_runtime_dir_path "$STATE_DIR"
     RUNTIME_DIR_ENSURED=""
     RUNTIME_DIR_CHECKED_AT=$((SECONDS - 1))
     checked_at=$RUNTIME_DIR_CHECKED_AT
     ensure_runtime_dir "$STATE_DIR"
     [[ "$RUNTIME_DIR_CHECKED_AT" == "$checked_at" ]] ||
         fail "ensure_runtime_dir renewed the runtime folder's check without reading its owner."
     ```
  5. **Modes (F6a):** under `umask 022`, `write_state_file`, `rewrite_state_values`, `write_status_file`, `write_runtime_file_atomically` and the lock's pid file give mode 600, and no `.tmp.` file is left.
  6. **One clock read (F7a):** `current_epoch` replaced by one that appends to a file; `STATUS_JSON_OUTPUT=true print_current_status` for a running lid-open session (stand-in `state_session_is_active`) reads it once and reports the token.
  7. **Admin-only paths (F9a):** for `/usr/bin /bin`, `/usr/bin $STATE_DIR`, `$STATE_DIR`, `/usr/bin` plus a missing path, and `/bin /usr/bin /usr/sbin`, `paths_are_admin_only` agrees with `path_is_admin_only` on each path; when `/usr/bin` is root's (on a Mac), `paths_are_admin_only /usr/bin /bin` is true.
  8. **JSON escaping (F11a):** a status record whose token is `a"b\c<TAB>d` gives JSON that Python parses, with the token intact and `"active":false`.
- **A new section "10a. Verifying the builtins that replaced small programs"** right after section 10's check (after 3145). It runs the function above, then:
  - with `env EUID=0 UID=0`, `--status-json` equals a plain read and a lid-open start is not refused;
  - a `STATUS_NOW` in the environment does not change added time:
    ```bash
    # A STATUS_NOW in the environment changes nothing either: only a status read
    # sets it, for the functions it calls.
    run_awake --terminal --backend awake --duration-seconds 600 >/dev/null
    if ! output=$(env STATUS_NOW=1 AWAKE_DRY_RUN=true /bin/bash "$AWAKE_SCRIPT" --dry-run --terminal --duration-seconds 600 2>&1) ||
        [[ "$output" != "Added 10 minutes."* ]]; then
        fail_test "Self-test failed: STATUS_NOW in the environment changed added time (${output})."
    fi
    run_awake --terminal --stop >/dev/null
    ```
  - then `bash awake --version` from `bin/`; `bin/awake-link --status-json` and `bin//awake-link --version` through an absolute symlink; and `bin/awake-rel --status-json` through a relative symlink to `awake-link`, which runs 226. All report `helper_installed` true and `awake-link 2.3.0`. After the `link_version=…` line:
    ```bash
    ln -s awake-link "${link_dir}/bin/awake-rel"
    rel_json=$(cd "$link_dir" && AWAKE_DRY_RUN=true /bin/bash bin/awake-rel --dry-run --status-json)
    ```
    and after the existing `helper_installed` check, whose message becomes "…awake run through a symlink did not find its helper.":
    ```bash
    json_field_equals "$rel_json" helper_installed __TRUE__ ||
        fail_test "Self-test failed: awake run through a relative symlink did not find its helper."
    ```
- **Item 10** (the day and the time from one `date`) is checked by `run_sourced_end_time_checks` (tests/cli/awake-self-test:2615-2619: today, two days away, tomorrow 00:10, 23:59). It runs on CI with BSD `date`; the emulation cannot run it (no `date -v`), so CI is its first run. Mac QA 8 checks the label in use.

**Which check covers which decision:**

| Decision | Covered by |
|---|---|
| F1a, F1b | block 2 (`CURRENT_UID`, `AWAKE_USER_UID`); 10a's two `EUID` checks (mutant m7); Mac QA 1 and 10. F1b's converted sites: 12m's I3d checks, and I3's own checks if I3 is in |
| F2a | the whole self-test (every runtime path runs in it) and the comparison; block 4's validators |
| F2b | block 2 (`set_parent_dir` against `dirname`); 10a's relative path, absolute symlink and relative symlink (the mutant at 226) |
| F3a | block 1 |
| F4a, F4b | block 4 (mutants m2, m3, m4, m10); Mac QA 4 and 10 |
| F5a | block 3 (mutants m1, m9) |
| F6a, F6b | block 5 (mutant m5); Mac QA 4 |
| F7a | block 6 (mutant m8); 10a's `STATUS_NOW` check; `run_sourced_end_time_checks` for item 10; Mac QA 8 |
| F8a | the whole self-test with F8a's helper; Mac QA 9 |
| F9a | block 7; Mac QA 6 |
| F10a | no check of its own: the whole self-test and the comparison's exit paths, as every start runs the worker and the runner without the check |
| F11a | block 8 (mutant m6); the comparison's 50 status reads; 5c (the report) |
| F12a | the comparison (50 status reads, 33 exit paths); the whole self-test |
| F13a | no check of its own: the whole self-test and the comparison's exit paths |
| F15a | each commit passed the whole self-test alone |

**Shown to fail without the change.** Each block ran on its own against `32094d1` in the emulation: 1 fails (`read_state_value failed on k=v=`: no `awk` on the empty `PATH`, and `_into`'s two differences), 2 fails (`set_parent_dir` missing), 4 fails (the owner read 6 times), 6 fails (the clock read twice). 3 fails on a Mac only (`ps -p 0` succeeds there, as the comment at 2587-2588 says), and 7 on a Mac only (on Linux root's paths show as the user's in the namespace). 5, 8 and the `EUID` checks guard rules that `32094d1` already keeps; deliberate mistakes in the prototype showed that each catches its break: m1 (`is_nonnegative_integer` and `kill -0`) and m9 (`is_positive_integer`) fail block 3; m2 (the cache before the `-L` check), m3 (no age limit), m4 (no fresh check after `mkdir`) and m10 (`ensure_runtime_dir` renews a fresh check) fail block 4; m5 (`rewrite_state_values` without `mktemp`) fails block 5; m6 (no backslash escape) fails block 8; m7 (`CURRENT_UID=$EUID`) fails both `EUID` checks of 10a; m8 (`get_remaining_seconds_from_file` reading the clock itself) fails block 6. The `STATUS_NOW` check fails on the prototype without the global line, with `The session already runs for the maximum of 365 days from now.` A mutant with `source_dir=.` at 226 fails the relative-symlink check (it reports `"helper_installed":false`). All blocks pass on the prototype with bash 5.2 and with a Linux build of bash 3.2.57; the three checks the review added (block 4's kept time, 10a's `STATUS_NOW` and relative symlink) fail on the prototype without its fixes and pass with them, under both.

**The whole self-test** passed on the prototype (both commits) in the emulation, with the three replacements the emulation needs (the `plutil` line, the end-time and picker checks): `All dry-run lifecycle and regression checks passed.`, exit 0, with bash 5.2 and the helper of `32094d1`; with bash 5.2 and F8a's helper (with an earlier state of F's CLI; F8a lands in phase 3, before F's CLI part, so its whole self-test runs there with that phase's CLI, and again with F's final CLI in phase 4); with a Linux build of bash 3.2.57 as `/bin/bash`, which also ran the helper and every process `awake` starts; and for commit 1 alone (bash 5.2). With the review's fixes (the `STATUS_NOW` line, `owner_read`, and the three new checks) it passed again with bash 3.2.57 as `/bin/bash`. (With a five-digit uid, section 13 fails on `32094d1` and on the prototype alike: the log path in `--help` is then 81 columns. Local macOS accounts have three-digit uids; network accounts can have longer ones, an existing limit of that check, not F's.)

**Byte for byte.** A comparison run (`compare2.sh`) gave the same `--status-json` and `--status`, read at the same second, for 11 states with sessions started by `32094d1` and the same 11 started by F (idle, lid-open running, until a time with the display off, indefinite, `-w`, lid-closed running, until tomorrow, indefinite, just stopped, leftover settings), a stale helper record, another account's session and a symlinked runtime folder; and the same stdout, stderr, exit status, app report and following `--status-json` on 33 exit paths: terminal and app starts and stops in both modes, added time in the same and the other mode, the toggle, stop when off, leftover settings stopped and restored before a start, a refused low-battery start, a bad option, a missing `-w` process, `--` with exit 3 and lid-closed, "already on", a symlinked folder, `--version`, `--help`, `-w`, `EUID=0` in the environment, and `--debug` runs (the log's lines without times and PIDs). 50 status reads and 33 exit paths, all the same, on the exact final prototype before the review's two fixes, which change nothing these runs print. Each sitting of the comparison shares one helper (`awake-helper` next to both copies), as a real install does. In phase 4 the comparison runs once more, against the branch at the end of phase 3.

**tests/app:** none; no Swift changes. **CI:** none; the self-test already runs on macOS with `/bin/bash` 3.2 (ci.yml:116-117), which is the first run of the new checks against BSD `stat`, `mktemp`, `dirname`, `date`, `ps -p 0` and Apple's bash.

### F.6 Mac QA

Run in the 2.5.0 QA, on the build with F's CLI part (the end of phase 4), with password-free mode on and the helper installed, plugged in. "Before" is the branch at the end of phase 3, in a worktree such as `~/awake-before`; both speak the same helper protocol (9, or 10 if I3 went in), so `--cli` works for every row.

1. `env EUID=0 UID=0 /bin/bash -c 'echo $EUID $UID $(/usr/bin/id -u)'` prints `0 0 501` (or your uid): Apple's bash takes both from the environment, the reason for F1a.
2. **Timing, one sitting.** `tools/measure-latency.sh --rounds 10 --lid-closed --cli ~/awake-before/bin/awake`, then `tools/measure-latency.sh --rounds 10 --lid-closed`, both without `--no-status-runs`, since F speeds the status reads too. Both builds have H, so the script's "The app waits" column is the action alone. Expected (estimates, F.8): each status read 40 to 100 ms faster; the actions: lid-open start 180 to 280 ms faster, lid-open stop 110 to 200 ms, lid-closed start 130 to 220 ms, lid-closed stop 40 to 100 ms (G1 is in by then, so this shows in the median too). Fill in this plan's results table (Timing).
3. **Terminal.** `time awake --status`, `time awake --start --backend caffeinate --duration 10m`, `time awake --stop`, three times each, before and after: 15 to 30 ms, 140 to 210 ms and 60 to 100 ms faster (estimates).
4. **Files.** With a lid-open session running: `ls -la /tmp/keep-awake-lid-closed-$(id -u)` shows `drwx------` for `.` and `-rw-------` for `state`, `status`, `session`; no `.tmp.` files. After `awake --stop`, the same for `status`.
5. **Output.** `awake --status-json` before and after the update, with a lid-open session and with a lid-closed one, differ only in `remaining_seconds`. `awake --status` reads the same.
6. **One stat for the helper's paths.** `/usr/bin/stat -f '%u %Lp' /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper /Library/PrivilegedHelperTools /Library/LaunchDaemons/net.kaenmaki.awake.boot-restore.plist` prints three lines, each `0` and a mode without write bits for group and others (for example `0 755`, `0 755`, `0 644`); `awake --status-json` shows `"helper_installed":true`, and a lid-closed start asks for no password.
7. **Whole sessions.** `awake --backend caffeinate --duration 2m` ends on its own with `last_completion_reason` `timeout`; one stopped from the menu after 30 s ends with `stopped`; the same lid-closed. Afterwards `pgrep -fl -- '--caffeinate|run-timer|run-guard'` prints nothing.
8. **The end label.** Not between 00:00 and 01:00: `awake --backend caffeinate --until "$(date -v-1H +%H):00"` (an hour ago, so tomorrow), then `awake --status`: the end reads `tomorrow HH:00`, and `awake --status-json` shows the same `deadline_label`; `awake --stop`. Then `awake --backend caffeinate --until "$(date -v+2H +%H):00"`, unless that is past midnight: `HH:00` alone.
9. **F8a, in the 2.5.0 QA.** First part, needed only for the optional combined call, and runnable without an Awake build (with the Mac preflight, before F8a's commit): `sudo pmset -b sleep 0 disablesleep 1; pmset -g | grep -E 'SleepDisabled|^ sleep'` shows `SleepDisabled 1` and `sleep 0` (a combined call is accepted), then `sudo pmset -b sleep 5 disablesleep 0` and check again. If either value does not change, keep two calls. Second part, with the new helper installed: a lid-closed start and stop; `ls -la /var/run/net.kaenmaki.awake` shows `session` (while running) and `last` as `-rw-r--r--  root`, no `.tmp.` files.
10. **Root.** With a lid-open session running: `sudo "$(command -v awake)" --status-json` shows the same `session_token` and `deadline_at` as `awake --status-json` (F1a's `SUDO_UID` branch; root never takes F4a's cache, as `-O` is false for your folder). `sudo "$(command -v awake)" --start` and `sudo env EUID=501 "$(command -v awake)" --start` both print `Run awake as your own user, without sudo. It asks for your password when it needs administrator rights.` and exit 1. Afterwards `ls -la /tmp/keep-awake-lid-closed-$(id -u)` still shows the folder and its files as yours.

### F.7 Docs

- **README:** nothing; no behaviour, file or option changes.
- **Help text:** nothing.
- **CHANGELOG `[Unreleased]`, under Changed** (79 columns; added with the release's other entries, not in F's commits):

  ```
  - Starting, stopping, adding time and every status check are quicker, from
    the menu bar app as from Terminal: `awake` reads its records, paths and
    user ID with shell builtins instead of running a small program (`awk`,
    `dirname`, `stat`, `id`, `date`, `chmod`, `ps`) for each, and builds the
    status JSON without a subshell per field. Its output is the same.
  ```
- **Upgrade notes:** none for F's CLI part. F8a adds nothing to the helper release's note: G's (run the installer again or `brew upgrade`; one password prompt; in a manual CLI-only install, copy both files and run `awake --install-helper`), or the protocol-10 note if I3 goes in.

### F.8 Gain

**Programs per run, before and after** (Linux strace, dry-run, `sleep` of the 0.05 s checks left out; forks include the programs):

| Run | Programs `32094d1` → F | Forks `32094d1` → F |
|---|---|---|
| `--status-json`, no record | 7 → 2 | 41 → 16 |
| `--status-json`, after a lid-open session | 19 → 3 | 74 → 22 |
| `--status-json`, after a lid-closed session | 22 → 3 | 76 → 21 |
| `--status-json`, lid-open session running | 31 → 7 | 119 → 52 |
| `--status-json`, lid-closed session running | 36 → 7 | 130 → 51 |
| App lid-open start, the command | 71 → 19 | 229 → 107 |
| its worker until it has recorded the runner | 57 → 16 | 97 → 30 |
| its runner, until the command exits | 15 → 6 | 28 → 18 |
| the start's critical path (command before the worker, worker, command after) | 124 → 36 (20 + 57 + 47 → 9 + 16 + 11; 123 → 35 in the review's trace) | |
| App lid-open stop | 53 → 12 | 153 → 52 |
| App lid-closed start, the command | 82 → 20 | 237 → 102 |
| its helper `start` / timer / guard (dry-run) | 32 / 13 / 12, unchanged; with F8a 11 / 6 / 5 | 43 / 17 / 13; with F8a 22 / 10 / 6 |
| App lid-closed stop | 70 to 73 → 17 | 170 to 179 → 55 |

The review re-counted the main rows on the exact final prototype and got the same figures. The review's two fixes add no program to a run that ends within 2 s of its first owner read. On a Mac with the helper installed, add 7 → 1 per JSON status read or report (F9a) and per helper call, and 4 (2 `pmset`, 2 `awk`) per read of the sleep settings, unchanged. What is left is what bash cannot do itself or what guards identity: one `id`, one `uname` (foreground only), one `stat` of the folder, the clock (`date`: 1 per status, 2 for an end time's label), `ps` for identity (2 or 3), the lock (`mkdir`, `mv`, `rm`, `rmdir`), atomic writes (`mktemp`, `cat`, `mv`), `nohup`, one `chmod 700` and one `chmod 600`, and the `sleep` of the waits.

**Time, Linux, measured.** 14 rounds; each round ran every version in turn, in a rotated order (`abn.sh`); dry-run; the app's commands as `tools/measure-latency.sh` runs them, and three terminal commands. Medians in ms. "Programs" is F's first commit; "F" is both.

| Step | bash 5.2: `32094d1` | programs | F | bash 3.2.57: `32094d1` | F | Change (5.2; 3.2) |
|---|---|---|---|---|---|---|
| Status after a session (a start's "before") | 95 | 69 | 43 | 95 | 49 | −55%; −49% |
| Status, lid-open running (its stop's "before") | 155 | 113 | 83 | 147 | 88 | −46%; −40% |
| Status, lid-closed running | 165 | 114 | 80 | 158 | 86 | −52%; −45% |
| App lid-open start, action | 522 | 299 | 257 | 510 | 262 | −51%; −49% |
| App lid-open stop, action | 321 | 180 | 144 | 287 | 149 | −55%; −48% |
| App lid-closed start, action | 407 | 267 | 220 | 388 | 224 | −46%; −42% |
| the same with F8a's helper | | | 189 | | 194 | −54%; −50% |
| App lid-closed stop, action | 654 | 627 | 663 | 700 | 666 | none: the helper's 1 s check; minimum 274 → 197 and 272 → 198 |
| Terminal `--start` (lid-open) | 413 | 204 | 200 | 400 | 202 | −52%; −49% |
| Terminal `--status` (running) | 82 | 60 | 55 | 82 | 59 | −33%; −28% |
| Terminal `--stop` (lid-open) | 226 | 136 | 126 | 218 | 131 | −44%; −40% |

The two bash runs were separate sittings; within each, the versions alternated. In the bash 5.2 run the second commit gave 40 to 50% of the gain on status reads and 15 to 20% on actions. The bash 5.2 "programs" and "F" columns were taken before three refinements (the `-O` test, caching only when the owner matched, the strict PID pattern); the bash 3.2 run had the `-O` test.

**Re-measured on the exact final prototype** (the review, Linux, bash 5.2, 10 rounds, `32094d1` and F alternated in every round; medians in ms): lid-open start 530 → 258 (minimum 521 → 253, maximum 540 → 269), lid-open stop 331 → 144, lid-closed start 406 → 222, lid-closed stop 723 → 666 (minimum 280 → 194); status lid-open running 158 → 82, lid-closed running 169 → 83, after a session 94 to 97 → 42 to 43; terminal start 416 → 201, status 85 → 56, stop 228 → 126. It agrees with the table above, so the three refinements cost nothing measurable. The review's two fixes (F.3 items 4 and 6) were not timed separately; they add no program.

**What the app waits for, Linux (bash 3.2):** lid-open start ("with C": status before + action) 605 → 311 ms; lid-open stop 434 → 237 ms; lid-closed start 481 → 274 ms (244 with F8a); lid-closed stop about 858 → 752 ms, most of it the helper's check. "With C and H" is the action alone.

**Mac, estimate.** For `32094d1` the Mac took 0.9 to 1.1 times the emulation's time for the lid-open actions, and more for the status reads and the lid-closed start, where it runs programs the emulation does not (`helper_is_ready`, `pmset`, real `sudo` and the helper; F.1). F's Mac gain is taken as 0.7 to 1.0 times the range of the two Linux runs (the lower end allows for the emulation's `stat`, `date` and `uname` stand-ins, which cost 1.4 to 2.2 times the programs, about 12% of the Linux gain), plus F9a's 6 programs per JSON status read, report or helper call, which only a Mac with the helper installed runs (9 to 18 ms each at 1.5 to 3 ms per program). Today's figures are the owner's (7.3). The last two columns are this plan's reconciled estimates for the phases ("Expected gains"): the phase-2 figures are lower bounds until H's timing without status runs, and they assume I3 stays out. With I3 (question I-1), lid-closed starts take 35 to 90 ms less in both.

| App action | Today, "with C" (measured, 7.3) | F alone on today's `dev` (estimate; not a planned state) | Before F: after phases 2 and 3 (I2, H, I1, G1, F8a; estimate) | After F, phase 4 (estimate) |
|---|---|---|---|---|
| Lid-open start | 662 | 310 to 440 | about 495 | about 210 to 310 |
| Lid-open stop | 542 | 260 to 390 | 300 to 320 | about 120 to 210 |
| Lid-closed start | 714 | 420 to 540 | about 470 to 495 | about 265 to 370 |
| Lid-closed stop | 1061 | 860 to 970 | about 310 to 340 (at most about 460) | about 220 to 330 |

Per step (Mac, estimate), F's CLI part: each status read 40 to 100 ms faster; actions: lid-open start 180 to 280 ms, lid-open stop 110 to 200 ms, lid-closed start 130 to 220 ms, lid-closed stop 40 to 100 ms (with G1 in, in the median too). F8a, in phase 3: about 30 ms per lid-closed start (Linux 220 → 189 ms). Terminal: `awake --status` 15 to 30 ms (it runs no `helper_is_ready`, so F9a saves it nothing), `awake --start` 140 to 210 ms, `awake --stop` 60 to 100 ms. faster-start-stop.md 6.1's estimate for F, 0.15 to 0.4 s per action once C and H are in, is about right for starts and lid-open stops (0.18 to 0.28 s); the lid-closed stop gains 40 to 100 ms once G1 has removed its wait.

### F.9 Risks, rollback and order

- **A builtin that behaves differently on Apple's bash 3.2.** Low. The new checks and the whole self-test ran with a Linux build of bash 3.2.57; CI runs Apple's. Shows as a failing 10a or 5c on CI.
- **The reader on files with odd bytes** (NUL, invalid UTF-8): `read` and `awk` may differ there. The files are written by awake and the helper only. Shows as a wrong status field; 10a's block 1 pins the common cases.
- **The runtime folder cache** (F4a) is the one rule that changes shape. Its residual race is described in F.4; it needs the user's own folder to be removed first. Shows nowhere unless attacked. Rollback: set `RUNTIME_DIR_RECHECK_SECONDS` to `-1` (every check reads the owner again), one line.
- **A later edit drops `mktemp`** and relies on F6a's missing `chmod`: 10a's block 5 fails.
- **A later variable taken from the environment.** `CURRENT_UID` and `STATUS_NOW` show the pattern: any global that a function reads with `${X:-}` must be set when the script loads. 10a's `EUID` and `STATUS_NOW` checks guard the two F adds.
- **`is_positive_integer` (1012-1014) accepts `00`,** which `kill` reads as 0, the process group. It guards the worker PID at 3489, 3544 (before the `kill -TERM` at 3557) and 4381. The values come from this user's own state files (written from `$!`), and 3544 checks identity with `ps` before the kill, so there is no attack path. A later hardening could use `^[1-9][0-9]*$` there too; not part of F.
- **Merge conflicts.** F touches many lines in small ways (commit 1: 205 lines added, 82 removed; commit 2: 139 and 100; the self-test: 226 added). It lands last, so it rebases onto everything else; the prototype scripts (`patch/f-c1.py`, `patch/f-c2.py`) re-apply by text and say which hunk no longer matches.
- **Rollback.** Revert commit 2, commit 1, or both; nothing is stored differently, so no state needs migrating, and no helper reinstall is involved. F8a is reverted with the helper release's other changes, or alone, at the cost of another password prompt if the helper has shipped.
- **Order.** F's CLI part is phase 4, last (question F-5); F8a is in phase 3.
  - After C and J1 (done): F changes `print_current_status` (C) and `state_session_is_ready`'s callee (J1).
  - After H (phase 2): H adds `json_string_or_null_into` (H1e) and a report built with `read_state_value_into`. F reuses H1e (F11a) and must keep `_into`'s results, which H's sourced check guards; F3a changes them only for lines no awake file has (`k=v=`, a line `k` without `=`).
  - After I2 and I1 (phase 2): I2 moves main's `pmset` read (6790-6791), which F does not touch. I1 changes `run_helper` (3792-3836), where F9a's `helper_is_ready` call (3812) stays as it is. I3d (phase 2, question I-4) and I3, if it goes in (phase 3, question I-1), bring the `id -u` sites of F1b.
  - After G1 (phase 3): G1 changes `request_helper_session_stop` (3920-3968), where F1a (3943) and F12a (3941-3955) change lines; F, landing second, rebases. F8a and G1 both change the helper, in different functions, and ship together.
  - F8a lands right after G1 in phase 3 (before I3, if it goes in), with Mac QA 9's first part before it if the combined `pmset` call is wanted.

## 5. G: the lid-closed stop without the helper's one-second poll

The helper's timer waits on a FIFO, `wake`, instead of `/bin/sleep 1`, and `awake` writes one byte to it right after it creates `stop-request` or `command-finished`. The timer then ends the session at once instead of at its next look, up to a second later. Recommended: G1 as below, with the TERM trap reduced to a flag (G1e), which the research's sketch in 6.4 did not have and which bash 3.2 needs, and a wait that cannot spin even when `read` fails at once (G1f). No protocol bump: the helper protocol stays 9, unless I3 goes into the same release, and then I3's protocol 10 covers G too (question G-1; I3 is gated on the Mac preflight, question I-1). G1 is the first commit of phase 3, the helper release, after phase 2 and the Mac preflight (G.6, 1 to 3); F8 follows it in the same phase, and I3 if it goes in, so users see one password prompt for all of them (question G-2). Prototype: `plan2-G/proto` (scratch), full self-test green on Linux with bash 5.2 and with bash 3.2.57 built from Apple's sources; G1f's `SECONDS` rule and check 8, added in review, passed section 12f on both shells (G.5).

### G.1 Today

The path at `32094d1`:

1. Every lid-closed stop of the user's own session goes through `request_helper_session_stop` (3917-3968), without privileges. Callers: the stop and the toggle (6991), `awake -- COMMAND` when the command ends (4102, with `command-finished`), `--uninstall-helper` with a session running (6758), Ctrl+C after the password during a start (7245), and a watched process that exited while the password was asked for (7287).
2. It reads the token and the uid from the helper's record `HELPER_SESSION_FILE` (185), in `HELPER_STATE_DIR` (174-178): `/var/run/net.kaenmaki.awake`, which the helper creates root-owned with mode 755 (`ensure_owned_dir`, awake-helper:193-203) and whose files are 644 (`write_kv_file`, awake-helper:184-191), so the user can read but not change anything there. In dry-run it is `/tmp/keep-awake-lid-closed-control-dry-run-UID`, the user's own.
3. It refuses another account's session (3941-3945), then writes `stop-request` (195) or `command-finished` (198) into the user's own runtime folder, `STATE_DIR` (189), with `write_runtime_file_atomically` (2635-2650: `mktemp`, `mv`, mode 600), at 3946-3949.
4. It checks every `STOP_WAIT_POLL_SECONDS` (0.05 s, 126), at most `STOP_WAIT_MAX_CHECKS` times (600, 125) and for `STOP_WAIT_MAX_SECONDS` (30, 127), whether the record's token changed (3951-3963). That is B8, done in phase 1.
5. The helper's `cmd_start` (awake-helper:842-981), under the lock taken at awake-helper:911, starts the timer and the guard with `spawn` (awake-helper:976-977; `spawn` 830-840, `nohup` in a process group of its own).
6. `cmd_run_timer` (awake-helper:1218-1336) builds the two request paths in the user's runtime folder (awake-helper:1249-1250, `stop_request_path` 316-318, `command_finished_path` 320-322), sets its TERM trap (awake-helper:1254-1256), then loops: the record's token (1264-1267), the heartbeat (1269-1272), the deadline (1273-1282), `-f stop-request` (1283-1286), `-f command-finished` (1287-1290), the guardrails on their own schedules (1291-1333), and `sleep 1` (1334).
7. `finish_session` (awake-helper:756-824) takes the lock, restores the settings, writes `last`, removes `session` and `heartbeat` (809) and lets go of the lock. The CLI's next check sees the token gone.
8. The guard (`cmd_run_guard`, awake-helper:1338-1440) sleeps 2 s per pass (1376) and looks at the request files only when the timer is gone or has written no heartbeat for 60 s (1403-1411).
9. Boot-restore (`cmd_boot_restore`, awake-helper:1174-1206) runs at startup, when macOS has emptied `/var/run`, and acts only on `saved` in `/var/db/net.kaenmaki.awake`.

**What it costs.** A request waits for the timer's next look: 0 to 1 s, about 0.5 s on average, plus the timer's pass and `finish_session`.

- Mac, measured (7.3, same sitting, 10 rounds, `tools/measure-latency.sh --lid-closed`): the lid-closed stop's action took 848 ms median, 314 to 1268 ms, on the dev build; 806 ms, 360 to 1267, on 2.3.0, whose helper is the same. The spread of about 0.95 s is the timer's poll; the minimum is a stop that met the timer's look soonest. What the app waits for "with C": 1061 ms, the slowest of the four actions.
- Linux, measured in the emulation (dry-run, `tools/measure-latency.sh --dry-run --lid-closed`, 32 rounds, G.8): the action took 764 and 906 ms median in the two series, 255 to 1241 ms, against 271 ms for the lid-open stop in the same runs.
- The timer also starts one `/bin/sleep` per second for the whole session, 86,400 a day (counted on Linux, G.8).

**Why.** The CLI runs as the user and cannot signal the root timer (EPERM), so it leaves a file that the timer looks for once a second.

### G.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| G1a | How the stop reaches the root timer | A FIFO the timer waits on with `read -t 1` in place of `sleep 1`; the CLI writes one byte after the request file. Both password modes gain, and the CLI needs no privileges. | **G2**, the CLI running `sudo -n helper restore` in password-free mode: password mode keeps the poll; each stop adds one or two `sudo` runs and a helper start, about 15 to 80 ms per stop (Mac estimate, from I's 15 to 40 ms per `sudo -n helper check`); `restore` takes no token and ends any account's session; and it records `stopped` where `awake --` needs `process_exited`. A new `stop UID TOKEN REASON` command would answer the last two, but it needs protocol 10 and still helps only password-free mode. **A launchd `WatchPaths` job:** a new root LaunchDaemon per user path, install and uninstall steps, and a new root process per event; no way to test it in the dry run. **kqueue through a small compiled tool:** a second root program next to the helper, against "only one small program ever runs as root" (README.md:89). **A shorter sleep** (0.2 s): five times the root wake-ups and `/bin/sleep` processes for the whole session, for 0.4 s. **Signalling the timer:** the user may not signal root's processes. |
| G1b | Where the FIFO lives | `wake` in the helper's own folder, `/var/run/net.kaenmaki.awake/wake`, mode 600, owned by the session's user. Only that user and root can open it. The folder is root's and 755, so the user cannot remove, rename or replace the FIFO, or put anything else at that path. | **In the user's runtime folder:** the root timer would then open a path the user controls, and a symlink there would make root open any file (bash has no `O_NOFOLLOW`). **Root-owned, mode 622:** any local user could wake the timer or fill the FIFO and block that user's stop (G1g). **Group-writable:** the user's group is `staff`, which every account shares. |
| G1c | Who makes and removes it | `cmd_start`, under the lock, after the settings are applied and right before `spawn` (awake-helper:976). `rm -f`, `mkfifo -m 600`, `chown UID`; any failure leaves no FIFO and the session starts all the same. `finish_session` (809) and `cmd_restore` (1152) remove it with `session` and `heartbeat`. macOS empties `/var/run` at startup, so nothing survives a restart. | **The timer making it:** a stop right after the start could find no FIFO yet. **A failed `mkfifo` failing the start:** a working session matters more than half a second. |
| G1d | How the timer waits | `read -r -n 1 -t 1 -u 3 wake_byte` on the FIFO, opened once with `exec 3<>` before the loop. Whole seconds, `-n` and `-u` are in bash 3.2 (Apple's bash-144 sources, bash-3.2/builtins/read.def:208, :221, :231); the timeout is an `alarm` and stays on for a FIFO, as only regular files turn it off (:320-340). One byte per read: bash reads a pipe one byte at a time (:387, :430) and keeps a whole line in memory, growing it 128 bytes at a time, so a writer that sends no newline could make a root process grow a buffer and copy it over and over. | **Fractions such as `read -t 0.2`, and `read -t 0`:** bash 4.0 and later. **Whole lines:** see the buffer above. |
| G1e | The timer's TERM trap (shutdown, `restore`) | Only `stop_signal=true`. The loop checks the flag after the token check at the top of each pass and before each wait, and ends the session there. Why: bash 3.2 runs a trap that arrives during `read` inside the signal handler (`interrupt_immediately`, read.def:384; trap.c:372-373), while the read's `alarm` is still set. When the alarm fires during the trap, its handler `longjmp`s back into the read (read.def:109, :326-333), which returns as timed out and the trap is abandoned half done. Measured on bash 3.2.57 built from Apple's sources: a 1.5 s trap was cut off after 4, 2 and 1 of its 6 steps in 3 of 3 runs (TERM 0.8, 0.4 and 0.1 s before the alarm), the script went on looping, and in one longer run it stopped timing out after about 195 passes and sat in `read` until it was killed. With the flag, 3 of 3 finished. The review reproduced both on the same build. bash 5.2 runs the trap outside the handler, so the self-test on Linux alone would not have shown this. | **Today's trap kept during `read -t`**, as 6.4 had it ("The timer's TERM trap then also runs during the wait"): at shutdown, `finish_session` (two `pmset` calls on a Mac) could be cut off and leave sleep disabled until boot-restore. **`trap '' ALRM` as the trap's first command:** a window stays before it runs, and it leans on bash internals. |
| G1f | Bytes that keep coming, and a read that fails | A wait that ended early is followed by a plain `sleep 1`. A wait ended early if it brought a byte, or if `read` returned within the same second of `SECONDS` in which it began; bash 3.2 returns 1 both for a timeout and for an error that comes at once (read.def:332, :494-499), and a one-second timeout always crosses a whole second. So the loop makes at most two passes a second, however many bytes arrive and whatever happens to the descriptor. Measured: a writer flooding the FIFO for 6 s gave 12 passes and 12 to 14 ms of CPU on bash 5.2 and bash 3.2. A child that set O_NONBLOCK on fd 3 made the loop without the `SECONDS` test run 163,476 passes in 2.4 s on bash 3.2 (bash 5.2 made 3, as its `read` waits with `select`); with it, 6 passes in 3 s. | **Reading until the FIFO is empty:** bash 3.2 cannot read without waiting (`read -t 0` fails at once, read.def:259-260). **No limit:** a flood would spin the root loop. **Trusting read's status alone:** bash 3.2 cannot tell a timeout from an error, so an error would spin the loop. |
| G1g | How the CLI writes | `{ printf 'x' 1<>"$HELPER_WAKE_FIFO"; } 2>/dev/null \|\| true`, only when the path is a FIFO (`-p`), not a symlink (`! -L`) and this user's (`-O`); in dry-run also only when the folder is this user's and not a symlink. `1<>` opens for reading and writing, which never blocks: XNU counts the opener as a reader and a writer before either of its two waits (`fifo_open` in bsd/miscfs/fifofs/fifo_vnops.c, apple-oss-distributions/xnu, main), and Linux documents it in fifo(7). The one-byte write blocks only when the FIFO's buffer is full (G.4). | **`>` or `>>`:** opening for writing alone blocks while no timer holds the FIFO open, for example after the timer died. **Writing in the background:** a fork per stop, and a process that could outlive the CLI. |
| G1h | Order of file and byte | The request file first, then the byte. A byte written before the timer has opened the FIFO is dropped when the CLI closes it, but the timer opens the FIFO before its first pass, and that pass sees the file. A byte left from a request that came as the session ended dies with that FIFO, as `cmd_start` makes a new one. | **Byte first:** the timer could wake, find nothing, and wait a full second (G1f). Check 8 catches it (mutant 7, 18 checks). |
| G1i | Protocol | Stays 9 (question G-1), unless I3 goes into the same release (question I-1); I3's protocol 10 then covers G, and nothing in G changes. Correctness needs no bump: an older helper makes no FIFO, so the new CLI writes nothing and the timer looks once a second; an older CLI writes nothing, so the new timer's `read -t 1` times out each second, as `sleep 1` did. The gain needs the new helper installed. The installer, which the Homebrew cask runs, reinstalls the helper whenever its bytes differ (`install_helper`'s `cmp`, 4231; `--passwordless on`, 4322; the installer then checks the result with `helper_is_installed`, scripts/install-awake.sh:466-468), with the one password prompt it already asks for. | **Protocol 10 for G alone:** manual CLI-only installs would get a forced password prompt at their next lid-closed start, and the app would report the helper as out of date until then; hand-copied copies of different versions would reinstall each other's helper, with a prompt at every lid-closed start (as the 2.1.0 Upgrade note describes, CHANGELOG.md:212-215); and the timing script would need its protocol guard. All that for half a second that the installer brings anyway. Bump only with I3, which needs it (6.6). |
| G1j | `FINISHING` | Removed (awake-helper:755, 770, 782): once the trap only sets a flag, nothing reads it. | Keeping a variable nothing reads. |
| G1k | Debug line | When the record shows the session ended, the CLI logs `request_helper_session_stop ended token=… request=… checks=N`, as `wait_for_session_start` logs its `checks=N` (faster-start-stop.md QA 40). The line is load-bearing: self-test check 8 and Mac QA 8 read it, so it must not be dropped later as noise, and the comment above it says so. | No log: QA could not tell a woken stop from a lucky one, and check 8 could not see the stop at all. |
| G1l | The guard and boot-restore | Unchanged. The guard never opens the FIFO; it still takes over from a timer that is gone (2 s) or stuck (60 s), and its `finish_session` removes the FIFO. Boot-restore runs after `/var/run` was emptied and never looks at `wake`. | Waking the guard too: it acts only when the timer is gone or stuck, and then 2 s is fine. |
| G1m | Dry-run | The same code. The dry-run helper runs as the user, so `make_wake_fifo` skips `chown`; the folder is under `/tmp`, so the CLI also checks that it is its own. | A dry-run-only path: the self-test would not test the real one. |

### G.3 Code changes

Line numbers are at `32094d1`. The prototype is `plan2-G/proto/bin/awake-helper` and `plan2-G/proto/bin/awake` (scratch); the sketches below are its code, with the review's `SECONDS` rule (G1f) and the debug line's comment added.

**`bin/awake-helper`**

1. **Header, 40-44.** The last sentence becomes:
   ```bash
   # tests whether these files exist; it never reads or writes outside its own
   # state directory. There it makes a FIFO, wake, owned by the session's user,
   # who writes a byte to it after creating one of these files so that the timer
   # looks at once; the timer reads single bytes and does nothing else with them.
   ```
2. **After 148:**
   ```bash
   # The FIFO through which the session's user wakes the timer (see the top).
   readonly WAKE_FIFO="${STATE_DIR}/wake"
   ```
3. **`finish_session`.** Delete `FINISHING=false` (755), `FINISHING=true` (770) and `FINISHING=false` (782) (G1j). Line 809 becomes `rm -f "$SESSION_FILE" "$HEARTBEAT_FILE" "$WAKE_FIFO"`.
4. **New `make_wake_fifo`, after `finish_session` (after 824).** Under `set -e`, every command that may fail is in a condition, so a failure never stops `cmd_start` after it has changed the settings (the self-test's directory case, G.5, check 4, caught exactly that in the prototype's first version).
   ```bash
   # Makes the FIFO through which user $1 wakes the timer, mode 600 and owned by
   # that user, so that nobody else but root can write to it. STATE_DIR is
   # root's own (ensure_owned_dir), so nobody else can put anything at this
   # path either. Without the FIFO the session runs as before, and the timer
   # looks for a stop once a second.
   make_wake_fifo() {
       rm -f "$WAKE_FIFO" 2>/dev/null || return 0
       mkfifo -m 600 "$WAKE_FIFO" 2>/dev/null || return 0
       if [[ "$DRY_RUN" != "true" ]] && ! chown "$((10#$1))" "$WAKE_FIFO" 2>/dev/null; then
           rm -f "$WAKE_FIFO" 2>/dev/null || true
       fi
   }
   ```
   `$1` already matched `UID_PATTERN` in `cmd_start` (awake-helper:864); `10#` drops leading zeros. `mkfifo -m` sets the mode regardless of the umask (022, awake-helper:52). `chown` is `/usr/sbin/chown`, which the helper's `PATH` (awake-helper:50) includes; the Mac QA checks the result (G.6, 6).
5. **`cmd_start`, before 976:** `make_wake_fifo "$uid"`. That is after `apply_settings` succeeded (968-974), so the failure path at 968-974 needs no change, and under the lock taken at 911.
6. **`cmd_restore`, 1152:** `rm -f "$SESSION_FILE" "$HEARTBEAT_FILE" "$WAKE_FIFO"`.
7. **`cmd_run_timer`.**
   - After 1235: `local wake_open=false`, `local woke=false`, `local wake_byte=""`, `local stop_signal=false`, `local wait_began=0`.
   - After 1252:
     ```bash
         # The FIFO the stop command wakes this loop through, if the session has
         # one: only a FIFO, never a symlink, in root's own folder. Opened for
         # reading and writing, which never blocks, and keeps reads from seeing
         # end-of-file when a writer closes it.
         if [[ -p "$WAKE_FIFO" && ! -L "$WAKE_FIFO" ]] && { exec 3<>"$WAKE_FIFO"; } 2>/dev/null; then
             wake_open=true
         fi
     ```
     A failed `exec` redirection in a condition returns 1 without ending the shell, on bash 3.2 and 5.2 (measured, and again in review under `set -euo pipefail`); the braces send its message to `/dev/null`, and the `3<>` stays open after them. The helper uses no other descriptor 3; programs the timer starts inherit it, as they inherit the others, and never read it. One that set O_NONBLOCK on it would make every later read fail at once; G1f's `SECONDS` test bounds that too.
   - 1254-1256 become:
     ```bash
         # Shutdown or `restore` sends TERM: the loop restores the settings at its
         # next check, within a second. The trap only notes it: bash 3.2 runs a
         # trap that comes during `read -t` inside read's signal handler, where
         # the read's timeout would cut the trap short.
         trap 'stop_signal=true' TERM
     ```
   - After 1267 (the token check, so a TERM from `restore`, which has removed the record, just exits):
     ```bash
             if [[ "$stop_signal" == "true" ]]; then
                 finish_session "$token" stopped
                 exit 0
             fi
     ```
   - 1334, `sleep 1`, becomes:
     ```bash
             # A second, or until a byte comes through the FIFO. A wait that ended
             # early, with a byte or with a read error (status 1 at once, as for a
             # timeout on bash 3.2), is followed by a full second, so nothing that
             # happens to the FIFO can make this loop spin.
             if [[ "$stop_signal" == "true" ]]; then
                 continue
             elif [[ "$wake_open" == "true" && "$woke" != "true" ]]; then
                 wait_began=$SECONDS
                 if read -r -n 1 -t 1 -u 3 wake_byte 2>/dev/null || (( SECONDS == wait_began )); then
                     woke=true
                 fi
             else
                 woke=false
                 sleep 1
             fi
     ```
     `read` runs in a condition, so its status 1 on a timeout (bash 3.2; 142 on bash 5.2) never trips `set -e`, and neither does the `(( ))` test. The `SECONDS` test counts a read that returned in the second it began as an early end, whatever the reason (G1f): a byte, or an error such as EAGAIN (a program the timer started set O_NONBLOCK on the shared descriptor) or EBADF. A one-second timeout always crosses a whole second of `SECONDS`, which the timer set to 0 at 1262; if one ever did not, the next wait would be a plain `sleep 1`, today's behaviour. A TERM that arrives while the pass runs is seen before the wait; one that arrives during the wait is seen within a second, at the next pass, as with `sleep 1` today, where bash runs the trap only after the foreground `sleep` ends. The byte is never used.

   **Unchanged:** `cmd_run_guard`, `cmd_boot_restore`, `cmd_extend`, `spawn`, the request files and their paths, `HELPER_VERSION` (54).

**`bin/awake`**

1. **After 186:**
   ```bash
   # The helper's timer looks for a stop request once a second, or at once when
   # a byte comes through this FIFO, which the helper makes for the session's
   # user. Older helpers make none.
   readonly HELPER_WAKE_FIFO="${HELPER_STATE_DIR}/wake"
   ```
2. **New `wake_helper_timer`, before 3917.** Builtins only.
   ```bash
   # Wakes the helper's timer, so that it looks for the request just written at
   # once rather than within a second. Only a FIFO that this user owns, never a
   # symlink; in dry-run only in a folder of this user's, as it is under /tmp.
   # Opened for reading and writing, which never blocks, as it would for
   # writing alone while no timer holds the FIFO open; one byte, never a line.
   # An older helper makes no FIFO, and then nothing is written.
   wake_helper_timer() {
       if dry_run_enabled && { [[ -L "$HELPER_STATE_DIR" ]] || [[ ! -O "$HELPER_STATE_DIR" ]]; }; then
           return 0
       fi
       if [[ -p "$HELPER_WAKE_FIFO" && ! -L "$HELPER_WAKE_FIFO" && -O "$HELPER_WAKE_FIFO" ]]; then
           { printf 'x' 1<>"$HELPER_WAKE_FIFO"; } 2>/dev/null || true
       fi
   }
   ```
   Outside dry-run no folder check is needed: users cannot create entries in `/var/run` (G.6, 7 checks it, including that the user is not in group `daemon`), so `/var/run/net.kaenmaki.awake` is either the helper's or missing, and only root can change its entries; the tests above are therefore free of races. `1<>` also has `O_CREAT`: if the FIFO vanishes between the test and the open, as the session ends, the open fails in root's folder (EACCES, silenced); in dry-run it could leave an empty regular file `wake` in the user's own folder, which the next `cmd_start` removes and the timer ignores (`-p`).
3. **After 3949:** `wake_helper_timer`.
4. **After 3952**, inside the token check and before the `rm` at 3953 (G1k):
   ```bash
               # The self-test (check 8 of the wake checks in 12f) and the Mac QA
               # read this line: keep it.
               log_debug "request_helper_session_stop ended token=$token request=$request_name checks=$waited"
   ```

**Not changed:** `HELPER_PROTOCOL_VERSION` (165), the app, `tests/app`, `.github/workflows/ci.yml`, `tools/measure-latency.sh` (its protocol guard is needed only if I3 brings protocol 10; I's section), the installer, the Homebrew cask, the uninstallers (`uninstall_helper`'s `rm -rf` of the folder at 4268 also removes `wake`).

### G.4 Security and compatibility

**What each change could weaken, and why it does not.**

- **A user-owned file in root's folder.** The user owns the FIFO's inode, not its name: the folder is root's and 755, so the user can neither remove nor replace `wake`. What the owner can do: write bytes (wakes the timer; G1f bounds the passes), read bytes (steals wakes, which slows only their own stop), `chmod` it (with 666, other local users could do the same to this user's stops), hard-link it elsewhere on the same volume (the inode outlives the session, with no reader; the next session gets a new inode). None of this reaches root: the timer reads one byte at a time into `wake_byte`, which nothing uses, and never writes.
- **Root opening a path.** The timer opens `$STATE_DIR/wake` in its own folder, which `ensure_owned_dir` has just checked (not a symlink, owned by root, awake-helper:193-203, called at 910) and whose entries only root can change. It also checks `-p` and `! -L` first. The helper still never follows a path the user controls; it still only tests whether the request files exist (README.md:93).
- **Memory and CPU as root.** One byte per read (G1d), at most two passes a second whatever happens to the descriptor (G1f). bash 3.2 leaks nothing per read: under valgrind, heap in use at exit was 54,926 bytes after 1 timeout and after 8, and 6 bytes more after 2,000 wakes (Linux, bash 3.2.57).
- **Can the CLI's write block?** Its open never blocks (G1g). Its one-byte write blocks only while the FIFO's buffer is full. That buffer is a local socket pair on macOS, 8,192 bytes by default (`PIPSIZ`, bsd/kern/uipc_usrreq.c; `sysctl net.local.stream.recvspace`, QA 2), 65,536 on Linux (measured). The CLI writes one byte per request and the timer reads one per wake, so only a process with write access, which is this user's or root's, writing thousands of bytes can fill it. Then that user's own `awake --stop` waits in the write until the timer has read a byte, which under a flood frees about one byte a second (measured: a write into a full FIFO was still blocked after 2 s). This is one of the user's own processes harming that user, with no more power than it has anyway (it could `kill -STOP` the CLI). Case by case:
  - timer stuck (in `pmset`, or stopped): each request leaves one byte in the buffer, which never fills unless a process of the user's has filled it. The guard takes over within 60 s and the CLI gives up after 30 s, as today. Only with a full buffer does the CLI wait in its write, with no limit, until the timer reads a byte or exits: the 30 s limit (`STOP_WAIT_MAX_SECONDS`, 127) covers only the wait after the write, and the guard ending the session does not free it, as the CLI already holds the inode open. Again, only the user's own process can bring that about.
  - timer gone and FIFO left: no process holds it open, so each open starts an empty buffer and the last close drops it (XNU `fifo_close_internal` closes both sockets when no reader and no writer is left; measured on Linux). The guard ends the session within 2 s.
  - FIFO replaced by a regular file or a symlink: impossible for a user outside dry-run; refused by `-p` and `! -L` (self-test check 6, mutant 5).
- **Flood as root.** G1f; self-test check 3 and mutant 2.
- **A read that fails at once.** G1f's `SECONDS` test. Measured in the emulation, not by a self-test check, as setting O_NONBLOCK on a descriptor needs a program other than bash (`plan2-verify-G/spin.sh`: 163,476 passes in 2.4 s without the test on bash 3.2, 6 passes in 3 s with it). The session's user cannot cause it: only the timer and the programs it starts share the timer's open file description, and a flag the user sets on a descriptor of their own does not reach it.
- **TERM handling.** G1e; self-test check 7 fails with today's trap under bash 3.2 (mutant 3).
- **Residual race.** On bash 3.2 the flag assignment itself runs inside read's handler; a TERM that lands within the microseconds before the alarm fires could be lost. The loop then goes on: after `restore`'s TERM it exits at the next pass anyway, as `restore` removed the record; at shutdown the session's settings stay until boot-restore puts them back at the next startup, which is the case it exists for (a session killed before it could restore).

**Old and new together.**

| CLI | Helper | What happens |
|---|---|---|
| new | new | The stop takes effect at once (G.8). |
| new | old (no FIFO) | `-p` is false; nothing is written; the timer finds the request within a second, as today. Self-test check 4 runs this case (a directory in the way, so no FIFO). |
| old | new | No byte; `read -t 1` times out every second and the timer finds the request within a second, as today. 7.1's same-sitting comparison runs exactly this (`--cli` an older copy with the new helper installed). |
| any | old session from the old helper, then the helper is updated | The installer stops the running session before it installs (scripts/install-awake.sh, `stop_previous_session`, 384-402; B2), so this arises only with a manual copy. The old timer has no FIFO: the new CLI writes nothing, and the stop takes up to a second. |

This table holds with protocol 9. If I3 brings protocol 10, the cross-cutting section's table of old and new versions applies instead: a new CLI installs its own helper at its first lid-closed start, and a new CLI meets an old timer only in the last row's case.

`awake --status-json` and the app see nothing new: `wake` is not reported, and the record files are unchanged.

**Dry-run.** The dry-run helper runs as the user in `/tmp/keep-awake-lid-closed-control-dry-run-UID`, so `make_wake_fifo` skips `chown`. Another local user could create that folder first; the helper then refuses it (`ensure_owned_dir`, wrong owner), and the CLI's folder check stops it from writing through a path that user controls.

**Installer and Homebrew.** No change to either. The installer runs `awake --install-helper` or `awake --passwordless on` on every run (scripts/install-awake.sh:517-526), and both reinstall the helper when `cmp` finds it different (4231, 4322), under the one password prompt the cask's caveat already announces (tools/homebrew/awake.rb). A manual CLI-only install keeps the old helper, and today's stop, until `awake --install-helper`. Uninstalling removes `wake` with the folder (4268).

### G.5 Tests

**`tests/cli/awake-self-test`, section 12f**, inserted after the `command-finished` check (after tests/cli/awake-self-test:4096, before the lid-closed sleep checks at :4097). About 175 lines; the prototype's text for checks 1 to 7 is in `plan2-G/proto/tests/cli/awake-self-test`, 4097-4254, and check 8's is below. A helper, `wait_for_timer_pass`, waits until the dry-run `heartbeat` changes, which the timer writes as a pass begins (once a second in dry-run, awake-helper:122); each wait polls every 0.05 s, 60 times at most.

| # | What it does | What it asserts | On `32094d1` |
|---|---|---|---|
| 1 | `start_helper_session none` | `wake` is a FIFO, not a symlink, owned by the user, mode 600 (`stat -f %Lp`) | fails: "the helper did not make its wake FIFO, mode 600, for the session's user." |
| 2 | waits for a pass, 0.2 s more, then `: > stop-request` and `printf 'x' 1<>wake` | the session record is gone within 8 checks of 0.05 s; afterwards `last` says `stopped` and `wake` is gone | fails (with check 1 skipped): "a byte through the wake FIFO did not make the timer stop the session at once."; the removal part also fails on its own |
| 3 | after a pass, 20 bytes in one write, 2.5 s wait; then `kill -STOP` the timer and count the bytes left with `read -r -n 1 -t 1 -u 9` | the session still runs; at least 15 of 20 bytes are left | passes (old helper reads nothing); mutant 2 fails it with "0 of 20 bytes left" |
| 4 | the test makes a directory `wake` before `start` | the start succeeds; `stop_helper_session` stops it within its usual wait | passes; mutant 4 (a plain `rm -f`) fails it, as the prototype's first version did |
| 5 | `run_awake --terminal --backend awake --duration-seconds 60`, a pass, `kill -STOP` the timer, `run_awake --stop &`, wait for `stop-request`, read the FIFO with `read -r -n 1 -t 1 -u 9`, `kill -CONT` | the byte is `x`, and the stop exits 0 | fails (with 1 and 2 skipped): "awake --stop did not wake the helper's timer through its FIFO"; mutant 6 too |
| 6 | for a symlink and a hard link to a user file put at `wake` after the start: `run_awake --stop` | the stop works (`Awake is off.`), and the file still reads `keep` | passes; mutant 5 (`-e` in place of `-p`/`! -L`) fails it: "awake wrote to a symlink in place of the helper's wake FIFO." |
| 7 | after a pass, the test holds the helper's lock (`mkdir lock`, `pid=$$` in `lock/owner`), sends TERM to the timer 0.3 s into its wait, lets go of the lock 1.5 s later | the session ends within 3 s, `last` says `stopped`, the mock `pmset` sleep is back at 15 | passes; mutant 3 (today's trap) fails it under bash 3.2 and passes under bash 5.2: with the lock held, the trap's `finish_session` is still waiting when the read's alarm fires |
| 8 | a lid-closed session from `run_awake`, `wait_for_timer_pass`, then `run_awake --debug --stop` | the last `request_helper_session_stop ended ... checks=N` line in the debug log has N of 6 or less | fails: `32094d1` logs no such line (its stops would take about 15 checks); mutant 7 (the byte before the request file) fails it with 18 checks |

In the file the checks come in the order 1, 2, 3, 7, 4, 5, 6, then 8, as in the prototype.

Check 8 is the only end-to-end check of a CLI stop against a running timer: check 2 wakes the timer with the test's own byte, and check 5 holds the timer still. Its text goes after check 6's loop, in place of the block's final `cleanup_state` (prototype line 4254), as it begins and ends with one:

```bash
# awake --stop itself ends a lid-closed session at once: its wait for the
# record to go counts its checks of 0.05 s (debug log). The stop starts as
# the timer begins a wait, so a stop the timer finds only at its next look
# takes most of a second, over ten checks.
cleanup_state
run_awake --terminal --backend awake --duration-seconds 60 >/dev/null 2>&1
if ! wait_for_status "Awake is on*" 20 >/dev/null || ! wait_for_timer_pass; then
    fail_test "Self-test failed: a lid-closed session did not start for the wake checks."
fi
run_awake --debug --stop >/dev/null 2>&1 || true
wake_stop_checks=$(sed -n 's/.*request_helper_session_stop ended .* checks=\([0-9][0-9]*\)$/\1/p' "$DRY_RUN_LOG_FILE" 2>/dev/null | tail -n 1)
if [[ -z "$wake_stop_checks" ]] || (( wake_stop_checks > 6 )); then
    fail_test "Self-test failed: awake --stop did not end a lid-closed session at once (${wake_stop_checks:-no} checks)."
fi
cleanup_state
```

How the failures were shown: the new checks were run, as a cut of the self-test (its first 2685 lines, then section 12f), against `32094d1`'s `bin/awake` and `bin/awake-helper`, five times, each time with the check that had failed replaced by a note: checks 1, 2, the removal part of 2, and 5 fail there, in that order; with those four replaced, checks 3, 4, 6 and 7 pass on `32094d1`, as they test the new code's limits rather than the gain. Then mutants of the prototype, each with one deliberate mistake, each caught by its check, on bash 5.2 and, for mutants 1, 2 and 3, on bash 3.2: (1) the timer never reads the FIFO → check 2; (2) no full second after an early wake → check 3; (3) today's trap → check 7, on bash 3.2 only; (4) a plain `rm -f` in `make_wake_fifo` → check 4; (5) the CLI tests `-e` instead of `-p` and `! -L` → check 6; (6) the CLI writes no byte → check 5; (7) the CLI writes the byte before the request file → check 8 (18 checks), on bash 5.2. Mutant 7 passes checks 1 to 7, yet its stops take about a second. Logs: `plan2-G/logs/basechk-final-v0.log` to `-v4.log`, `plan2-G/logs/final-mut-*.log`, `plan2-verify-G/logs/mutbf-12f-b5.log`.

The whole self-test, with the plutil and the two sourced checks switched off as for every Linux run, passed on the prototype with bash 5.2 (297 s) and with bash 3.2.57 bind-mounted as `/bin/bash` (293 s); `32094d1` passed with bash 3.2.57 too (292 s), so the build behaves as CI's shell does on everything else the self-test covers. The review then added G1f's `SECONDS` rule and check 8 to the prototype; the cut with section 12f passed with them on bash 3.2.57 (49 s) and bash 5.2 (53 s), check 8 seeing 1 check on both (`plan2-verify-G/logs/fix8-12f-b32.log`, `fix8-12f-b5.log`). The whole self-test runs again on the final commit.

**Timing in the checks.** Check 2 allows 8 checks of 0.05 s (about 0.5 s with the checks' own time) for a stop that, without the byte, comes about 0.8 s after the request. On a slow CI Mac the dry-run `finish_session` (about 15 programs) might take 0.15 s (estimate), still inside. Check 3's margin is wide: the new timer reads 2 or 3 bytes in 2.5 s, a spinning one all 20. Check 8 allows 6 checks (0.3 s plus the checks' own time); the emulation needed 1, a stop the timer finds at its next look about 15. If check 2 or check 8 ever flakes on CI, widen it to 12 checks, which still fails a stop that waits for the timer's next look.

**`tests/app`, CI.** Nothing new. CI's macOS job already runs the self-test with `/bin/bash` (ci.yml:117), so checks 1 to 8 run on Apple's bash 3.2 there; check 7 is the one that needs it.

**Bash 3.2 evidence.** Apple's bash sources (github.com/apple-oss-distributions/bash, tag bash-144, which reports 3.2.57) were built on Linux with three small shims (`xlocale.h`, `EBADEXEC`, a `fmtcheck` stand-in and its declaration). The builtins and the trap code are Apple's; the system calls are Linux's. The FIFO and signal facts that depend on the kernel are Mac QA 1 to 3.

### G.6 Mac QA

The scratch copies of the small scripts are in `plan2-G/exp`; the commands below stand alone. Times are Mac estimates unless measured.

QA 1 to 3 are part of the Mac preflight: about 15 minutes together with I's QA I-1, I-2 and I-3 (a), run on the installed 2.4.0 before I1's commit and before G1 is written. They need no Awake build. The last part of 7 (`/private/var/run` and the `daemon` group) needs none either and can run with them. If 1, 2 or the `flag` run of 3 do not give what they expect, G1 is not written as specified (question G-3); the `work` run of 3 only shows whether G1e is needed, and G1e stays either way. The rest runs in the 2.5.0 QA.

1. **Preflight: bash 3.2 basics.** In Terminal:
   ```bash
   d=$(mktemp -d); mkfifo -m 600 "$d/w"
   /bin/bash -c 'exec 3<>"$1"; time read -r -n 1 -t 1 -u 3 b; echo "rc=$?"' _ "$d/w"
   /bin/bash -c 'exec 3<>"$1"; (sleep 0.3; printf x 1<>"$1") & time read -r -n 1 -t 1 -u 3 b; echo "rc=$? b=$b"' _ "$d/w"
   /bin/bash -c 'time printf x 1<>"$1"' _ "$d/w"
   rm -f "$d/w"; rmdir "$d"
   ```
   Expected: `real 0m1.00` and `rc=1`; `real 0m0.3` and `rc=0 b=x`; the write returns at once (`real 0m0.00`), with no reader.
2. **Preflight: the FIFO buffer.** `sysctl net.local.stream.sendspace net.local.stream.recvspace`: 8192 each (G.4's figure).
3. **Preflight: the trap, on the Mac's bash.** Save as `/tmp/g-trap.sh` and run `/bin/bash /tmp/g-trap.sh work; /bin/bash /tmp/g-trap.sh flag`:
   ```bash
   d=$(mktemp -d); mkfifo "$d/w"
   /bin/bash -c '
       exec 3<>"$1"; flag=false
       if [[ $2 == work ]]; then trap "for i in 1 2 3 4 5 6; do echo step \$i; sleep 0.25; done; echo finished; exit 0" TERM
       else trap "flag=true" TERM; fi
       for p in 1 2 3 4 5 6; do
           [[ $flag == true ]] && { echo flag; exit 0; }
           read -r -n 1 -t 1 -u 3 b || echo timeout
       done' _ "$d/w" "$1" &
   sleep 0.5; kill -TERM $!; wait $!; rm -f "$d/w"; rmdir "$d"
   ```
   Expected, as with the bash 3.2.57 build on Linux: `work` prints one to three `step` lines (usually `step 1`, `step 2`; the number depends on when TERM lands in the first wait), then six `timeout` lines, and no `finished` (the trap was cut off); `flag` prints `timeout`, then `flag`. bash 5.2 prints all six steps and `finished` for `work`. If the Mac's `/bin/bash` prints `finished`, it differs from the build; G1e is still safe there, only not needed.
4. **Old helper, new CLI**, before installing (protocol 9 only: with protocol 10 the new CLI would install its own helper first): with password-free mode on, from the new checkout, `bin/awake --backend awake --duration 10m; sleep 2; time bin/awake --stop`. Expected: stops, real 0.3 to 1.3 s, no error; `ls /var/run/net.kaenmaki.awake/` shows no `wake`.
5. **Install.** Run the installer. Expected: one password prompt, which installs the helper; afterwards `cmp ~/Library/Application\ Support/Awake/bin/awake-helper /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper && echo same` prints `same`.
6. **The FIFO.** `awake --backend awake --duration 10m`, then `stat -f '%Sp %Su %Lp' /var/run/net.kaenmaki.awake/wake`. Expected: `prw------- <you> 600`. Then `tp=$(awk -F= '$1=="timer_pid"{print $2}' /var/run/net.kaenmaki.awake/session); sudo lsof -p "$tp" | grep wake`: one line, FD `3u`, type `FIFO`.
7. **The user cannot replace it.** `rm /var/run/net.kaenmaki.awake/wake` and `ln -s /tmp /var/run/net.kaenmaki.awake/x`: both `Permission denied`. `ls -ld /private/var/run`: owned by `root`, and not writable by your account (expected `drwxrwxr-x  root  daemon`; if it differs, report it, as G.3's CLI change relies on it), and `id -Gn | tr ' ' '\n' | grep -x daemon` prints nothing (members of group `daemon` could create entries in `/var/run`).
8. **The stop.** Five times: `awake --debug --backend awake --duration 10m; sleep 2; time awake --debug --stop`. Expected: real about 0.3 to 0.4 s each (estimate), every time, not spread over a second; `grep 'request_helper_session_stop ended' /tmp/keep-awake-lid-closed-$UID/awake-debug.log | tail -5` shows `checks=N` with N of 6 or less every time (estimate). 2.4.0 logs no such line; its stops spread over a second (7.3). Afterwards `ls /var/run/net.kaenmaki.awake/wake`: no such file.
9. **Timing, one sitting (7.1, step 5).** If it is not there yet: `mkdir -p ~/awake-qa; git -C ~/awake worktree add ~/awake-qa/awake-2.4.0 v2.4.0`. Then `tools/measure-latency.sh --lid-closed --rounds 10 --cli ~/awake-qa/awake-2.4.0/bin/awake`, then `tools/measure-latency.sh --lid-closed --rounds 10`. Both use the new helper; the 2.4.0 CLI writes no byte. Expected: the lid-closed stop's action median about 850 ms for 2.4.0 and about 320 ms for the new one (estimate), close to the lid-open stop's, with the new maximum under about 450 ms; the other rows within the sitting's noise. Fill in this plan's results table (Timing). This works only with protocol 9; if I3 brings protocol 10, time the lid-closed rows right before the install and right after it instead (the cross-cutting section's Timing).
10. **`awake --`.** `time awake --backend awake -- sleep 3`. Expected: `sleep finished (exit status 0). Awake stopped.`, real about 3.6 s (estimate: the start, 3 s, and a stop from a CLI already running; 3.6 to 4.6 s before).
11. **TERM, as at shutdown.** Start as in 6, note `pmset -g | grep -E '^ sleep|SleepDisabled'` before, then `sudo kill -TERM "$tp"`. Expected: within about a second `awake --status` says `Awake is off.`, `grep reason /var/run/net.kaenmaki.awake/last` says `reason=stopped`, `pmset -g` shows the values from before, and `wake` is gone.
12. **`restore`.** Start, then `sudo /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper restore`. Expected: `restore_result=…`; `ps -p "$tp"` finds no process 2 s later.
13. **CPU and processes.** Start with `--duration 10m` and wait 5 minutes. `ps -o time= -p "$tp"`: under about 0:00.50 (estimate); `pgrep -P "$tp" sleep` prints nothing almost every time (no `sleep 1` child; before G, one most of the time).
14. **A flood.** During a session: `printf '%04000d' 0 1<>/var/run/net.kaenmaki.awake/wake`. Expected: the session keeps running for the next 20 s (`awake --status`); `ps -o time= -p "$tp"` grows by under 0.1 s; then `time awake --stop` stops it within about a second.
15. **Password mode.** With password-free mode off, 8 again: each start asks for the password as usual; each stop asks for nothing and takes the same time as in 8.
16. **Restart.** Start with `--duration 1h`, note `pmset -g | grep -E '^ sleep|SleepDisabled'`, then restart the Mac normally (Apple menu, Restart). After login: `awake --status` says `Awake is off.`; `pmset -g` shows the values from before; `ls /var/db/net.kaenmaki.awake/saved` reports no such file; `ls /var/run/net.kaenmaki.awake/` shows no `wake`, or there is no such folder. Then `awake --status-json | grep -o '"last_completion_reason":"[a-z_]*"'` prints either nothing (the timer restored at shutdown after G1e's flag, and boot-restore had nothing to do) or `restart` (the shutdown restore did not run or failed, and boot-restore restored at startup). Note which; both are correct. A forced power-off is qa-2.4.0.md 6.12.
17. **The app.** Shortcut mode lid-closed: ⇧⌘A to start, then ⇧⌘A to stop, five times, with the 7.2 stopwatch method. Expected: `Awake stopped` and the stop sound about half a second sooner than with 2.4.0 on average, and no longer spread over a second.
18. **Uninstall.** With a session running, `awake --uninstall-helper`. Expected: the session stops, and `/var/run/net.kaenmaki.awake` is gone.

### G.7 Docs

- **README.md:93** (Security notes), after "the helper only checks whether that file exists, which is why stopping never needs a password.": "It then writes one byte to `wake`, a FIFO that the helper makes for you in its own folder for each session, so that the helper looks at once; the helper reads single bytes from it and does nothing else with them."
- **README.md, Runtime files**, under `/var/run/net.kaenmaki.awake/` after the `heartbeat` bullet (575), one line: "  - `wake`: a FIFO, owned by you with mode `600`, while a lid-closed session runs; `awake` writes a byte to it after it creates `stop-request` or `command-finished`, so the helper's timer looks at once"
- **README.md:603** (what the self-test does), one line still: "- stopping a session through the helper's guard after its timer has been killed, and at once through the FIFO that wakes the helper's timer,"
- **`--help`:** nothing; it never mentions the helper's poll.
- **CHANGELOG.md, `[Unreleased]`, `### Changed`:**
  ```
  - Stopping a lid-closed session is quicker: `awake` wakes the helper when
    it asks for the stop, so the helper no longer finds the request only at
    its next look, up to a second later. The same goes for a lid-closed
    `awake -- COMMAND` when the command ends. It takes the updated helper
    (see Upgrade notes).
  ```
- **`### Upgrade notes`:** 2.5.0's one note about the helper, which also covers F8's change to it (F's section):
  ```
  - Run the installer again, or `brew upgrade`. It stops a running session
    and updates the helper, which asks for your password once, also in
    password-free mode. In a manual CLI-only install, copy both `bin/awake`
    and `bin/awake-helper` again, then run `awake --install-helper`; until
    then, lid-closed stops work as before.
  ```
  If I3 goes in (question I-1), or with protocol 10 for G (question G-1, option b), the note takes 2.2.0's wording for protocol 10 instead:
  ```
  - Run the installer again, or `brew upgrade`. It stops a running session
    and installs helper protocol version 10, which asks for your password
    once, also in password-free mode. In a manual CLI-only install, copy both
    `bin/awake` and `bin/awake-helper` again; the next lid-closed start then
    updates the helper in the same step, with one password prompt. If you
    cancel the installer's prompt, that start asks.
  ```
- **docs/plans/faster-start-stop.md 7.1, step 5**, in G's commit. Its last sentence ("Use 10 rounds or more for lid-closed stops: each takes anything up to a second more, depending on where it meets the helper's check (G1 would remove that).") becomes: "Use 10 rounds or more for lid-closed stops when one side is a CLI before 2.5.0: its stops take anything up to a second more, depending on where they meet the helper's check. With 2.5.0's CLI and helper, a lid-closed stop no longer spreads over a second (G1)." If I3 brings protocol 10, the same step's "a 2.3.0 checkout's `bin/awake` works with the new helper, whose protocol is the same" no longer holds for the lid-closed rows.
- `suggest_level` in `tools/release.sh` (183) stays minor: a Changed entry and an Upgrade note, no `**Breaking`.

### G.8 Gain

Measured in the emulation (Linux, dry-run, bash 5.2), `tools/measure-latency.sh --dry-run --lid-closed`, `32094d1` against the prototype, in two series: whole 10-round runs alternated (old, new, old, new), and 12 one-round runs of each, alternated round by round. The pause before each stop is spread over a second (faster-start-stop.md 4.5). Other agents ran emulations at the same time, so only figures from the same series compare.

| Step (ms, min / median / max) | Old, 10-round runs (n=20) | New, 10-round runs (n=20) | Old, round by round (n=12) | New, round by round (n=12) |
|---|---|---|---|---|
| Lid-closed stop: action | 255 / 764 / 1241 | 246 / 256 / 278 | 309 / 906 / 1133 | 253 / 258 / 276 |
| Lid-closed stop: status before | 142 / 152 / 171 | 142 / 155 / 172 | 148 / 156 / 178 | 149 / 157 / 173 |
| Lid-open stop: action (unchanged code) | 240 / 271 / 297 | 264 / 270 / 311 | 266 / 272 / 290 | 264 / 270 / 278 |
| Lid-closed start: action (unchanged code) | 340 / 380 / 421 | 354 / 374 / 411 | 355 / 370 / 382 | 361 / 374 / 394 |

The steps G does not touch match within 10 ms. The new lid-closed stop's median (256, 258 ms) is about the old one's minimum or below it (255 and 309 ms), the stop that met the timer's look soonest, and its spread shrinks from about a second to about 30 ms. It is now as quick as the lid-open stop.

The review's own run, with G1f's `SECONDS` rule, in another sitting (8 one-round pairs alternated, bash 5.2): lid-closed stop action 399 / 500 / 1163 ms old against 278 / 290 / 296 new; lid-open stop 298 / 308 / 319 against 297 / 304 / 330; lid-closed start 395 / 424 / 438 against 419 / 432 / 438. The rule costs nothing measurable.

| Action | Today (Mac, measured) | With G (Mac, estimate) | Basis |
|---|---|---|---|
| App or ⇧⌘A lid-closed stop: the action | 848 ms median, 314 to 1268 | about 320 ms, at most about 450 | on Linux the new median (256, 258 ms) was about the old minimum or below it (255, 309 ms); the Mac's old minimum is 314 ms, and its lid-open stop, which does about as much, 315 ms |
| The same, what the app waits for with C (G alone on 2.4.0) | 1061 ms | about 535 ms | 214 ms status before (measured) + the action |
| The same, what the app waits for after phase 2 (I2, H, I1) | about 830 to 850 ms, still spread over a second (estimate; a lower bound until H's timing run, H.8) | about 310 to 340 ms after phase 3 (G1 and F8), at most about 460 | the plan's reconciled estimates (Expected gains): the action above, with H's report added and I2's and F8's savings taken off |
| Terminal `awake --stop`, lid-closed | about 0.3 to 1.3 s (estimate: the same parts as the action) | about 0.3 to 0.4 s | as the action |
| Lid-closed `awake -- COMMAND`, after the command ends | 0 to 1 s plus the stop | about 0.5 s sooner on average, up to 1 s | the same wait |
| `--uninstall-helper` with a session, Ctrl+C during a start | the same wait | about 0.5 s sooner on average | the same function |
| Lid-open actions, starts, added time | unchanged | unchanged | not on this path |

Besides: in 20 s of a dry-run session (strace on the timer, Linux), the timer started 38 programs before, 19 `sleep` and 19 `mv` for the dry run's one-second heartbeat, and 19 after, only the `mv`s. Outside dry-run the heartbeat comes every 10 s (awake-helper:141), so the timer's programs drop from about 1.1 a second to about 0.1 a second, plus the battery and heat checks every 60 and 30 s (awake-helper:134, :136), which are unchanged (estimate from the schedules). That is 86,400 fewer root processes per day of session. The timer still wakes once a second (the read's alarm), as it did with `sleep 1`.

### G.9 Risks, rollback and order

- **Root code.** A mistake in the timer loop could end sessions early or never. Covered by checks 1 to 8, the seven mutants, both shells, and the unchanged guard, which still ends a session whose timer is gone or stuck. Shows as a self-test failure, or on the Mac as QA 8, 11 or 13 failing.
- **macOS's bash differs from the build.** The read and trap code is Apple's, but the kernel under it was Linux's. Shows in QA 1 to 3, which run in the preflight before G1 is written, and in CI's self-test (check 7 runs on `/bin/bash`). If `read -t` behaves differently on the Mac, G1e keeps the TERM path safe either way.
- **The password prompt.** Installer and Homebrew users see one prompt for the helper update, as for any helper change (`install_helper`'s `cmp`, 4231). A user who cancels keeps the old helper and today's stop (G.4 table). This is why G1 and F8, and I3 if it goes in, are all in phase 3, one helper release (question G-2).
- **A flood by the user's own process** can make that user's own stop wait (G.4). Not a boundary.
- **Shutdown.** If shutdown signals the timer's `sleep 1` child as well as the timer (XNU's `proc_shutdown` signals every process; not checked on a Mac), today's trap restores at once. With G1e, the flag waits for the read's alarm, so the restore starts up to a second later, inside the time macOS allows before SIGKILL (several seconds; estimate). If the system kills the timer first, boot-restore restores at the next startup, as today. QA 16 shows which happened.
- **Rollback.** Revert the commit. The protocol stays 9, so every mix of CLI and helper works (G.4 table); reinstalling the previous version's helper (its installer) brings back the poll. If I3 brought protocol 10, reverting G leaves that bump to I3. A `wake` FIFO left by the new helper is harmless to an old one, and macOS empties `/var/run` at startup. If Mac QA fails, ship without G rather than switch to G2 (question G-3).
- **Order.**
  - Phase 3's first commit: after phase 2 (I2, H, I1, and I3d if question I-4 is answered (a)) and the Mac preflight, which runs before I1's commit and checks G's QA 1 to 3 with I's sudo facts and costs. F8 follows G1 in the same phase, and I3 if it goes in, so that every helper change reaches users under one prompt.
  - Needs phase 1's B8 (the CLI's 0.05 s check, 125-127), done; without it the CLI's own 0.2 s check would eat part of the gain.
  - Independent of H at the code level; the gains add (G.8).
  - I1 does not touch this path: a stop of the user's own session uses no `sudo`. I2 shortens the same stop by other means: main reads `pmset` twice on every run (6790-6791), also while a lid-closed session runs, and I2's saving (0 to 20 ms, Mac estimate; I's section) adds to G's.
  - F1a changes 3943 (`id -u`), and F12a the reads at 3941, 3942, 3952, 3954 and 3955 of `request_helper_session_stop`; F's CLI part comes in phase 4, after G, so F rebases onto G's lines. F8 changes the helper too, in other functions (`write_kv_file`, `SELF`, the uid reads).
  - I3 goes in only if the preflight finds that the two programs it removes, the helper's root `osascript` and `pmset -g batt`, cost 100 ms or more per lid-closed start (question I-1); at the estimate from 7.3 it stays out. If it goes in, it rides in this helper release, its protocol 10 covers G, the Upgrade note takes 2.2.0's wording (G.7), and the timing script needs its protocol guard.
  - C's report is written after `request_helper_session_stop` returns, so it comes sooner and needs no change.

## 6. H: no "before" status run for each app action

Line numbers without a file name are `bin/awake` at `32094d1`. "7.3" is faster-start-stop.md 7.3. Mac times are the owner's measurements of 7.3 unless marked "estimate". Linux times come from the macOS emulation (dry-run, 12 rounds or more, versions alternated in every round) and are marked "Linux". H is in phase 2, after I2 and before I1 (H.9). Its code is written against `32094d1`; H.3 says where it meets I2's change to `main`.

### H.1 Today

**The code path.** Every start, stop, added time and helper change from the app first runs `awake --status-json`, on the command queue, before the action:

- `performStart` (AwakeCLI.swift:337-379) calls `fetchStatus` at :349; `performStop` (:381-400) at :388; `performMaintenance` (:404-422) at :410. `fetchStatus` (:292-304) runs `runProcess` (:487-512): a new bash that reads the 7,336-line script. With a session running, `print_status_json` (3029-3152) runs about 37 programs (19 `awk`, 5 `date`, 1 `ps`; "Why it is slow", Counts).
- The status is read without the CLI's lock (6754). The action takes the lock and reads the same state again at 6767-6801.

**What the app uses it for.**

| Use | Where | What it needs |
|---|---|---|
| The shortcut and `Start default session` add no time to a session that is on | AwakeCLI.swift:350-356 (`startOnlyIfOff`) | `active` |
| The picker's lid mode is left out when a session is on | AwakeCLI.swift:357-361 | `active` |
| Stop time | StatusBarController.swift:405 (`recordStopTime`, :587-609) | `active`, `error`, `last_completed_at`, `last_completion_reason` |
| `Awake started` | :418-431 | `active` |
| `Awake is already on` | :440-445 | `active` |
| `Awake stopped` (or the title for how it ended) for the app's own session | :447-465 | `active`, `session_token` (`isAppSession`, :577-582), `session_backend`, `watch_command` |
| Helper changes | :871-886 | nothing: only `outcome.after` |

**What it costs.**

| App action | Status run before (Mac, dev, median) | What the app waits for, "with C" (Mac) | Status run before (Linux) | "With C" (Linux) |
|---|---|---|---|---|
| Lid-open start | 171 ms | 662 ms | 92 ms | 570 ms |
| Lid-open stop | 228 ms | 542 ms | 165 ms | 447 ms |
| Lid-closed start | 178 ms | 714 ms | 92 ms | 459 ms |
| Lid-closed stop | 214 ms | 1,061 ms | 156 ms | 870 ms |

The Linux status run in dry-run reads a mock file for `pmset`, so it is cheaper than the Mac's.

**Why it exists, and two faults.** The CLI does not tell the app what it found, so the app reads it first. Because that read happens outside the lock:

1. **Race.** A session started in Terminal between the app's read and the action's lock (about 0.1 to 0.2 s, Linux) gets time added by the shortcut. The app then posts `Awake started` and stores that session's token as its own.
2. **A lost end.** A timed app session ends on its own. Before the next 10 s poll, the user clicks Stop (or chooses `Add 1 hour`). The "before" read already shows the session as off, so the stop branch (:447) is not taken. The next poll compares the new status with `currentStatus`, which is already off, so nothing is posted. `Awake finished` is lost. A's paused polls make this window a little wider.

**A third fault, from the same result logic.** Added time can meet the session's own end: behind a lid-closed session's password dialog, with the password then given, or, rarely, in the moment between main's read and the change. `extend_running_session` then returns 3 (6343 lid-closed, 6378 lid-open), and `main` starts a new session that ends as asked (6941-6952). The app sees "before" on with the old token and "after" on with a new one. It posts `Awake extended`, posts no end for the old session, and keeps the old token as its own. So the new session's end is never posted either, and a stop of it posts no `Awake stopped`. The unlocked read does not cause this one, but H gives the app what it needs to fix it (H3h).

### H.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| H1a | How the CLI hands over the state it found | A second file, named in a new internal variable `AWAKE_STATUS_BEFORE_JSON_FILE`, read and unset at the top next to C's (after line 63). An older CLI ignores it. An older app never sets it. | One more key, such as `"found"`, in C's object. A 2.4.0 app would decode it, as JSONDecoder ignores unknown keys, but C's report would no longer be `--status-json`'s output (C2; 5c compares them), and `main` would have to keep the found state in globals until the EXIT trap writes C's report. Two objects in one file: a 2.4.0 app decodes C's file as one `AwakeStatus`, so it would fail and run `--status-json` again. Standard output: the reason of C1. A new option: an older CLI exits 1. |
| H1b | When it is written | Once, in `main`, right after the state is read under the lock (after line 6801). That is before anything changes: the housekeeping at 6803-6812, added time, stops, starts, and the pickers that let go of the lock while they are open (the add-time list at 6874, the terminal prompt at 7046, the GUI picker at 7069). Password dialogs keep the lock. | In `finish_main_run`: the state has changed by then. Before the lock: the same race as today. |
| H1c | What is written | An object of `--status-json`'s schema 1 with only 10 keys: `schema_version`, `active`, `session_backend`, `session_token`, `watch_command`, `last_completion_reason`, `last_completed_at`, `leftover_settings`, `other_user_session`, `error`. Each key has the value `--status-json` gives it. These are exactly the keys the app reads (table in H.1, plus `maybeNotifyCompletionTransition` for H3c). Without a session and without `pmset`, it is `--status-json`'s error object. The app decodes it with the same `AwakeStatus`, and the missing keys become nil (checked with the app's struct on Linux). The app never shows this object (H3g). | The full object, from `print_current_status` or from `print_status_json` on main's state. In-process it costs 49-54 ms idle, 122-139 ms with a lid-open session and 109-127 ms with a lid-closed one (Linux). A separate status run costs 88-165 ms, so H would save only about 40 ms. key=value text: it would need a second parser. |
| H1d | How it is built | From main's own reads: `caffeinate_session_active`, `helper_state`, `HELPER_SESSION_FOREIGN`, `pmset_read_ok` and `pmset_session_active` (whether the settings keep the Mac awake). Both `pmset` variables exist at `32094d1` (6790-6797) and after I2, which sets them whenever no session runs and drops main's `current_sleep` and `current_disablesleep` (I2b). H reads them only when no session runs. The rest is read with the builtin `read_state_value_into` (2361-2373) and printed with `printf -v`. One `$( )` for the whole object. It runs no programs, except the process name of a session tied to one (`watched_process_label`, 3992-4010). Cost: 1.3-2.0 ms, or 15 ms with `-w` (Linux). | Reading the state again (`ps`, `stat`, `pmset`). Passing the raw `sleep` and `disablesleep` values, as the first prototype did: I2 removes them from `main`. |
| H1e | JSON strings without subshells | `json_escape` (2927-2938) becomes `json_string_or_null_into VAR VALUE` (`printf -v`). `json_string_or_null` (2940-2948) calls it, and its output stays byte for byte the same; a sourced check pins it (H.5, 3a). With the old helpers the report cost about 8 ms (Linux, paired A/B), 6 ms of that in 9 subshells. Status reads also lose one nested subshell per string field: `--status-json` medians fell 3 to 6 ms (Linux). Question H-4. | Leaving it to F: the report would cost 4 to 6 times as much. |
| H1f | File safety | The rules of C9: only an existing regular file of this user, not a symlink (`-f`, `-L`, `-O`). It never creates one, writes only a whole object, and sends errors to `/dev/null`. | |
| H2a | How the app asks for "start only while off" | A new internal option `--if-off`, parsed in `parse_cli_args`, kept out of `--help` (question H-2). | An environment variable. An older CLI would ignore it and add time without notice. A developer's exported variable would also change `awake --start` without notice. |
| H2b | Where it is valid | Only with `--start`, and never with `-w` or `--`. Otherwise it exits 1 before the lock with `Option --if-off needs --start, and cannot be used with --wait-pid or --.` | Allowing `--`: `awake --start --if-off -- make && deploy` would exit 0 without running make, and then deploy. |
| H2c | What "on" means | `--status-json`'s `active`: a lid-open session; a lid-closed session of any account; a lid-closed record without its processes; or, with `pmset` read, settings that keep the Mac awake. This is the app's `before.active` today, so every `Awake is already on` case stays. One new function, `state_is_active`, holds the rule. The sourced check ties it to `print_current_status` in 7 states. | Only this account's sessions: a lid-open shortcut start next to another account's session would then start, which is a change in behaviour. |
| H2d | Its exit | Exit 0 right after the found report, before 6803, with nothing changed and nothing printed (one `log_debug` line). C's after report is still written by `finish_main_run`. This also closes the race in H.1 (1), because the decision is made under the lock. | A message or another exit status: the app tells "already on" from the two reports, and any status other than 0 would be posted as `Awake failed`. |
| H2e | Where the app puts it | Right after `--start`, so that an older CLI meets it before any other option (H3f). | |
| H3a | The app's status run | None in `performStart`, `performStop` or `performMaintenance`. A command's result is judged from `before = found ?? shown`. | |
| H3b | What `shown` is | `currentStatus`, copied at each of the four call sites just before the CLI is called. | `currentStatus` at completion: polls keep running during added time (A9) and post nothing then, so a session that ended behind its password dialog would never be posted. |
| H3c | A session that ended before the lock (`shown` on, found off) | `recordStopTime(from: shown, to: found)` and `maybeNotifyCompletionTransition(from: shown, to: found)` (:548-575), as the poll that missed the end would have done. That function posts each end only once (`lastNotifiedCompletionIdentifier`). This fixes H.1 (2). When the CLI wrote no found report and exited with a status other than 0, it stopped before it read the state under its lock and changed no session (H.3, "Every place the CLI can stop"), so the status read after it stands in for found (`CommandResult.foundOrRead`). A stop refused because the lock stayed busy then still posts the end it met. | Ignoring it, which keeps today's loss. Using the after report: after added time, the after report describes the new session. Only the found report: a refusal before the lock would still lose the end. |
| H3d | Where the result logic lives | A new Foundation-only `CommandResult.swift`. The rules and their order are exactly those of StatusBarController.swift:411-474, with one rule added before `Awake extended` (H3h). `tests/app/command-result-check.swift` makes 550 checks. | Keeping it in the controller: H changes the inputs of that logic, and no check could cover the controller. |
| H3e | The picker's lid mode | Always the app's `lastBackend`, as `--backend`. The rule at AwakeCLI.swift:357-361 goes, because a click start only runs while `shown` is off (:135-141). Question H-1. | A new `--picker-backend` (question H-1, option b). |
| H3f | An awake older than the app | When the CLI exits 1, writes neither report, and its standard error starts with `Unknown option: --if-off` (every release since 1.0.0 prints `Unknown option: %s\n\n` first), the app reads the status itself and runs the start without `--if-off`, as 2.4.0 did. This costs one refused run of 31-36 ms (Linux) in that case only. Question H-3. | Nothing: with a 2.3.0 or 2.4.0 CLI, which faster-start-stop.md's QA 29 covers, every shortcut start would fail. A version check: dev builds report the last release's version. |
| H3g | The found status in the app | Its `fetchedAt` and `fetchedUptime` are the launch time, taken just before `process.run()`. It is never `currentStatus`, never shown, and never sent to the heat recorder, which today never sees the "before" either. | |
| H3h | Added time that started a new session (H.1, third fault) | Added time keeps a session's token (dry run, both modes; 5d pins it). So added time with found on and after on under another token means the CLI started a new session. The app posts the old session's end, if it was the app's, once (`token:completed_at`, as a poll would), then does what `Awake started` does: it takes the new session as its own and posts `Awake started` (`.replaced`). With an older CLI, `shown` stands in for found, and the rule works the same. | Listing it as known: `Awake extended`, and no end for either session. |
| H4a | The helper | Unchanged. No protocol bump and no reinstall. 2.5.0's helper release (G1 and F8, in phase 3) is separate, and H needs none of it. | |
| H4b | `tools/measure-latency.sh` | It passes the found file too, which older versions ignore. It does not pass `--if-off`, which older versions refuse and which costs nothing while Awake is off. A new `--no-status-runs` leaves out the status runs around each action, as the app with H does, and checks the result in C's report instead (`/usr/bin/grep -q '"active":true' "$REPORT_FILE"`, and `false` after a stop). It refuses a CLI that writes no report, and its summary prints only the actions. Without it, each action runs right after a status run, so the "with C and H" column is a lower bound: on the Mac a run right after another can be quicker (7.3, J1). In the emulation the order made no difference (12 rounds, alternated: start 574 vs 572 ms, stop 306 vs 310 ms median, Linux). | |
| H4c | Release | Changed and three Fixed entries (H.7), no `**Breaking`, so `tools/release.sh` suggests a minor version. | |

### H.3 Code changes

**`bin/awake`** (about 165 lines added, 9 removed; prototype in `plan2-H/proto/bin/awake`, with the four-argument `state_is_active` of item 5 in `plan2-H-final/proto4/bin/awake`):

1. **After line 63** (C's block):
   ```bash
   # Awake.app also names a file here for its starts and stops. A run that gets
   # as far as reading the session state, under the state-change lock, writes
   # what it found into it before it changes anything (write_before_report), so
   # the app need not run --status-json before the command. Not passed on to
   # the processes awake starts.
   STATUS_BEFORE_REPORT_FILE=${AWAKE_STATUS_BEFORE_JSON_FILE:-}
   unset AWAKE_STATUS_BEFORE_JSON_FILE
   ```
2. **After line 248:** `START_IF_OFF=false`, with the comment `# --if-off: a start that changes nothing while Awake is on (main).`
3. **`parse_cli_args`, after the `--start` case (419-421):**
   ```bash
               # Internal, for Awake.app's keyboard shortcut and Start default
               # session; not in --help.
               --if-off)
                   START_IF_OFF=true
                   ;;
   ```
   **After 616-619:**
   ```bash
       # Not with a process: `awake --start --if-off -- make && deploy` would
       # deploy without running make.
       if [[ "$START_IF_OFF" == "true" && ( "$START_ONLY" != "true" || -n "$WATCH_PID" || ${#RUN_COMMAND[@]} -gt 0 ) ]]; then
           printf '%s\n' "Option --if-off needs --start, and cannot be used with --wait-pid or --." >&2
           exit 1
       fi
   ```
4. **2927-2948:** `json_escape` and `json_string_or_null` become:
   ```bash
   # Sets variable $1 (any name but "value") to $2 as a JSON string, or to
   # null when $2 is empty, with printf -v rather than a subshell: the report a
   # start or stop writes for Awake.app before it changes anything
   # (print_before_status_json) builds its object this way.
   json_string_or_null_into() {
       local value=${2:-}

       if [[ -z "$value" ]]; then
           printf -v "$1" '%s' "null"
           return 0
       fi
       # ... the seven escapes of json_escape, unchanged ...
       printf -v "$1" '"%s"' "$value"
   }

   json_string_or_null() {
       local json=""

       json_string_or_null_into json "${1:-}"
       printf '%s' "$json"
   }
   ```
   `json_escape` has no other caller. `printf -v` into a caller's local is what `read_state_value_into` (2361) already does under CI's Bash 3.2.
5. **After `print_current_status` (3159-3228)**, three functions:
   ```bash
   # True when --status-json, for the state main read, says "active": a
   # Caffeine session runs ($1 true), a lid-closed session of any account runs
   # ($2, what helper_session_state printed, is running), or, with the battery
   # sleep settings read ($3 true), a lid-closed session's record is left
   # without its processes or the settings keep the Mac awake ($4 true, main's
   # pmset_session_active): settings left behind, which a stop restores. The
   # same rule as print_current_status's.
   state_is_active() {
       [[ "$1" == "true" || "$2" == "running" ]] ||
           { [[ "${3:-false}" == "true" ]] && [[ "$2" == "stale" || "${4:-false}" == "true" ]]; }
   }

   # Prints the session state main found, with the arguments of state_is_active,
   # as an object of --status-json's schema with only the keys that tell
   # Awake.app what a command started from: "schema_version", "active",
   # "session_backend", "session_token", "watch_command",
   # "last_completion_reason", "last_completed_at", "leftover_settings",
   # "other_user_session" and "error", each with the value --status-json would
   # give it. It reads with builtins, but for the name of the process a session
   # waits for, so that writing it costs the app's commands next to nothing.
   # Without a session and without the settings, it prints --status-json's
   # error object and returns 1.
   print_before_status_json() {
       local active=false leftover=false other_user_session=false record=""   # one local per line in the code
       local session_backend="" session_token="" watch_pid="" watch_label="" watch_command=""
       local status_completed_at="" helper_completed_at="" last_file=""
       local last_completion_reason="" last_completed_at=""

       if [[ "$1" == "true" ]]; then
           active=true; session_backend=$SESSION_BACKEND_CAFFEINATE; record=$STATE_FILE
       elif [[ "$2" == "running" ]]; then
           active=true; session_backend=$SESSION_BACKEND_AWAKE; record=$HELPER_SESSION_FILE
           if [[ "$HELPER_SESSION_FOREIGN" == "true" ]]; then
               other_user_session=true
           fi
       elif [[ "${3:-false}" != "true" ]]; then
           print_status_json_error "Could not read the current battery sleep settings from pmset."
           return 1
       elif state_is_active "$@"; then
           active=true; leftover=true; session_backend=$SESSION_BACKEND_AWAKE
       fi

       # The session that ended last, picked as last_session_record_file does.
       read_state_value_into status_completed_at completed_at "$STATUS_FILE"
       read_state_value_into helper_completed_at completed_at "$HELPER_LAST_FILE"
       if is_nonnegative_integer "$helper_completed_at" &&
           { ! is_nonnegative_integer "$status_completed_at" || (( helper_completed_at >= status_completed_at )); }; then
           last_file=$HELPER_LAST_FILE
       elif [[ -f "$STATUS_FILE" ]]; then
           last_file=$STATUS_FILE
       fi
       if [[ -n "$last_file" ]]; then
           read_state_value_into last_completion_reason reason "$last_file"
           read_state_value_into last_completed_at completed_at "$last_file"
       fi

       if [[ "$active" == "true" && "$leftover" == "true" ]]; then
           read_state_value_into session_token session_token "$HELPER_SESSION_FILE"
       elif [[ "$active" == "true" ]]; then
           read_state_value_into session_token session_token "$record"
           read_state_value_into watch_pid watch_pid "$record"
           if [[ "$watch_pid" =~ ^[1-9][0-9]*$ ]]; then
               watch_label=$(watched_process_label "$watch_pid")
               watch_command=${watch_label% (PID *}
           fi
       elif [[ -n "$last_file" ]]; then
           read_state_value_into session_token session_token "$last_file"
           if [[ "$last_file" == "$STATUS_FILE" ]]; then
               # As session_backend_from_value reads it: anything else is awake.
               read_state_value_into session_backend session_backend "$STATUS_FILE"
               if [[ "$session_backend" != "$SESSION_BACKEND_CAFFEINATE" ]]; then
                   session_backend=$SESSION_BACKEND_AWAKE
               fi
           else
               session_backend=$SESSION_BACKEND_AWAKE
           fi
       fi

       json_string_or_null_into session_backend "$session_backend"
       json_string_or_null_into session_token "$session_token"
       json_string_or_null_into watch_command "$watch_command"
       json_string_or_null_into last_completion_reason "$last_completion_reason"
       is_nonnegative_integer "$last_completed_at" || last_completed_at=null
       printf '{"schema_version":1,"active":%s,"session_backend":%s,"session_token":%s,"watch_command":%s,' \
           "$active" "$session_backend" "$session_token" "$watch_command"
       printf '"last_completion_reason":%s,"last_completed_at":%s,"leftover_settings":%s,"other_user_session":%s,"error":null}\n' \
           "$last_completion_reason" "$last_completed_at" "$leftover" "$other_user_session"
   }

   # Writes print_before_status_json's object into the file Awake.app named in
   # AWAKE_STATUS_BEFORE_JSON_FILE, with write_status_report's rules: only an
   # existing regular file of this user, not a symlink, and only a whole
   # object. main calls it once, with the state it read under the lock, before
   # it changes anything.
   write_before_report() {
       local report=""

       if [[ -z "$STATUS_BEFORE_REPORT_FILE" ]] ||
           [[ ! -f "$STATUS_BEFORE_REPORT_FILE" || -L "$STATUS_BEFORE_REPORT_FILE" || ! -O "$STATUS_BEFORE_REPORT_FILE" ]]; then
           return 0
       fi
       report=$(print_before_status_json "$@" 2>/dev/null) || true
       if [[ "$report" == "{"*"}" ]]; then
           { printf '%s\n' "$report" > "$STATUS_BEFORE_REPORT_FILE"; } 2>/dev/null || true
       fi
       log_debug "write_before_report $report"
   }
   ```
   The values come from the same files and the same rules as `print_status_json` (3055-3106) and `last_session_record_file` (2975-2993). The comments of those two functions get a line: "print_before_status_json reads the same; the self-test compares them." That line is still to be written: the prototype lacks it. The awk reader and the builtin reader differ only on lines that end in `=` or have no `=` (6.3, F3). Tokens, numbers, words and process names never have either.

   The first prototype passed the raw `sleep` and `disablesleep` values as `$4` and `$5` and called `keep_awake_is_enabled` on them. I2 removes those two values from `main` (I2b), so `state_is_active` takes `pmset_session_active`, which holds `keep_awake_is_enabled`'s answer at `32094d1` and after I2. The rule is the same, as `pmset_session_active` is only true when the read worked. The full self-test passes with it (H.5).
6. **`main`, after 6798-6801** (`LEFTOVER_SETTINGS_PRESENT=true`):
   ```bash
       # The state found, for Awake.app, before anything changes.
       write_before_report "$caffeinate_session_active" "$helper_state" "$pmset_read_ok" "$pmset_session_active"
       # --if-off, from Awake.app's keyboard shortcut and Start default session:
       # while Awake is on, as --status-json would say, the start changes
       # nothing. It adds no time and replaces no settings left behind; the
       # status it leaves (write_status_report) shows what is on.
       if [[ "$START_IF_OFF" == "true" ]] &&
           state_is_active "$caffeinate_session_active" "$helper_state" "$pmset_read_ok" "$pmset_session_active"; then
           log_debug "main if_off already_on caffeinate=$caffeinate_session_active helper=$helper_state"
           exit 0
       fi
   ```
   Without the variable, `write_before_report` is a single `[[ ]]`. Without `--if-off`, `state_is_active` is not called. After I2, 6790-6797 is I2's guarded `read_sleep_settings_for_main`, which sets both `pmset` variables whenever no session runs and leaves them at their defaults (`true`, `false`) otherwise. H's call goes in the same place, right after `LEFTOVER_SETTINGS_PRESENT` and before 6803, and reads them only when no session runs (`state_is_active`'s third clause, `print_before_status_json`'s third and fourth branches).
7. **Unchanged on purpose:** `print_current_status`, `print_status_json`, `write_status_report`, `finish_main_run` (1202-1205), the lock, and the helper.

**Every place the CLI can stop, and what the app gets:**

| Where the CLI stops | Exit | Found report | After report (C) | The app |
|---|---|---|---|---|
| Option errors, including the new `--if-off` check (`parse_cli_args`, 384-644) | 1 | no | no | `before = shown`; the status read after it stands in for found (H3c); `Awake failed` with the message; after = `fetchStatus` |
| The root refusal (6644-6647); `require_macos` and `require_command pmset` (6687-6688); the runtime folder (6701, `ensure_runtime_dir` 782-818); `-w` checks (6703-6713); `--terminal` (6729-6737); `osascript` (6741) | 1 | no | no | the same |
| The lock: internal errors (1309-1322); busy after 100 tries, about 10 s (1332-1335) | 1 | no | no | the same: `Awake failed: Another awake command is already changing the session state. Please try again.` |
| Helper changes (6756-6765) | their own | no | yes | `performMaintenance` never used the before |
| Under `set -e`, a failure between the lock (6754) and the found report (after 6801), such as the `rm -f` at 6777 | not 0 | no | yes | `before = shown`; `Awake failed` |
| `--if-off` while on (new, after 6801) | 0 | yes, on | yes | `Awake is already on` |
| Every later exit: starts, added time, stops, refusals (battery, heat, other mode), the cancelled picker, add-time list or password dialog, `set -e` | any | yes | yes | judged from found and after |
| Killed by a signal before 6801 | not 0 | no | no | `Awake failed` |

So for a start or a stop, a missing found report always comes with an exit status other than 0, except with an older CLI (H3f). Helper changes exit 0 without one, and `performMaintenance` never reads it.

**`app/AwakeStatusApp/Sources/AwakeCLI.swift`** (about 80 lines added, 34 removed; prototype in `plan2-H/swift/AwakeCLI.swift`, type-checked):

- :51-54, the doc comment of `fetchedAt` adds: "…; for the state it found, when it was launched, just before its read."
- :162-167, `ManagedCommandResult` gets `let foundStatus: AwakeStatus?`, documented as "Only some keys: a status that tells which session the command started from, never one to show". It also gets:
  ```swift
  /// True when the CLI stopped at `option` as unknown: an awake older than
  /// this app, which then changed nothing. Every released version prints
  /// this line first, before its usage, and exits 1.
  func cliRefused(option: String) -> Bool {
      processResult.exitCode == 1 && foundStatus == nil && reportedStatus == nil &&
          processResult.stderr.hasPrefix("Unknown option: \(option)\n")
  }
  ```
- :211-215, `AwakeCommandOutcome.before` becomes `AwakeStatus?`. Doc comment: "The state the command started from, as the CLI found it under its lock, with only the keys that tell which session that was; or, with an awake older than this app, as read just before the command. Nil when the CLI reported none: an awake older than this app, or one that stopped before it read the state under its lock, with an exit status other than 0."
- :331-336, the doc of `performStart`: "With `startOnlyIfOff`, the CLI changes nothing while Awake is on (`--if-off`)", and a sentence on question H-1's case. The body :347-374 becomes:
  ```swift
  let arguments = self.startArguments(
      preferences: preferences,
      durationSeconds: durationSeconds,
      endArguments: endArguments,
      backend: backend,
      keepDisplay: keepDisplay,
      onlyIfOff: startOnlyIfOff
  )
  let run = try self.runManagedCommand(
      arguments: arguments,
      customPassword: customPassword,
      appCustomPasswordMode: preferences.useCustomPasswordDialog
  )
  guard startOnlyIfOff && run.cliRefused(option: "--if-off") else {
      return try self.outcome(of: run)
  }
  // An awake older than this app: as older apps did, the status
  // is read first, and a session that is on is left alone.
  let before = try self.fetchStatus()
  if before.active {
      return AwakeCommandOutcome(
          before: before,
          after: before,
          processResult: ProcessResult(exitCode: 0, stdout: "", stderr: "")
      )
  }
  let started = try self.runCommand(
      arguments: arguments.filter { $0 != "--if-off" },
      customPassword: customPassword,
      appCustomPasswordMode: preferences.useCustomPasswordDialog
  )
  return AwakeCommandOutcome(before: before, after: started.after, processResult: started.processResult)
  ```
  The `startBackend` rule (:357-361) goes.
- :386-395 and :408-417: `performStop` and `performMaintenance` call `runCommand` without `fetchStatus`.
- :424-439, `runCommand` loses its `before:` parameter and becomes `try outcome(of: runManagedCommand(…))`. A new `private func outcome(of result: ManagedCommandResult) throws -> AwakeCommandOutcome` holds today's two lines (`result.reportedStatus ?? fetchStatus()`) and passes `before: result.foundStatus`.
- :441-472, `startArguments` gets `onlyIfOff: Bool`, which appends `--if-off` right after `--start`. The doc says why (H2e).
- `runManagedCommand` (:514-604):
  - the doc (:514-519) adds the fourth file;
  - after :531, `let foundURL = …"awake-statusbar-found-\(UUID().uuidString)"`, removed in the `defer` at :532-536;
  - at :543-544, `createFile` for it, under "The CLI writes only into files that exist.";
  - after :571, `commandEnvironment["AWAKE_STATUS_BEFORE_JSON_FILE"] = foundURL.path`;
  - before :574, `let launchedAt = Date()` and `let launchedUptime = ProcessInfo.processInfo.systemUptime`, under "The CLI reads the state it found just after it starts.";
  - after :593-599, the same decode for `foundURL`, with `fetchedAt = launchedAt` and `fetchedUptime = launchedUptime`, returned as `foundStatus`.
- :634-635, `environment()` also removes `AWAKE_STATUS_BEFORE_JSON_FILE`, so status reads and the picker never pass one, not even one the app was started with.

**`app/AwakeStatusApp/Sources/CommandResult.swift`** (new, 155 lines, Foundation only; in `plan2-H-final/CommandResult.swift`):

```swift
enum CommandResult {
    enum Intent: Equatable { case start, defaultStart, extend, stop, stopAndQuit }
    struct Facts: Equatable { let active: Bool; let sessionToken: String? }
    enum Announcement: Equatable {
        case failed, started, extended, replaced(appSession: Bool), alreadyOn, ended(appSession: Bool), nothing
    }
    enum Quit: Equatable { case no, quit, cancelled }

    static func before(found: Facts?, shown: Facts) -> Facts { found ?? shown }

    static func foundOrRead<Status>(found: Status?, after: Status, exitCode: Int32) -> Status? {
        if let found = found { return found }
        if exitCode != 0 { return after }
        return nil
    }

    static func endedBeforeCommand(shown: Facts, found: Facts?) -> Bool {
        guard let found = found else { return false }
        return shown.active && !found.active
    }

    static func announcement(intent: Intent, exitCode: Int32, before: Facts, after: Facts,
                             appSessionToken: String?) -> Announcement {
        if exitCode != 0 { return .failed }
        if !before.active && after.active { return .started }
        if intent == .extend && before.active && after.active,
           let oldToken = before.sessionToken, !oldToken.isEmpty,
           let newToken = after.sessionToken, newToken != oldToken {
            // Added time keeps a session's token. A new one means that the
            // session ended behind the password dialog, and the CLI started
            // a new one (extend_running_session's 3, then main).
            return .replaced(appSession: isAppSession(before, appSessionToken: appSessionToken))
        }
        if intent == .extend && after.active { return .extended }
        if (intent == .start || intent == .defaultStart) && before.active && after.active { return .alreadyOn }
        if before.active && !after.active {
            return .ended(appSession: isAppSession(before, appSessionToken: appSessionToken))
        }
        return .nothing
    }

    static func quit(intent: Intent, announcement: Announcement, after: Facts) -> Quit {
        guard intent == .stopAndQuit else { return .no }
        switch announcement {
        case .ended: return .quit
        case .nothing: return after.active ? .cancelled : .quit
        case .failed, .started, .extended, .replaced, .alreadyOn: return .no
        }
    }

    static func isAppSession(_ status: Facts, appSessionToken: String?) -> Bool {
        guard let token = status.sessionToken, !token.isEmpty else { return false }
        return token == appSessionToken
    }
}
```

In the file, each case and function has the doc comment of the prototype, and every statement is on its own line. `foundOrRead` is generic so that the controller passes `AwakeStatus` and the check passes `Facts`. Its doc: "The status to look for an end in that the command did not make: the one the CLI found, or, when it reported none and its exit status is not 0, the one read after it. A CLI that stopped before its lock changed nothing, so that read is the one a poll would have made." `.replaced`'s doc: "Added time met the session's own end, and the CLI started a new session that ends as asked. The old session's end is posted when it was the app's own, as for `ended`; the new session is the app's from now on, as for `started`."

**`app/AwakeStatusApp/Sources/StatusBarController.swift`** (about 105 lines added, 70 removed; in `plan2-H-final/StatusBarController.swift`):

- :14-25, the private `CommandIntent` enum becomes `private typealias CommandIntent = CommandResult.Intent`.
- :179, :215, :313 and :337: `let shown = currentStatus` just before `cli.performStart` or `cli.performStop`. Each closure passes `shown: shown`.
- :390-476, `handleCommandResult(_:intent:shown:)`. The `.failure` branch is unchanged. The `.success` branch:
  ```swift
  // A session shown as on may have ended on its own before the
  // command took the CLI's lock. Its end is posted as the poll
  // that missed it would have posted it, and only once. Without
  // the status found, a CLI that failed stopped before its lock
  // and changed nothing, so the status read after it serves.
  if let found = CommandResult.foundOrRead(
      found: outcome.before,
      after: outcome.after,
      exitCode: outcome.processResult.exitCode
  ),
     CommandResult.endedBeforeCommand(shown: shown.commandFacts, found: found.commandFacts) {
      recordStopTime(from: shown, to: found)
      maybeNotifyCompletionTransition(from: shown, to: found)
  }
  let before = outcome.before ?? shown
  currentStatus = outcome.after
  recordStopTime(from: before, to: outcome.after)
  recordHeat(from: outcome.after)
  updateStatusItem()

  let soundEnabled = preferences.soundEnabled
  let announcement = CommandResult.announcement(
      intent: intent,
      exitCode: outcome.processResult.exitCode,
      before: before.commandFacts,
      after: outcome.after.commandFacts,
      appSessionToken: preferences.appSessionToken
  )
  switch announcement {
  case .failed:      // clearCachedCustomPassword(); postFailure(normalizedErrorMessage(…)), as :412-414
  case .started:
      announceStart(outcome.after, intent: intent, soundEnabled: soundEnabled)
  case let .replaced(appSession):
      // Added time met the session's own end behind its password
      // dialog, and the CLI started a new session. The old one's
      // end is posted once, as a poll would have; the new one is
      // the app's start.
      if appSession {
          announceReplacedEnd(before: before, after: outcome.after, soundEnabled: soundEnabled)
      }
      announceStart(outcome.after, intent: intent, soundEnabled: soundEnabled)
  case .extended:    // postExtended, as :434-436
  case .alreadyOn:   // postAlreadyOn, as :443
  case let .ended(appSession):
      rememberCompletionIfNeeded(from: outcome.after)
      if appSession {
          playSoundIfNeeded(enabled: soundEnabled)
          notifications.postStopped(soundEnabled: soundEnabled, reason: outcome.after.lastCompletionReason,
                                    backend: outcome.after.sessionBackend ?? before.sessionBackend,
                                    processName: before.watchCommand)
      }
  case .nothing:
      break
  }
  switch CommandResult.quit(intent: intent, announcement: announcement, after: outcome.after.commandFacts) {
  case .quit: NSApp.terminate(nil)
  case .cancelled: notifications.postQuitCancelled()
  case .no: break
  }
  ```
- After `handleCommandResult`, two private functions:
  ```swift
  /// Takes the session in `status`, which a command just started, as the
  /// app's own, and announces it.
  private func announceStart(_ status: AwakeStatus, intent: CommandIntent, soundEnabled: Bool) {
      preferences.appSessionToken = status.sessionToken
      // The picker opens with the choices made in it, which a start of the
      // default session, in the shortcut's mode, leaves alone.
      if intent != .defaultStart {
          preferences.lastBackend = status.sessionBackend
          if let keepDisplay = status.keepDisplay {
              preferences.lastKeepDisplay = keepDisplay
          }
      }
      playSoundIfNeeded(enabled: soundEnabled)
      notifications.postStarted(soundEnabled: soundEnabled, status: status)
  }

  /// Posts the end of the app's session that added time met: its token,
  /// lid mode and process come from `before`, the state the command
  /// started from; its reason and time from `after`, whose last finished
  /// session it is. Only once, like an end a poll posts.
  private func announceReplacedEnd(before: AwakeStatus, after: AwakeStatus, soundEnabled: Bool) {
      if let token = before.sessionToken, let completedAt = after.lastCompletedAt {
          let identifier = "\(token):\(completedAt)"
          if identifier == lastNotifiedCompletionIdentifier {
              return
          }
          lastNotifiedCompletionIdentifier = identifier
      }
      playSoundIfNeeded(enabled: soundEnabled)
      notifications.postStopped(
          soundEnabled: soundEnabled,
          reason: after.lastCompletionReason,
          backend: before.sessionBackend,
          processName: before.watchCommand
      )
  }
  ```
  `announceStart` holds today's :419-429. The identifier is the one a poll builds for that end (`AwakeStatus.completionIdentifier`, AwakeCLI.swift:148-153): the old token and `last_completed_at`. In the after report that is the old session's end, as `print_status_json` reports the last finished session also while a new one runs (3055-3062). Polls during added time post nothing (StatusBarController.swift:521-524), so no poll has posted it. Like the `.ended` branch, it posts through `postStopped`, whose title for reason `failed` is `Awake failed`, with Tink.
- :577-582, `isAppSession` calls `CommandResult.isAppSession(status.commandFacts, appSessionToken: preferences.appSessionToken)`.
- After :1165: `private extension AwakeStatus { var commandFacts: CommandResult.Facts { CommandResult.Facts(active: active, sessionToken: sessionToken) } }`.
- Unchanged: the previews (:173-177, :307-311, :333-335), `pausesPolls` and `pollResultApplies` (StatusIcon.swift:35-59), `refreshStatus`, `maybeNotifyCompletionTransition`, `recordStopTime`, and `runMaintenance` (it uses only `after`).

Swift 5.7 syntax: explicit `self.` in the closures, no `if` or `switch` expressions, `guard let x = x` and `if let x = x`.

**`tools/measure-latency.sh`** (about 55 lines changed):

- :11-15, `NO_STATUS_RUNS=false`. The usage line (:19-20) gains `[--no-status-runs]`, and after `--dry-run` (:37) comes:
  ```
    --no-status-runs
                  Time each start and stop with no status read right before
                  or after it, as Awake.app runs them since 2.5.0, and check
                  each in the status it writes for the app. Needs awake
                  2.4.0 or later. The summary then shows the actions only.
  ```
- :52-88, the case `--no-status-runs) NO_STATUS_RUNS=true; shift ;;`.
- After :93-96:
  ```bash
  # Without the status runs, each start and stop is checked in the status it
  # writes for the app, as awake 2.4.0 and later do.
  if [[ "$NO_STATUS_RUNS" == "true" ]] && ! /usr/bin/grep -q AWAKE_STATUS_JSON_FILE "$CLI"; then
      printf '%s\n' "Option --no-status-runs needs awake 2.4.0 or later, which writes the status it leaves for the app." >&2
      exit 1
  fi
  ```
- :100-101 also unsets `AWAKE_STATUS_BEFORE_JSON_FILE`.
- After :126, `FOUND_FILE="${WORK}/status-found"`.
- `action_run` (:136-147) empties `FOUND_FILE` and passes `AWAKE_STATUS_BEFORE_JSON_FILE="$FOUND_FILE"` in both branches, with the comment "The app's shortcut start also passes --if-off; it is left out here, as older versions refuse it, and while Awake is off it costs nothing."
- The rounds (:218-258): with `--no-status-runs`, the four status steps (:225, :232, :246, :248) are left out, and the checks at :233 and :249 read `"$REPORT_FILE"` in place of `"${WORK}/out"`. Before the first round comes `/bin/sleep 1`, so that the first start does not run right after the script's own status read (:200). Every other action already follows a pause (:244, :254).
- :269-275: the options line adds ", no status runs".
- :281-284, the comment names the columns: "today" (the app before 2.4.0), "with C" (2.4.0), "with C and H" (the action alone, right after a status run: a lower bound for the app with H, which runs it after an idle gap; `--no-status-runs` times that). With `--no-status-runs`, awk gets `-v actions_only=true` and leaves out the "The app waits" table (:322-328): the step table then holds only the actions, each what the app with H waits for.

**`.github/workflows/ci.yml`**, after :82-87 ("Check the menu bar icon"):

```yaml
      # CommandResult.swift uses Foundation only, so its check builds with
      # that file alone.
      - name: Check what the app posts after a start or stop
        run: |
          swiftc -target arm64-apple-macos12.5 -parse-as-library \
            app/AwakeStatusApp/Sources/CommandResult.swift tests/app/command-result-check.swift \
            -o "$RUNNER_TEMP/command-result-check"
          "$RUNNER_TEMP/command-result-check"
```

And "Check the timing script" (:121-122) runs the script twice, so that CI covers the new option too:

```yaml
      - name: Check the timing script
        run: |
          tools/measure-latency.sh --dry-run --rounds 1 --cli bin/awake
          tools/measure-latency.sh --dry-run --rounds 1 --no-status-runs --cli bin/awake
```

**Every message the user can see.** In each row, "found" replaces today's unlocked read. The check rows are those of `checkWhatTheUserSees`.

| What the user sees | When | Today's input | With H | Stays right because |
|---|---|---|---|---|
| `Awake started` (+ Tink with Sound on) | `.started` | before off, after on | found off, after on | found is read under the lock, so a Terminal session started a moment before is no longer taken for the app's (H2d) |
| `Awake extended` | `.extended` | intent and after | intent and after, and the same token before and after | 5d: the stop after added time finds the session's first token |
| `Awake is already on` with the session's line | `.alreadyOn` | before on, after on; the app ran nothing | found on, after on; the CLI exits at `--if-off` with nothing changed | same "on" (H2c); 5d checks token, deadline and duration in both modes, and leftovers; 12i checks another account's session |
| `Awake stopped`, `Awake finished`, `Awake stopped: the battery is low`, `…: the Mac got too hot`, `…: the Mac was unplugged`, `Awake finished: the process it waited for exited`, `Awake failed` (reason `failed`) + Tink | `.ended(appSession: true)` | before's token, backend, `watch_command`; after's reason | found has the same keys | 5d compares each key with `--status-json`, `watch_command` included |
| The end of a session that ended just before the click | new: H3c | lost | posted once, exactly as the poll that missed it would have: `maybeNotifyCompletionTransition` with found's token, reason, `completed_at` and backend. For reason `failed` that is `Awake failed: Awake stopped unexpectedly before the session finished.` (lid-open) or `Awake failed: Awake stopped, but the normal sleep settings may still need attention.` (lid-closed), without Tink. Without a found report and with an exit status other than 0, the status read after the command stands in for found | de-duplicated by `token:completed_at`; check rows "stop just after…", "added time just after…", "stop refused before the lock just after the session ended" |
| The old session's end (`Awake finished` or the title for how it ended, + Tink), then `Awake started` for the new one | new: `.replaced(appSession: true)` (H3h) | `Awake extended`, no end for either session | found's token, backend and `watch_command`; after's reason and `completed_at`; a new token in after | de-duplicated by `token:completed_at`; check row "added time, the session ended behind its password dialog, password given"; QA 6 |
| `Awake failed: <the CLI's message>` | exit status not 0 | standard error | unchanged; the found report prints nothing | 5d `expect_same_errors_without_found`: byte-identical standard error with and without the file |
| `Awake failed: <error>` (launch failed, CLI missing, bad status output) | `.failure` | | unchanged | |
| `Quit cancelled` | stop-and-quit, `.nothing`, after on | | unchanged rule | check row "stop and quit, password dialog cancelled" |
| `Awake needs attention` | polls, shortcut registration | | untouched | |
| Icon, tooltip, menu's first line, VoiceOver | `PendingCommand`, then `currentStatus = after` | | unchanged; `Awake has been off for …` uses `lastStoppedAt`, which only moves forward | |
| `awake` in a terminal | | | unchanged: the variable is unset at the top, and `--if-off` is never passed | `--status`/`--status-json` byte-identical (H.5) |

### H.4 Security and compatibility

- **The new variable.** It is read once and unset at the top, before anything runs. The Caffeine worker and runner, the notifier, the helper and the command after `--` never see it (5d checks the command). It is written only into an existing regular file of this user, never through a symlink, and never created (5d). It holds a session token, a lid mode, a reason, a time and a process name, all of which `--status-json` already shows this user. The app's file lives in its own `$TMPDIR`. Root never writes it: state-changing runs refuse root at 6644-6647, before the lock.
- **`--if-off`.** It only narrows what a start does. It is refused before the lock unless given with `--start`, and refused with `-w` and `--`. It touches no privileged path.
- **The helper.** Unchanged. The variable is gone before any `sudo` call, and sudo resets the environment anyway. The password-free rule has no `SETENV` (it is written at 4331).
- **A new app with an older CLI** (2.3.0, 2.4.0, a copy made by hand). The variable is ignored, so `before = shown`. For the shortcut and `Start default session`, the older CLI refuses `--if-off` and the app falls back (H3f). Stops and click starts work as in 2.4.0. Messages differ from 2.4.0's only in two rare cases. A click start while a Terminal session started since the last poll posts `Awake started` instead of `Awake is already on`, because `shown` is off. And since such a CLI never writes the found report, after any failure the status read after it stands in for found (H3c): a lid-closed stop whose helper ended the session but could not restore the settings (`request_helper_session_stop`'s return 1 at 3956-3957), and whose own restore then failed too (`Failed to restore the battery sleep settings.`, 7011), also posts that end, which 2.4.0's app does not. Both notifications are true. With the new CLI that stop has a found report, so it does not happen.
- **An older app (2.4.0) with the new CLI.** It never sets the variable and never passes `--if-off`. The CLI then does everything 2.4.0's does, and `--status-json`'s output is byte-identical (H1e).
- **Dry-run.** The report works there unchanged, and the self-test runs it. The helper is not involved.
- **Installer and Homebrew.** The installer builds the app, stops the session, quits the app, then installs both (scripts/install-awake.sh:488, :496-497, :507), and the cask runs the installer. So the two always match after an update. H adds no helper reinstall and no password prompt. The one prompt of the 2.5.0 update comes from G1 and F8 (G's Upgrade note).

### H.5 Tests

**Self-test** (`tests/cli/awake-self-test`, about 250 lines; line numbers at `32094d1`):

1. **Line 8:** the `unset` list also names `AWAKE_STATUS_BEFORE_JSON_FILE`, and the comment above it (4-7) says "the files Awake.app names".
2. **After line 38:** `APP_BEFORE_REPORT_FILE=""`. `cleanup_app_status_report` (294-300) also removes it and its `-target`, `-missing`, `-stderr` and `-stderr-without` files.
3. **Sourced check, after line 1845** (after C's cancelled-prompt check), in a `( … )` subshell with stand-ins for `helper_session_state`, `helper_session_is_foreign` and `get_battery_setting`, a fake helper `session` (another uid) and a fake `last` record. It works out `pmset_session_active` from the stand-in values with `keep_awake_is_enabled`, as `main` does. It covers 7 states: another account's session, this account's lid-closed session, a stale record, settings left behind, nothing, and `pmset` unreadable with nothing and with a stale record. For each it asserts:
   - for the error object, `print_before_status_json` equals `print_current_status`'s output;
   - otherwise it has exactly 10 keys, each equal to `print_current_status`'s;
   - `state_is_active` equals `active`.

   This is the drift guard for H1c and H2c.

   **3a. Before it,** in `run_sourced_regression_checks`, the JSON string check for H1e. Every string of `--status-json` and of the found report goes through `json_string_or_null_into`, and nothing else in the self-test checks the escaping:
   ```bash
   # json_string_or_null and json_string_or_null_into write every string of
   # --status-json and of the report of the state found (H1e): both give the
   # same JSON string, which decodes back to the value, and null for nothing.
   json_sample=$'quote " backslash \\ newline \n return \r tab \t feed \f back \b end'
   json_sample_into=""
   json_string_or_null_into json_sample_into "$json_sample"
   if [[ "$(json_string_or_null "")" != "null" ]] ||
       [[ "$json_sample_into" != "$(json_string_or_null "$json_sample")" ]] ||
       ! python3 -c 'import json, sys; assert json.loads(sys.argv[1]) == sys.argv[2]' \
           "$json_sample_into" "$json_sample" 2>/dev/null; then
       printf 'Self-test failed: json_string_or_null did not write a JSON string (%s).\n' "$json_sample_into" >&2
       exit 1
   fi
   ```
4. **New section "5d. Verifying the status starts and stops write for Awake.app before they change anything, and --if-off"**, after line 2988, before section 6.
   - `expect_before_report RC ARGS…` reads `--status-json`, then runs as the app does with both files. It checks the exit status, that standard output is empty, that the found file has exactly the 10 keys, and that each equals the value read just before. It keeps standard error.
   - `expect_same_errors_without_found RC ARGS…` runs again with C's file alone and compares standard error byte for byte.
   - For `caffeinate`, then `awake`:
     - a start with `--if-off` while off: found off, and a session starts;
     - `--if-off` in the same lid mode and in the other one: exit 0, and the token, `deadline_at` and `duration_seconds` 1200 stay, in `--status-json` and in C's report;
     - added time without `--if-off`: found on, duration 1800;
     - a stop: found names the token, which added time kept (H3h);
     - a stop with nothing running: found off, `last_completion_reason` `stopped`, the stopped session's token and lid mode, and the same standard error as without the file;
     - a start at a mocked 4% battery: exit 1, found written, and the same standard error.
   - **Both records**, after that loop and before the `-w` check. The loop cleans up between the lid modes, so it never has a record of each at once, and that is H3c's case after a lid-closed session yesterday and a lid-open one that just ended:
     ```bash
     # Both lid modes have a record of a session that ended: the status found
     # names the one that ended last, as --status-json does
     # (last_session_record_file). The loop above cleans up between the modes,
     # so it never has both.
     cleanup_state
     for first_backend in awake caffeinate; do
         second_backend=caffeinate
         if [[ "$first_backend" == "caffeinate" ]]; then
             second_backend=awake
         fi
         for ended_backend in "$first_backend" "$second_backend"; do
             AWAKE_NO_NOTIFICATIONS=true run_awake --terminal --backend "$ended_backend" --duration-seconds 1200 </dev/null >/dev/null 2>&1
             # completed_at counts whole seconds; the second end must be later.
             /bin/sleep 1
             run_awake --stop </dev/null >/dev/null 2>&1
         done
         before=$(expect_before_report 0 --gui --stop)
         json_field_equals "$before" session_backend "$second_backend" ||
             fail_test "Self-test failed: after a $first_backend and then a $second_backend session, the status found did not name the one that ended last."
     done
     cleanup_state
     ```
   - Also:
     - a `-w` session: found's `watch_command` is `sleep`;
     - settings left behind (`write_mock_pmset_state 0 1`): found has `leftover_settings` true, and `--if-off` creates no state file and leaves the mock file as it was;
     - `--if-off`, `--if-off --stop`, `--if-off --duration-seconds 60`, `--start --if-off -w $$` and `--start --if-off -- /usr/bin/true` each exit 1 with the message and write nothing;
     - the command after `--` prints `unset` for the variable;
     - a symlink is not written through, and a missing file is not created.
5. **12i, after line 4413** (another account's session): a lid-open `--if-off` start exits 0, found has `other_user_session` true, and no state file appears.
6. **13, after line 5098:** `--help` does not contain `--if-off`.

**They fail without the change.** On `plan2-H`, a mini test (5c, 5d, the 12i part, 13's line and the sourced check, built from the prototype's self-test) was run against `32094d1`'s `bin/awake` and against ten deliberate mistakes in the prototype. Each one failed:

| CLI | Caught by |
|---|---|
| `32094d1` | 5d, first check (`Unknown option: --if-off`), and the sourced check (no `print_before_status_json`) |
| no `write_before_report` call | 5d: "did not write the status it found" |
| `--if-off` without its `exit 0` | 5d: "changed the running caffeinate session" (`deadline_at` moved) |
| `state_is_active` without stale records and leftovers | 5d (leftovers) and the sourced check (`stale false normal`) |
| no token for the last session | 5d (stop with nothing on) and the sourced check (`none false normal`) |
| no `-L` test | 5d: "through a symlink" |
| `--if-off` allowed with `-w` and `--` | 5d: "`--start --if-off -w …` was not refused" |
| the variable not unset | 5d: "awake -- COMMAND passed on AWAKE_STATUS_BEFORE_JSON_FILE" |
| no `other_user_session` | 12i part and the sourced check (`running true normal`) |
| no `watch_command` | 5d (`-w` session) |
| the report also printed on standard error | 5d: `expect_same_errors_without_found` |

Two more mistakes passed the whole self-test of the prototype (exit 0, in copies of it). The two checks added for them catch them, run in the emulation against those copies and again against `plan2-H-final/proto4` with each mistake put back:

| CLI | Caught by |
|---|---|
| `json_string_or_null_into` without the backslash escape | 3a, the JSON string check (the rest of the self-test passes without it) |
| the older of the two last records (`<=` for `>=`) | 5d, both records: the found report named the session that ended first, in both orders (the rest of the self-test passes without it) |

The full self-test passes on the prototype in the emulation: 5 min 7 s, exit 0, with the usual Linux changes (`plutil`, end-time and picker checks skipped). It passes again on `plan2-H-final/proto4`, with the four-argument `state_is_active`, 3a and 5d's both-records part: 5 min 31 s, exit 0. Not run here: Bash 3.2. CI runs `/bin/bash` 3.2, and the new code uses only `printf -v` (3.1), here-strings, `[[ =~ ]]` and `${#array[@]}` under `set -u`, all of which the script already uses.

Other checks:

- `--status-json` and `--status` were byte-identical between `32094d1` and the prototype in five states: idle, a `-w` session whose process name has a quote, a backslash and a tab, after a stop, a lid-closed session, and after its stop. The found report escaped that name, and Python decoded it back. 3a now checks the escaping on every CI run.
- `tools/measure-latency.sh --dry-run --rounds 2 --lid-closed --cli bin/awake` ran in the emulation. CI's step at ci.yml:121-122 keeps covering it, and with H also runs `--no-status-runs`.
- Added time keeps a session's token in both modes (dry run: caffeinate and awake, 1200 s, then 3600 s more, same token), which H3h rests on.

**`tests/app/command-result-check.swift`** (new, 231 lines; built like `status-icon-check`; in `plan2-H-final/command-result-check.swift`):

- every intent × exit status 1, 2 and 15 × 25 status pairs gives `.failed` (the statuses: off, the app's session on, it ended, a Terminal session on, and a new session);
- starts, added time, stops and quit, case by case; added time to a session that comes back with a new token gives `.replaced`, with `appSession` true only for the app's token, and without a token on either side `.extended`;
- `before(found:shown:)`, `foundOrRead` (the found status, also after a failure; without it, the read after a failure; without it and with exit 0, nothing) and `endedBeforeCommand`;
- `isAppSession` with nil, empty, other and stored tokens;
- 16 rows of what the user sees, among them "added time, the session ended behind its password dialog, cancelled" (`.ended`), "…, password given" (`.replaced(appSession: true)`) and "stop refused before the lock just after the session ended" (end found through the read, `.failed`).

It built and ran on Linux with Swift 5.10.1 (`-swift-version 5 -parse-as-library`): all 550 checks passed. Eight deliberate mistakes were each caught: `before` always `shown` (6 failures); no end before the command (5); no read without a found report (2); the read also after exit 0 (2); no `.replaced` rule (3); the `.replaced` rule after the `.extended` one (3); every replaced session taken as the app's (1); a quit that is never cancelled (2).

The app's sources (the new AwakeCLI.swift, StatusBarController.swift and CommandResult.swift, with StatusIcon, StatusDescription, HeatReport, PickerSettings and StartShortcut) were type-checked on Linux against AppKit stand-ins (`tc-e`), with the two changes of H3c and H3h in. A deliberate type error was reported (`outcome.before`, an optional, passed to `announceReplacedEnd` in place of `before`), so the check is real. CI's app build and its macOS 12.5 build are the first true compile.

### H.6 Mac QA

1. **Timing, same sitting.** At the end of phase 2, with the branch in `~/awake-2.5` (cross-cutting: Timing, phase 2; no install needed, as the script runs the CLI alone). In the 2.5.0 QA, the installed build takes the place of `--cli ~/awake-2.5/bin/awake`.
   - If it is not there yet: `git -C ~/awake worktree add ~/awake-qa/awake-2.4.0 v2.4.0`.
   - Run the branch's script: `~/awake-2.5/tools/measure-latency.sh --rounds 10 --lid-closed --cli ~/awake/bin/awake` (`dev`, the 2.4.0 code; in the 2.5.0 QA, `--cli ~/awake-qa/awake-2.4.0/bin/awake`), then at once `~/awake-2.5/tools/measure-latency.sh --rounds 10 --lid-closed --cli ~/awake-2.5/bin/awake`, then `~/awake-2.5/tools/measure-latency.sh --rounds 10 --lid-closed --no-status-runs --cli ~/awake-2.5/bin/awake`.
   - Expected: the status steps of the first two runs are within about 20 ms of each other, so the sitting held steady.
   - Lid-open start, lid-open stop and lid-closed start: the second run's actions are within about 30 ms of the first run's, and the third run's within about 30 ms of the second's. Leave the lid-closed stop out: the helper's once-a-second check spreads it over 0.3 to 1.3 s (G). In phase 2, I1 may take up to about 40 ms off the second run's lid-closed start (estimate, I's section). In the 2.5.0 QA the second run also carries G1, F8 and F, so only the third run against the second applies.
   - H's gain per action is the first run's "with C" minus the third run's action. At the end of phase 2 that is phase 2's gain (H with I2 and I1). If the third run's actions are more than 30 ms slower than the second's, an action after an idle gap costs more on the Mac than one right after a status run. Note it in this plan's results table and in H.8.
   - Fill in this plan's results table (cross-cutting: Timing, Results). If I3 went in (protocol 10), the 2.4.0 run in the 2.5.0 QA times the lid-open rows only (the timing script's guard); compare those.
2. **No status run around an action.**
   - In Terminal: `while :; do pgrep -lf -- 'awake.*--(status-json|start|stop|passwordless)'; sleep 0.05; done | uniq`.
   - Press ⇧⌘A twice. Click the icon and pick 20 minutes. Choose `Add 1 hour`, then `Stop session`. In Settings, turn password-free mode off, then on.
   - Expected: no `--status-json` line within about a second before a start or a stop, or right after one: polls are paused while those run (StatusIcon.swift:35-42). `Add 1 hour` and the password-free changes keep their polls, so a `--status-json` line may appear while they run, but none just before them. `--if-off` appears only on the ⇧⌘A start.
3. **Already on, both modes.**
   - Run `awake --backend caffeinate --duration 10m; awake --status-json | grep -o '"deadline_at":[0-9]*'`. Within 5 s, while the icon is still regular, press ⇧⌘A. Run the `grep` again.
   - Expected: `Awake is already on`, "Awake is on and has 10 minutes left (keep the lid open)", the same `deadline_at`, and no `Awake failed`.
   - Repeat with the shortcut's mode set to lid-closed: the same, with no password dialog. Then `awake --stop`.
   - With `launchctl setenv AWAKE_DEBUG true` and the app relaunched, `grep 'if_off already_on' /tmp/keep-awake-lid-closed-$UID/awake-debug.log` shows the line. Then `launchctl unsetenv AWAKE_DEBUG`, relaunch, and delete the log.
4. **The end just before a stop.**
   - In Settings, add a 1-minute length and make it the Default session. Turn Sound on. Set the shortcut to lid-open.
   - Press ⇧⌘A. At about 0:50, Ctrl-click the icon and keep the menu open until about 1:03, then choose `Stop session`.
   - Expected: exactly one `Awake finished` ("The timed session finished.") with Tink. The icon is regular, and the tooltip reads `Awake has been off for less than a minute`. No second `Awake finished` in the next 30 s.
   - If `Awake finished` appeared while the menu was still open, a poll came first. Try again.
   - 2.4.0, in the same steps, posts nothing.
5. **The end just before added time.** As 4, but choose `Add 1 hour` at about 1:03. Expected: `Awake finished`, then `Awake started` ("…for 1 hour"), and `awake --status-json` shows a new `session_token` and `duration_seconds` 3600.
5a. **4 and 5, lid-closed.** As 4 and 5, with the shortcut set to lid-closed and password-free mode on. Expected: as there, with `Awake finished` reading "The timed session finished and normal sleep settings were restored.", and for 5 a new lid-closed session (`"session_backend":"awake"`) with no password dialog. This reads the helper's `last` record, which root writes, with the builtin reader (H1d); the dry run writes it as the user.
6. **faster-start-stop.md's QA 8a, 12a, 9 and 27 again.**
   - Added time while a lid-closed session ends behind its password dialog, cancelled: posted once as the dialog closes.
   - The same, but enter the password after the session has ended instead of cancelling (H3h): `Awake finished` (or the title for how it ended), then `Awake started` ("…for 1 hour"). The new session may ask for the password once more. `awake --status-json` shows a new `session_token`. A `Stop session` then posts `Awake stopped`, which shows that the app took the new session as its own. 2.4.0 posts only `Awake extended`, and nothing for that stop.
   - `Stop Awake and quit` with the dialog cancelled: the app stays and posts `Quit cancelled`.
   - A start refused for the battery: `Awake failed` with the CLI's sentence.
   - A cancelled lid-closed password dialog: nothing posted.
7. **Mixed versions.**
   - Save the new CLI. Run `cp ~/awake-qa/awake-2.4.0/bin/awake "$HOME/Library/Application Support/Awake/bin/awake"` and relaunch the app.
   - Expected: ⇧⌘A starts with `Awake started` and stops with `Awake stopped`.
   - With `awake --backend caffeinate --duration 10m` just started in Terminal, press ⇧⌘A within 5 s, while the icon is still regular: `Awake is already on`. The app reads the status itself after the 2.4.0 CLI refuses `--if-off` (H3f). Then `awake --stop`.
   - Restore the new CLI. Then, with a 2.4.0 app and the new CLI: start, stop and already on.
8. **Temporary files.** After the above, `ls "$TMPDIR" | grep -c awake-statusbar` prints `0`.
9. **`--if-off` in Terminal.**
   - With `awake --backend caffeinate --duration 10m` running: `awake --start --if-off --backend caffeinate --duration 1h; echo $?` prints `0`, and `awake --status` still shows about 10 minutes.
   - After `awake --stop`: `awake --start --if-off --backend caffeinate --duration 1m` starts.
   - `awake --if-off --stop; echo $?` prints the message and `1`.
   - `awake --help | grep -c -- --if-off` prints `0`.
10. **Lid-closed, password-free on.** ⇧⌘A start and stop post `Awake started` and `Awake stopped` once each, and the icon behaves as in faster-start-stop.md's QA 4.

### H.7 Docs

- **README.md:600** (one line) ends: "…and that a start, added time, or stop run the way the menu bar app runs it writes the same status as `--status-json` for the state it leaves, and, before it changes anything, for the state it found,".
- **README.md:241:** no change. It already says that a press adds no time to a session started elsewhere and that the app says `Awake is already on`. The CLI now decides that under its lock.
- **`--help`, README options:** no change. `--if-off` and `AWAKE_STATUS_BEFORE_JSON_FILE` are internal, like `AWAKE_STATUS_JSON_FILE` (C10) (question H-2, which answers 6.10's question 4).
- **faster-start-stop.md:** in 6.1, H's row points to this section, with "about 0.17 to 0.23 s per app start or stop (the status runs of 7.3's dev sitting)". 6.5 points here. 6.10's questions 3 and 4 point to questions H-1 and H-2.
- **CHANGELOG**, in the `[Unreleased]` after 2.4.0 (each line within 79 columns; the longest is 75):
  ```
  ### Changed

  - Starting, stopping and adding time from the menu bar app or with the
    keyboard shortcut is quicker again: `awake` also writes for the app the
    state it found before it changed anything, so the app no longer runs
    `awake --status-json` before each of them either. Installing the helper
    and turning password-free mode on or off from the app skip that run too.

  ### Fixed

  - If a session from the menu bar app ended on its own in the seconds before
    you stopped it or added time to it from the app, its end was not
    announced (`Awake finished`, for example).
  - The keyboard shortcut and `Start default session` could add time to a
    session started in Terminal a moment before, announce it as
    `Awake started`, and then treat it as the app's own. They now leave it
    alone and say `Awake is already on`.
  - Adding time from the menu bar app to a session that ended while its
    password dialog was open said `Awake extended`, although `awake` had
    started a new session. The app now announces the old session's end, then
    `Awake started`, and treats the new session as its own, so that its end
    is announced too.
  ```
- **No Upgrade note from H:** it changes no helper byte. 2.5.0's Upgrade note is G's, for the helper release.

### H.8 Gain

| What | Before H | With H | Basis |
|---|---|---|---|
| Lid-open start, app | 662 ms | about 495-500 ms (−25%) | Mac: measured action 492 ms plus the report, 2 to 10 ms (estimate; 1.3-2.0 ms Linux) (a lower bound until QA 1's `--no-status-runs` run) |
| Lid-open stop, app | 542 ms | about 320 ms (−41%) | Mac: 315 ms plus the report (a lower bound until QA 1's `--no-status-runs` run) |
| Lid-closed start, app | 714 ms | about 540 ms (−24%) | Mac: 535 ms plus the report (a lower bound until QA 1's `--no-status-runs` run) |
| Lid-closed stop, app | 1,061 ms | about 855 ms (−20%), still spread 0.3 to 1.3 s by the helper's check (G) | Mac: 848 ms plus the report (a lower bound until QA 1's `--no-status-runs` run) |
| The same, Linux, measured (min/median/max per round) | 554/570/652, 417/447/484, 437/459/509, 410/870/1211 | 465/475/537, 267/271/317, 358/382/431, 317/740/1209 | A/B, 12 rounds, versions alternated every round; median saved 94, 176, 78, 130 ms |
| `Add 1 hour` | a status run with a session on first | none | Mac: about 210-230 ms saved (estimate, the stops' measured status run in the same state) |
| `Install helper…`, password-free on or off | an idle status run first | none | about 160-180 ms (estimate, the starts' status run), behind a password dialog anyway |
| ⇧⌘A while a session started elsewhere is on (rare) | the status run only | one CLI run that exits at `--if-off`, with C's report | Linux: 132 → 173 ms (lid-open session), 141 → 188 ms (lid-closed): 41 to 47 ms slower; Mac estimate 50 to 100 ms slower |
| ⇧⌘A with an older CLI (mixed versions) | | plus one refused run | 31-36 ms (Linux); Mac estimate 50-100 ms |
| Terminal commands | | unchanged | `--status`/`--status-json` 3 to 6 ms quicker (Linux medians 95→89, 91→88, 161→157, 154→148 ms), from H1e |
| The found report itself | | 1.3-2.0 ms; 15 ms for a session tied to a process | Linux, in-process, 40 calls each |

The Mac rows time the 2.4.0 action right after a status run (7.3's script); the app with H runs it after an idle gap (H4b). With I2 and I1, which phase 2 also holds, the app waits for about 495, 300 to 320, 500 to 525 and 830 to 850 ms (estimates, and lower bounds in the same way; cross-cutting: Expected gains).

### H.9 Risks, rollback and order

- **Drift between the found report and `--status-json`.** Someone may change `print_status_json` or `last_session_record_file` without the new printer. The sourced check (7 states), 5d and its both-records part fail. The comments of both functions name the new one.
- **The JSON escaping.** H1e moves the escaping every `--status-json` string goes through. A slip would make `--status-json` invalid for a process name with a quote or a backslash, and the app would post `Awake returned an invalid status response` on every poll. 3a checks it on every CI run, under `/bin/bash` 3.2.
- **The result logic.** The rewrite of `handleCommandResult` keeps the old order, adds one rule (H3h), and the 550 checks pin it. The mistake to watch for is the source of `before`: shown versus found. Check rows and QA 3 to 6 cover it.
- **The replaced rule** rests on added time keeping a session's token. It does in both modes (dry run), and 5d pins it: the stop after added time finds the session's first token. If a later change gave added time a new token, every `Add 1 hour` would post a stray end and `Awake started`.
- **The found-or-read rule** rests on a new CLI changing nothing before it writes the found report (H1b): every exit without one and with a status other than 0 comes before any change to a session (the exit table). With an older CLI, a failure that ended the session also posts that end (H.4).
- **The Mac after an idle gap.** H.8's Mac figures time the action right after a status run. On the Mac, steps right after another run took 29 to 34% less in one later sitting (7.3, J1). In the emulation the order made no difference (H4b). QA 1's `--no-status-runs` run settles it; until then H.8's Mac figures are lower bounds.
- **The older-CLI fallback** depends on the exact first line, `Unknown option: --if-off`. If a future change altered that line, an older CLI's refusal would show as `Awake failed: Unknown option: --if-off …`. That is visible, not silent.
- **"Already on" is about 40 ms slower** (Linux): rare, and accepted. The app needs C's full report to show the session.
- **The menu-tracking timing in QA 4** is not relied on. The test only expects exactly one `Awake finished`.
- **Known, not changed by H.** A click start meets a session started elsewhere since the last poll only while the icon shows off. If its add-time list is answered and the password dialog after it outlives that session, the CLI starts a new one (6343), and the app says `Awake is already on` and does not take it as its own, as today. H3h covers only `Add 1 hour`, whose intent says that time was added.
- **Not verified here:** Bash 3.2 (CI), the Swift compile (CI), notification delivery and sounds (QA), Mac costs of the report and of an action after an idle gap (QA 1), the found-or-read path on a Mac (check rows only).
- **Rollback.**
  - Revert the app commit alone: the app reads the status first again. The CLI's additions are inert without the variable and the option, and an old app with the new CLI is the H.4 case.
  - Revert both commits to remove everything. No file format or state changes, nothing to migrate.
- **Order.**
  - Phase 2 (cross-cutting: Order and release): after I2, before I1. I2 first, because both change main's state block (6790-6801) and H passes the `pmset` variables as I2 leaves them (H.3, item 6). I1 changes `run_helper`, after the found report, and does not meet H.
  - Two commits: (1) `bin/awake`, the self-test, the timing script, ci.yml's timing step and README.md:600; (2) the Swift files, the check and its ci.yml step. Either order is safe because of H3f. The CHANGELOG bullets of H.7 go where the plan's CHANGELOG rule puts them (cross-cutting: CHANGELOG and Upgrade notes).
  - After A and C (done).
  - Before F: F can reuse `json_string_or_null_into` and the builtin reader, and must keep `read_state_value_into`'s results, which the sourced check guards.
  - Independent of G, I3, D, E and J1.

## 7. I: less duplicate work on lid-closed starts (and the pmset reads)

Three changes. **I1** drops the `sudo -n helper check` that runs before every password-free helper run. **I2** reads the sleep settings with `pmset` only when no session runs. Both change `bin/awake` only and ship in **phase 2** (I2, then H, then I1), with no helper change and no password prompt at the update. **I3** lets the helper skip the battery and thermal reads that `awake` has just made (new helper commands `start-checked` and `extend-checked`, helper protocol 10). I3 is **conditional**: it goes into 2.5.0's helper release (phase 3) only if the Mac preflight finds that the two programs it removes, the helper's root `osascript` and its `pmset -g batt`, cost 100 ms or more per lid-closed start together (QA I-2 and I-3, question I-1). At the estimate from 7.3 (35 to 90 ms, I.1) it stays out, and 2.5.0 keeps protocol 9. I3's full specification stays here for that decision. **I3d**, a fix to the wait after a lid-closed start, is CLI only and also fixes a 30 s wait that exists today (question I-4). Bare line numbers are `bin/awake` at `32094d1`.

### I.1 Today

**A lid-closed start from the app in password-free mode** (⇧⌘A with the shortcut set to lid-closed: `--gui --start --duration-seconds N --backend awake --min-battery 5 --thermal-guard on --unplug-guard off --keep-display on`, built by `startArguments`, AwakeCLI.swift:443-470, with `AWAKE_APP_THERMAL_STATE` set at AwakeCLI.swift:629):

1. `main` reads the sleep settings at 6790-6797: `get_battery_setting sleep` (2089-2123: `pmset -g custom | awk`, and `pmset -g | awk` when the Battery Power section has no `sleep`) and `get_battery_setting disablesleep` (`pmset -g`, then `printf | awk`, 2079-2087). Two `pmset`, two `awk`, four subshells.
2. The start checks: the battery at 7133-7141 (`battery_percent_on_battery`, 2158-2172: one `pmset -g batt`), the thermal state at 7142-7150 (`foreground_thermal_state`, 2210-2219: the app's value, no program, since D).
3. `run_helper` (3790-3836): `helper_is_ready` (3614-3630: three `path_is_admin_only` checks of two `stat` runs each, and a builtin read of the version line), then **`sudo -n HELPER check`** at 3826, a `sudo` plus a bash that reads the 1,476-line helper and exits, then `sudo -n HELPER start …` at 3827.
4. The helper's `cmd_start` (awake-helper:842-981) checks **the battery again** (awake-helper:903, `pmset -g batt`) and **the thermal state again** (awake-helper:906, `thermal_state` at awake-helper:548-559: a root `osascript -l JavaScript` under `run_with_timeout`, awake-helper:522-543, which also forks a watcher subshell with a `sleep 10` and kills it). Then the lock, `date`, `pmset -g custom` and `pmset -g` for the settings to restore, two `pmset -b` writes and two spawns.
5. The timer's first pass (`cmd_run_timer`, awake-helper:1218-1336) checks **both a third time** at once: `next_battery_check=0` and `next_thermal_check=0` (awake-helper:1229-1230) make the checks at awake-helper:1291 and :1308 run on the first pass, another `pmset -g batt` and another root `osascript`. This runs after the helper has exited, off the command's critical path.
6. `wait_for_helper_session_start` (3902-3915) finds the session on its first check (the helper records the timer before it exits: 30 of 30 in J1's emulation runs), and C's report is written at exit.

So the battery is read three times and the thermal state three times, two of them as root with `osascript`, and `sudo` runs twice. A lid-closed start **from Terminal** in password-free mode runs `sudo` three times: 7151-7153 calls `helper_runs_without_password` (3713-3715, one more `sudo -n HELPER check`) before the builtin terminal test, and `foreground_thermal_state` runs its own `osascript` (no app value). **Added time** on a lid-closed session repeats the pattern: `helper_extend_guard_message` (6272-6288) reads the battery and the thermal state, then `run_helper … extend` (6331-6332) runs the check and `extend`, and `cmd_extend` reads both again under its lock (awake-helper:1059-1066, a root `osascript` again).

**The pmset read while a session runs.** 6790-6797 run on every state-changing run. The two values (`pmset_read_ok`, `pmset_session_active`) are used at 6798-6801 (leftover settings: only when `helper_state` is `stale`, or `none` with the settings on), 6805-6811 (needs no session running), 6980 (with a helper session `running` the condition is true without them), 7126 and 7182 (starts only). With a lid-open session running, `main` stops it (6955-6976) or adds time (6828-6953); with a helper session running it stops it (6980-7019) or adds time. None of these uses the values. The one exception is the path where the session ends just as time is added (`extend_rc` 3, 6936-6952): it goes on to a start, which needs them (7126 for lid-closed, 7182 for lid-open). So every stop and every added time runs two `pmset` and two `awk` for nothing before it acts. `print_current_status` (3159-3228) already reads them only when no session runs (3206-3207, C6).

**What `sudo -n -l HELPER` says** (6.6 proposed it as the tiebreak; checked here, not used). From sudo(8) and sudoers(5) of sudo 1.9.15p5, and run with real `sudo` 1.9.15p5 on Linux as an unprivileged user, in a private mount namespace, against eight sudoers layouts (A to H below): with `-l` and a command, the exit status is 0 when the command is *permitted*, password or not (sudo(8), EXIT VALUE), and `-l` itself needs a password unless one of the user's entries has `NOPASSWD` (`listpw=any`, the default).

| Layout | `sudo -n -l HELPER` | `sudo -n HELPER check` |
|---|---|---|
| A: `user ALL = (root) NOPASSWD: HELPER` (Awake's rule, 4331) | prints HELPER, 0 | 0 |
| B: `%admin ALL = (ALL) ALL` only, no cached credentials | `sudo: a password is required`, 1 | same, 1 |
| C: no rule | `sudo: a password is required`, 1 | same, 1 |
| D: `%admin ALL = (ALL) ALL`, then Awake's rule (macOS: `/etc/sudoers` includes `sudoers.d` at its end) | HELPER, 0 | 0 |
| E: `%admin ALL = (ALL) ALL` plus a `NOPASSWD` rule for another command | HELPER, 0 | **1, a password is required** |
| F: Awake's rule with `Defaults listpw=always` | **a password is required, 1** | 0 |
| G: `user ALL = (root) HELPER` (no `NOPASSWD`) | a password is required, 1 | same, 1 |
| H: Awake's rule, then `%admin ALL = (ALL) ALL` (the last match wins, sudoers(5)) | HELPER, 0 | **1** |

`-l` answers "may this user run it at all", not "without a password". Used as the tiebreak after a failed run, it would report sudo's refusal as a helper failure in E and H (a false refusal: no password dialog where today there is one), and in F it would ask for the password after the helper had already run and failed (an unexpected dialog, and a second run). `sudo -n HELPER check` makes exactly the decision the real call makes, as the rule names the helper without arguments, which allows any (4331). A new exit code would not do either: the helper exits 1 itself (`fail`'s default, awake-helper:150-153, and `set -e` exits), and sudo exits 1 for all its own failures (sudo(8)). macOS's sudo is not the Linux build: QA I-1 records its version and repeats B, A and D; the design only relies on what today's code already relies on (`sudo -n` never asks; `sudo -n HELPER check` passes only when sudo would run the helper).

**What it costs.** Mac, measured (dev, Mac14,2, 7.3): the lid-closed start's run is 535 ms (the lid-open start's 492); the app waits 714 ms for it with C. The lid-closed stop's run is 848 ms (314 to 1268), set by the helper's once-a-second check (G), and the lid-open stop's 315. Mac, estimated:

- one `sudo -n HELPER check`: 15 to 40 ms. On Linux it took 10 and 13 ms (medians of 30, two runs), against 5 and 8 ms for the helper's `check` run directly and 4 and 5 ms for `sudo -n true`. The emulation runs a whole status read at about the Mac's speed (105 ms idle against the Mac's 123 to 130, 186 ms with a lid-open session against 172), but macOS's `sudo` also asks opendirectoryd for the user's groups and logs each run, so the range is wide. 7.3's two starts cannot isolate `sudo`: the lid-open start launches the worker bash and waits for it, which the lid-closed start does not. A budget of the 535 ms run gives a rough cross-check (estimate). `awake`'s own work before the helper is at least an idle status read (171 to 178 ms, with the pmset pair) plus the lock and `pmset -g batt`: about 190 ms. C's report is about 138 ms (next bullet). The helper's start work (`osascript` about 45 ms, five `pmset`, about 15 small programs for three atomic writes, the lock and two spawns), `helper_is_ready`'s seven programs and the first wait check come to roughly 160 ms. That leaves about 45 ms (535 − 190 − 138 − 160) for two `sudo` runs, each starting the helper's bash: about 20 to 25 ms per call, the low end of the range. QA I-2 measures it.
- the helper's root `osascript` with the JavaScript bridge: 30 to 75 ms with its watcher's fork (estimate from 7.3; the program itself 25 to 65 ms, below), so 35 to 90 ms with `pmset -g batt`. 2.3.0's lid-closed start (441 ms) ran the CLI's own `osascript`. Dev's (535 ms) does not, as the timing script passes the thermal state (tools/measure-latency.sh:107-145) and D uses it, but dev writes C's report in the same process. In the emulation that report costs 83% of a whole status run (117 against 141 ms, medians of 15, a lid-closed session running), so on the Mac about 0.83 × 166 ≈ 138 ms. The `osascript` was then about 138 − 94 ≈ 45 ms; allowing for the medians' noise, 25 to 65 ms. The first sitting (715 → 834 ms) gives less still. The helper's read also forks `run_with_timeout`'s watcher. Plus `pmset -g batt` (5 to 15 ms). The plan's 0.1 to 0.4 s (faster-start-stop.md:77) was a guess made before any Mac timing. QA I-2 and I-3 measure both, and I3's gate rests on them.
- the pmset pair (I2): 0 to 20 ms. When C6 took the same pair out of the status read, the status after a start dropped from 191 to 172 ms (lid-open) and 186 to 166 ms (lid-closed) between 2.3.0 and dev in one sitting; the status before a stop moved by −2 and +6 ms.

Linux, measured in the emulation (dry run, uid 1094, 14 rounds, HEAD and the prototype alternating every round, min / median / max in ms):

| Step | HEAD | Prototype |
|---|---|---|
| lid-closed start | 394 / 436 / 473 | 415 / 428 / 490 |
| lid-closed add time | 358 / 400 / 441 | 387 / 399 / 423 |
| lid-closed stop | 344 / 748 / 1278 | 379 / 833 / 1261 |
| lid-open start | 553 / 571 / 608 | 498 / 576 / 624 |
| lid-open add time | 386 / 417 / 463 | 385 / 405 / 443 |
| lid-open stop | 294 / 306 / 351 | 290 / 300 / 309 |

The dry run cannot show I1 or I3: `run_helper` runs the helper without `sudo` (3803-3811), and the dry-run helper reads mock files with builtins. Counted with `strace -f -e execve`, a stop or added time runs 1 or 2 programs fewer (the mock reads; 71 → 69 for a lid-open stop, 112 → 110 for lid-open added time); in real mode it is two `pmset` and two `awk`. The lid-closed stop's spread is the helper's 1 s check. Timing a lid-closed start in real mode needs a Mac (QA I-2, I-3, I-11).

### I.2 Decisions

**Phase 2: I1 and I2** (CLI only, no helper change).

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| I1a | How `run_helper` tells sudo's refusal from the helper's own failure | In password-free mode, run `sudo -n HELPER ARGS` first. On exit 0 it is done. On any other status, run `sudo -n HELPER check`: if it passes, sudo ran the helper, so the status and the error output are the helper's; if it fails, sudo refused, its message is dropped, and the password is asked for, as today when the check fails. A dialog therefore only ever follows a refused check, as today, and a failure is reported as the helper's only after sudo has shown it runs the helper. Checked against real sudo in layouts A to H (I.5). | `sudo -n -l HELPER` (wrong in E, F and H, I.1). A new helper exit code (the helper and sudo both exit 1). Matching sudo's message (`a password is required` is translated with `LANG`). |
| I1b | When it applies | Only while the rule file exists (`passwordless_is_configured`, 3632-3634). Otherwise the check still comes first: without the rule a direct run is almost always refused, and would add a refused `sudo` before every password dialog to save one call in the rare case of a valid sudo ticket. | Running directly in every mode. |
| I1c | Which statuses get the check | Every non-zero one. Only 1 is ambiguous (sudo(8): sudo's own failures are 1; a helper killed by a signal comes back as 128+n), but checking every failure keeps the fallback right on a sudo that behaves otherwise, and costs one `sudo` only when the helper fails. | Only status 1. |
| I1d | The helper's output | Standard output passes through; standard error is held in a variable and printed after the check, only if the helper ran. The command substitution cannot hang today: nothing the helper leaves running keeps its standard error open (`spawn`, awake-helper:830-840, `run_with_timeout`'s watcher, awake-helper:531-537). 12f pins this: the helper's `start`, with standard error captured the same way, returns within 3 s while its session runs. As well, the dry-run branch of `run_helper` (3803-3811) captures the same way, so that every dry-run lid-closed start in the self-test goes through the capture with the helper's real `spawn`. | A temporary file (one more file in the runtime folder). |
| I1e | The Terminal pre-check at 7151-7153 | `terminal_can_authenticate` (a builtin `/dev/tty` test with a terminal) before `helper_runs_without_password` (a `sudo` and a helper run). Both are tests without side effects joined by `&&`, so the order changes only the cost. | Leaving it: one more `sudo` per Terminal start. |
| I1f | Testability | `sudo -n` moves into `sudo_without_password`, so the self-test can stand in for sudo. | Calling `/usr/bin/sudo` in place, untestable on CI. |
| I2a | When `main` reads the settings | Only when no lid-open session of this account runs and no helper session of any account runs, the only cases that use them (I.1), and once more on the "ended just as time was added" path, before the start it leads to. Skipped, the values keep their defaults (`true`, `false`), which no skipped path reads. | Reading them always (two `pmset` and two `awk` per stop and added time). |
| I2b | How | A function, `read_sleep_settings_for_main`, that sets `main`'s two locals (bash's dynamic scope), called from both places. `main`'s `current_sleep` and `current_disablesleep` go; H's "before" report uses `pmset_session_active` (H.3, item 6). | Copying the block. Passing names to `printf -v` (more code for two fixed names). |

**I3d** (CLI only; with I3, or in phase 2 after I1, question I-4).

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| I3d | A session the timer ends before `awake` sees it | `wait_for_helper_session_start` returns 2 at once when the session record is gone (the helper writes it before it exits, so the session has ended). `main` reports the reason from the helper's `last` if that record is this account's and completed no earlier than the start (`completed_at >= helper_started_at`); otherwise a generic message. A `stale` record still waits, as today. Today the wait goes on for 30 s and reports `Failed to start the awake session.` (a watched process that exits as the session starts hits this now). No helper change, so it does not depend on I3; I3 makes such an end likelier. | Waiting as today. |

**I3: conditional, gated on the Mac preflight (question I-1).** The preflight (QA I-1 to I-3 (a), about 15 minutes with G's facts, on the installed 2.4.0, no Awake build, before I1's commit and before G1) times the two programs I3 removes from each lid-closed start: the helper's root `osascript` and its `pmset -g batt`. **I3 goes into 2.5.0 only if the two together cost 100 ms or more per lid-closed start** (QA I-3 (a), with I-2 as the cross-check). At 7.3's estimate (35 to 90 ms) it stays out, and so do protocol 10, the forced dialog for CLI-only installs, the reinstall loop between mixed manual copies, and the timing script's guard (I3f). If it goes in, it is the last helper commit of phase 3, after G1 and F8.

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| I3a | Whether the helper may skip its start-time checks | Yes, through a new command, `start-checked`, with `start`'s arguments in full (no defaults for the guardrails). It does not refuse for the battery or the thermal state; the session record keeps both guardrails; the timer checks both on its first pass (awake-helper:1229-1230). No new right: `start UID END 0 off` already starts a session with neither cut-off at all (question I-1). Keeping the three reads is not rejected: it is what happens when the gate is not met (question I-1, options a and d). | Passing `--min-battery 0` and `--thermal-guard off` to `start`: it stores them as the session's guardrails (`write_session_file`, awake-helper:712-741), so the session would run without them for its whole length, and no command turns them back on (`extend` changes only the end). Dropping the start-time checks from `start` and `extend` themselves (question I-1, option c): the same gain, no new command and no bump. As G1 and F8 need no bump either, the helper release would need none: no protocol-10 Upgrade note, no dialog for CLI-only installs, no reinstall loop between mixed copies, no I3f. Its cost: after a password dialog or the CLI's picker, a Mac that turned critical (or a battery that ran down) meanwhile gets a session of a fraction of a second that ends as `overheated` or `low_battery` and clears a `SleepDisabled` 1 set before it (awake-helper:791-799), instead of a refusal. A 2.4.0 or older `awake` that meets such an end before its first check also waits 30 s (I3d). Not recommended, because it turns D's backstop (6.7 "Keep") from a refusal into an immediate end where the app's value can be 30 s old. Overlapping the helper's thermal read with its other work (start `osascript` in the background at the top of `cmd_start`, wait for it before `apply_settings`): no bump, but it saves at most the time of the work it overlaps (the lock, `date` and the two `pmset` reads, roughly 20 to 50 ms on the Mac, estimate), and it adds a background process to root code, which every `fail` path after it must wait for or kill. |
| I3b | When `awake` uses `start-checked` | Only after a fresh thermal reading: the thermal guard is off, or the reading came from this run's own `osascript`, or from Awake.app at most a second or two before (`app_thermal_state_is_current`: `SECONDS - APP_THERMAL_STATE_SECONDS` from 0 to 1; `SECONDS` counts whole seconds). After the CLI's picker the app's value is up to 30 s old (D4), so the helper still checks. A failed reading (empty `thermal`) also keeps the plain `start`. The battery is read afresh in every case. A `pmset -g batt` that fails on battery power counts as AC power for `awake`'s check, as today; `start-checked` then leaves the battery to the timer's first pass, which reads it again a moment later (`awake` cannot tell a failed read from AC power). `run_helper` turns `start-checked` into `start` whenever it asks for a password; in custom password mode, `run_as_admin`'s gui-custom path (3754-3763) runs the plain `start` even when Awake.app supplied the password without a dialog (question I-2). | `start-checked` whenever no password is asked (a picker start would then rely on the timer alone). |
| I3c | Added time | `extend-checked UID END`, the same idea: `cmd_extend` skips awake-helper:1059-1066. `awake` uses it when the session's thermal guard is off or Awake.app's state is at most a second or two old; from Terminal, where it cannot tell whether its own `osascript` read worked, it keeps `extend`. The timer goes on with its checks every 30 s (thermal) and 60 s (battery; 20 s at 15% or less) (question I-3). | Start only. |
| I3e | Protocol | 10 in both files, in I3's commit. A new `awake` must never send `start-checked` to helper 9, which exits 64 (`usage`); with the bump, `helper_is_ready` sees helper 9 as out of date and `run_helper` installs 10 first under the one dialog (3812-3825), running a plain `start`. G1 and F8 need no bump (G1i, F8a), so without I3, 2.5.0 keeps protocol 9; with I3, its protocol 10 covers them. | Accepting 9 and 10 (`helper_is_ready` wants an exact match, and a range would need rules for what each version supports). A capability line in the helper (`readonly HELPER_FEATURES="start-checked extend-checked"`), read by `helper_version_of`'s builtin scan (3594-3608): it would avoid the bump, but it adds a second compatibility rule next to the exact protocol match. No new command at all: I3a, question I-1, option c. |
| I3f | The timing script | Only with the bump. `--lid-closed` also requires that the timed `awake` expects the installed helper's protocol; otherwise it skips the lid-closed rows with a message. After the bump, an older `awake` timed with `--cli` would otherwise install its own helper 9 behind a password dialog. | Leaving it (7.1 step 5's method would downgrade the helper). |

**Order.**

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| I4 | Order | Phase 2: I2, then H, then I1, each on its own commit, CLI only, no password prompt at the update. I1 after the preflight's sudo facts (QA I-1). I3d after I1, if question I-4 says so. Phase 3, the helper release: G1, then F8, then I3 if it passes its gate, with the bump and I3f in I3's commit, so that every helper change reaches users under one prompt. | I3 in a release of its own (a second dialog after G1's and F8's). I1 in the helper release, as faster-start-stop.md 6.9 had it: it needs no helper change. |

**The safety cut-offs at start, before and after I3** (only with I3):

| Start | Today (`32094d1`) | With I3 |
|---|---|---|
| Battery, any start | `awake` (fresh `pmset -g batt`), helper, timer's first pass | `awake` (fresh), timer's first pass (estimate: within about 0.05 s of the timer starting) |
| Thermal, ⇧⌘A or a menu start (app's value, milliseconds old) | `awake` (app's value), helper (root `osascript`), timer's first pass | `awake` (app's value), timer's first pass (estimate: 0.05 to 0.15 s after the settings change: the timer's bash start, `pmset -g batt` and `osascript`) |
| Thermal, after the CLI's picker (app's value up to 30 s old) | `awake`, helper, timer | unchanged: plain `start` |
| Thermal, from Terminal | `awake` (own `osascript`), helper, timer | `awake` (own `osascript`), timer |
| Any start after a password dialog, and any start in custom password mode without password-free mode | `awake` (before the dialog), helper, timer | unchanged: plain `start` |
| Added time, app, fresh value | `awake`, helper `extend` | `awake`; the timer's regular checks go on |

D's backstop (6.7 "Keep", 11) changes accordingly, only with I3: the helper's start check stays wherever the app's value can be stale; where it is dropped, the timer's immediate first check (awake-helper:1230) is the backstop. A session cannot outlive that first check.

### I.3 Code changes

**Phase 2, I2's commit (`bin/awake`):**

1. **Before `run_maintenance_action` (6520)** (I2b):
   ```bash
   # Sets main's pmset_read_ok (false when the battery sleep settings cannot be
   # read) and pmset_session_active (true when they keep the Mac awake with the
   # lid closed). Bash hands a function's local variables down to the functions
   # it calls, and this one sets main's.
   read_sleep_settings_for_main() {
       local current_sleep=""
       local current_disablesleep=""

       pmset_read_ok=true
       pmset_session_active=false
       if current_sleep=$(get_battery_setting sleep) &&
           current_disablesleep=$(get_battery_setting disablesleep); then
           if keep_awake_is_enabled "$current_sleep" "$current_disablesleep"; then
               pmset_session_active=true
           fi
       else
           pmset_read_ok=false
       fi
   }
   ```
2. **`main`:**
   - locals: 6550-6551 (`current_sleep`, `current_disablesleep`) go.
   - **6790-6797** (I2a) become:
     ```bash
         # The sleep settings count only while no session runs, as in
         # print_current_status: no lid-open one of this account and no lid-closed
         # one of any account. A running one is stopped, given more time, or left
         # alone (a refusal, or a lid-open start next to another account's
         # lid-closed one); none of these reads them, and both values keep their
         # defaults then. A session that ends just as time is added reads them
         # below, before the start that follows.
         if [[ "$caffeinate_session_active" != "true" && "$helper_state" != "running" ]]; then
             read_sleep_settings_for_main
         fi
     ```
   - **After 6952** (the `rm -f -- "$STATE_FILE"` block of the `extend_rc` 3 path): `read_sleep_settings_for_main`, commented "Not read above while the session ran: a lid-closed start needs them read, and a lid-open one restores settings left behind first." `LEFTOVER_SETTINGS_PRESENT` (6798-6801) is not recomputed there, as today; only `prompt_start_terminal` (4457) reads it, and this path has `END_CONDITION_GIVEN=true` (6944), so it never shows that prompt.

**Phase 2, I1's commit (`bin/awake`):**

1. **After `print_no_terminal_for_password` (3708-3711)**, and `helper_runs_without_password` (3713-3715) uses it (I1f):
   ```bash
   # Runs a command as root through sudo without asking for a password: when
   # sudo would ask, it exits 1 at once and runs nothing. A function of its own,
   # so that the self-test can stand in for sudo.
   sudo_without_password() {
       /usr/bin/sudo -n "$@"
   }
   ```
2. **`run_helper` (3790-3836)** (I1a to I1d). A local `helper_error=""`. The comment above the function adds: "In password-free mode it runs the helper at once, and asks sudo whether it runs the helper only after a failure." The dry-run branch (3803-3811) becomes:
   ```bash
       if dry_run_enabled; then
           # Its error output is held back as in password-free mode below, so
           # that every dry-run start shows that nothing the helper leaves
           # running keeps it open.
           { helper_error=$("$helper" --dry-run "$@" 2>&1 1>&3 3>&-); } 3>&1 || rc=$?
           if [[ -n "$helper_error" ]]; then
               printf '%s\n' "$helper_error" >&2
           fi
           HELPER_LAST_RC=$rc
           if (( rc != 0 )); then
               return 1
           fi
           ADMIN_LAST_RESULT="ok"
           return 0
       fi
   ```
   and 3826-3833 become:
   ```bash
       if passwordless_is_configured; then
           # Password-free mode: the helper runs at once, with no check first.
           # sudo -n never asks for a password. When its rule does not apply,
           # sudo exits 1 without running the helper, and the helper can exit 1
           # too, so its error output waits until a check has told the two
           # apart: the check passes only if sudo runs the helper.
           { helper_error=$(sudo_without_password "$helper" "$@" 2>&1 1>&3 3>&-); } 3>&1 || rc=$?
           log_debug "run_helper passwordless command=${1:-} rc=$rc"
           if (( rc == 0 )) || sudo_without_password "$helper" check >/dev/null 2>&1; then
               if [[ -n "$helper_error" ]]; then
                   printf '%s\n' "$helper_error" >&2
               fi
               HELPER_LAST_RC=$rc
               if (( rc != 0 )); then
                   return 1
               fi
               ADMIN_LAST_RESULT="ok"
               return 0
           fi
           # sudo refused, and its message is dropped: the password is asked
           # for below, as without password-free mode.
           log_debug "run_helper passwordless_refused rc=$rc"
       elif sudo_without_password "$helper" check >/dev/null 2>&1; then
           # A sudo ticket that is still valid: no password either.
           sudo_without_password "$helper" "$@" || rc=$?
           … (3828-3833 as today)
       fi
       run_as_admin "$transport" "Awake needs your password to change the sleep settings." "$helper" "$@"
   ```
   The debug line is I1's mechanism line for the timing rules (one `sudo` run per helper call, and a `passwordless_refused` only when sudo refused).
3. **7151-7153** (I1e): `! dry_run_enabled && ! terminal_can_authenticate && ! helper_runs_without_password`, with the comment "The terminal test comes first: with a terminal it runs no program, where the other runs sudo and the helper."

**I3d's commit (`bin/awake`; question I-4):**

1. **`wait_for_helper_session_start` (3902-3915):** a comment ("Returns 2 at once when its record is gone: the helper writes it before it exits, so the session has already ended, as its timer can end it on its first pass"), a local `state`, and in the loop:
   ```bash
           state=$(helper_session_state)
           if [[ "$state" == "running" ]]; then
               return 0
           fi
           if [[ "$state" == "none" ]]; then
               log_debug "wait_for_helper_session_start ended_already checks=$waited"
               return 2
           fi
   ```
   `stale` (a record whose processes are gone) still waits, as today.
2. **`main`:** after 6546 add the locals `helper_started_at=""`, `helper_last_reason=""`, `helper_last_completed_at=""`. At 7232, `helper_started_at=$(current_epoch)` before `run_helper` (7234). **7278-7281** become:
   ```bash
           start_rc=0
           wait_for_helper_session_start || start_rc=$?
           if [[ "$start_rc" == "2" ]]; then
               # The timer ended it on its first pass. Its record of the end is
               # this session's if it is this account's and no older than the
               # start.
               helper_last_reason=""
               helper_last_completed_at=$(read_state_value completed_at "$HELPER_LAST_FILE" 2>/dev/null || true)
               if [[ "$(read_state_value uid "$HELPER_LAST_FILE" 2>/dev/null || true)" == "$(/usr/bin/id -u)" ]] &&
                   [[ "$helper_last_completed_at" =~ ^[1-9][0-9]{0,11}$ ]] && (( helper_last_completed_at >= helper_started_at )); then
                   helper_last_reason=$(read_state_value reason "$HELPER_LAST_FILE" 2>/dev/null || true)
               fi
               case "$helper_last_reason" in
                   low_battery) message="The battery is too low for a lid-closed session. Connect the charger first." ;;
                   overheated) message="The Mac is overheating, too hot for a lid-closed session. Let it cool down first." ;;
                   process_exited) message="${bound_label:-The process} has already exited." ;;
                   *) message="The awake session ended as soon as it started. Run awake --status-json to see why." ;;
               esac
               report_start_failure "$message" "$verbose"
               exit 1
           elif [[ "$start_rc" != "0" ]]; then
               report_start_failure "Failed to start the awake session." "$verbose"
               exit 1
           fi
   ```
   The completion time is read once and checked as a number without a leading zero before it reaches `(( ))`, so file text never runs as arithmetic.

**I3's commit, only if I3 passes its gate (phase 3, after G1 and F8).**

`bin/awake`:

1. **165:** `readonly HELPER_PROTOCOL_VERSION=10`.
2. **After `foreground_thermal_state` (2210-2219):**
   ```bash
   # True when Awake.app passed its thermal state at most a second or two ago,
   # as fresh as an osascript reading. SECONDS counts whole seconds.
   app_thermal_state_is_current() {
       local age=$((SECONDS - APP_THERMAL_STATE_SECONDS))

       [[ -n "$APP_THERMAL_STATE" ]] && (( age >= 0 && age <= 1 ))
   }
   ```
3. **7130-7132**, the comment above the start checks:
   ```bash
       # A session on a nearly empty battery would only drain it, and one on an
       # overheating Mac would keep it hot. Running sessions end at these levels
       # too. For lid-closed ones the helper checks again, or with start-checked
       # its timer does, at once.
   ```
4. **`run_helper`** (I3b). A local `prompt_arguments=()` (an empty `local` array, then the assignment: the idiom the script already uses, safe in bash 3.2). After `shift` (3798):
   ```bash
       # Never empty: every caller names a helper command.
       prompt_arguments=("$@")
       case "${1:-}" in
           start-checked) prompt_arguments[0]=start ;;
           extend-checked) prompt_arguments[0]=extend ;;
       esac
   ```
   The install command's loop (3820-3822) and the final `run_as_admin` (3835) use `"${prompt_arguments[@]}"`; the dry-run branch and both `sudo_without_password "$helper" "$@"` runs pass `"$@"` unchanged, so the dry run uses the new commands too. The comment above the function adds: "start-checked and extend-checked (the caller has just checked the battery and the thermal state) become a plain start or extend when a password is asked for first: the dialog can stay open for minutes, so the helper then checks both again itself."
5. **After `helper_extend_guard_message` (6272-6288)** (I3c), and 6332 runs `"$(helper_extend_command)"` in place of `extend`:
   ```bash
   # Prints extend-checked when helper_extend_guard_message has just checked the
   # running session's guardrails with fresh readings, so that the helper need
   # not check them again, or extend. The battery is read afresh; the thermal
   # state counts as fresh only as Awake.app's from at most a second or two ago,
   # or when the session's thermal guard is off. The timer goes on checking
   # both.
   helper_extend_command() {
       if [[ "$(read_state_value thermal_guard "$HELPER_SESSION_FILE" 2>/dev/null || true)" == "off" ]] ||
           app_thermal_state_is_current; then
           printf '%s' "extend-checked"
       else
           printf '%s' "extend"
       fi
   }
   ```
   The `HELPER_LAST_RC` 4 and 8 messages (6349-6357) stay for the plain `extend` after a dialog.
6. **`main`:** after 6546 add the local `helper_start_command=""`. **7226** (I3b) becomes:
   ```bash
           # The battery and the thermal state were checked just above, so the
           # helper need not check them again (start-checked), as long as the
           # thermal reading was fresh: this run's own osascript, or Awake.app's
           # state from at most a second or two ago, not from before a picker
           # was open. The helper's timer checks both again as soon as the
           # session runs, and run_helper makes this a plain start when a
           # password is asked for first.
           helper_start_command=start
           if [[ "$THERMAL_GUARD" != "on" ]] || { [[ -n "$thermal" ]] &&
               { [[ -z "$APP_THERMAL_STATE" ]] || app_thermal_state_is_current; }; }; then
               helper_start_command=start-checked
           fi
           log_debug "helper_start command=$helper_start_command thermal=${thermal:-unknown}"
           helper_start_arguments=("$helper_start_command" "$(/usr/bin/id -u)" "$(selected_end_token)" "$MIN_BATTERY_PERCENT" "$THERMAL_GUARD" "$UNPLUG_GUARD")
   ```
   `thermal` is `main`'s local set by the check at 7143; it stays empty when the thermal guard is off or the read failed. With an app value that is not current, the start stays plain even when `foreground_thermal_state` fell back to its own `osascript` (a value more than 30 s old): the test cannot tell that case apart, and errs towards the helper's check.

`bin/awake-helper` (prototype: 38 lines added, 10 removed):

1. **Header (after awake-helper:26 and :29):**
   ```bash
   #   start-checked UID END MIN_BATTERY THERMAL_GUARD UNPLUG_GUARD [WATCH_PID]
   #                               the same, for a caller that has just checked
   #                               the battery and the thermal state: it does not
   #                               refuse for them, but the session keeps both
   #                               guardrails, and its timer checks them at once
   …
   #   extend-checked UID END      the same, for a caller that has just checked
   #                               the battery and the thermal state: it does not
   #                               refuse for them, and the timer goes on checking
   ```
2. **54:** `readonly HELPER_VERSION=10`.
3. **62-64:**
   ```bash
   # On battery power, sessions do not start and running ones end at this charge,
   # so a closed MacBook is not drained until it shuts down. start-checked leaves
   # the start check to its caller, and the timer then ends a session at once.
   # `start` can set another level in this range, or 0 to turn the check off.
   ```
4. **73-74:** "Sessions do not start at critical, unless the caller has just checked (start-checked); the timer then ends one at once. `start` can turn this check off."
5. **`cmd_start` (842):** a 7th parameter, `local start_checks=${7:-on}` ("off for start-checked: the caller has just checked the battery and the thermal state, and the timer checks both again on its first pass"), and **903-908** inside `if [[ "$start_checks" == "on" ]]; then … fi`. Every other check stays: the user ID against `SUDO_UID`, the end, the ranges, the watched process and its owner, a session already running, the end time against the clock after the lock.
6. **`cmd_extend` (987):** `local guard_checks=${3:-on}`, and **1059** and **1063** start with `[[ "$guard_checks" == "on" ]]` (`&&` for the first; the second's test becomes `[[ "$guard_checks" == "on" && "$THERMAL_GUARD" == "on" ]]`). The version check at 1036-1041 and everything else stay.
7. **Dispatch (after 1452 and 1456):**
   ```bash
       start-checked)
           # The guardrails are given in full: the session keeps the ones the
           # caller checked.
           [[ $# -eq 6 || $# -eq 7 ]] ||
               fail "usage: awake-helper start-checked UID SECONDS|@EPOCH|none MIN_BATTERY THERMAL_GUARD UNPLUG_GUARD [WATCH_PID]" 64
           cmd_start "$2" "$3" "$4" "$5" "$6" "${7:-}" off
           ;;
       …
       extend-checked)
           [[ $# -eq 3 ]] || fail "usage: awake-helper extend-checked UID SECONDS|@EPOCH|none" 64
           cmd_extend "$2" "$3" off
           ;;
   ```
   and the catch-all usage at 1474 lists both. A caller cannot pass the `off` to plain `start` or `extend`: their dispatch takes at most 6 and exactly 2 arguments (1449, 1454).

**`tools/measure-latency.sh`** (I3f; 19 lines added, 3 removed): in the lid-closed check at 205-212, after the `sudo -n` test, read `readonly HELPER_PROTOCOL_VERSION=N` from `$CLI` and `readonly HELPER_VERSION=N` from the installed helper (`sed -n`, `|| true`, so an unreadable file counts as a mismatch), and time the lid-closed rows only when both are equal and not empty; otherwise print `Skipping lid-closed: this awake expects helper protocol 9, and the installed helper speaks 10.` The `--help` text of `--lid-closed` adds "and the awake to time expects the installed helper's protocol".

Prototype: `/tmp/claude-0/-home-user-awake/002aec65-4ac7-5605-9e81-ce18d6bc76df/scratchpad/plan2-I/proto2` (diffs against `32094d1` in `proto2-*.diff` next to it). It holds all of I in one diff (`bin/awake` +151 −21, the helper +38 −10, the timing script +19 −3), written before the review: the dry-run capture, `app_thermal_state_is_current`, the two comments, the `run_helper passwordless` debug line, the `process_exited` message check and the new checks of I.5 marked "not run here" are not in it.

### I.4 Security and compatibility

**Phase 2 (I1, I2):**

- **I1 grants nothing new.** The same `/usr/bin/sudo -n`, the same rule (the helper's fixed path, 4331), the same helper. It cannot bring a dialog that today's code would not: the dialog still follows only a failed `sudo -n HELPER check`. It reports a failure as the helper's only after that check passed. Two races remain, each inside the few milliseconds between the two `sudo` runs: an administrator removes the rule (the helper ran and failed, then the check fails: one dialog and a second run of the same command), or adds one (sudo's refusal is reported as a failure, without a dialog). Both need an administrator acting in that window. A misconfigured rule (layouts E and H: the file exists, sudo refuses) costs one refused `sudo` more than today before the same dialog.
- **The `sudo` log.** A refused password-free run now logs two refusals (the run and the check) instead of one; a working one logs one run instead of two.
- **The new command substitution** (I1d) runs in the password-free branch and in the dry run. The helper's output order changes only between its standard output and standard error, which every caller separates (7234, 6332, 7004 and 7188 send standard output to `/dev/null`). It relies on nothing the helper leaves running holding its standard error open. That is true today and 12f pins it; a regression (say, a new `spawn` without `2>&1`) would hang every password-free lid-closed start until the session ends, and the app's command queue (AwakeCLI.swift:240) with it. macOS's `sudo` may run the command in a pseudo-terminal when it is started from a terminal (`use_pty`; macOS 26's default not verified here); QA I-4 checks that a Terminal start returns within about a second.
- **I2 is read-only.** It removes reads whose values no skipped path uses (I.1). Settings left behind are still found and restored whenever no session runs (12m checks it), and before a lid-open start on the "ended as time was added" path (12m checks that too).
- **The app:** unchanged. It runs the CLI next to it and reads the same status JSON. In custom password mode it still asks `sudo -n HELPER check` itself before showing its own dialog (StatusBarController.swift:939, AwakeCLI.swift:244-259); that stays (6.11, K).
- **Dry run:** the helper runs without `sudo` (3803-3811), so I1's `sudo` path does not apply there; its error output is captured as in password-free mode (I1d). The dry-run helper still refuses root.
- **Bash 3.2:** no new constructs beyond what the script uses: `case`, `${1:-}`, fd duplication in a command substitution. The self-test adds `declare -f` and `eval` to keep a copy of a function, and here-strings, both in bash 3.2. CI runs it all under `/bin/bash` 3.2.

**I3d:** it reads this account's helper `last` record only through `read_state_value`, and checks `completed_at` as a number before `(( ))` (`[[ =~ ]]` with an unquoted brace interval, as at 2898). It changes no exit status: it ends a 30 s wait early with exit 1, as the wait's timeout does today, and with a clearer message.

**Only with I3:**

- **I3 grants nothing new.** `start-checked` can do only what `start UID END 0 off` can already do, and less: that starts a session with no battery or heat cut-off at all, while `start-checked` keeps both in the record. `extend-checked` adds time that the timer's next check ends anyway on a low battery or a critical Mac. The helper still validates everything else. The one effect it makes reachable at once is the guardrail rule: a `low_battery` or `overheated` end clears a `SleepDisabled` 1 set before the session and sleeps a closed Mac (awake-helper:791-799, 812-821). For example, `start-checked UID 60 50 on off` on battery below 50%. That is not new either: the same user can start with `UNPLUG_GUARD` on, on AC power, and pull the charger (an `unplugged` end, same rule), or start just above a chosen battery level and wait.
- **The race.** In the rare case that the Mac turns critical (or the battery runs down, or the charger is pulled at the threshold) between `awake`'s fresh check and the timer's first pass, a session runs for a fraction of a second (estimate: 0.05 to 0.15 s) with `SleepDisabled` 1 instead of being refused. The timer then ends it as `overheated` or `low_battery`, which clears a `SleepDisabled` 1 that the user had set before (awake-helper:791-799, the guardrail rule), and sleeps the Mac if the lid is closed with nothing keeping it awake (awake-helper:812-821). What the user sees depends on when the timer's end lands (estimate: 0.05 to 0.15 s after the helper exits). Before the CLI's first check: I3d's message, exit 1. Between that check and C's report: exit 0 with a report that is already inactive. That matches no branch of `handleCommandResult` (StatusBarController.swift:403-468), and as the app's status is then already inactive, its next poll posts no end either (`maybeNotifyCompletionTransition` needs an active status before, :548-549): the icon goes back to off without a word. After the report: `Awake started`, then `Awake stopped: the Mac got too hot` (or the battery text) at the next poll, up to 10 s later (StatusBarController.swift:116). The silent case can be closed in the app: a start with exit 0 whose before and after are both inactive and whose after has a `lastCompletionReason` posts `postStopped` with that reason. That is not part of I's code; with H, it is one more rule of `CommandResult` and one more row of its check (H.3), worth adding only if I3 goes in. Without I3 the same case needs a state change within about 0.1 s of a start, or a watched process that exits then, as today.
- **D's value still never reaches the helper.** `start-checked` carries no thermal state; it only skips a read. The helper keeps its own read wherever the app's value can be stale.
- **New `awake` with helper 9:** `helper_is_ready` is false, so a lid-closed start installs helper 10 and runs a plain `start` under one dialog (3812-3825), as after 2.2.0's bump. A stop needs no helper (`stop-request`). Added time to a session that helper 9 started fails after the install with exit 6, "started by an older version of Awake. Stop it and start a new one." (awake-helper:1036-1041), as with every bump.
- **Old `awake` with helper 10:** it sees the helper as out of date and installs its own helper 9 behind a dialog, a downgrade. Only mixed manual copies meet this: the installer, which the Homebrew cask runs (tools/homebrew/awake.rb), installs both files together (scripts/install-awake.sh:507-508, 517-526) and stops the running session first. The timing script skips that case (I3f).
- **The installer:** `--install-helper` reinstalls the helper whenever it differs from the installed copy (4231), so G1 and F8 already cost installer and Homebrew users one dialog at the update; I3 adds none for them. The bump adds one for CLI-only installs, at their next lid-closed start, and the reinstall loop between mixed manual copies. The password-free rule names the path, not the version, so it keeps working after the reinstall; `visudo` is not involved.
- **Dry run:** `start-checked` and `extend-checked` run in the dry run as in real mode, which is how 12f, 12l and 12m test them.
- **Bash 3.2:** an empty `local` array then an assignment, `case`, `${1:-}`, as the script already uses.

### I.5 Tests

**Self-test, at `32094d1`'s lines. Phase 2:**

1. **12f, after 4155** (the `cleanup_state` after the boot-restore checks, before the 12g line at 4157), in I1's commit:
   ```bash
   # run_helper captures the helper's standard error in password-free mode and
   # in the dry run, so nothing the helper leaves running may keep it open: the
   # capture would then wait for the session to end.
   cleanup_state
   mkdir -p -- "$DRY_RUN_STATE_DIR"
   started=$SECONDS
   helper_stderr=""
   { helper_stderr=$(run_helper_dry start "$TEST_UID" 8 0 off off 2>&1 1>&3 3>&-) || true; } 3>/dev/null
   if (( SECONDS - started > 3 )) || [[ ! -f "$DRY_RUN_HELPER_SESSION_FILE" || -n "$helper_stderr" ]]; then
       fail_test "Self-test failed: something the helper left running kept its error output open ($((SECONDS - started)) s)."
   fi
   run_helper_dry restore >/dev/null
   cleanup_state
   ```
   The review ran this with `start-checked "$TEST_UID" 8 0 off off` on the prototype: it passed, and with `2>&1` removed from `spawn`'s dry-run `nohup` line (awake-helper:834) the capture returned only after 8 to 10 s, when the 6 s session had ended. Plain `start` with `0 off` makes no guardrail read and takes the same path through `spawn`; with plain `start` it was not run here.
2. **New 12m, before 13 (5088)**, "Verifying the helper runs of password-free mode and the reads of the sleep settings" (with I3: "…, and the starts the helper need not check again"). One sourced block (`set -euo pipefail`, as 12l's). I2's commit creates it, headed "Verifying when awake reads the sleep settings", and I1's renames it; I1's, I3d's and I3's commits add their checks: about 300 lines with all of I.
   - I2: `main` with logging stand-ins for `get_battery_setting` and `run_helper`. Each start reads the settings exactly once. A lid-closed stop, lid-closed added time and a lid-open stop with sessions running read none. A session that ends as time is added (`extend_running_session` returning 3) reads them once and then starts. Settings left behind without a session are still restored (`RUN_HELPER gui restore`). A lid-open session that ends as time is added, with settings left behind (`disablesleep` 1), still runs `RUN_HELPER terminal restore` before the new lid-open start. As built: the stand-ins write one log, in order, with the session starts, stops and changes, so that the path where the session ended shows the read after the end; the block also checks lid-open added time, a lid-open start while another account's lid-closed session runs (no read), a `stale` record, a lid-open start with settings left behind (restored first), and that a failed read refuses a lid-closed start, also after a session ended as time was added. Each lid-closed start's helper arguments are matched in full, so a second read after it shows. 8 of its 16 checks fail on `32094d1`, every one of something I2 changes.
   - I1: `run_helper` with `DRY_RUN=false` and stand-ins for `sudo_without_password` (logging each call) and `run_as_admin`. Password-free success is one `sudo` run with the helper's output passed through. A helper failing with 1 and with 3 keeps its status and message after exactly one check, with no dialog. Sudo refusing drops `sudo: a password is required` and asks with the same arguments. `restore` reaches the dialog unchanged. Without password-free mode the check comes first, and a refusal asks.

**I3d** (its commit, question I-4), in 12m:

- `wait_for_helper_session_start` returns 2 within a second when the record is gone. With `helper_session_state` answering `stale` three times and then `running`, it returns 0 after the fourth check: a stale record still waits (not run here).
- The first-pass end, with `current_epoch` fixed: `overheated` and `low_battery` give their messages, and `process_exited` the process message (not run here); `timeout`, a `completed_at` 100 s before the start, and another account's record give the generic one.

**Only with I3:**

1. **12f**, after the check of item 1, about 90 lines more, using only helpers defined earlier (`run_helper_dry`, `set_mock_thermal`, `set_mock_battery`, `wait_for_helper_session_end`, `helper_session_value`, `helper_last_value`):
   - mock thermal 3: plain `start` exits 8 and writes no record; `start-checked UID 60 10 on off` prints `session_token=`, and within 3 s the session ends with `reason=overheated` and `disablesleep=0`;
   - mock battery 4% on battery: plain `start` exits 4; `start-checked` records `min_battery_percent=10` and `thermal_guard=on`, and the timer ends it as `low_battery` within 3 s;
   - `start-checked` refuses `60`, `60 10`, `60 10 on`, `60 3 on off`, `60 10 maybe off`, `60 10 on maybe`, `60 10 on off 0` and an end time in the past, leaving no record;
   - a session with its timer and guard paused (`kill -STOP`), mock thermal 3: plain `extend` exits 8 and keeps the deadline; `extend-checked` adds 60 s; it refuses a missing or zero change; after `kill -CONT` the timer ends the session as `overheated`;
   - with nothing wrong, a `start-checked` session runs on past its timer's first pass (the review ran it: it passes on the prototype; on `32094d1` the start fails with `usage`, exit 64):
     ```bash
     # With nothing wrong, a start-checked session runs on past its timer's
     # first pass.
     cleanup_state
     mkdir -p -- "$DRY_RUN_STATE_DIR"
     set_mock_thermal 0 open
     set_mock_battery ac 80
     if ! run_helper_dry start-checked "$TEST_UID" 60 10 on off >/dev/null; then
         fail_test "Self-test failed: start-checked did not start on a cool Mac on AC power."
     fi
     first_token=$(helper_session_value session_token)
     /bin/sleep 2
     if [[ -z "$first_token" || "$(helper_session_value session_token)" != "$first_token" ]]; then
         fail_test "Self-test failed: a start-checked session on a cool Mac on AC power did not keep running."
     fi
     cleanup_state
     ```
     Most other lid-closed checks run plain `start`, as `cleanup_state` removes the mock thermal file, so `thermal` stays empty and I3b keeps `start`; without this check, a regression that ended every `start-checked` session on its first pass would get through.
2. **12l, 5084:** `expect_thermal_record "lid-closed" "--dry-run start-checked" …`: an app start with a fresh value (1) runs `start-checked`, and the helper still never sees the value.
3. **12h's picker checks, 2484:** `--thermal-guard off` now expects `RUN_HELPER gui start-checked … 60 5 off on $$`. 2477 (thermal guard on, `thermal_state` failing) still expects a plain `start`. This function needs `defaults` and runs only on macOS CI.
4. **12m:** `run_helper` asks with a plain `start` for `start-checked` and a plain `extend` for `extend-checked`, after a refusal and without password-free mode; the install command runs `'start'`. `main`: `start-checked` after a reading of 0, a plain `start` after a failed reading, `start-checked` with `--thermal-guard off`, `start-checked` with the app's value from this second, a plain `start` with one from 5 s ago. Added time runs plain `extend` without the app's value, `extend-checked` with this second's value or the session's thermal guard off, plain `extend` with a value 5 s old. A session that ends as time is added reads the settings once and then runs `start-checked`. Then end to end in the dry run: the app's fresh value says fair (1) but the mock state is critical: the start runs `start-checked`, and within 10 s the status is `Awake is off.`, `last` says `overheated`, and `disablesleep` is 0.

**Shown to fail without the change.** On the prototype, the whole self-test passed in the emulation (`SELFTEST_EXIT=0`, 5 min 14 s with all of I; `32094d1` took 5 min 7 s in the same emulation). The prototype's self-test run against `32094d1`'s `bin/` stopped at 12f: "start-checked did not start a session on an overheating Mac (awake-helper: usage: …)"; `32094d1`'s helper answers `extend-checked` with the same `usage` exit 64. 12m's sourced block, run on `32094d1` with `fail` changed to count instead of exit, ran 46 checks and reported 28 failures: every check of something I adds (one `sudo` run, the check after a failure, a plain `start` or `extend` in the dialog, the wait ending at once, `start-checked` and `extend-checked` chosen, the first-pass messages, no settings read while a session runs). The 18 that passed pin what I keeps (each start reads the settings once, a plain `start` or `extend` after a failed or old reading, `restore` unchanged, leftover settings restored, the dialog stand-in still reached). On the prototype it reported none. That run held all of I in one block; the split by commit, and the checks marked "not run here", were not run. 12l fails on `32094d1`, whose helper runs `start`. The 2484 change was not run here (it needs `defaults`). The run against real `sudo` (I.1's layouts, the prototype's `run_helper` sourced as an unprivileged user with only `run_as_admin`, `helper_path`, `helper_is_ready` and `passwordless_is_configured` replaced): A, D and F ran the helper with one `sudo` run and reported failures 1 and 3 as the helper's with no dialog; B, C, E, G and H asked with a plain `start`, sudo's message not shown. `32094d1`'s `run_helper` used two `sudo` runs in A, D and F.

**Run it three times.** Run the whole self-test three times on each final commit, locally and on CI, with the dry-run capture (I1d) in place, which the prototype did not have. One of the review's two full emulation runs of the prototype ended with `SELFTEST_EXIT=1` right after 12g's header and printed nothing; the second passed (5 min 13 s), and ten targeted rounds of the new 12f block followed by that start all passed. So it is probably a flake not caused by I, but the suite's silent exit hides the cause. While at it, 12g's first start (tests/cli/awake-self-test:4167) can show its output when it fails:
```bash
if ! output=$(AWAKE_NO_NOTIFICATIONS=true run_awake --terminal --backend "$backend" --indefinite 2>&1); then
    printf '%s\n' "$output" >&2
    fail_test "Self-test failed: an indefinite $backend session did not start."
fi
```

**tests/app:** none; I has no Swift changes (the app-side silent case of I.4, if added with I3, is a row of H's `CommandResult` check). **CI:** no change. The self-test step and the timing script's dry run (ci.yml:116-122) cover it; the timing script's new guard, with I3, runs only outside the dry run (QA I-10).

### I.6 Mac QA

Password-free mode on, plugged in, unless a step says otherwise. `H=/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper` in each Terminal window.

**Preflight** (the installed 2.4.0, no Awake build; before I1's commit and before G1, with G's QA 1 to 3):

- **I-1. sudo.** `sudo -V | head -1`; `sudo -k; sudo -n "$H" check; echo "exit $?"`; `sudo -n -l "$H"; echo "exit $?"`; `sudo -n "$H" extend "$(id -u)" 60; echo "exit $?"` with no session; `sudo grep -nE 'includedir|^%admin' /etc/sudoers`. Expected: the version (note it); `exit 0` with no prompt; the helper's path and `exit 0`; `awake-helper: no Awake session is running.` and `exit 5` (the helper's own status comes through `sudo`); the `%admin` line before `#includedir /private/etc/sudoers.d` (layout D). Then `awake --passwordless off`, `sudo -k`, and the first two again: `sudo: a password is required` and `exit 1` for both, with no prompt. `awake --passwordless on` to finish. If a result differs from layouts A, B or D of I.1, I1 waits until the difference is understood.
- **I-2. What each removed piece costs, one sitting.** `time (for i in {1..20}; do sudo -n "$H" check; done)`; `time (for i in {1..20}; do pmset -g batt >/dev/null; done)`; `time (for i in {1..20}; do pmset -g custom >/dev/null; pmset -g >/dev/null; done)`; `sudo -v; time (for i in {1..20}; do sudo -n true; done)`; `time (for i in {1..20}; do sudo -n osascript -l JavaScript -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState' >/dev/null; done)`. Expected: each total divided by 20 is I1's saving per helper call, I3's battery read and I2's pair; the `osascript` loop less the `sudo -n true` loop, divided by 20, is I3's thermal read, which also runs `sudo` in this loop and not in the helper. They replace the estimates of I.1 and I.8; note them in this plan's results table.
- **I-3. The helper's start with and without its two reads.**
  - (a) On 2.4.0, no session running: `for i in 1 2 3 4 5 6 7 8 9 10; do for g in 5:on 0:off; do /usr/bin/time -p sudo -n "$H" start "$(id -u)" 60 "${g%:*}" "${g#*:}" off 2>&1 >/dev/null | awk -v g="$g" '/^real/ { print g, $2 }'; sudo -n "$H" restore >/dev/null; sleep 2; done; done` (written to work in zsh, Terminal's default shell, as in bash). `5:on` makes the battery and thermal reads, as every lid-closed start does today; `0:off` makes neither (awake-helper:903-908), and is otherwise the same start (its timer then makes no reads either, which only lightens the background). Expected: the difference of the two medians is what I3 would remove from each lid-closed start. **The gate:** I3 goes into 2.5.0 (question I-1, option a) only if that difference is 100 ms or more. I-2's `osascript` (less `sudo -n true`) plus `pmset -g batt` is the cross-check; if the two disagree by more than about 30 ms, I-3 counts, as it times the helper as it runs, watcher included. Afterwards `awake --status` says `Awake is off.` and `pmset -g | grep SleepDisabled` shows 0.
  - (b) Only with I3, new helper, no session running: `for i in 1 2 3 4 5 6 7 8 9 10; do for c in start start-checked; do /usr/bin/time -p sudo -n "$H" $c "$(id -u)" 60 5 on off 2>&1 >/dev/null | awk -v c=$c '/^real/ { print c, $2 }'; sudo -n "$H" restore >/dev/null; sleep 2; done; done`. Expected: `start-checked` is shorter by about (a)'s difference; afterwards `awake --status` says `Awake is off.` and `pmset -g | grep SleepDisabled` shows 0.

**Phase 2** (I1 and I2; in the 2.5.0 QA, except I-11, which is the optional timing sitting at the end of phase 2 and needs no install):

- **I-4. One `sudo` per helper call.** In a second window, `sudo log stream --style compact --predicate 'process == "sudo"'`. Then ⇧⌘A (shortcut lid-closed), `Add 1 hour`, stop; then in Terminal `time awake --backend awake --duration 1m` and `awake --stop`. Expected: the start shows one line ending `COMMAND=/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper start <uid> <seconds> 5 on off` (with I3: `start-checked …`; 2.4.0: a `check` line, then `start`); `Add 1 hour` one `extend <uid> 3600` line (with I3: `extend-checked`); the stops none; the Terminal start one line (2.4.0: three lines), and `time` shows that it returned within about a second (`real` under 1.0 s). A hang of I1's capture of the helper's error output, for example under `sudo`'s `use_pty` when run from a terminal, would show here as a wait until the session ends. If the stream shows no `sudo` lines at all, repeat with `sudo eslogger exec > /tmp/awake-exec.json` (macOS 13 and later) and count the events of `/usr/bin/sudo` in it. `eslogger` needs Full Disk Access for Terminal (System Settings → Privacy & Security); without it, it exits at once.
- **I-7. A rule that does not cover the helper.** `printf '%s ALL = (root) NOPASSWD: /usr/bin/true\n' "$(id -un)" > /tmp/awake-rule; sudo visudo -cf /tmp/awake-rule && sudo install -m 440 -o root -g wheel /tmp/awake-rule "/private/etc/sudoers.d/awake-$(id -u)"; sudo -k; awake --debug --gui --start --duration 1m`. Expected: one macOS password dialog; after the password the session starts, no `sudo:` line is printed, and the debug log has `run_helper passwordless command=start rc=1` (with I3: `command=start-checked`), then `run_helper passwordless_refused rc=1`. Again with Cancel: nothing starts and nothing is posted. Then `awake --stop`, `awake --passwordless on` (one dialog) to restore the real rule, and `rm /tmp/awake-rule`.
- **I-9. No `pmset` before a stop or added time.** In a second window, `sudo eslogger exec > /tmp/awake-exec.json` (Full Disk Access for Terminal, as in I-4); stop it after the steps. Start a lid-open session in Terminal (`awake --backend caffeinate --duration 10m`), add time (`awake --duration 10m`), stop (`awake --stop`). Expected: count the exec events of `/usr/bin/pmset` whose arguments are `-g custom` or `-g` alone (not `-g batt`, which the session's runner reads every minute): none from the added time or the stop (2.4.0: two each); the start still runs them. From the app, a stop runs the pair once, for the status it writes afterwards (C), where 2.4.0 ran it twice; added time from the app runs none.
- **I-11. Timing.** At the end of phase 2 (no install), in the sitting of H's QA 1 (Timing, phase 2): its first two runs, the 2.4.0 code (`--cli ~/awake/bin/awake`), then at once `--cli ~/awake-2.5/bin/awake`, both with the branch's script. Both speak protocol 9 and use the installed helper, so the lid-closed start's action differs by I1 (and H's report, a few ms): expected about 15 to 40 ms less. The stops' actions move by no more than I-2's pmset pair. With I3 (protocol 10), the runs before and after the install are different sittings: compare each run's lid-closed start action with its own lid-open start action, which I does not change; the gap shrinks by about I-2's `sudo` check plus I-3 (a)'s difference. Note both in this plan's results table.
- **I-12. Regression.** faster-start-stop 8, items 4, 5, 8a, 11 and 27 on the new build (password-free and password mode, a dialog during added time, settings left behind, a refused start).

**Only with I3:**

- **I-5. Which start runs when.** `launchctl setenv AWAKE_DEBUG true`, relaunch the app. (a) ⇧⌘A lid-closed, stop: `grep 'helper_start command=' /tmp/keep-awake-lid-closed-$UID/awake-debug.log | tail -1` shows `command=start-checked thermal=<0 to 2>`. (b) `Use custom password dialog` off: click while off, wait 3 s in the picker, choose a lid-closed length, stop: `command=start`. (c) In Terminal, `awake --debug --duration 1m`, stop: `command=start-checked` with the state `osascript` read. Then `launchctl unsetenv AWAKE_DEBUG`, relaunch, and delete the log.
- **I-6. The timer's first pass, on battery power below 50%.** `sudo -n "$H" start "$(id -u)" 60 50 on off; echo "exit $?"`, then `sudo -n "$H" start-checked "$(id -u)" 60 50 on off; sleep 3; awake --status-json | grep -o '"last_completion_reason":"[a-z_]*"'; pmset -g | grep SleepDisabled`. Expected: `awake-helper: the battery is at NN%, too low for a lid-closed session. Connect the charger first.` and `exit 4`; then `session_token=…`, `"last_completion_reason":"low_battery"` and `SleepDisabled 0`.
- **I-8. The update.** From 2.4.0, run the new installer: one password dialog (helper 10). Then `grep '^readonly HELPER_VERSION' "$H"` shows 10, `awake --status-json` has `"helper_installed":true` and `"passwordless":true`, and ⇧⌘A starts lid-closed without a dialog. CLI-only: with helper 9 still installed, copy the new `bin/awake` and `bin/awake-helper` over the CLI's copies and run `awake --duration 1m`: one prompt, "Awake needs your password to install its helper and change the sleep settings.", then the session runs; the next start asks nothing.
- **I-10. The timing script's guard.** `tools/measure-latency.sh --lid-closed --rounds 1 --cli ~/awake-qa/awake-2.4.0/bin/awake` (the `v2.4.0` worktree, G's QA 9). Expected: `Skipping lid-closed: this awake expects helper protocol 9, and the installed helper speaks 10.`, then only the lid-open rows, and no password dialog.

### I.7 Docs

- **README.md:606** (I1's commit): "- and running additional sourced regression checks for helper matching, password retries, password-free helper runs, prompt behavior, CLI parsing, and failure handling."
- **README.md:604** (I3's commit, only with I3) ends: "…and that the thermal state the menu bar app passes counts only for the start checks and never reaches a session's processes, and that a lid-closed start the helper does not check again ends at once, and time added without the helper's check ends at the timer's next check, when a simulated battery is low or a simulated Mac overheats,"
- README.md:56 stays: `awake` itself still refuses to start at `critical`, and the README does not describe the helper's internal checks. README.md:93 stays: `start-checked` is a start with the same strictly checked arguments. `--help` is unchanged (no new options).
- `bin/awake-helper`'s header lists the two commands (with I3, I.3).
- **CHANGELOG, 2.5.0's `[Unreleased]`** (added as the cross-cutting section says). All lines within 79 columns (checked: at most 75).
  - Phase 2, under `### Changed`, I2's and I1's bullets:
    ```
    - `awake` no longer reads the sleep settings with `pmset` before it stops a
      running session or adds time to one; it reads them only when no session
      runs.
    - In password-free mode, lid-closed starts and added time are quicker:
      `awake` runs the helper through `sudo` at once, rather than first asking
      `sudo` whether it may. If `sudo` refuses, `awake` asks for the password,
      as before.
    ```
  - I3d, under `### Fixed`:
    ```
    - When a lid-closed session ended before `awake` saw it running, for
      example because the process it was to wait for had just exited, `awake`
      went on waiting for 30 seconds before it reported
      `Failed to start the awake session.` It now says at once why the session
      ended.
    ```
  - Only with I3, under `### Changed`:
    ```
    - In password-free mode, lid-closed starts, and time added from the menu
      bar app, are quicker: right after `awake` has checked the battery and the
      thermal state, the helper no longer reads them again (helper protocol
      version 10). The session keeps both guardrails: a new session's timer
      checks them at once, and a running one's at its next check. When the
      start picker or the add-time list was open for more than a second, or a
      password was asked for, the helper still checks them first.
    ```
    and, under `### Upgrade notes`, 2.2.0's wording (CHANGELOG.md:141-147) for protocol 10 in place of G's note, as in G.7:
    ```
    - Run the installer again, or `brew upgrade`. It stops a running session
      and installs helper protocol version 10, which asks for your password
      once, also in password-free mode. In a manual CLI-only install, copy both
      `bin/awake` and `bin/awake-helper` again; the next lid-closed start then
      updates the helper in the same step, with one password prompt. If you
      cancel the installer's prompt, that start asks.
    ```
    Without I3 the release keeps G's note (run the installer again or `brew upgrade`; one password prompt; in a manual CLI-only install, copy both files and run `awake --install-helper`). Either way `tools/release.sh` suggests a minor version: no `### Removed`, no `**Breaking`.
- **faster-start-stop.md** (in the commit named):
  - 6.6 gets a pointer to this section (I2's commit).
  - 6.1's rows (I2's commit): I1 "each password-free helper call, 15 to 40 ms"; I2 "stops and added time, 0 to 20 ms"; I3 "lid-closed starts and added time from the app, 35 to 90 ms; only if the Mac preflight finds 100 ms or more (faster-start-stop-2.md, I)".
  - 6.9 (I2's commit; "Why this order" leaves this edit to I): step 1 becomes "After A to D, low risk, no helper change: I2 and I1 (faster-start-stop-2.md, phase 2, with H)." Step 4 becomes "A helper release: G1 and F8, and I3 only if the Mac preflight finds it worth protocol 10 (faster-start-stop-2.md, I). Any helper change asks for the password once at the update; protocol 10 and 2.2.0's Upgrade note come only with I3. Mac checks first."
  - 6.10's question 5 is answered by questions I-1 to I-3 (I2's commit).
  - Only with I3, in I3's commit: 6.7's "Keep" bullet becomes "**Keep:** the runner's immediate first thermal check (`next_thermal_check=0`, bin/awake:5433 at `32094d1`), and the helper's own start check (awake-helper:906) wherever the app's thermal state can be stale (after the CLI's picker, after a password dialog). Elsewhere, `start-checked` leaves it to the timer's immediate first check (awake-helper:1230). They back D up." Section 11's bullet "A stale thermal value weakening a session's guard (D)" ends with the same: "Backstops: the runner's immediate first check (bin/awake:5433 at `32094d1`), and the helper's start check (awake-helper:906) wherever the app's thermal state can be stale; elsewhere `start-checked` leaves it to the timer's immediate first check (awake-helper:1230) (6.7)." 7.1 step 5, next to G's edit of the same step, adds: "After a helper protocol bump an older `awake` cannot time lid-closed rows against the new helper (the script skips them); compare each sitting's lid-closed start with its lid-open start instead."

### I.8 Gain

Per action, password-free mode, from the app unless named. Mac figures are estimates built from I.1's per-piece estimates; the "today" column is measured (dev, Mac14,2, 7.3).

| Action | Today's run (measured) | I2 (phase 2) | I1 (phase 2) | After I2 and I1 | I3 (only if gated in) | With I3 too |
|---|---|---|---|---|---|---|
| Lid-closed start | 535 ms | 0 | −15 to −40 ms (one `sudo` and helper run; about 20 by I.1's budget) | about 495 to 520 ms | −35 to −90 ms (root `osascript`, `pmset -g batt`, the watcher) | about 405 to 485 ms |
| Lid-closed added time | not timed | 0 to −20 ms | −15 to −40 ms | 15 to 60 ms less | −35 to −90 ms (`extend-checked`) | 50 to 150 ms less |
| Lid-closed stop | 848 ms (314 to 1268) | 0 to −20 ms | 0 (no `sudo`) | about 830 to 848 ms; the 1 s check stays (G1) | 0 | the same |
| Lid-open start | 492 ms | 0 | 0 | 492 ms | 0 | 492 ms |
| Lid-open stop | 315 ms | 0 to −20 ms | 0 | 295 to 315 ms | 0 | the same |
| Lid-open added time | not timed | 0 to −20 ms | 0 | up to 20 ms less | 0 | the same |
| Terminal `awake --duration 1h` (lid-closed) | not timed | 0 | −30 to −80 ms (two checks) | 30 to 80 ms less | −35 to −90 ms (the CLI keeps its own `osascript`) | 65 to 170 ms less |
| Terminal `awake --stop` | not timed | 0 to −20 ms | 0 | up to 20 ms less | 0 | the same |
| Lid-closed start or added time in custom password mode, without password-free mode | the app's own dialog or its cached password | 0 | 0 (no rule: the check still comes first) | unchanged | 0 (`run_as_admin`'s gui-custom path runs the plain `start` or `extend`, even without a dialog) | unchanged |
| Any start or added time after a password dialog | the dialog dominates | 0 | 0 | unchanged | 0 (plain `start` or `extend`) | unchanged |

What the app waits for, from the plan's reconciled estimates (cross-cutting: Expected gains): a lid-closed start, 714 ms today with C; about 500 to 525 ms after phase 2 (I2, H, I1); about 470 to 495 ms after phase 3 (G1, F8); about 265 to 370 ms after phase 4 (F's CLI part). With I3, every lid-closed start after phase 3 is 35 to 90 ms less again. A lid-open stop, 542 ms today, about 300 to 320 ms after phase 2; a lid-closed stop, 1061 ms today, about 830 to 850 ms after phase 2, still spread over 0.3 to 1.3 s until G1. The phase 2 figures are lower bounds until H's `--no-status-runs` timing (H.6, QA 1). Basis: I1 from Linux's 10 to 13 ms `sudo -n HELPER check`, widened for macOS's `sudo`, and about 20 ms by the budget of the 535 ms run (I.1); I3 from 7.3's 2.3.0 → dev change of the lid-closed start, less C's report (I.1); I2 from the 2.3.0 → dev status rows (C6's effect, 191 → 172 and 186 → 166 ms). Linux showed no change outside noise in any row. The dry run saves only two `awk` reads of a mock file; the lid-open stop and added time moved −6 and −12 ms, lid-closed added time −1 ms, with spreads of 20 to 60 ms. QA I-2, I-3 and I-11 replace the estimates.

### I.9 Risks, rollback and order

- **macOS's `sudo` differs from the Linux build tested.** It would show as password-free starts asking for a password (QA I-4, I-7) or failures reported with `sudo:` text. Either way no worse than a missing rule today: a dialog only after a refused check, never a silent run. QA I-1, in the preflight, before I1 is written.
- **I1's capture of the helper's error output hangs.** Only if something the helper leaves running keeps its standard error open, which nothing does today. 12f pins it, the dry-run branch puts every dry-run lid-closed start through the same capture, and QA I-4 times a Terminal start on the Mac.
- **I2's list of unused paths is wrong somewhere:** it would show as settings left behind that a lid-open start does not restore, or a lid-closed start refused with "Could not read the current battery sleep settings". 12m pins the paths, the "ended as time was added" path included; QA I-9 and I-12 check them on a Mac.
- **The preflight finds I3 worth less than 100 ms** (the expected case, I.1): I3 stays out, with no work lost but its specification. Question I-4 decides whether I3d still ships.
- **Only with I3: the race of I.4** (a fresh check says fine, the timer's first pass a moment later says critical or low): a session of a fraction of a second and a user-set `SleepDisabled` 1 cleared. Depending on when the end lands, the user sees I3d's message, or nothing at all (the icon goes back to off), or `Awake started` and then the stop notice up to 10 s later. Accepted; it needs the state to change within about 0.1 s, and for the thermal state only where the app's value is under 2 s old or the CLI read it itself. The silent case can be closed in H's `CommandResult` (I.4).
- **Only with I3: the protocol bump:** a forced password dialog for CLI-only installs at their next lid-closed start (installer and Homebrew users get one for G1 and F8 anyway), and mixed manual copies reinstall each other's helper (I.4). The Upgrade note says so; the timing script avoids it (I3f).
- **Rollback.** I2, I1 and I3d: revert their commits (CLI only). I3: the CLI can go back to plain `start` and `extend` (drop I3b and I3c) without another bump, as helper 10 still accepts both. Reverting the helper itself needs protocol 11 and another dialog, so it is not the first step.
- **Order.**
  - Phase 2: I2 first (low risk, CLI only, after C, which is done). H next: its "before" report is written from main's state after I2 and uses `pmset_session_active` only when no session runs, as `print_current_status` does, since I2 leaves the values at their defaults otherwise (H.3, item 6). I1 after H, after the preflight's QA I-1; it touches `run_helper`, after H's found report, and does not meet H. I3d after I1 if question I-4 says so.
  - The preflight (QA I-1 to I-3 (a), with G's QA 1 to 3) runs before I1's commit and before G1. Its I-3 (a) decides I3.
  - Phase 3, the helper release: G1, then F8, then I3 if it passes its gate. I3 is written on top of I1 (both change `run_helper`) and on top of G1's and F8's helper lines: G1's FIFO lines in `cmd_start` sit next to I3's (awake-helper:903-910 and the spawn at :976), and F8 rewrites the helper's file writes, so I3's line numbers are taken from the tree after them. The bump to 10 and the timing script's guard land in I3's commit, before the release's Mac timing.
  - Phase 4: F1's `CURRENT_UID` (F.3) also covers the `/usr/bin/id -u` that I3d adds (the `last` check) and, with I3, the two sites I3 rewrites (6332, 7226).

## 8. Timing

### Rules for every phase

1. **Compare in one sitting.** Runs in different sittings differ by up to a third (faster-start-stop.md 7.3). Time the old version and the new one straight after each other, the old with `--cli`, and keep the steps a phase cannot change as the check that the sitting held steady: they should agree within about 10% (H's QA 1 uses 20 ms for the status steps and 30 ms for the actions).
2. **10 rounds or more,** with `--lid-closed` when password-free mode is on. Report min, median and max; for the lid-closed stop the max matters as much as the median.
3. **Conditions** as faster-start-stop.md 7.1: the same Mac, plugged in, heavy apps closed, Awake.app quit, Sound off. Run each command once to warm up and keep the second.
4. **In the emulation,** alternate old and new every round in one harness and report both. Other work on the same machine makes absolute times noisy.
5. **Show the mechanism, not only the time.** Where an item adds a debug line, read it as in qa-2.4.0.md 4.8: `awake --debug …`, then `grep` in `/tmp/keep-awake-lid-closed-$UID/awake-debug.log`. Program counts come from the emulation (`strace -f -e trace=execve`): they are exact and the same on a Mac, apart from the real-mode programs each section names.

### Per phase

| Phase | In the emulation | On the Mac | Mechanism |
|---|---|---|---|
| 2: I2, H, I1, I3d (question I-4) | `tools/measure-latency.sh --dry-run --lid-closed --rounds 1`, alternating `--cli` old and new, 10 times or more, the new also with `--no-status-runs` | Optional (question X-5), about 15 minutes, no install, so it may run before 2.4.0 ships. The branch's script, `~/awake-2.5/tools/measure-latency.sh --rounds 10 --lid-closed`, first with `--cli ~/awake/bin/awake` (`dev`, the 2.4.0 code), then with `--cli ~/awake-2.5/bin/awake`, then the same with `--no-status-runs` (H's QA 1). Both speak protocol 9 and use the installed helper (2.2.0 or later), so the lid-closed rows work for both, and the lid-closed start shows I1 with the real `sudo`. The app's own part of H shows only in the 2.5.0 QA. | No `--status-json` just before or after an app start or stop (H's QA 2: a `pgrep` loop, or `sudo eslogger exec`, which needs Full Disk Access for Terminal). No `pmset -g custom` or `pmset -g` in a stop or added time (I2; I's QA I-9). One `sudo` per helper call (I1; I's QA I-4); `run_helper passwordless_refused` only after a refusal. |
| 3: G1, F8 (I3) | the same, with old and new pairs of CLI and helper side by side, as the dry run uses the helper next to the CLI (`helper_path`, 3569-3575) | At the 2.5.0 QA. Without a bump the 2.4.0 CLI works with the new helper, so right after the install `--cli ~/awake-qa/awake-2.4.0/bin/awake` against the installed 2.5.0 compares every row in one sitting; the 2.4.0 CLI writes no byte (G's QA 9). F8 is in the helper, which both then use, so it shows only before against after the install, with the lid-open rows as the check that the two sittings compare. With I3 (a bump) an older CLI's lid-closed rows are skipped (change 2 below): time them right before and right after the install, and compare each sitting's lid-closed start with its lid-open start (I's QA I-11). | G1: `request_helper_session_stop ended token=… request=… checks=N` (G1k) with N of 6 or less at every stop; 2.4.0 logs no such line, and its stops spread over a second (7.3). The line is load-bearing: G's check 8 and QA 8 read it, so it must not be dropped as noise later. I3, if in: `helper_start command=start-checked` (I's QA I-5). |
| 4: F's CLI part | A/B as above, and program counts per action and per status read, before and after | At the 2.5.0 QA: one sitting with `--cli` a checkout of the branch before F's commits (F's QA 2); no protocol change in phase 4 | the program counts; byte-identical `--status-json` and `--status`, and the same output on the exit paths, before and after F (83 of 83 in the prototype) |
| The 2.5.0 QA | — | Before the install: 10 rounds with `--lid-closed` on the installed 2.4.0, and `time` for the terminal commands of "Expected gains". After it: the same, then `--no-status-runs`. Also in one sitting after the install: `--cli ~/awake-qa/awake-2.4.0/bin/awake` (every row without a bump; the lid-open rows only with one), then the installed 2.5.0. | all of the above |

### Changes to the timing script and to faster-start-stop.md 7.1

The code belongs to the item sections named; the rules are here so that every phase uses them. The script changes only on `dev-2.5`.

1. **With H** (H's first commit, H4b). The script passes the found file (`AWAKE_STATUS_BEFORE_JSON_FILE`) on every action, which older versions ignore, and unsets the variable with the others (tools/measure-latency.sh:100-101). It does not pass `--if-off`, which older versions refuse and which costs nothing while Awake is off. A new `--no-status-runs` leaves out the status runs around each action, as the app with H does, and checks the result in C's report instead (`/usr/bin/grep -q '"active":true' "$REPORT_FILE"`, and `false` after a stop). It refuses a CLI that writes no report, and its summary prints only the actions. The comment at 281-284 names the columns: "today" (the app before 2.4.0), "with C" (2.4.0), "with C and H" (the action alone, right after a status run). Without `--no-status-runs`, "with C and H" is a lower bound for what the app with H waits for (Basis). CI's step (ci.yml:121-122) runs the script twice, the second time with `--no-status-runs` (H.3), so CI covers the new option in dry-run; its first Mac runs are H's QA 1.
2. **With a protocol bump only** (I3f, in I3's commit, with the bump). Outside the dry run, the lid-closed rows run only when the CLI's `HELPER_PROTOCOL_VERSION` (bin/awake:165) equals the installed helper's `HELPER_VERSION`; otherwise the script prints why and times the lid-open rows only. Today's guard (tools/measure-latency.sh:205-212) only runs `sudo -n helper check`, which passes for any protocol. Across a bump a 2.4.0 CLI would find the helper out of date, show the macOS password dialog in the middle of the timing (3812-3825), and with the password put back its own protocol-9 helper. Without a bump nothing is needed: a 2.4.0 CLI times correctly against the new protocol-9 helper.
3. **faster-start-stop.md 7.1, step 5, in G's commit (G.7).** Its last sentence says to use 10 rounds or more for lid-closed stops, which take up to a second more "(G1 would remove that)". With G1 in both the CLI and the installed helper they no longer spread; a CLI without G1 (2.4.0 and older) still does, even with the new helper, as it writes no byte. The sentence becomes G.7's: "Use 10 rounds or more for lid-closed stops when one side is a CLI before 2.5.0: its stops take anything up to a second more, depending on where they meet the helper's check. With 2.5.0's CLI and helper, a lid-closed stop no longer spreads over a second (G1)." With I3 (a bump), I's sentence follows: "After a helper protocol bump an older `awake` cannot time lid-closed rows against the new helper (the script skips them); compare each sitting's lid-closed start with its lid-open start instead." The script's own help (tools/measure-latency.sh:39-44) and its comment on the pause (237-242) stay: the spread pause still matters whenever one side lacks G1.

### Results

This plan gets a results table like faster-start-stop.md 7.3: one row per action and phase, with old, new and the change, the sitting and the commit, and the debug counts; and the preflight's costs (`sudo -n helper check`, `pmset -g batt`, the `pmset` pair, the root `osascript` less `sudo -n true`, I-3's difference). Every Mac figure in this plan stays an estimate until that table is filled in. A figure in the CHANGELOG, if the owner wants one, comes from that table.

## 9. Shared tests and QA

### The self-test

- **Where the new checks go,** as the item sections place them, at `32094d1`'s lines of `tests/cli/awake-self-test`:
  - **H:** a new section 5d after 5c (after :2988, before section 6); two sourced checks in `run_sourced_regression_checks` (section 10), after :1845 (the found report against `print_current_status` in 7 states, and the JSON string check of H1e); parts of 12i (after :4413) and 13 (after :5098). The `unset` on line 8 and its comment at 5-7 gain the new variable.
  - **G:** eight checks in 12f, after :4096, before the lid-closed sleep checks; in the file in the order 1, 2, 3, 7, 4, 5, 6, 8.
  - **I:** parts of 12f (after :4155: I1's capture test, which shows that nothing the helper leaves running keeps its standard error open, and I3's `start-checked` and `extend-checked` checks only with I3); 12l (:5084) and 12h's picker checks (:2484) only with I3; and a new section 12m before 13 (:5088), with a sourced block for I2, I1 and I3d (and I3's choices if it goes in).
  - **F:** a new sourced function, `run_sourced_builtin_checks`, after `run_sourced_end_time_checks` (after :2679, before `trap cleanup EXIT` at :2681), and a new section 10a right after section 10 (after :3145).
  - qa-2.5.0.md's self-test item then expects the section lines "1, 1a … 5c, 5d, 6 … 10, 10a, 11 … 12l, 12m, then 13".
- **Mixed versions with stand-ins, not old releases.** G's check 4 (a directory in the way, so no FIFO) runs a new CLI with a helper that made none. The existing 12f stops through `stop_helper_session` (tests/cli/awake-self-test:3987-3993) write only `stop-request`, as an older CLI does, so they run the new timer without a byte. H's fallback for an older CLI rests on that CLI's refusal of `--if-off`, which H's review checked against the 2.3.0 and `32094d1` CLIs in the emulation; the app's side of it is Mac QA (H's QA 7). The self-test does not use git today, and CI checks out one commit without tags (`actions/checkout@v5`'s default), so real old releases are mixed in the emulation during development (`git show v2.3.0:bin/awake-helper`, which 2.4.0 ships unchanged, next to the new CLI, in dry-run) and on the Mac in QA. Rejected: a section that takes the last release's files from git, which needs `fetch-depth: 0` in ci.yml and fails from a release tarball.
- **What dry-run cannot show.** `run_helper`'s dry-run branch runs the helper next to the CLI directly (3803-3811): no `sudo`, no `helper_is_ready`, no protocol check. I1's `sudo` path, the protocol mismatch (with I3), the helper as root, its `chown` of the FIFO and Apple's `sudo` are Mac QA only. I1's capture of the helper's standard error is not: the dry-run branch captures it the same way, so every dry-run lid-closed start in the self-test goes through it with the helper's real `spawn`. In dry-run a new CLI next to an old helper would send I3's new command to it and fail; that mix does not exist outside the dry run.
- **The variable.** H's new variable is unset at the top of the self-test (line 8), in tools/measure-latency.sh:100-101, and by AwakeCLI.swift `environment()` (634-635) for status reads, as C's is.
- **Time.** CI's job may take 20 minutes (ci.yml:16) and takes about 6.5 to 8 today (qa-2.4.0.md 0.3). In the emulation G's and I's prototypes took 4 and 7 s longer than `32094d1` for the whole self-test (Linux); the new sections together should add about a minute at most.
- **Three runs on the final code.** One of I's review runs stopped once, silently, at 12g's first start, and ten targeted runs did not repeat it. Run the whole self-test three times on the final code, locally and on CI; I's section makes that start print its output when it fails.

### App checks and CI

- H moves the outcome logic of `handleCommandResult` into a Foundation-only `CommandResult.swift`. Its check, `tests/app/command-result-check.swift` (550 checks), builds with that file alone, in a CI step after ci.yml:87 in the style of "Check the menu bar icon" (ci.yml:80-87). `tools/build-awake-app.sh` compiles `Sources/*.swift`, so the app build needs no change.
- One other CI change: H's first commit runs the timing script's step (ci.yml:121-122) a second time, with `--no-status-runs` (H.3). Otherwise CI keeps checking syntax with `/bin/bash` 3.2, the version consistency, the app build, the macOS 12.5 build, the app checks, the cask, the dry-run self-test and the timing script in dry-run (ci.yml:20-122). The self-test runs on `/bin/bash`, and so does the helper (its shebang), so G's check 7 runs on Apple's bash 3.2 there. The timing script's protocol guard (only with a bump) does not apply in dry-run, so I3 adds nothing to that step.
- Swift 5.7 still bounds H's app changes, as in faster-start-stop.md 4.1: explicit `self.` in escaping closures, no `if` or `switch` expressions. CI's newer `swiftc` does not catch these; the Mac's own build in the QA does.

### `qa-2.5.0.md`: structure

Written before the 2.5.0 QA, against the `dev` commit that holds `dev-2.5`, with every expected result checked against that commit, README.md and CHANGELOG.md `[Unreleased]`, like qa-2.4.0.md. It must have:

1. **Front matter:** status, the commit it was written against, what it covers (this plan's QA lists for G, H, F and I, the timing, the release), how to record results, which items are optional, and whether I3 went in.
2. **What changed since the plan was written,** as one list.
3. **Conventions,** as qa-2.4.0.md, plus how to tell the builds apart: the dev build reports 2.4.0 until `tools/release.sh` runs; `grep -c '^readonly HELPER_WAKE_FIFO=' "$HOME/Library/Application Support/Awake/bin/awake"` prints 1 for it and 0 for 2.4.0; `grep -c '^readonly WAKE_FIFO=' /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper` prints 1 for the new helper and 0 for 2.4.0's; `cmp "$HOME/Library/Application Support/Awake/bin/awake-helper" /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper` prints nothing when the installed helper is the managed copy. With I3, `grep '^readonly HELPER_VERSION=' /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper` shows 10.
4. **Safety, Time** (a table per section) and **Quick pass,** with at least: the preflight's recorded results (repeat 1 to 5 only if macOS was updated since), the "before" timing, the install's one prompt, the self-test, the main check of each item, the main mixed-versions case, the "after" timing and `brew upgrade`.
5. **0. Preparation:** tools, CI green on the commit, the tap token, backups (settings, `pmset -g`, copies of the 2.4.0 CLI and app), a `v2.4.0` worktree under `~/awake-qa` (`git -C ~/awake worktree add ~/awake-qa/awake-2.4.0 v2.4.0`), password-free mode on for the timing.
6. **The Mac preflight** (X8): its results, recorded when it ran before I1's commit, and the answer to question I-1 that followed.
7. **1. Before updating,** with the installed 2.4.0: the timing script with `--lid-closed`, `time` for the terminal commands of "Expected gains", and G's QA 4 (the new CLI from the checkout with the old helper).
8. **2. Install the dev build** over a running 2.4.0 lid-closed session: exactly one password prompt, also with password-free mode on; the installed helper the same as the managed copy (`cmp`); a second installer run (without `--passwordless`) asks nothing ("Awake's helper is already installed and up to date."); a cancelled prompt prints the installer's message. Then, without a bump: nothing asks again, lid-closed sessions run on the old helper as before, and `awake --install-helper` installs the new one with one prompt. With I3: the first lid-closed start asks once and never again.
9. **3. Automated checks on the Mac:** the self-test with `/bin/bash`; the app checks with this Mac's `swiftc`, including `command-result-check`; a release rehearsal that goes from 2.4.0 to 2.5.0.
10. **One section per item,** in the order of the phases: I (I2, I1, I3d), H, G, F with F8, each with its own QA list; I3's items only if it went in.
11. **Regression of what the items touch** from 2.4.0: the icon (A), the lid-open stop (B), the report (C), the app's thermal state (D), the sounds (E), J1's counts, and notifications posted once each.
12. **Mixed versions:** each row of "Old and new versions together" for the case that shipped, plus a 2.4.0 app with the new CLI and the new app with a 2.4.0 CLI (H's QA 7: the shortcut starts and stops, and says `Awake is already on` when pressed within 5 s of a Terminal start).
13. **Restart:** a lid-closed session across a normal restart (G's QA 16): the settings are back, `saved` is gone, the FIFO is gone (macOS empties `/var/run`), and `last_completion_reason` is either missing (the timer restored at shutdown) or `restart` (boot-restore did). A forced power-off stays qa-2.4.0.md 6.12's. Optional, like that item.
14. **Timing after the update,** by the rules of "Timing"; fill in this plan's results table.
15. **Old versions, uninstall and Homebrew:** `brew upgrade` from 2.4.0 with one macOS password dialog and every setting kept; the uninstaller removes `/var/run/net.kaenmaki.awake`, the FIFO with it; a fresh install.
16. **Release and post-release,** as qa-2.4.0.md 12.1 to 12.7 with 2.5.0, including reading the Upgrade note against what the install did.
17. **Results** and an **appendix** that maps every QA item of this plan to a checklist item.

### CHANGELOG and Upgrade notes

- The bullets are written in each item's section, within 79 columns, and committed together after the 2.4.0 merge (X7). Check them with `/bin/bash tools/release.sh --notes Unreleased | awk 'length > 79'`.
- Order: Upgrade notes, then Changed in the order of the commits (I2, H, I1, G, I3 if it went in, F), then Fixed (H's three, in H.7's order: the session ends that were not announced, the race in which the shortcut took a Terminal session for the app's own, and added time that started a new session but was announced as `Awake extended`; then I3d's, question I-4). F8 has no bullet of its own; it rides with the Upgrade note. No `**Breaking`, no `### Removed` (X5).
- No Mac figure in the CHANGELOG unless it comes from the results table.
- **Without a bump** (the recommendation), G's Upgrade note (G.7), first under `### Upgrade notes`. `brew upgrade` is what README.md:132 documents.

  ```
  - Run the installer again, or `brew upgrade`. It stops a running session
    and updates the helper, which asks for your password once, also in
    password-free mode. In a manual CLI-only install, copy both `bin/awake`
    and `bin/awake-helper` again, then run `awake --install-helper`; until
    then, lid-closed stops work as before.
  ```

- **With a bump** (I3), in the words of 2.2.0's (CHANGELOG.md:141-147) instead:

  ```
  - Run the installer again, or `brew upgrade`. It stops a running session
    and installs helper protocol version 10, which asks for your password
    once, also in password-free mode. In a manual CLI-only install, copy both
    `bin/awake` and `bin/awake-helper` again; the next lid-closed start then
    updates the helper in the same step, with one password prompt. If you
    cancel the installer's prompt, that start asks.
  ```

  The same texts as G.7.
- With question X-1 answered (b), the Upgrade note goes with 2.6.0 instead, and 2.5.0 has none.

### README

- Every README bullet stays on one line: the Help window renders only one-line `- ` bullets, and shows the new text after a reinstall.
- README lines go in their item's commit. Unlike CHANGELOG bullets they cannot land in the wrong release: a merge either places them or conflicts.
- Lines the items touch, at `32094d1`: G, README.md:93 (how a stop reaches the helper: it writes a byte to `wake`, and the helper reads single bytes from it and does nothing else with them) and the Runtime files list (:573-576, a `wake` bullet after `heartbeat` at :575); the self-test bullets at :598-606, H at :600, G at :603 and I at :604 and :606. I3 changes neither :93 nor :56 (`awake` itself still refuses to start at `critical`). H's new variable and option stay undocumented, like C's (decision C10). F changes no documented behaviour.
- `Current version:` changes only through `tools/release.sh`.

## 10. Risks across items

- **Any helper change asks installer and Homebrew users for the password once** (scripts/install-awake.sh:525, bin/awake:4231). X4 keeps all of them in one release. A later release that touches `bin/awake-helper`, even its comments, asks again.
- **Without a bump, the new helper is not forced on anyone.** A manual CLI-only install, or a user who cancels the installer's prompt, keeps the old helper with no further prompt: lid-closed stops keep their once-a-second wait and F8's gain is missing, but nothing breaks (every mix works, "Old and new versions together"). The Upgrade note says to run `awake --install-helper`. Accepted, against a bump's forced prompt for CLI-only installs (X3, question G-1).
- **With I3, the bump's costs:** a forced prompt for CLI-only installs, mixed hand-copied versions reinstalling each other's helper at every lid-closed command, and the timing script's guard. Hence the preflight's 100 ms gate (X8).
- **A 2.5.0 bullet in 2.4.0's release notes.** `date_changelog` puts the 2.4.0 heading right under `## [Unreleased]`; a branch whose bullets sit inside the old `[Unreleased]` subsections merges without a conflict, and its bullets end up in `[2.4.0]`. Checked here: on a scratch clone, a bullet added to `dev-2.5`'s `### Changed`, then `tools/release.sh minor` on `dev` and `git merge dev` into the branch, merged cleanly with the bullet under `## [2.4.0]`. X7 avoids it, and the `diff` in "Branching while 2.4.0 is in QA" checks it.
- **The branch drifts from `dev`.** QA fixes land in code G, H, I and F rewrite. Merge `dev` in the same day, and let the draft PR's CI run on the merge. This plan's line numbers are those of `32094d1`; take them again from the merged tree before each commit.
- **I2 and H share main's state block.** H's sketch reads `pmset_read_ok` and `pmset_session_active`, which exist at `32094d1` and which I2 keeps (it removes only `current_sleep` and `current_disablesleep`); I2 sets them whenever no session runs, the only case in which H reads them ("Why this order", 1). H's sourced check and 5d fail if the rule drifts.
- **H's real gain is not known yet.** Its Mac estimates time each action right after a status run, which on the Mac can make it quicker (7.3). The `--no-status-runs` timing settles it ("Timing", change 1).
- **Root code** (G1, F8, I3). The helper's rules must hold: it never reads or writes outside its own folder (awake-helper:40-44), validates its arguments, ignores its environment (awake-helper:15), and never spins (G's `SECONDS` bound on the timer's loop, G1f). One review of `git diff v2.3.0 -- bin/awake-helper` at the end of phase 3 (X4). Dry-run runs the helper as the user, so root behaviour, `sudo` and the protocol check are Mac QA only.
- **I1's capture and G1's spawn.** In password-free mode I1 holds the helper's standard error in a command substitution, which returns only when every process holding it has closed it. The helper's background processes redirect it today (`spawn`, awake-helper:830-840; `run_with_timeout`, 522-543). A change near `spawn`, such as G1's FIFO lines before it in `cmd_start`, that started a process without the redirection would make every password-free lid-closed start hang until the session ends. I's 12f check pins it; G1 keeps the redirections.
- **macOS and Bash 3.2 facts not verified here:** a FIFO opened read-write with `exec 3<>`, `read -t 1 -u 3` on it in `/bin/bash` 3.2, a write with `1<>` that never blocks, a TERM trap during `read -t`, and how Apple's `sudo` answers `sudo -n` with and without the rule. The preflight (X8) checks them before I1's and G1's code; CI checks only syntax with `/bin/bash` 3.2 and the dry run (in which G's check 7 does run on Apple's bash).
- **Mixed versions.** A new app with an older CLI would fail a start if H passed an option the old CLI does not know; H's fallback (H3f) keeps that mix working, as phase 1 did (faster-start-stop.md 1, goal 4). Only a hand-copied CLI makes the mix, as the installer and Homebrew replace both.
- **Two reports, one lock.** After H, a state-changing run writes two status objects under the lock. H's found report costs 1.3 to 2.0 ms (Linux), so other `awake` commands wait only a few ms longer (faster-start-stop.md 11, the lock entry).
- **Notifications.** H's change to `handleCommandResult`, with A's paused polls, decides whether `Awake finished` is still posted for a session that ended just before a stop, and H also handles added time that met the session's end and started a new session (a changed token). With I3, a session the timer ends on its first pass can end without a word in the app (I's section). The 2.5.0 QA repeats qa-2.4.0.md's notification checks.
- **F last** means F's changes to the security checks (the runtime folder, the uid, `kill -0`) are reviewed on the final code. F must not change a byte of what `--status-json` or the reports print. Its review found one global taken from the environment (`STATUS_NOW`); any new global read with `${X:-}` must be set when the script loads, as `CURRENT_UID` is.
- **No Mac timing yet** for any of G, H, F or I. Every Mac figure here is an estimate until the results table is filled in.
