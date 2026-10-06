# Plan: keep the Mac awake while Claude works

- Status: a plan, not started. Nothing in it is implemented. The owner's answers to the questions below decide the details. Until then the plan follows the recommended answer to each question. A Mac preflight of about 45 minutes (section 9) comes before any code. It needs no Awake build, only Claude Code and a test hook. Two reviews (one of the code, one of the sources) were applied on 2026-10-06; "How this plan was checked" lists what changed and the few points that were adapted rather than taken as written.
- In brief: once the user turns it on (`awake --claude-hooks on`, or `Keep awake while Claude works` in the menu), Claude Code's hooks append one line per event to a file in the user's runtime folder. One small watcher process reads those lines and keeps a "holder" for each Claude session and subagent that works, waits for the user, or has background work. While any holder needs it, the watcher runs an ordinary Awake session tied to its own PID (`-w`), lid-closed in password-free mode, with a 12-hour limit that the root helper enforces. About a minute after the last holder ends, it ends that session the way `awake --` does, so a closed Mac sleeps. When a time rule is about to let the Mac sleep, it asks Claude Code once (`claude agents --json`) whether that session is still busy. The helper does not change (protocol 9), and nothing changes for users who never turn it on.
- Target version: after 2.4.0, the next minor version: 2.5.0. 2.4.0 is in its Mac QA on `dev` now (plan-2.4.0.md:3, faster-start-stop-2.md:3). The feature adds `### Added` entries, so `tools/release.sh` suggests a minor release (tools/release.sh:183-191). The helper does not change: no new command, no new file, not one byte. So the helper protocol stays 9 (bin/awake:172, awake-helper:56), and nobody is asked for a password at the update.
- Written: 2026-10-06, against `dev` at `a9cd6d1`, from the owner's request of 2026-10-06: "I was not aware of Adrafinil; we should study what they do with AI agents at some point. It would be a nice addition to be able to select 'keep awake as long as Claude works'." Bare line numbers are lines of `bin/awake` at `a9cd6d1`. Other files are named, for example `awake-helper:851` or `StatusBarController.swift:603`.
- Scope, checked against the code at `a9cd6d1`:
  - W, agent sessions in the CLI: `bin/awake`. It gets:
    - a builtins-only fast path for hooks right after `set -euo pipefail` (6);
    - two internal modes next to `--caffeinate-start` and `--notify-wait` (7007-7071);
    - an internal option `--agent-session` next to `--if-off` (469);
    - `admin_transport` (6916-6926) and `run_as_admin` (4060-4131), so that the agent's start never asks for a password, and a dry-run branch in `helper_runs_without_password` (4052-4055);
    - an optional token argument for `request_helper_session_stop` (4320-4376);
    - the lock helpers `main_lock_is_abandoned` and `take_over_stale_main_lock` (1377-1413), with the lock folder as a parameter;
    - main's start path (7256-7397), for the handover of 5.8;
    - `write_session_file` (2785-2799);
    - the status text (2984-3066) and `print_status_json` (3190-3333);
    - new functions after `run_bound_command` (4455-4545);
    - `show_usage` (348-427).
    Tests: `tests/cli/awake-self-test`, a new section 12n after 12m (5992-6382), `cleanup_state` (262-270) and section 13 (6383).
  - K, connecting Claude Code: `bin/awake` gets `--claude-hooks on|off|refresh|status|print`, with `--backend` and `--config-dir`, as a maintenance action next to `--passwordless` (parse_cli_args 607-624 and the check at 676-680, `run_maintenance_action` 6948-6965). Also touched:
    - `scripts/install-awake.sh`: a refresh step after :525;
    - `scripts/uninstall-awake.sh`: a removal step before `stop_active_session_if_needed` at :195;
    - `scripts/homebrew-uninstall.sh`, which runs that uninstaller;
    - `tests/cli/awake-self-test`, a new section 12o.
  - M, the menu bar app (`app/AwakeStatusApp/Sources/`):
    - `AwakeCLI.swift`: the decoded fields, 10-88;
    - `StatusDescription.swift`: the agent sentences, 22-54;
    - `StatusBarController.swift`: a menu item in `showContextMenu`, 783-850, and the end notifications in `maybeNotifyCompletionTransition`, 603-631;
    - `SettingsWindowController.swift`: a "Claude Code" group;
    - `InstallSupport.swift`: the guardrail notification text, 375-431;
    - optionally checks in `tests/app/` with their CI steps (`.github/workflows/ci.yml`, after :96).
  - Docs: `README.md` (Highlights, the use case at :44, a new "While Claude works" section, Options, Menu bar app, Runtime files, Security notes, Uninstall), `CHANGELOG.md` (`[Unreleased]`, once 2.4.0 has shipped), and `docs/plans/` (this plan, and later a `qa-2.5.0.md`).
  - Not touched: `bin/awake-helper`, the boot-restore LaunchDaemon, the sudoers rule (4737), the picker `tools/awake-gui-picker.swift` (unless question S-1 is answered (b) or (c)), and `tools/release.sh`. No new shipped file: the hook code lives in `bin/awake` (decision W14).
- Relation to other plans:
  - faster-start-stop-2.md is done and ships in 2.4.0. This plan builds on three of its results:
    - G1: `wake_helper_timer` (4308-4318) and `command-finished`, so an agent session ends at once and as `process_exited`;
    - H: the status report that a command writes for the app as it exits (`write_status_report`, 3549), which `--claude-hooks` and the watcher's end step also write, so the app's view changes at once;
    - I1: `sudo_without_password` (4047-4050) and `helper_runs_without_password` (4052-4055), which decide whether a lid-closed agent session can start without a prompt.
  - plan-2.4.0.md's rule "`awake` posts no notifications unless asked" (CHANGELOG.md, `[Unreleased]`) holds for agent sessions too (decision W16).
  - qa-2.4.0.md does not change.
  - Nothing here conflicts with an open plan.

## Questions for the owner

The plan follows the recommended answer to each question. The section named in each question explains it. S-1, H-1 and B-7 shape the most code. The other B questions change constants or a few branches.

### Scope and the menu

- **S-1. What does "keep awake as long as Claude works" mean in Awake? (sections 4, 5)**
  - (a) A setting. Once it is on, every Claude Code turn keeps the Mac awake, also with the lid closed, and the Mac sleeps again about a minute after the work stops. A checkmark item in the Ctrl-click menu turns it on and off. This is Adrafinil's model, and it matches how Claude is used: prompt after prompt, and sometimes with the lid closed. **Recommended.**
  - (b) A one-off choice in the picker's `Custom…` step, `While Claude works`, next to `For`, `Until` and `While`. It starts a session now and ends it the first time Claude stops working. The next turn starts nothing. It needs the same hooks as (a), and also a new end token and the picker's code (tools/awake-gui-picker.swift, around :938).
  - (c) Both. (a)'s code, plus (b)'s picker work and a "one-off" marker the watcher clears when it ends the session.

- **S-2. Which agents in the first version? (sections 1, 2)**
  - (a) Claude Code only. The hook verbs, the holder keys and the event log are not tied to Claude Code, so Codex can follow in a later version with its own `--codex-hooks`. **Recommended.**
  - (b) Claude Code and OpenAI Codex. Codex's hooks.json has the same nested shape and an `Interrupt` event Claude Code lacks (codex-rs/hooks/src/schema.rs:102-125 at `c0c230e`). But every handler needs a one-time trust approval in Codex's `/hooks` (codex-rs/hooks/src/config_rules.rs:33-60). Adrafinil also reports that `codex exec` ignores hooks.json (adrafinil@6e4eece …/CodexIntegration.swift:11-27). Codex's own docs could not be read here (the proxy blocked developers.openai.com).
  - (c) Also Gemini CLI (BeforeAgent and AfterAgent, gemini-cli@fb972b2 docs/hooks/index.md:38-50). Same cost, and less tested.

- **S-3. Names, and where the switch lives. (sections 7, 8)**
  - (a) CLI: `awake --claude-hooks on|off|refresh|status|print`, with `--config-dir DIR` for each extra Claude Code folder (`CLAUDE_CONFIG_DIR`). App: a Ctrl-click menu item `Keep awake while Claude works`, with a checkmark, shown only when a Claude Code settings folder exists. Settings: a `Claude Code` group with the same checkbox, a lid-mode popup and the folders it manages. Status: `Awake is on while Claude works.` **Recommended.**
  - (b) The same, but the switch only in Settings, not in the menu. One click further away, and a shorter menu.
  - (c) A neutral CLI name now, such as `--agent-hooks on|off [claude-code]`. Ready for more agents, but longer to type, and the only agent for now is Claude Code.

### Setup

- **H-1. How do Awake's hooks get into Claude Code? (section 7)**
  - (a) `awake --claude-hooks on` merges Awake's 13 handlers into `~/.claude/settings.json` (and into each `--config-dir` folder), one handler at a time. Each handler is one shell-form command, `'<awake path>' --agent-hook VERB; exit 0`, which every Claude Code version with hooks runs the same way (K2). It leaves every other handler alone, and it refuses a file it cannot parse or that changes while it works. It writes through a symlink and keeps the file's mode. `off` removes only Awake's handlers, from every event, and also ends a running agent session and its watcher. The installer runs `refresh`, which updates the handlers and the path only where they are already on, and the uninstaller runs `off` for every folder Awake wrote to. `print` prints the block for pasting by hand. **Recommended.**
  - (b) A Claude Code plugin in Awake's repository, with the repository as its own marketplace (`/plugin marketplace add anttikaenmaki/awake`, discover-plugins.md:180-213; hooks in `hooks/hooks.json`, plugins/components.md:745-779). Awake never edits a Claude Code file, and Claude Code installs and removes the plugin. Timeouts on plugin hooks also never raise the shared `SessionEnd` budget (hooks.md:3391). But:
    - the plugin's version is not tied to the installed `awake`;
    - its script must find `awake` (the managed path or `PATH`);
    - installing needs the `claude` command or a `/plugin` step in a session;
    - the app's checkbox would have to drive `claude plugin install`.
  - (c) Only `print`: the user pastes the block into the settings themselves. There is no risk to their file, but there is no menu switch either, and every update that changes the hook set needs a manual edit.

- **H-2. Lid mode of agent sessions, and password-free mode. (5.2, W12, K8)**
  - (a) Lid-closed by default. That needs password-free mode, because a hook has no terminal and must never pop a password dialog in the middle of a turn (hooks.md:720).
    - The first `--claude-hooks on`, and any `on --backend awake`, refuses while password-free mode is off, and names `awake --passwordless on`.
    - The app's checkbox offers to turn password-free mode on first, which asks for the password once, as turning it on always does.
    - `--claude-hooks on --backend caffeinate` chooses lid-open sessions instead. The choice is stored, and `on` without `--backend` and `refresh` keep it.
    - If password-free mode is turned off later, agent sessions fall back to lid-open, and `--status` says why.
    **Recommended.**
  - (b) Lid-closed when password-free mode works, otherwise lid-open, with no refusal at setup. Less friction, but a user who never turned password-free mode on closes the lid and finds that the Mac slept.
  - (c) Lid-open only. No password-free mode is needed. But Claude Code already keeps the Mac from idle sleep while it works, with its own `caffeinate -i` (section 2), so lid-open agent sessions add little: only the waits and the minute between turns.

### Behaviour

- **B-1. Waiting for the user: a permission prompt, a question, a plan to approve. (5.5)** No hook fires when a prompt is answered (section 2). So after `PermissionRequest` the holder stays `waiting` until the approved tool has run and its `PostToolUse` arrives.
  - (a) Stay awake for 10 minutes of waiting, then take the last look (B-7): if Claude Code reports that session `busy` (the prompt was answered and the tool runs), the holder goes back to working, and otherwise the Mac may sleep. Without the last look (B-7 (b)) the allowance is 20 minutes: 10 to answer, plus the 10-minute maximum of a foreground Bash call (tools-reference.md:160-161). The 10 minutes let an answer from a phone over Remote Control reach a Mac whose lid is closed. Adrafinil's default is the same (adrafinil@6e4eece AdrafinilShared/…/Models/AdrafinilSettings.swift:3-15, 52-57). **Recommended.**
  - (b) 10 minutes and nothing more. A tool approved at minute 5 that runs 8 minutes is cut off at minute 10, and a closed Mac sleeps in the middle of it.
  - (c) Stay awake while waiting, as while working, up to the 15-minute idle limit. Simpler (no `waiting` hooks), but a forgotten prompt keeps a closed Mac awake for 15 minutes.
  - (d) Sleep after the end grace (60 s). The Mac sleeps soonest, but a phone answer after a minute finds it asleep.

- **B-2. Timings. (5.4, 5.5, 5.9)** All are constants in `bin/awake`, with shorter values in the dry run:
  - the end grace after the last holder ends: 60 s (3 min without the last look, B-7 (b));
  - the idle limit without any sign of work: 15 min;
  - the waiting allowance: B-1; the background allowance: B-8;
  - each agent session's own time limit: 12 h.
  - (a) As listed, with no setting in the app. **Recommended.** The idle limit is longer than a foreground Bash call (10 minutes by default, tools-reference.md:160-161), and it counts from the start of the running tool, as `PreToolUse` sends a heartbeat (K.3). MCP tools may run for about 28 hours (`MCP_TOOL_TIMEOUT`, env-vars.md:483), and the user can raise `BASH_MAX_TIMEOUT_MS`: with the last look such a tool reads `busy` and goes on, and without it the README lists it as not covered.
  - (b) A 5-minute idle limit. The Mac sleeps sooner after an Esc or Ctrl+C interrupt. Safe only with the last look: without it, a 6-minute build in Claude's Bash tool would end the session while it runs.
  - (c) No session limit, as with Adrafinil's hooks: only its 24 h backstop applies (adrafinil@6e4eece …/Policy/IdleReleaseEvaluator.swift:27-28). Then a bug in the watcher could keep a closed Mac awake without end. With the 12 h limit, the root helper itself ends the session at 12 h, whatever the watcher does.
  - (d) A rolling limit of 2 h, still enforced by root, which the watcher extends through the same add-time path as `awake --duration` (5.3), only while fresh hook events arrive. A stuck watcher is then cut off within 2 hours instead of 12, and a `/goal` run longer than 12 hours, which goes on turn after turn without a prompt (goal.md:9, 66), is not cut off. It costs one helper run per extension and an internal path that extends only the watcher's own session.

- **B-3. Which guardrails do agent sessions use? (5.9)**
  - (a) The app's Guardrails settings: `Stop when too hot`, `Stop at low battery` with its level, and `Stop when unplugged`. The CLI reads them from the app's defaults domain, as it already reads the picker's settings (1156-1191). When they are not set, the CLI's defaults apply (5%, on, off). **Recommended.**
  - (b) Always the CLI's defaults: 5%, thermal guard on, unplug guard off. No new reads, but the app's settings do not apply to agent sessions.
  - (c) As (a), but with the unplug guard on by default for agent sessions. A Mac carried off while Claude works then sleeps within 5 to 10 seconds of unplugging (README.md:61). It surprises users who work on battery, though: a session started on battery is affected only after the Mac has been plugged in (README.md:61).

- **B-4. A session the user started by hand. (5.8)** In every option, a start by hand during an agent session (a time option, `-w`, `--`, the picker) replaces the agent session instead of adding time to it or being refused (the handover, 5.8), and an agent session starts only when no session runs.
  - (a) Agent sessions never change the user's session. When it ends while Claude still works:
    - with the lid open, an agent session follows within a pass (2 s);
    - with the lid closed, the Mac still sleeps at your session's end, even while Claude works (awake-helper:850-855), and Claude's turn stalls until you open the lid. Then an agent session follows (B-11).
    The README says this plainly. **Recommended.**
  - (b) While Claude works, the user's timed session is extended past its end. The Mac stays awake with the lid closed, but a session the user timed no longer ends when they said.
  - (c) While a holder works and the lid is closed, the watcher adds 5 minutes at a time to the user's timed session, and `--status` says so. Claude's turn does not stall, and the session ends at most 5 minutes after Claude stops. It costs a helper run per 5 minutes, and it still changes a session the user timed.

- **B-5. What a stop by the user does while Claude works. (5.8)** That is a click on the icon, `Stop session`, `awake --stop` or plain `awake`, of an agent session or of the user's own.
  - (a) It ends the session. Agent sessions then pause until Claude's next turn starts while the lid is open: a prompt typed at the Mac, or a background subagent's report, a `/loop` iteration or a message from another session (hooks.md:1325-1329) that arrives while the lid is open. With the lid closed nothing clears the pause. **Recommended.**
  - (b) It pauses agent sessions until the user turns the setting off and on again.
  - (c) No pause. The next tool call starts a session again, so a stop seems not to work.

- **B-6. Notifications. (5.11)**
  - (a) None for an agent session's start or its normal end, as both come with every turn. When a guardrail ends an agent session (low battery, too hot, unplugged), the app posts it and says that Claude may still be working. The CLI posts none, by 2.4.0's rule. **Recommended.**
  - (b) Also `Claude finished` when a session ends normally. That is useful once, but with the lid open it comes after every turn.
  - (c) None at all, guardrail ends included.

- **B-7. A last look at Claude Code before the Mac may sleep. (5.5, W21)** When a time rule would end the last holder that keeps an agent session (the end grace, the waiting allowance, the idle limit, the background allowance), and when a tool starts for a session whose turn had ended and whose holder was dropped, the watcher runs `claude agents --json` once. That is "the supported way to read session state from outside Claude Code" (agent-view.md:779), and it gives each live session's `pid` and `status`, `busy`, `waiting` or `idle` (agent-view.md:774). A holder whose process reads `busy` goes back to working. Anything else, or a failed call, lets the time rule apply.
  - (a) Yes, if section 9 shows that it works with the installed Claude Code, starts no background supervisor (`claude daemon status` before and after; agent-view.md:757-758, 919), and takes under 1 s; otherwise (b). It covers what no hook signals: a prompt answered (B-1), a `/goal` or Stop-hook continuation that starts its first tool late, a plan run that thinks before its first tool, an MCP tool longer than the idle limit. It is one call at each expiry, not polling. **Recommended.**
  - (b) No. Time rules only, with the waiting allowance at 20 minutes (B-1) and the end grace at 3 minutes, so that a slow Stop hook or a plan run is covered more often. Each normal reply then keeps a closed Mac awake 3 minutes instead of 1.
  - (c) As (a), and also poll it during gaps of 2 minutes or more without hooks. The Mac sleeps sooner after an interrupt, but each poll starts `claude`, on a feature in research preview (agent-view.md:22).

- **B-8. Background work and scheduled wakeups after a turn. (5.5, W9)** `Stop` reports `background_tasks` (shells, subagents, monitors, workflows) and `session_crons` (scheduled wakeups and `/loop`) (hooks.md:2583-2605). Local background commands have no time limit (tools-reference.md:186, 190), so a dev server or `tail -f` can run for days.
  - (a) Background tasks keep the Mac awake for 1 hour, counted from the first `Stop` that reports some. Later `Stop`s that still report some do not renew it; only a `Stop` with none resets it. Scheduled wakeups never keep the Mac awake between iterations, and the README suggests a timed session for a `/loop` that should run with the lid closed. A long-lived dev server then costs at most one hour, once. **Recommended.**
  - (b) 1 hour, renewed at every `Stop` that reports background work. A dev server started once then keeps a closed Mac awake for an hour after every turn.
  - (c) As (a), and a non-empty `session_crons` counts as background work, under the same allowance.
  - (d) None. Only background subagents keep the Mac awake, through their own holders (5.6). A background build ends with the Mac asleep if the lid is closed.

- **B-9. Remote Control between turns. (5.5)** Remote Control from a phone is a main reason to keep a closed Mac awake while away. A sleeping Mac drops the session until it wakes (remote-control.md:16-18).
  - (a) As for any turn: the Mac may sleep 60 s after each reply, so the phone cannot send the next prompt to a closed Mac. The README points to `awake -w <claude PID>`.
  - (b) While Remote Control is connected, the end of a turn keeps the holder for the waiting allowance (10 minutes) instead of 60 s. A phone prompt within those 10 minutes reaches the Mac, and its turn starts the next 10 minutes. Hooks see `CLAUDE_CODE_BRIDGE_SESSION_ID` exactly while the connection is up (env-vars.md:220, since 2.1.199), so this costs one builtin test in the hook. With "Enable Remote Control for all sessions" (remote-control.md:180-193) every turn gets 10 minutes. **Recommended.**
  - (c) Keep the Mac awake for the whole connection. No hook reports the connection's end, so the holder would need a time limit anyway.

- **B-10. Usage-limit and API-error waits. (5.5)** A claude.ai usage limit stops Claude in the middle of a task. Claude Code then waits and goes on by itself at the reset, which is on by default for subscriptions (interactive-mode.md:657), through a prompt that runs `UserPromptSubmit` (interactive-mode.md:688). `/goal` retries by itself after an overloaded server (goal.md:145).
  - (a) `StopFailure` ends the turn like `Stop`. With the lid closed the Mac sleeps a minute later. If it sleeps more than about 30 minutes across the reset, Claude Code waits for Enter (interactive-mode.md:671). The README says so. **Recommended**: the wait can last hours, and nothing signals its end before the reset.
  - (b) As (a) for `rate_limit`, but `StopFailure` with `overloaded` or `server_error` (hooks.md:2679) keeps the holder for the waiting allowance, so that `/goal`'s retries run on a closed Mac.
  - (c) Keep the Mac awake until the reset.

- **B-11. May an agent session start while the lid is closed? (5.9, W20)**
  - (a) No. An agent session starts only while the lid is open, and once it runs it goes on with the lid closed. So a `/loop` iteration, a scheduled task or a background report that fires while a sleeping Mac is briefly awake never starts a session in a bag. Neither does a holder that outlived a sleep, nor the end of the user's own session with the lid closed (B-4). A Mac in clamshell mode with an external display stays awake through the display, not through Awake. **Recommended.**
  - (b) Yes, except after a stop by the user or after a session ended with the lid closed, until the lid has been open. A wakeup after a normal end can still start a lid-closed session in a bag.
  - (c) Yes, always.

### Release

- **R-1. Where does the code go while 2.4.0 is in its QA? (section 10)**
  - (a) A branch `dev-2.5` from `dev`, with a draft PR into `dev` so that CI runs. It is merged once 2.4.0, and any 2.4.x, has shipped, as faster-start-stop-2.md question X-2 (a) described. The CHANGELOG entries go in one commit after that merge (faster-start-stop-2.md X-4 (a)). **Recommended.**
  - (b) No code until 2.4.0 ships, then on `dev`.
  - (c) Into 2.4.0. That changes the build under QA. Not recommended.

## How this plan was checked

- **Code.** Written on Linux, from the code at `a9cd6d1`. Every line number in `bin/awake`, `bin/awake-helper`, the app and the scripts was read at that commit.
- **Sources.** Three research passes came first: Adrafinil and the other tools, Claude Code's hooks, and Awake's own code. Their notes and copies are in the scratch folder `agent-plan/research-*`.
- **Claude Code docs.** They are cited as `<page>.md:LINE`. These are lines of the raw pages `https://code.claude.com/docs/en/<page>.md`, downloaded on 2026-10-06 and downloaded again by the second review that day, byte for byte the same. The plugin page is `plugins/components.md`. Claude Code's changelog is cited as `cc-changelog.md:LINE`, lines of `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` on that day.
- **Adrafinil.** It is cited as `adrafinil@6e4eece path:lines`, which means `https://github.com/kageroumado/adrafinil/blob/6e4eece4dd5a3155eea93ef71d3c785716114b1b/path#Llines`. In section 1, paths under `AdrafinilShared/Sources/AdrafinilShared/` are shortened to their last parts, such as `Policy/CutoutLatch.swift`. The other repositories are cited at the commits named in section 1.
- **No code was copied.** This plan describes Awake's own design. It takes ideas and observed behaviour from Adrafinil (MIT), never its code.
- **Probes.** Two probes from the research ran today's `awake` in the dry run under the Linux macOS emulation (`agent-plan/research-awake/lease-probe.sh` and `holders-probe.sh`, scratch). Three more ran for this plan (`agent-plan/draft/probe`, scratch), on bash 5.2 only, as no bash 3.2 build was at hand:
  - a fast path at the top of a copy of `bin/awake`: 3.0 ms per run, against 2.9 ms for `bash -c 'exit 0'` and 24.7 ms for `awake --version` (50 runs each);
  - reading a hook's stdin with one `cat` and pulling out top-level fields with regular expressions: 7 to 8 ms for a `Stop` payload, and 72 ms for a 3 MB prompt, in which a quoted `\"agent_id\":\"evil\"` did not match;
  - incremental reads of an append-only file through a descriptor kept open, which also showed that a line not yet ended by a newline is consumed by `read` (decision W3).
  None of this ran on macOS, under Apple's bash 3.2, or with Claude Code. Section 9's preflight checks the facts the design rests on before any code is written.
- **Reviews.** Two reviews on 2026-10-06. One checked about 60 of the file:line citations against `a9cd6d1` and found them accurate; it found seven holes in the design (starts by hand during an agent session, exec form on older Claude Code, lost events and stale locks, an end that could hit the user's session, real `sudo` in the dry run, restarts in a bag, the installer switching the lid mode) and a dozen smaller points. The other downloaded every source again and found the claims about other tools accurate, with two wrong and two stretched citations; it found six cases where the holder rules surprise a user (`idle_prompt` during background work, renewed background hours, approved prompts, Stop hooks and `/goal`, a plain `/clear`, Remote Control) and several missing owner questions. All of their points were applied. Four were adapted rather than taken as written:
  - The pattern proposed for top-level fields, `^\{[^{]*"agent_id"…`, fails whenever an object comes before `agent_id`, and the common fields include one: `effort`, on exactly the tool events where `agent_id` matters (hooks.md:736). The hook instead cuts the payload at the first content key and looks for the ids before it (W2).
  - The first review's rule that a `working` event never reopens an ended holder, and the second's `PreToolUse` heartbeat that must revive one after a Stop hook continues the turn, contradict each other. They are reconciled by telling `PostToolUse` (`working`) from `PreToolUse` (`tool-start`), by a 2-second rule, and by the last look (5.5, W22).
  - The pause "until the lid is open" that the first review proposed after a stop and after the user's session ends with the lid closed is generalised into one rule: an agent session never starts while the lid is closed (B-11, W20).
  - A plain `/clear` gets its own verb, as the second review proposed, and the last look covers a plan run that thinks longer than the grace before its first tool (5.6).
  The second review cited interactive-mode.md:703-706 for the continuation through `UserPromptSubmit`; the line is interactive-mode.md:688.
- **Not readable.** Some sources could not be read:
  - Codex's and Cursor's web docs, geminicli.com, and aider.chat: blocked by the proxy. The GitHub sources were read instead.
  - The comment threads of Adrafinil's GitHub issues: only the opening reports were readable. Fixes were confirmed from commits.
  - The GitHub API for Adrafinil and for anthropics/claude-code: it answered 403. The Claude Code issues were read through the web pages.
  - kagerou.glass/adrafinil: not fetched.
  - The second half of the long hooks page through the summarising fetch tool. The raw `hooks.md` was read in full instead.
  Where a fact rests on one of these, the plan says "not found".

## 1. What other tools do

### Adrafinil

Adrafinil keeps a MacBook awake, also with the lid closed, only while at least one agent session holds it. With no holder the Mac sleeps normally, lid close included (adrafinil@6e4eece README.md:38-46, 63). It is MIT-licensed, needs macOS 26.4 or later, and ships as a notarized DMG and an official Homebrew cask (README.md:76-85, 224).

- **What it hooks in Claude Code.** It writes handlers into `~/.claude/settings.json` (…/Installer/Integrations/ClaudeCodeIntegration.swift:61-104):
  - `UserPromptSubmit` acquires and `Stop` releases;
  - `Notification` with matcher `idle_prompt` releases, as a fast path it does not rely on;
  - `SubagentStart` and `SubagentStop` acquire and release per `agent_id`;
  - `SessionEnd` releases;
  - `SessionStart` with matcher `clear` acquires;
  - an optional `PreToolUse` on `Bash` holds `run_in_background` commands, with a time limit (:117-132).
- **Why per turn and not per session.** An earlier version held the Mac from `SessionStart` to `SessionEnd`, so it was also awake while the session sat idle at the prompt (commit ffda975; ClaudeCodeIntegration.swift:5-10).
- **Leases.** Hook calls are idempotent leases in a per-user LaunchAgent daemon, keyed `<tool>:<session_id>`. The id comes from the hook's stdin JSON, with `$CLAUDE_CODE_SESSION_ID` as the fallback, on purpose: `SessionEnd` carries the retiring session's id on stdin and `SessionStart` the new one (ClaudeCodeIntegration.swift:26-28, 43-47, 93-96). Sleep is blocked while any lease exists (AssertionRegistry.swift:40-42, 64-107; AcquireCommand.swift:125-139).
- **Safety nets for a missed release:**
  - an exit watch on the owning `claude` process, found by walking up the parent processes (ProcessResolver.swift:16-29; ProcessWatcher.swift:28-81);
  - a sweep every 30 s that releases a lease whose process tree stays under 3% CPU for 90 s, where Claude Code's own `caffeinate` child counts as working (IdleReleaseEvaluator.swift:9-41, 86-166; PowerAssertionReader.swift:4-49; Models/AdrafinilSettings.swift:62). This sweep is also what ends the hold after a plain `/clear` ("a bounded cost", ClaudeCodeIntegration.swift:36-39);
  - time limits, and a 24 h backstop.
- **Waiting for the user.** It reads Claude Code's internal `~/.claude/sessions/<pid>.json` (status busy, idle or waiting) every 10 s. That file is rewritten when a dialog is answered, also from a phone over Remote Control (ClaudeSessionStatus.swift:3-79, 7-12). By default it keeps the Mac awake for 10 minutes of waiting (SessionWaitEvaluator.swift:18-137).
- **Hooks never fail the agent.** Acquire and release exit 0 on every failure, as exit 2 on `UserPromptSubmit` would block and erase the user's prompt (AcquireCommand.swift:8-16).
- **Installing.** Per handler, and in place: other handlers in the same group survive. Files that are not a parseable JSON object, or that change during the edit, are refused. Writes go through symlinks and keep the file's permissions. Uninstalling strips only Adrafinil's handlers, from every event (NestedJSONHookShape.swift:90-106, 163-217; ConfigFileIO.swift:7-11, 29-62).
- **Root rights.** A root helper whose one job is `pmset -a disablesleep 1|0` plus an IOPM assertion (AdrafinilHelper/SleepBlocker.swift:8-35, 101-171). Its notes say that only `pmset -a disablesleep 1` kept a lid-closed Mac without a display awake (Docs/ARCHITECTURE.md:55-65).
- **Cutouts.** Thermal at 80 °C and battery at 20%, both only with the lid closed. A cutout latches until the hazard recedes or the lid opens, so that the agent's next hook does not start the hold again at once (Models/AdrafinilSettings.swift:43-50; Policy/CutoutLatch.swift:3-75).
- **The lid.** By default it locks the screen when the lid closes while it holds, "so the awake machine is still secured", and it can play a chime (Models/AdrafinilSettings.swift:39-41; LidActionDecider.swift:37-44).
- **Its issues and commits list the pitfalls** this plan has to answer:
  - Esc fires no `Stop`, and `idle_prompt` often does not fire (commits 8c17e4d, 11aa5d1; ClaudeCodeIntegration.swift:12-18);
  - a dialog left open held the Mac for 48 minutes (issue #20);
  - `/clear` and plan approval leaked a hold for 64 minutes (issue #19, commit 6dbdd6a);
  - the Mac slept while background work went on after `Stop` (issue #7);
  - the native install's file name is a version number, so a crashed agent was not found (commit 3d7f687);
  - its CPU-idle rule needed three fixes (11aa5d1, 1e67aec, afd5971);
  - its thermal cutout did not work on Apple silicon until a device test (c0bbb49).

### The others

- **keepawake** (ecc521/keepawake@683ec26) has no agent features. It wraps a command with `pmset -a disablesleep` through a sudoers rule limited to those two commands (README.md:16-56). It counts concurrent sessions with a shared `flock` that the kernel drops when a session is killed (cli/keepawake/main.swift:484-560).
- **clawake** (ItaiZeilig/clawake@534e93e) is now On/Off only (README.md:41-53). It documents that the screen still locks unless an option keeps it unlocked (README.md:51, 100-101). On 2026-08-31 (commit 2b67ced) it removed a "Follow Claude sessions" mode, which:
  - posted hook events to a Unix socket;
  - counted a session as live for 15 minutes after its last hook and its last transcript change;
  - wrote `{}` over a `settings.json` it could not parse (2b67ced^ Sources/Clawake/ClaudeHooks.swift:19-37, 72-83).
- **Codex** has an experimental `prevent_idle_sleep`, off by default. It holds an IOPM assertion "Codex is running an active turn", which does not cover a closed lid (codex-rs/features/src/lib.rs:1942-1959 and codex-rs/utils/sleep-inhibitor/src/macos.rs:23-26, both at `c0c230e`).
- **Claude Code itself** spawns `caffeinate` while it works:
  - Its changelog for 2.1.83 says "Fixed `caffeinate` process not properly terminating when Claude Code exits, preventing Mac from sleeping" (cc-changelog.md:5904).
  - Issue reporters see `caffeinate -i -t 300`, renewed while a session is busy (https://github.com/anthropics/claude-code/issues/64522, closed as not planned; #85261 and #21432 are open).
  - `caffeinate -i` prevents idle sleep only, not sleep on lid close (README.md:25).

### What to take, and what to avoid

| From | Take | Avoid, or do differently |
|---|---|---|
| Adrafinil | Hold per turn (`UserPromptSubmit` to `Stop`), not per session. Release on `SessionEnd`, and mark `SessionStart` `clear`, for a plan approved with a cleared context. Hold sub-agents by `agent_id`. Take ids from stdin first. Hooks always exit 0, print nothing, and never ask for anything. Watch the agent's process. Give waits a grace. Latch after a guardrail end. Install per handler and remove only our own handlers. Refresh the hooks at upgrade. | No always-running daemon or LaunchAgent: Awake's watcher runs only while there is agent work. No new root code: Awake's helper, guardrails and boot-restore do the `pmset` part. No marker key in `settings.json`, as Claude Code shows a Settings Error for a value its schema rejects (settings.md:607): Awake's handlers are found by their command. No CPU or network heuristics (Adrafinil reverted an open-socket rule that pinned the Mac, commit 9115653). No reading of `~/.claude/sessions/*.json`, whose format is not documented (claude-directory.md:1562): `claude agents --json` is the documented way (B-7). No MCP server in version 1. |
| keepawake | A count that a crash cannot leak. | `flock`: macOS has no `flock(1)`, and one watcher with an event log (W3) needs none. |
| clawake | Heartbeats as a fallback signal, with a time limit. | Writing over a file it cannot parse. Sessions held for 15 minutes after the work. |
| Codex | Its `Interrupt` hook, when Codex follows (S-2). | |
| Claude Code's own `caffeinate` | Lid-open agent sessions add little to it (H-2). | Using it as a signal (O6). |

## 2. What Claude Code gives a keep-awake tool

What the design rests on:

- **Hooks fire wherever Claude Code runs:** the terminal, IDE extensions, the Desktop app, and cloud sessions (hooks.md:13). Cloud sessions do not read the local `~/.claude/settings.json` (hooks.md:265), which does not matter here. Hooks also run inside subagents, whose tool events carry `agent_id` and `agent_type` (hooks.md:269).
- **Three cadences** (hooks.md:21-25):
  - per session: `SessionStart` and `SessionEnd`;
  - per turn: `UserPromptSubmit`, and `Stop` or `StopFailure`;
  - per tool call: `PreToolUse` and `PostToolUse`.
- **How handlers run.** All matching hooks run in parallel, and identical handlers from several settings files run once (hooks.md:412). They run in the session's current folder, with Claude Code's environment (hooks.md:414). The default timeout is 600 s for command hooks, 30 s for prompt hooks and 60 s for agent hooks, and it is not enforced on an async command hook (hooks.md:426, 3730).
- **`UserPromptSubmit`** also fires for a scheduled task or `/loop` iteration, for a background subagent reporting back, and for a message from another session (hooks.md:1325-1329). It blocks the prompt until the hook returns, with a 30 s default timeout (hooks.md:1331). Exit 2 blocks the prompt. Any other non-zero exit is a non-blocking error (hooks.md:776-850). Plain stdout of `UserPromptSubmit` and `SessionStart` hooks is added to Claude's context (hooks.md:786), so Awake's hooks must print nothing.
- **`Stop`** "does not run if the stoppage occurred due to a user interrupt". API errors fire `StopFailure` instead (hooks.md:2567-2569; hooks-guide.md:960). Since 2.1.145 (cc-changelog.md:4540), `Stop` and `SubagentStop` carry `background_tasks` and `session_crons`, which are meant to tell "session is done" from "paused waiting for background work" (hooks.md:2575, 2583-2605). `/goal` is a session-scoped prompt-based `Stop` hook after which Claude starts another turn (hooks.md:2571-2573; goal.md:9, 120). Whether such a continuation fires `UserPromptSubmit`: not found.
- **`StopFailure`** carries `error`: `rate_limit`, `overloaded`, `server_error` and others (hooks.md:2675-2679).
- **`SessionEnd`** fires on exit, `/clear` and an in-session `/resume`. All `SessionEnd` hooks share a budget of 1.5 s, which a per-handler `timeout` in a settings file raises to match, up to 60 s (hooks.md:3388-3393).
- **Subagents.** `SubagentStart` and `SubagentStop` carry `agent_id` (hooks.md:2390, 2426). Subagents run in the background by default (hooks.md:1762). `SubagentStop` also fires for internal agents, with an empty `agent_type` (hooks.md:2428).
- **The top-level fields.** Every event carries `session_id`, and inside a subagent `agent_id`; the common fields also include `effort`, an object, on tool events, `Stop` and `SubagentStop` (hooks.md:730-743). Tool events add `tool_name`, `tool_input` and `tool_response`. Inside any JSON string a quote is escaped, so an unescaped `"agent_id":` can only be a key: at the top level, or nested in `tool_input` or `tool_response`.
- **Waiting signals.**
  - `PermissionRequest` fires the moment Claude Code is about to ask for permission. `Notification` `permission_prompt` fires only after about 6 s (hooks.md:1916-1921, 2298).
  - `PreToolUse` matches `AskUserQuestion` and `ExitPlanMode` (hooks.md:1580). A question stays open until it is answered, unless `askUserQuestionTimeout` is set, and permission prompts never close on their own (tools-reference.md:131-137).
  - `idle_prompt` fires when "Claude finished responding about 60 seconds ago and you haven't typed since", and only if no background agent, such as a background subagent, still runs; not while Claude Code waits for a usage limit to reset (hooks.md:2299, 2321). Whether a background shell holds it back, and whether it fires after an interrupt: not found.
- **Tools.** A foreground Bash call runs 2 minutes by default and at most 10, unless `BASH_MAX_TIMEOUT_MS` is raised (tools-reference.md:157-161). MCP tools time out after about 28 hours by default (env-vars.md:483). Background commands of a local session have no time limit and outlive the reply (tools-reference.md:186, 190).
- **Environment.** Hooks get `CLAUDE_CODE_SESSION_ID`, which "matches the `session_id` field in the hook JSON input and is updated on `/clear`" (env-vars.md:371). `CLAUDE_CODE_BRIDGE_SESSION_ID` is set while Remote Control is connected and removed when it ends, since 2.1.199 (env-vars.md:220; hooks.md:416). `CLAUDE_CONFIG_DIR` moves the settings folder, "useful for running multiple accounts side by side" (env-vars.md:418).
- **No terminal.** Command hooks run "in their own session without a controlling terminal" and cannot open `/dev/tty` (hooks.md:720).
- **Forms.** A command hook runs in exec form when `args` is set and in shell form, `sh -c` on macOS, when it is not (hooks.md:466-470). `args` exists since 2.1.139 (cc-changelog.md:4758); what an older version does with it: not found. A command hook with `"async": true` runs in the background and cannot block anything. In `-p` mode it is killed at teardown (hooks.md:3703-3735).
- **Settings files.** Claude Code watches them and applies hook edits to a running session (settings.md:584). A file with "a value the schema rejects" is a Settings Error, and the session may go on without it (settings.md:607).
- **Where hooks do not run:**
  - in an interactive session, hooks from every settings file, `~/.claude/settings.json` included, wait until the folder is trusted (hooks.md:3813-3818);
  - managed `allowManagedHooksOnly` blocks user and plugin hooks (hooks.md:270-280), and managed settings can come from a file, an MDM profile or the claude.ai console (managed-settings.md:61-71);
  - `disableAllHooks` turns them off, and a project's value overrides the user's (hooks.md:706-712);
  - `claude -p --bare` skips hooks (headless.md:37).
- **`claude agents --json`** lists every live session with `pid` and `status` (`busy`, `waiting` or `idle`), `waitingFor` and `sessionId` (agent-view.md:762-777). It is "the supported way to read session state from outside Claude Code" (agent-view.md:779). Agent view is in research preview (agent-view.md:22). After a `claude daemon stop`, "the next `claude agents` or `claude --bg` starts a fresh supervisor" (agent-view.md:758); whether `claude agents --json` starts one on a Mac that runs none, and whether `disableAgentView` (agent-view.md:836) turns it off: not found.
- **Remote Control.** "If your laptop sleeps" the session reconnects when it wakes, and "your computer has to stay on" (remote-control.md:16-18). A Mac asleep with the lid closed cannot take the next prompt from a phone.
- **Usage limits.** Claude Code waits for a claude.ai usage limit to reset and goes on by itself; after a sleep of more than about 30 minutes across the reset it waits for Enter (interactive-mode.md:655-671, 688).

What it does not give:
- no hook for an interrupt (Esc, or Ctrl+C, which "interrupts a running operation", interactive-mode.md:21);
- no documented hook when the terminal window is closed or the process is killed;
- no hook when a permission prompt is answered;
- no hook for the end of a background shell: none was found in hooks.md (`TaskCompleted`, hooks.md:2509-2513, is for tasks and teammates).
Awake's own watch on the agent's process, its time limits and the last look cover these gaps (5.4, 5.5, 5.7).

## 3. Awake today

What already works, with no change:

- **Headless runs.** `awake -- claude -p "<task>"` keeps the Mac awake, also with the lid closed, for the whole run, and exits with Claude's status (README.md:44, 371). This is the exact fit for one-off headless work, and it needs no hooks.
- **The whole lifetime of an interactive `claude`.** `awake -w <PID>`, or `While` in the picker, which lists the user's terminal commands (tools/awake-gui-picker.swift:526-596), keeps the Mac awake for the process's whole life. That includes the time it waits at the prompt. It ends with `process_exited`, and with the lid closed the helper then sleeps the Mac (awake-helper:850-855).

What is missing for "while Claude works":

- **A tie to Claude's turns, not its process.** A session can watch one PID (555-562, 7083-7100) or end at a time. It cannot follow turns.
- **A start without a terminal and without a prompt.** A hook has no terminal, so `awake` runs in GUI mode (7144-7172). A lid-closed start would then show the macOS password dialog, unless password-free mode or a valid sudo ticket covers it (`run_helper` 4133-4207, `run_as_admin` 4060-4131).
- **Calls that run side by side.** State changes take a `mkdir` lock with 100 tries of 0.1 s, then fail with "Another awake command is already changing the session state." (1416-1463, 1446). Hooks of parallel sessions and subagents run at the same time (hooks.md:412).
- **A cheap call.** Parsing all of `bin/awake` costs about 23 ms before anything runs (lease-probe, research), and that would come on every tool call.

Facts the design reuses:

- **How a session tied to a process works.**
  - For a lid-closed session, the root helper's timer checks the watched PID every 2 s with `kill -0`, and every 10 s also its start time (awake-helper:86, 537-548, 1393-1398). The guard checks it too once the timer is gone (awake-helper:1503).
  - For a lid-open session, the Caffeine runner does the same (6029-6041).
  - The helper checks that the PID is the user's own, and records `watch_pid` and `watch_started` in its session file (awake-helper:934-944, 769-770). A lid-open session records the same in its state file (6384-6387).
- **How such a session ends at once.**
  - Lid-closed: `request_helper_session_stop command-finished` writes `command-finished` and wakes the timer through the FIFO (4320-4376, 4308-4318). The helper ends any session of that user as `process_exited` when the file exists; it only tests whether the file exists, and never reads the token in it (awake-helper:39-46, 1353-1356, 1495-1497). `request_helper_session_stop` writes whatever token is current when it is called (4342-4350). The probe confirmed the end for a session that was not tied to a process.
  - Lid-open: `command-finished` with the token, then TERM to the worker, which then records `process_exited` (4486-4504, `caffeinate_stop_reason` 4446-4453).
  - `finish_session` sleeps the Mac with the lid closed only for `timeout`, `low_battery`, `overheated`, `unplugged` and `process_exited`, never for a user's `stopped` (awake-helper:845-856). Clearing the sleep settings alone does not sleep a closed Mac: "macOS decides on clamshell sleep only when the lid, the power source or the displays change" (awake-helper:621-624).
- **One lid-closed session per Mac.** A second start is refused with exit 3 (awake-helper:962).
  - A `-w` or `--` start while a session runs is refused (7262-7266).
  - A time option instead adds time (7268-7377), or, for a session with no end time, says "Awake already runs until NAME (PID n) exits." (7299-7310). `--indefinite` removes the end time (`run_helper … extend UID none`, 6737).
- **The main lock** has a pid file with the holder's start time and a takeover of a stale lock (1377-1463). `acquire_main_lock` exits after its 100 tries, and sets an `EXIT` trap that writes the status report and releases the lock (1444-1448, 1462; `finish_main_run` 1311-1314).
- **Status.** A session tied to a process reads `Awake is on until NAME (PID n) exits[, with at most X left]` (3042-3045). The JSON has `watch_pid`, `watch_command` and `end_mode` (3190-3333). The app mirrors the sentences, and a comment asks to keep them in sync (StatusDescription.swift:22-54; 3038). In the app, `schemaVersion` and `active` are required and the other fields optional (AwakeCLI.swift:10-20).
- **Notifications.** The CLI posts none unless asked, except `Awake failed` for a refused start that no terminal shows (25-37, `report_start_failure` 4590-4607). The app posts end notifications only for the sessions it started, and only when a poll goes from active to inactive (StatusBarController.swift:604-606, 613-615). It polls every 10 s (StatusBarController.swift:106-109).
- **The helper protocol** is 9 in both files (172; awake-helper:56). A different number makes `run_helper` install the helper behind a password prompt (4160-4172). A hook must never get there.
- **Password-free mode** lets the user run the helper with any arguments without a password (4737). README.md:103 states the trade-off: "any program running as you can then change the sleep settings the way Awake does".
- **The dry run.** `helper_is_ready` accepts the copy of the helper next to the script and skips the admin-only checks (3947-3961), and `run_helper` returns before `run_as_admin` (4145-4159). `helper_runs_without_password` runs the real `/usr/bin/sudo -n` (4052-4055); its only caller skips it in the dry run (7599-7600). GitHub's macOS runners have passwordless `sudo` (https://raw.githubusercontent.com/github/docs/main/content/actions/reference/runners/github-hosted-runners.md, line 77).
- **Detached processes.** `start_detached` starts an internal mode of `awake` in its own process group with `nohup`, and prints the child's PID on its stdout (3567-3573). It does not change folder.
- **The probes.**
  - A watcher stand-in tied to the session with `--start -w`, which exits once no holder file names a live process, kept the session through the release of one of two holders. It ended it as `process_exited`, with one mock `sleepnow`, about 3 s after the last holder's process died. All of this ran on today's code (`holders-probe.sh`).
  - Repeated `--start --until @now+300` calls also work as a lease. But each one runs the helper, and it silently extends a session the user started (`lease-probe.sh`, steps 1-3 and 10).

## 4. Design options

| # | Option | For | Against |
|---|---|---|---|
| O1 | **Hooks drive holders, with a watcher, time limits and a last look** (recommended). `UserPromptSubmit`, `Stop`, `SessionEnd`, the tool events, the subagent events and a few others mark holders. One user-level watcher runs a session tied to its own PID while any holder needs it, and ends it about a minute after the last one. The agent's process exit and time limits cover missed events, and one `claude agents --json` call checks before a time rule lets the Mac sleep (B-7). | Documented events, so the session follows Claude's turns. It reuses `-w`, `command-finished` and the helper as they are, with protocol 9. Several sessions and subagents are just several holders. The helper ends the session within 2 s if the watcher dies. | A one-time setup in Claude Code's settings (H-1). An interrupt fires no hook, so it is covered by `idle_prompt` if it fires, or by the 15-minute limit (5.4). Lid-closed needs password-free mode (H-2). |
| O2 | **Hooks renew a lease:** `awake --start --until @now+N` on each event (design A of the research). | Almost no new code (`lease-probe.sh`). | Every renewal runs `sudo` and the helper with its own battery and thermal reads (awake-helper:1078-1113). A tool call longer than N ends the session mid-call. It extends a session the user timed. No early end that sleeps the Mac. |
| O3 | **`awake -w <claude pid>`**, by hand or from a `SessionStart` hook. | Works today (3). | Covers the whole process life, idle time at the prompt included, which is the session-scoped mistake Adrafinil moved away from (ffda975). Background agent-view sessions keep their process for about an hour after they finish (agent-view.md:807, 948). |
| O4 | **`awake -- claude -p "<task>"`** for headless runs. | Works today, needs no hooks, and passes the exit status through (README.md:44, 371). | Headless runs only. Documented as the way for one-off runs, next to O1. |
| O5 | **An MCP tool** (`keep_awake(minutes, pid)`, `release_awake`), as Adrafinil has (adrafinil@6e4eece AdrafinilCLI/MCP/MCPServer.swift:4-126). | The model can hold the Mac for work that outlives its reply, such as a background build. | Only when the model decides to call it, so it cannot follow turns. JSON-RPC in Bash 3.2 is a project of its own. Later at most (section 12). With the handover (5.8), Claude can already run `awake --duration 1h` or `awake -w $!` through its Bash tool where permissions allow; that replaces the agent session with the session it asked for. |
| O6 | **No hooks: watch Claude Code's own `caffeinate` child**, or the assertion "caffeinate command-line tool", with one `ps` every 15 to 30 s. | No setup. Covers every surface that spawns it. Adrafinil's source says it runs exactly while `isLoading && !waitingForApproval` (PowerAssertionReader.swift:3-17). | Not documented. Issues ask for a way to turn it off (#21432, #85261). Adrafinil's own commits disagree whether it was there (34d023e against 9115653). It cannot tell waiting from idle. It needs a process that is always running to start a session. |
| O7 | **No hooks: poll `claude agents --json`.** | Documented as the supported interface, with busy, waiting and idle per PID (agent-view.md:762-779). | Research preview. Each poll starts `claude`, at a cost nobody has measured. It needs an always-running poller to start sessions. O1 uses it only for a last look at each expiry (B-7 (a)); polling is B-7 (c). |
| O8 | **A menu bar choice.** | What the owner asked for: "be able to select". | Not a mechanism of its own. It is the switch for O1 (S-1 (a), S-3), or a one-off choice in the picker on top of O1 (S-1 (b)). |
| O9 | **A Claude Code plugin** that carries O1's hooks. | Claude Code owns the configuration. | See H-1 (b). |

Recommended: O1, switched on and off from the menu (O8), with O4 documented for headless runs. Version 1 has no MCP tool (O5), and O6 is not one of its signals.

## 5. The recommended design: behaviour

### 5.1 Words

- **Agent session:** a session that Awake starts by itself because Claude works. It is lid-closed (or lid-open, H-2), tied to the watcher's PID, with a time limit of 12 h.
- **Holder:** one reason to stay awake. Its key is `s:<session_id>` for a main conversation and `a:<agent_id>` for a subagent. It has a state (5.5), the agent's process ID and start time, and the times of its last events.
- **Watcher:** an internal `awake --agent-watch` process, started by a hook when needed. It reads the hooks' events, keeps the holders, and starts and ends agent sessions. Only one runs per user.
- **Event:** one line that a hook appends to `agent-events` in the user's runtime folder (W3).
- **Tombstone:** the time of a key's last `turn-end`, `agent-end` or `session-end`, kept until that key's next turn starts (5.5).
- **Last look:** one `claude agents --json` call before a time rule lets the Mac sleep (B-7, W21).

### 5.2 When a session starts

1. A hook runs. It appends its event (W3). If its verb may start work (5.5) and no live watcher answers, it goes on to `main`, which starts one (W4). It then exits 0, in about 10 to 25 ms on a Mac (estimate, W14, W.8).
2. The watcher reads the event and creates or updates the holder. It starts an agent session when all of these hold:
   - a holder that may start a session exists: `working`, `waiting`, `background` or `remote` (5.5);
   - no session runs, which the watcher reads from the helper's session file and the lid-open state file with builtins on each pass, so it never runs a start that would be refused;
   - no pause stands (5.8, 5.9);
   - the lid is open (B-11).
   The hook never waits for this, so the prompt is not held up by the session's start, which takes about half a second with the lid closed (faster-start-stop-2.md:144).
3. The start is `awake --agent-session -w <watcher PID> --duration-seconds 43200 --backend B --min-battery N --thermal-guard T --unplug-guard U --keep-display off --no-notifications`, run by the watcher as a child.
   - `B` is the stored lid mode (H-2, K8), and lid-closed only when `helper_runs_without_password` succeeds (4052-4055); in the dry run a mock decides (W12).
   - `N`, `T` and `U` are the guardrails (B-3).
   - `--agent-session` makes the start ask for nothing: no password dialog, no helper install (W12). It also records the session as an agent session.
4. A start that fails anyway (for example "Another awake command is already changing the session state", 1446) is tried again at most once a minute.
5. With the lid-open backend, sleep settings left by an earlier lid-closed session would first need `run_helper restore` (7625-7641), which the agent's transport refuses. The watcher then starts nothing, sets `agent_note` to "Run awake --stop to restore the sleep settings.", and does not try again until they are gone.

### 5.3 How it is kept alive

- The session is tied to the watcher's PID, so neither the helper nor the Caffeine runner ends it while the watcher runs (awake-helper:1393-1398; 6029-6041).
- The watcher keeps it while at least one holder keeps it (5.5). Hooks only append events. They never change the session.
- The 12 h limit is the session's own time limit, which the root helper ends on its own. It is a safety cap, not a promise about Claude's work, so the status sentence does not show it; `--status-json` has it as `deadline_at`. A start by hand replaces the agent session (5.8) instead of moving this limit. The app hides `Add` for agent sessions (M4).

### 5.4 When and how it ends

1. **The work stops.** When no holder keeps the session any more, after the last look (B-7), the watcher ends it at once (W6). It takes the main lock, checks that the running session is its own (its `watch_pid` is the watcher's PID and its `watch_started` the watcher's start time), and asks for the end with that session's token: `command-finished` for a lid-closed session, or `command-finished` and TERM to the worker for a lid-open one, as `run_bound_command` does (4486-4511). The reason recorded is `process_exited`, so with the lid closed the helper sleeps the Mac (awake-helper:850-855). The end grace of 60 s is part of the holder rules (5.5), so a quick next prompt, or a Stop hook that continues the turn, does not end a session only to start a new one.
2. **The watcher dies** (killed, or a bug). The helper or the runner finds its PID gone within 2 s and ends the session as `process_exited` (awake-helper:1393-1398; 6033-6040). This needs no change.
3. **The 12 h limit:** `timeout`, which sleeps a closed Mac. Agent sessions then pause (5.9).
4. **A guardrail:** `low_battery`, `overheated` or `unplugged`, as for every session. Agent sessions then pause until the cause has gone (5.9).
5. **A stop by the user:** `stopped`, as today. That does not force sleep (awake-helper:847-849). Agent sessions then pause until the next turn starts with the lid open (5.8).
6. **An interrupt** (Esc, or Ctrl+C, interactive-mode.md:21) fires no hook (2). The `idle` verb, from `Notification` `idle_prompt`, ends a working holder whose last event is at least 50 s old, if it fires; that it fires after an interrupt is not documented, and Adrafinil found that it often does not (ClaudeCodeIntegration.swift:12-18). The documented backstop is the 15-minute idle limit, after which the last look reads `idle` and the holder ends.
7. **A start by hand:** the handover of 5.8 ends the agent session as `stopped`, with no pause.
8. **`--claude-hooks off`:** the same stop as a handover, then the watcher is stopped and its files removed (K11).

The watcher exits once no holder is left and no session of its own runs, under the exit protocol of W3, which loses no event that arrives meanwhile.

### 5.5 Holder states, and the rules

**Verbs.** Each handler (K.3) passes one verb:

| Verb | From | Starting verb |
|---|---|---|
| `turn-start` | `UserPromptSubmit` | yes |
| `turn-maybe` | `SessionStart` `clear` | no |
| `turn-end` | `Stop`, `StopFailure` | no |
| `session-end` | `SessionEnd` | no |
| `idle` | `Notification` `idle_prompt` | no |
| `agent-start` | `SubagentStart` | yes |
| `agent-end` | `SubagentStop` | no |
| `waiting` | `PermissionRequest`; `PreToolUse` for `AskUserQuestion` or `ExitPlanMode` | yes |
| `tool-start` | `PreToolUse` for any other tool (async) | yes |
| `working` | `PostToolUse`, `PostToolUseFailure` (async) | yes |

A starting verb that finds no live watcher goes on to `main`, which starts one; the others only append. Each event line carries the hook's start time in whole seconds (`/bin/date +%s`, one program per hook), the agent's process ID, `BG=1` when a `Stop` reports background tasks, and `RC=1` while Remote Control is connected (B-9). The log keeps the order in which the hooks finished.

**States.**

| State | Entered by | Keeps a running agent session | May start one | Left by |
|---|---|---|---|---|
| working | `turn-start`, `agent-start`; `tool-start` or `working` (rules below) | while the last sign of work is under 15 min old (the idle limit, B-2), then the last look | yes | `turn-end`, `agent-end`, `session-end`, `waiting`, `idle` (if the last event is at least 50 s old), process exit, the idle limit |
| waiting | `waiting` | for 10 min (B-1), then the last look | yes | `tool-start` or `working` at least 2 s later (the tool ran after the answer), `turn-start`, `turn-end`, `session-end`, process exit, the 10 min |
| background | `turn-end` with `BG=1` | until 1 h after `bg_since` (B-8), then the last look | yes | `turn-end` with `BG=0`, `turn-start`, `tool-start` or `working` at least 2 s later, `session-end`, process exit, the 1 h |
| remote | `turn-end` with `RC=1` and `BG=0` (B-9) | for 10 min (the waiting allowance) | yes | `turn-start`, `tool-start` or `working` at least 2 s later, `session-end`, process exit, the 10 min |
| ended | `turn-end` with `BG=0` and `RC=0`, `agent-end`, `session-end`, `turn-maybe` | for the end grace (60 s), then the last look | no | `turn-start`, `agent-start`, `tool-start` at least 2 s later (or `working`, for a `turn-maybe` holder, which has no tombstone); dropped after the grace |

**Rules.**

- **The 2-second rule.** Async hooks of the previous tool can finish after the sync event that followed them in Claude Code. So `tool-start` and `working` change a holder that is `waiting`, `background`, `remote` or `ended` only when their time is at least 2 s later than the event that put it there. An answer within 2 s followed by a short tool is caught by the next event.
- **Tombstones.** `turn-end`, `agent-end` and `session-end` leave a tombstone for their key. `turn-start` or `agent-start` for that key removes it, and it expires after the idle limit.
  - `working` (`PostToolUse`) never reopens or recreates a key with a tombstone: after a turn has ended, a late heartbeat of its last tool cannot keep a closed Mac awake.
  - `tool-start` (`PreToolUse`) can: a Stop hook or `/goal` that continues the turn starts its next tool, and `PreToolUse` runs before every tool call (hooks.md:1580, 2571-2577). Within the end grace, a `tool-start` at least 2 s after the tombstone puts the holder back to working. After the holder was dropped, it creates it again only if the last look reads that session `busy`; without the last look (B-7 (b)), the 2-second rule alone decides.
  - `turn-maybe` creates an `ended` holder without a tombstone.
- **Dropping.** A holder is dropped when its time runs out and the last look does not keep it, or at once when its agent process has exited (5.7). A key dropped by the waiting allowance has no tombstone, so answering a prompt on the Mac after the 10 minutes starts a session again with that tool's `tool-start`.
- **`idle`** ends only a `working` holder whose last event is at least 50 s old: the case of an interrupt. It changes nothing in the other states, so `idle_prompt` during background work (hooks.md:2299, 2321) never cuts off a background build.
- **Background work.** `bg_since` is the time of the first `turn-end` with `BG=1` since the holder was created or since the last `turn-end` with `BG=0`; later ones do not move it (B-8). A background subagent also has its own `a:` holder, with its own events (5.6). Whether a background shell's end fires any hook: none was found in hooks.md, and section 9 (h, l) records what fires. Scheduled wakeups (`session_crons`) do not count (B-8).
- **The last look.** When the times of one or more holders that keep a running session run out in a pass, and no other holder keeps it, the watcher runs `claude agents --json` once (W21). Each such holder whose process (by `pid`, else by `sessionId`) reads `busy` goes back to working, with a fresh idle limit. A holder that reads `waiting` or `idle`, a missing entry, or a failed call lets the time rule apply. One call answers for every holder in that pass.
- **The session runs** while any holder keeps it, and starts only for a holder that may start one (5.2).

### 5.6 Several agents

- Each Claude Code session (several terminals, the Desktop app, IDEs, background sessions) has its own `s:` holder, and each subagent its own `a:` holder.
- One watcher and one agent session serve them all. The one-lid-closed-session rule (awake-helper:962) holds by itself.
- `SessionEnd` ends only the holder of the session that ends. A background subagent survives `/clear` (Adrafinil's note, ClaudeCodeIntegration.swift:20-41) and keeps its own holder.
- `SessionStart` with matcher `clear` gives the new session an `ended` holder (`turn-maybe`). This is for a plan approved with a cleared context: according to Adrafinil, that plan's run bypasses `UserPromptSubmit`, and no `Stop` fires for the old session (ClaudeCodeIntegration.swift:20-41). That is Adrafinil's finding, not documented; section 9 (g, o) checks it. The run's first `tool-start` puts the holder to working, and a run that thinks longer than the grace before its first tool reads `busy` in the last look. A plain `/clear` costs at most the 60 s grace, and nothing when no session runs, as `turn-maybe` cannot start one.

### 5.7 Crashes, restarts and stale state

- **The agent's process.** Each holder records the process the hook ran under. The hook's parent is the shell that runs the handler's command (K2), which ends with the hook, so the hook passes that shell's parent, read with one `/bin/ps -o ppid= -p $PPID`. The watcher walks further up past `sh`, `bash`, `zsh` and `dash`, at most three levels, to the first other process, and records its start time with one `ps` (`process_start_time`, 2366-2376).
  - Every pass checks it with `kill -0`, and every 10 s also its start time (`process_is_same`, 2379-2383). This covers `kill -9`, a crash and a closed terminal.
  - A process that is not the user's, or PID 1, is not recorded, and the holder then relies on its events and time limits.
- **The watcher killed:** 5.4, item 2. Its record `agent-watch` stays, but the watcher rewrites it on every pass with `beat=<time>`, and a hook trusts it only while `kill -0` answers and the beat is at most 10 s old, so a PID that another process reuses does not fool it; `main` also checks the start time. The next starting hook starts a new watcher, which resumes at the saved line count (W3) and drops events older than the idle limit.
- **A hook killed while it holds `agent-lock/`.** Claude Code cancels a sync hook at its timeout (K2 sets 10 s). The lock records its holder's PID and start time, and a waiter takes over a lock whose holder is gone, or whose record has been missing for 5 s (`LOCK_ABANDONED_SECONDS`, 232), as the main lock does (1377-1413).
- **The Mac restarts.** The watcher is gone. Recorded agent processes fail their start-time check and are dropped. The helper's boot-restore handles a lid-closed session cut short, as today.
- **`/tmp` cleanup** after 3 days: the watcher touches its files every 6 h (`KEEPALIVE_TOUCH_SECONDS`, 168), as the runner does (6043-6046).

### 5.8 A session the user started, a start by hand, and a stop by the user

- **The user's own session is never changed** by agent sessions (B-4 (a)). While it runs, the watcher keeps its holders and does not try to start.
  - When it ends while a holder may start a session: with the lid open, the watcher starts an agent session within a pass. With the lid closed, the helper has already put the Mac to sleep for a `timeout` or `process_exited` end (awake-helper:850-855), and no agent session starts until the lid is open (B-11). Claude's turn stalls meanwhile, and the README says so.
  - When it ends by a guardrail, agent sessions also pause, as after their own guardrail end (5.9). When the user stopped it, the stop rule below applies.
  - `awake -- claude -p "<task>"` with the hooks on: the run's own turns make holders while the session tied to it runs. When the run ends, its holders are `ended`, which cannot start a session, so the end of `awake --` sleeps a closed Mac as today.
- **A start by hand during an agent session (the handover).** To `main`, an agent session would otherwise be a running session, so a time option would add time to it and `-w` or `--` would be refused (7262-7377). Then the watcher would end that session a minute after Claude stops, and the user's request would be lost. Instead:
  1. After it reads the state under the main lock (7196-7216), `main` counts an agent session as running when the running record's `watch_pid` is the PID in `agent-watch`, that process is the same (`process_is_same`), and the session file says `agent=claude-code`.
  2. For any start that is not `--agent-session` and not `--if-off` (a time option, `-w`, `--`, or `--start` with the picker's answer), `main` skips the add-time branch and the refusal of a session tied to a process. Once the user's choice is known, after the picker if one shows, it writes `agent-handover` (`session_token=<the agent session's token>`, mode 600), stops the agent session with a plain stop request (`request_helper_session_stop`, or `request_active_session_stop` for lid-open), waits for its end and resets its state, as the branch for a session that ended while time was added does (7378-7397), and starts the user's session with the user's own options and transport. `stopped` never forces sleep, and clearing the settings alone does not sleep a closed Mac (awake-helper:621-624), so the change of sessions does not sleep it either.
  3. The watcher sees an end it did not cause, with reason `stopped` and an `agent-handover` that names its token. It removes the marker, keeps its holders, writes no pause, and waits for the user's session like any other.
  So `awake --duration 2h`, `--until 18:00`, `--indefinite`, `-w PID` and `awake -- make` all do what they say during a Claude turn, also when Claude runs them through its Bash tool. `--if-off` (the app's keyboard shortcut and `Start default session`) still changes nothing while Awake is on (7234-7243).
- **A stop by the user while a holder is active** (plain `awake`, `--stop`, the icon) pauses agent sessions until the next `turn-start` handled while the lid is open (B-5 (a)). The watcher writes `agent-pause` (`reason=stopped`, `since=`) and clears its holders. While the pause exists, the fast path drops every event except `turn-start`, which goes to `main`; `main` removes the pause and appends the event only when `lid_is_closed` is false (2385-2391), and drops it otherwise. This covers the agent session's own stop, and the stop of a session the user started.

### 5.9 Guardrails, the pause after one, the lid, and the maximum time

- **Agent sessions are ordinary sessions,** so every guardrail works as for any other. That covers 5% battery, critical and serious-with-the-lid-closed heat, and the optional unplug guard, both at the start (7575-7595; awake-helper:949-954) and while the session runs (awake-helper:1357-1400).
- **After a guardrail end, agent sessions pause** (`agent-pause`, `reason=low_battery|overheated|unplugged`). Otherwise the agent's next hook would start a session again within seconds (Adrafinil's latch, CutoutLatch.swift:3-12). The watcher keeps running and keeps its holders without a session, and checks every 30 s:
  - `low_battery` and `unplugged`: the Mac is on AC power (`power_source`, 2419);
  - `overheated`: the thermal state is below serious (`thermal_state`, 2311).
  Hooks make no guardrail reads: `thermal_state` runs `osascript` with a 10 s timeout (2311-2320, 149), and `UserPromptSubmit` blocks the prompt until its hook returns (hooks.md:1331). During a guardrail pause a hook appends as usual and starts a watcher if none runs. When the cause has gone and a holder may still start a session, the watcher removes the pause and starts one, with the lid open only. Turning the setting off and on, or a start by hand, also clears it.
- **The lid (B-11).** The watcher starts an agent session only while `lid_is_closed` is false, checked right before each start (one `ioreg`; a mock in the dry run). A running agent session goes on with the lid closed. So after any end with the lid closed (the user's session, a guardrail, the 12 h limit), a wakeup of a sleeping Mac in a bag never starts a session; with the lid open again, a holder that still works gets one within a pass.
- **The 12 h limit** (B-2) ends the session as `timeout`, and agent sessions pause (`reason=limit`) until the next `turn-start` handled while the lid is open, as after a stop (5.8).
- **Starts that keep failing** are tried again at most once a minute (5.2).

### 5.10 What `--status`, `--status-json` and the app show

| State | `awake --status` | JSON (new fields) | App |
|---|---|---|---|
| Agent session, working | `Awake is on while Claude works.` | `agent_session: true`, `agent_phase: "working"`, `agent_holders: 1`, `agent_wait_ends_at: null`, `agent_note: null`, plus the existing `end_mode: "duration"`, `deadline_at` (the 12 h cap), `watch_pid` (the watcher) and `watch_command: "awake"` | The same sentence in the tooltip and at the top of the menu; the icon bold |
| …all holders waiting | `Awake is on while Claude waits for you, for up to 9 more minutes.` | `agent_phase: "waiting"`, `agent_wait_ends_at: <epoch>` | The same |
| …waiting for the next message over Remote Control | `Awake is on while Claude waits for your next message, for up to 9 more minutes.` | `agent_phase: "remote"` | The same |
| …background tasks only | `Awake is on while Claude's background tasks run, for up to 52 more minutes.` | `agent_phase: "background"` | The same |
| …in the end grace | `Awake is on for up to 1 more minute after Claude's last turn.` | `agent_phase: "ending"` | The same |
| …lid-open after a fallback | `Awake is on while Claude works (keep the lid open; the display may sleep).` | `agent_note: "Password-free mode is off, so Claude's sessions keep the Mac awake only while the lid is open."` | The sentence, and the note in the Claude Code group of Settings |
| Paused | `Awake is off.`, and a second line `Claude's sessions are paused until your next prompt.` (or `…until the Mac is on power.`, `…until the Mac has cooled down.`) | `agent_paused: "stopped"` (or `limit`, or the guardrail) | `Awake is off`, and the note in Settings |
| Hooks on, nothing running | `Awake is off.` | `claude_hooks: "on"` | Checkmark at `Keep awake while Claude works` |

- The lid-open sentences end in `(keep the lid open; the display may sleep)`, because agent sessions start with `--keep-display off` (3058-3061; StatusDescription.swift:47-52).
- `agent_phase` is the most active state among the holders that keep the session: `working`, then `waiting`, `remote`, `background`, `ending`. `agent_wait_ends_at` is the latest end of their allowances when no holder works, and `null` otherwise, so the app can compute "for up to N more minutes" as the CLI does.
- `agent_*` fields are `null` when the watcher has written no record. `claude_hooks` is `on`, `partial` or `off`, or `null` when no Claude Code settings folder exists. `--status-json` computes it with builtins only (W15), as the app polls every 10 s (StatusBarController.swift:106).
- `last_session_token`, the token of the record that `last_completion_reason` comes from, lets the app see that a session ended even when the next poll finds another one running (M6).
- All new fields are added before `"error"`. `schema_version` stays 1: the app decodes every field it does not require as optional, and only `schemaVersion` and `active` are required (AwakeCLI.swift:10-20), so older apps ignore the new ones.
- The sentences live in one place in `build_status_text` (3013-3066) and are mirrored in `StatusDescription.swift`.

### 5.11 Notifications

- **None for an agent session's start or normal end** (B-6 (a)). The child start passes `--no-notifications`, which also stops `Awake failed` for a refused start (`report_start_failure`, 4590-4607). Without it, a low battery would post one at every turn.
- **The app** posts a notification when an agent session ends by a guardrail. The title is the usual one (InstallSupport.swift:418-431). The body adds "Claude Code may still be working." The rule is in `maybeNotifyCompletionTransition`, as an exception next to `isAppSession` (StatusBarController.swift:603-631).
- **Sessions back to back.** A session the app started that ends with the lid open can be followed by an agent session within 2 s, so the next poll sees "active" twice and today's check (StatusBarController.swift:605-607) misses the end. With `last_session_token`, the app notices it (M6).
- **The CLI** posts nothing for agent sessions. `awake --status` names the last reason (`last_completion_reason`).

### 5.12 Examples

1. **Lid closed during a long task.** The user types a prompt, closes the lid and leaves.
   - `UserPromptSubmit` starts the watcher and a lid-closed agent session.
   - Each tool call's `PreToolUse` and `PostToolUse` keep the holder working.
   - Claude finishes: `Stop` ends the holder. 60 s later the last look reads `idle`, the watcher ends the session as `process_exited`, and the helper sleeps the Mac.
2. **A permission prompt with the lid closed.** `PermissionRequest` marks the holder waiting.
   - The user approves from the phone at minute 5 (Remote Control), and the approved command runs for 8 minutes. At minute 10 the last look reads `busy`, so the holder goes back to working, and the command's `PostToolUse` and the next tools keep it so.
   - If nobody answers, the last look at minute 10 reads `waiting`, the session ends and the Mac sleeps. Claude Code waits for the answer when the Mac wakes.
3. **Two sessions and a background subagent.**
   - Terminal 1 works while terminal 2 waits for the user, so the session runs.
   - Terminal 1's turn ends with a background subagent still running. `Stop` has a background task, and the subagent's `a:` holder keeps working through its own tool calls.
   - The subagent's `SubagentStop` and the 60 s grace end the session, unless terminal 2 is still within its 10 minutes.
4. **Remote Control over an evening** (B-9 (b)). Each reply leaves the holder `remote` for 10 minutes, so a prompt from the phone within that time reaches the closed Mac and starts the next turn. After 10 minutes without one, the Mac sleeps.
5. **`/goal` with a slow check.** After each turn, `/goal`'s Stop hook asks a model whether the goal is met (goal.md:120). If not, Claude goes on, and its next tool's `PreToolUse` puts the holder back to working, even when that comes later than the grace: the last look reads `busy`.
6. **The user's own 2-hour session with the lid closed.** Claude still works at the end of the 2 hours. The helper ends the session as `timeout` and sleeps the Mac (B-4 (a)). No agent session starts in the bag (B-11). When the user opens the lid, Claude's turn goes on and an agent session starts within a pass.

## 6. W: agent sessions in the CLI

### W.1 Today

See section 3. In short: sessions tied to one process (`-w`, `--`), with an end through `command-finished`. There is nothing for an agent's turns, no way to start a lid-closed session that is sure not to prompt, and every call parses all of `bin/awake`.

### W.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| W1 | What starts and ends the holding | Claude Code's hooks (2), with the agent process's exit, the time limits and the last look as safety nets (5.4-5.7). | Polling (O6, O7): undocumented or in research preview, and it needs a process that always runs. A lease (O2): a helper run per renewal, mid-call ends. |
| W2 | Holder keys and the payload | `s:<session_id>` and `a:<agent_id>`, each id matching `^[A-Za-z0-9._-]{1,128}$`. Anything else is dropped at the hook. The hook cuts the payload at the first content key (`"tool_input"`, `"tool_response"`, `"prompt"`, `"last_assistant_message"`) and looks for `session_id`, `agent_id` and `tool_name` only before it, with patterns such as `"agent_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9._-]{1,128})"` kept in variables (`[[ $s =~ $re ]]`, as at 4067). A nested `agent_id` inside a tool's input or output therefore never counts, and the regular expressions run over a short prefix. `CLAUDE_CODE_SESSION_ID` is used only when stdin has no `session_id`. Section 9 checks that the ids come before the content keys. | The variable first: it "is updated on `/clear`" (env-vars.md:371), so a `SessionEnd` might name the new session, while stdin carries the retiring one (Adrafinil's note, ClaudeCodeIntegration.swift:93-96). A pattern anchored at the payload's start that allows no `{` before the key: `effort`, an object, is a common field of exactly the tool events that need `agent_id` (hooks.md:736). The first match anywhere: a main-thread event would be filed under an `agent_id` from a tool's output. |
| W3 | How hooks talk to the watcher | One append-only file, `agent-events`, mode 600, in the user's runtime folder. Each line is `VERB KEY EPOCH AGENT_PID BG RC`, in ASCII. The protocol: (1) every hook appends first, with one `printf >>`, which for a line this short is a single `write` with `O_APPEND`, and checks the watcher after; (2) the watcher reads new lines through a descriptor it keeps open (`exec 4<`), with `LC_ALL=C` and builtins; a line not yet ended by a newline is consumed by `read` (probe), so the watcher keeps the piece and puts it in front of the next one; (3) on every pass it saves the number of complete lines it has read in `agent-offset`, and a new watcher skips that many lines and drops events older than the idle limit by their time (bash 3.2 cannot report a byte offset); (4) it exits only under `agent-lock/`: it removes `agent-watch`, reads to the end once more, and if a line arrived it writes `agent-watch` again and goes on; otherwise it empties `agent-events`, saves the count 0, releases the lock and exits; (5) past 64 KB, under `agent-lock/`, it moves `agent-events` to `agent-events.1`, puts a new empty file (mode 600) in place, reads `.1` to its end once more and deletes it; a hook that finds no file goes the slow path. Lines with an unknown verb, a bad key or bad numbers are skipped. | One file per holder, with modification times: bash 3.2 has no builtin for a file's time, and `-nt` compares whole seconds. A socket or FIFO to a watcher: a hook would block or fail while no watcher reads. Appending only after seeing a live watcher: a watcher that exits just then never reads the event. |
| W4 | The watcher | An internal mode, `awake --agent-watch`, started with `start_detached --agent-watch >/dev/null` (3567-3573): its own process group, under `nohup`, so a hook's end, or Claude Code killing an async hook at `-p` teardown (hooks.md:3732-3735), does not end it, and the PID that `start_detached` prints does not reach Claude's context. It runs `cd /` first, so it never holds a project folder (hooks run in the session's folder, hooks.md:414, and `start_detached` keeps it). `agent-lock/` lets only one starter at a time decide; it has the main lock's scheme, with the holder's PID and start time in `agent-lock/pid` and a takeover of a stale lock, through `main_lock_is_abandoned` and `take_over_stale_main_lock` with the lock folder as a parameter (1377-1413). A starter waits up to about 1 s for it. The watcher records `pid=`, `started=` and `beat=` in `agent-watch` and rewrites it on every pass. A pass every 2 s (0.5 s in the dry run). | A LaunchAgent that always runs, like Adrafinil's: install and uninstall steps, a process all the time, and no dry-run test. The hook itself waiting for the work: a hook has to end within milliseconds. A lock without a holder record: a hook killed at its timeout would leave it for good. |
| W5 | How a session follows the watcher | The watcher runs `awake --agent-session -w $$ …` as a child (5.2), the path that `awake -w` uses for any process. Nothing new in the helper or the runner. | A new helper command for agent sessions: protocol 10, a password prompt for every user at the update (4160-4172). |
| W6 | How a session ends | `agent_end_session` runs in a subshell: it takes the main lock (`acquire_main_lock` waits up to 10 s, and exits the subshell on failure, so the watcher simply tries again on its next pass, 1416-1463); it counts the session as its own only when the running record (the helper's session file, or the state file for lid-open) has `watch_pid` equal to the watcher's `$$`, `watch_started` equal to its start time, and the user's `uid`; and it passes that record's token to `request_helper_session_stop command-finished TOKEN`, a new optional argument that makes it return 1 without writing anything when the current token differs. For lid-open it makes the same check before writing `command-finished` with the token and calling `request_active_session_stop`. The reason is `process_exited`, so a closed Mac sleeps (awake-helper:850-855). `run_bound_command` (4505-4508) can pass its token too, which closes the same small window for `awake --`. | Ending without the lock: a stop and start by the user just before the request would end the user's new session as `process_exited` and sleep a closed Mac, as the helper never reads the token in `command-finished` (awake-helper:39-46, 1353-1356). Reading the token after the start: it can adopt a session the user just started. A stop request: `stopped` never sleeps a closed Mac (awake-helper:847-849). A new reason, such as `agent_idle`: the lid-open stop waiter accepts only the known reasons (3811), the CLI's and the app's texts need it, and lid-closed sessions need a helper change. |
| W7 | Timings | End grace 60 s, idle limit 15 min, waiting 10 min, background 1 h, session limit 12 h, the 2-second rule, `idle`'s 50 s, retry 60 s, guardrail checks 30 s, the beat's 10 s, rotation at 64 KB. As constants after `WATCH_IDENTITY_CHECK_SECONDS` (165). In the dry run: grace 2 s, idle 5 s, waiting 3 s, background 5 s, the limit from `AWAKE_TEST_AGENT_LIMIT_SECONDS`, 1 s for the 2-second rule, 2 s for `idle`, retry 1 s, checks 1 s, beat 3 s, rotation from `AWAKE_TEST_AGENT_ROTATE_BYTES`; the `AWAKE_TEST_*` values are read only in the dry run. Without the last look (B-7 (b)): waiting 20 min and grace 3 min. (B-1, B-2.) | Settings in the app: more UI, for values few users would change. |
| W8 | Waiting | 5.5. The hooks are `PermissionRequest` and `PreToolUse` with matcher `AskUserQuestion\|ExitPlanMode`. The way back to working is `tool-start` and `working` under the 2-second rule, or the last look. `tool-start` for `AskUserQuestion` and `ExitPlanMode` is dropped at the hook (by `tool_name`), so it cannot undo the `waiting` from the same tool. | Reading `~/.claude/sessions/<pid>.json`: undocumented (claude-directory.md:1562). |
| W9 | Background work | B-8 (a): `BG=1` puts the holder in `background`, with `bg_since` from the first such `Stop`; only `BG=0` resets it. | Ignoring it: the Mac sleeps under a background build (adrafinil issue #7). Renewal at every `Stop`: a dev server holds a closed Mac for an hour after every turn. No limit: a forgotten `tail -f` holds it for good. |
| W10 | Pause | 5.8, 5.9. `agent-pause` with `reason=` (`stopped`, `limit`, `low_battery`, `overheated`, `unplugged`) and `since=`. The fast path reads it with builtins. For `stopped` and `limit` it drops every event but `turn-start`; for a guardrail it changes nothing, as the watcher handles those. | Clearing all holders and doing nothing more: the next tool call would start a session again. |
| W11 | Time limit | 12 h as the session's own limit (`--duration-seconds 43200` with `-w`), so the root helper ends it whatever the watcher does (B-2). | A limit kept only by the watcher: a stuck watcher would hold the Mac. |
| W12 | Never a password prompt | A new transport `none`. `admin_transport` (6916-6926) returns it for `--agent-session`. `run_as_admin` (4060-4131) then fails at once with `ADMIN_LAST_RESULT=no_password`, for a start and for a helper install alike, as `run_helper` reaches the install through `run_as_admin` (4160-4172). The watcher picks lid-closed only when `helper_runs_without_password` succeeds. In the dry run that function never runs `sudo`: it reads `passwordless=on\|off` from a mock file `mock-passwordless` in the dry-run runtime folder, off by default, like `mock-battery` and `mock-thermal` (225-226). `passwordless_is_configured` stays false in the dry run. | Relying on the check alone: a sudoers rule removed between the check and the start would show the dialog. The real `sudo -n` in the dry run: it succeeds on GitHub's macOS runners, which have passwordless `sudo`, and fails on a developer's Mac, so the same check would pass in one place only. |
| W13 | A hook never fails Claude | Every handler is one shell-form command, `'<awake path>' --agent-hook VERB; exit 0` (K2). So even a syntax error in a later `bin/awake`, a crash, or a missing `awake` exits 0, and exit 2, which blocks and erases the prompt on `UserPromptSubmit` (hooks.md:776-850), cannot happen. `awake` itself also exits 0 on every path of `--agent-hook`, and prints nothing on stdout, which `UserPromptSubmit` and `SessionStart` would add to Claude's context (hooks.md:786). Diagnostics go to the debug log only (`--debug` or `AWAKE_DEBUG=true`). | Exec form with `args`: Claude Code before 2.1.139 does not know `args` (cc-changelog.md:4758). If it ignored the key, it would run `sh -c "/bin/sh"`, whose inner shell would read the hook's JSON, tool output included, as a script; if it rejected it, the whole settings file could be set aside as a Settings Error (settings.md:607). The same file is read by every Claude Code on the Mac. Running `awake` directly: an `awake` that is gone after an uninstall would put a hook error in the transcript on every turn. |
| W14 | Speed | A builtins-only fast path right after `set -euo pipefail` (6), run only when the script is executed, not sourced: `if [[ "${1:-}" == --agent-hook && "${BASH_SOURCE[0]}" == "$0" ]]; then agent_hook_fast_path "$@"; set -euo pipefail; fi`. The function's `set +e +u` changes the whole shell's options (bash 3.2 has no `local -`), so they are restored before `main`. Bash runs a script one command at a time, so an `exit` there means the other 7,800 lines are never parsed (probe: 3.0 ms against 24.7 ms on Linux). Only a starting verb that finds no live watcher, or a `turn-start` during a stop pause, goes on to `main`, with the parsed fields in variables, as its stdin has been read. | A separate small script: no faster, as the probe's fast path cost what a bare `bash` costs, and a new shipped file for the installer, Homebrew and `release.sh`. The fast path without the `BASH_SOURCE` test: the self-test sources `bin/awake` with arguments (tests/cli/awake-self-test:418, 941). |
| W15 | Status | 5.10. The watcher writes `agent-state` (phase, holders, wait end, note, session token) when they change. `--status` reads it with builtins. A session is an agent session when the session file says `agent=claude-code`, which `write_session_file` (2785-2799) adds for `--agent-session`. `claude_hooks` comes from one `while read` pass over the recorded settings files (K1), counting the lines that hold Awake's quoted path and `--agent-hook <verb>; exit 0`: all 13 handlers means `on`, some `partial`, none `off`. | Telling it by `watch_pid` alone: a reused PID. Parsing the settings with `osascript` on every status read: the app polls every 10 s. |
| W16 | Notifications | 5.11. | |
| W17 | Helper | Unchanged, protocol 9. The root helper reads no new file. | |
| W18 | Dry run | Everything runs in the dry run with the existing mocks: lid, battery, thermal, `sleepnow` (tests/cli/awake-self-test:4330-4424), plus `mock-passwordless` (W12) and `mock-claude-agents` for the last look (W21). The agent's process is the hook's parent, or `AWAKE_TEST_AGENT_PID`. Two seams hold the watcher at a race point: `AWAKE_TEST_AGENT_EXIT_PAUSE` between removing `agent-watch` and exiting (W3), and `AWAKE_TEST_AGENT_END_PAUSE` between deciding to end and asking for the end (W6). All are read only in the dry run (as `AWAKE_TEST_SETTINGS_DOMAIN`, 1166-1175). | |
| W19 | A start by hand during an agent session | The handover of 5.8. | Adding time to the agent session or refusing `-w` and `--`: the watcher ends the session a minute after Claude stops, and the user's request is lost. |
| W20 | The lid | B-11 (a): no agent session starts while `lid_is_closed` (2385-2391) is true. | A pause only after a stop or a lid-closed end: a wakeup in a bag after a normal end can still start one. |
| W21 | The last look | B-7 (a). `claude agents --json`, run under `run_with_timeout` 5 s (2341); `claude` is the one on the `PATH` the watcher inherited from Claude Code, or else the agent process's executable. Its output is parsed with `osascript -l JavaScript`, as K5 parses settings, and never evaluated. In the dry run it reads `mock-claude-agents` (`<pid> busy\|waiting\|idle`, or `fail`). The watcher stops using it for the rest of its life after a call fails, and falls back to B-7 (b)'s timings. | Parsing the JSON with patterns: a `cwd` or `name` can hold any text, braces included. |
| W22 | Ordering | The 2-second rule and tombstones (5.5), with `tool-start` and `working` told apart. | Whole-second order alone: an async heartbeat that starts a second late reopens an ended holder. A tombstone that no event can lift until the next prompt: a Stop hook or `/goal` that continues the turn would lose its hold. |
| W23 | Guardrail reads | Only the watcher, every 30 s during a guardrail pause (5.9). | In hooks: `osascript` with a 10 s timeout in front of every prompt, and a hook killed at its own timeout while it holds `agent-lock/`. |

### W.3 Code changes

Line numbers are at `a9cd6d1`.

1. **The fast path, after 6** (W14). It uses builtins, plus `/bin/date +%s`, one `/bin/cat` for stdin and one `/bin/ps` for the agent's process. Every path ends in `exit 0`, except a starting verb that hands over to `main`. In order:
   1. Pick the runtime folder from `AWAKE_DRY_RUN` and bash's `UID`. Go on only if the folder passes `-d`, `! -L` and `-O`, which is the kernel's owner check, so a forged `UID` in the environment only makes the hook do nothing. `main` makes the folder with mode 700 (`ensure_state_dir`, 985). If it is missing, a starting verb goes on to `main` and the others exit.
   2. Read stdin with one `/bin/cat` unless it is a terminal (`-t 0`). Claude Code passes the JSON on stdin (hooks.md:406). That it then closes stdin is checked in section 9, where the probe's own `cat` must return. For sync handlers the handler's `timeout` (K2) bounds a writer that does not close it; for async handlers Claude Code enforces no timeout (hooks.md:426, 3730), so the only bound is that it closes stdin.
   3. Read the agent's process: the parent of the handler's shell (`$PPID`), with one `/bin/ps -o ppid= -p $PPID` (5.7).
   4. Cut the payload at the first content key and take `session_id`, `agent_id`, `tool_name` and, for `turn-end`, whether `background_tasks` is a non-empty array (W2). Set `RC=1` when `CLAUDE_CODE_BRIDGE_SESSION_ID` is non-empty. Drop a `tool-start` for `AskUserQuestion` or `ExitPlanMode` (W8).
   5. Read the time with `/bin/date +%s`.
   6. If `agent-pause` exists with `reason=stopped` or `limit`: a `turn-start` hands over to `main` (5.8), and every other event exits 0 unwritten.
   7. Append the event to `agent-events`, if that file passes `-f`, `! -L` and `-O`. If it does not, a starting verb hands over to `main`, and the others exit.
   8. Read `agent-watch`. If its PID answers `kill -0` and its `beat` is at most 10 s older than step 5's time, exit 0.
   9. Otherwise a starting verb hands over to `main`, and the others exit 0: their event is in the file, and the next watcher reads it.
2. **The internal modes, in main's early `case` (7007-7071):**
   - `--agent-hook VERB`, reached only from the fast path. It runs `cd /`, takes `agent-lock/` (W4), and then: for a `turn-start` under a `stopped` or `limit` pause, removes the pause only when `lid_is_closed` is false, and otherwise drops the event; appends the event if the fast path could not; checks the watcher with its start time (`process_is_same`); and, if none runs, starts one with `start_detached --agent-watch >/dev/null`. It makes no guardrail read. The whole handler runs in a subshell with its output sent to `/dev/null` and its status ignored, then `exit 0` (W13).
   - `--agent-watch`. `cd /`, `LC_ALL=C`; it records itself in `agent-watch` under `agent-lock/`, or exits if another watcher is alive. Then the loop of 5.2-5.9: read the events (W3), update the holders (5.5), check the processes, take the last look when times run out (W21), start (5.2) or end (5.4, W6) the session, notice an end it did not cause (`completion_reason_for_token`, 4431-4444) and act on it (handover, stop, guardrail, limit), run the guardrail checks during a guardrail pause, write `agent-state`, rewrite `agent-watch`, save `agent-offset`, rotate the log, touch files every 6 h, and exit as W3 says.
   - Holders are kept in indexed arrays, as bash 3.2 has no associative ones.
   - Like `--caffeinate-start`, neither mode runs `require_macos` (7006-7007).
3. **New functions, after `run_bound_command` (after 4545):**
   - `agent_parse_payload`;
   - `agent_append_event`;
   - `agent_lock_acquire` and `agent_lock_release`;
   - `agent_watch_alive` (PID, start time and beat);
   - `agent_resolve_process` (5.7);
   - `agent_read_events` (W3, with the leftover piece, the count and the rotation);
   - `agent_update_holders` (5.5, with tombstones and the 2-second rule);
   - `agent_session_needed` and `agent_other_session_running` (builtins over the two session records);
   - `agent_last_look` (W21);
   - `agent_start_session`, which chooses the backend (W12) and reads the guardrails (B-3);
   - `agent_end_session` (W6);
   - `agent_pause_set`, `agent_pause_check`, `agent_write_state` and `agent_cleanup` (for `--claude-hooks off` and the self-test).
   The guardrail reads use `read_setting` (1177-1182) for `minBatteryPercent`, `lowBatteryGuardEnabled`, `thermalGuardDisabled` and `unplugGuardEnabled`, with the app's rules (InstallSupport.swift:130-166). A comment asks to keep them in sync.
4. **Changed functions:**
   - `request_helper_session_stop` (4320-4376): an optional second argument, the expected token (W6).
   - `main_lock_is_abandoned` already takes the folder as `$1` (1377-1385); `take_over_stale_main_lock` (1392-1413) gets the lock folder, its pid file and its takeover folder as arguments, with today's values as defaults.
   - `helper_runs_without_password` (4052-4055): the dry-run mock (W12).
5. **`--agent-session`, internal, after `--if-off` (469-471).** It sets `AGENT_SESSION=true` and `START_ONLY=true`. It needs `-w`, and is refused with `--` or with maintenance actions.
   - `admin_transport` (6916-6926) returns `none` when it is set.
   - `run_as_admin` gets a `none)` case: `ADMIN_LAST_RESULT=no_password; return 1`.
   - main's terminal check (7596-7604) does not apply, as the transport is not `terminal`.
6. **The handover in main** (5.8, W19), after the state is read (7196-7216): the `agent_running` test, then, for a start that is not `--agent-session` or `--if-off`, the add-time branch (7268-7397) and the refusal at 7262-7266 are skipped, and the agent session is stopped right before the new session starts, after any picker, with `agent-handover` written first.
7. **`write_session_file` (2785-2799)** writes `agent=claude-code` for `--agent-session`.
8. **The status.**
   - `running_status_text` (2984-3011) reads `agent` from the session record and `agent-state`.
   - `build_status_text` (3013-3066) gets the agent sentences (5.10) before the `watch_label` branches at 3042-3045, with the lid-open endings at 3058-3061.
   - `print_current_status` (3335-3423) adds the pause line of 5.10 to `--status`.
   - `print_status_json` (3190-3333) gets `agent_session`, `agent_phase`, `agent_holders`, `agent_wait_ends_at`, `agent_note`, `agent_paused`, `claude_hooks` (W15) and `last_session_token` before `"error"`.
   - `watched_process_label` (4398-4418) names the agent watcher `awake`, so `watch_command` reads `awake`. Today it would read `bash` (holders-probe).
9. **`show_usage` (348-427).** One option, `--claude-hooks`, under the maintenance options (K). The internal modes and `--agent-session` are not listed, as with `--if-off` (467-468).

Not changed:
- `bin/awake-helper`;
- `HELPER_PROTOCOL_VERSION` (172);
- the stop waiter's list of reasons (3811);
- `announce_completion` (5449-5496);
- the toggle and stop paths of main (7400-7465): a stop is seen by the watcher, which pauses (5.8).

### W.4 Security and compatibility

- **No new root power.** The root helper's commands, arguments and checks do not change:
  - `start` with a `WATCH_PID` that it checks is the user's own (awake-helper:934-944);
  - its own battery and thermal checks;
  - the existence-only tests of `stop-request` and `command-finished` (awake-helper header, 39-46).
  The helper never reads, stats or follows `agent-events`, `agent-watch`, `agent-state`, `agent-pause`, `agent-offset` or `agent-handover`. Only the user's own processes read them.
- **User-writable files.** All new files are in the user's runtime folder: mode 700, owner checked, symlinks refused (806-927). They are created mode 600 (`create_private_runtime_file`, 4547-4552). Any program running as the user can append events. In password-free mode it could then keep the Mac awake with the lid closed until the 12 h limit. It can do the same today with `awake --indefinite`, and README.md:103 says so. Without password-free mode such sessions are lid-open only (W12).
- **Untrusted input.** Hook payloads hold the prompt and tool output. The hook keeps only two ids, a tool name and one flag, all checked against fixed patterns, and only from the part of the payload before any content (W2). It never evaluates them, writes no payload text anywhere, and logs only verbs, keys and numbers. The watcher checks every field of every line again (W3). The last look's JSON is parsed as data by JavaScript's `JSON.parse` (W21).
- **Never a prompt** (W12, W13).
- **Older versions.**
  - A 2.4.0 `awake` given `--agent-hook` exits 1 with "Unknown option" (641). Through the `; exit 0` of the handler (W13), Claude Code sees exit 0. This only happens if the hooks were written by 2.5.0 and `awake` was then replaced by an older copy.
  - A 2.4.0 app with a 2.5.0 CLI ignores the new JSON fields. For it, an agent session reads as a session tied to the watcher: "Awake is on until awake (PID n) exits".
  - The helper protocol stays 9, so every mix of CLI and helper works as today.
- **Claude Code versions.** Shell-form command hooks work in every version with hooks. `background_tasks` needs 2.1.145 (cc-changelog.md:4540): before it, a `Stop` reads as having no background tasks. Remote Control's variable needs 2.1.199 (env-vars.md:220): before it, B-9 does not apply. The README names 2.1.145 as the version from which background work counts.

### W.5 Tests

**`tests/cli/awake-self-test`, a new section 12n** after 12m (before 6383): "Verifying sessions while a coding agent works (dry-run hooks)". In the dry run, Claude Code is played by a stand-in process that runs the hooks as its children, through the same shell-form command as K2 (`/bin/sh -c "'AWAKE' --agent-hook VERB; exit 0"`), then `exec sleep 300`. The test writes the payload files, and sets `CLAUDE_CODE_SESSION_ID` only where a check needs it. That also tests how the hook finds the agent's process through the handler's `sh`. `AWAKE_TEST_AGENT_PID` stands in for an agent process with no shell parent, and the mocks of W18 for the lid, password-free mode and the last look. Checks:

| # | What it does | What it asserts |
|---|---|---|
| 1 | `--agent-hook turn-end` with no watcher | exits 0 at once, prints nothing on stdout or stderr, starts no watcher |
| 2 | `--agent-hook` with a bad key (`../x`), a missing runtime folder, and a folder owned by someone else (as in 12i); in a sourced shell, the `-t 0` branch, using `/dev/tty` only when it opens; and `source bin/awake --agent-hook turn-start` | exit 0 and nothing written; sourcing runs no fast path |
| 3 | `turn-start`, lid open, `mock-passwordless` on | within 3 s a lid-closed session runs, tied to the watcher, `agent=claude-code`; `--status` reads `Awake is on while Claude works.`; `--status-json` has `agent_session:true`, `agent_phase:"working"` |
| 4 | mock lid closed, `turn-end`, then wait (last look `idle`) | the session ends after the dry-run grace with `process_exited`; one mock `sleepnow`; the watcher exits; `agent-watch` is gone and `agent-events` is empty |
| 5 | `turn-end`, then `turn-start` within the grace | the session runs on (same token) |
| 6 | two `s:` holders; end one | the session runs on; ending the other ends it |
| 7 | `agent-start` (with `agent_id`), then the main `turn-end` | the session runs on while the `a:` holder works; `agent-end` ends it after the grace |
| 8 | `turn-end` with `background_tasks:[{…}]`, then another 3 s later, under a 5 s background limit | the session ends 5 s after the first, plus the grace; a `turn-end` with `[]` in between resets `bg_since` |
| 9 | `waiting`, then nothing; once with the last look `waiting`, once `busy` | `--status` reads `…waits for you…`; with `waiting` the session ends after the dry-run allowance; with `busy` it runs on, `agent_phase:"working"` |
| 10 | `waiting`, then `working` 0 s later, then `tool-start` for `AskUserQuestion`, then `working` 1 s (the dry-run 2 s) later | the first two change nothing; the last puts the holder to working |
| 11 | `idle` for a working holder whose last event is older than the dry-run 50 s; `idle` during `background` | the first ends the holder; the second changes nothing, and the session runs until the background limit |
| 12 | `turn-end`, then `working` 1 s later; then `tool-start` 1 s later; then, after the holder was dropped, `tool-start` with the last look `busy`, and once with `idle` | `working` never reopens it; `tool-start` within the grace does; after the drop, `busy` recreates it and `idle` does not |
| 13 | `turn-maybe`, then nothing; `turn-maybe` with no session running; `turn-maybe`, then `tool-start` | ends after the grace; starts no session; the holder works |
| 14 | `turn-end` with `CLAUDE_CODE_BRIDGE_SESSION_ID` set | `agent_phase:"remote"`; the session ends after the dry-run waiting allowance |
| 15 | kill the stand-in agent process (`kill -9`) | its holder is dropped within two passes; the session ends |
| 16 | kill the watcher (`kill -9`); then write an `agent-watch` that names the test shell's own PID with an old beat; then leave `agent-lock/` with a dead PID | the helper ends the session within about 3 s with `process_exited` (as holders-probe); after each of the other two, a `turn-start` still starts a watcher |
| 17 | `AWAKE_TEST_AGENT_EXIT_PAUSE` holds the watcher between removing `agent-watch` and exiting; a `turn-start` meanwhile | a session runs afterwards |
| 18 | `AWAKE_TEST_AGENT_END_PAUSE` holds the watcher between its decision and its request; meanwhile `--stop`, then `--duration-seconds 60` | the user's session survives, with no mock `sleepnow` |
| 19 | `awake --stop` during an agent session; then `working`; then `turn-start` with the mock lid closed; then with it open | reason `stopped`; `agent-pause` exists; the first two start nothing; the last starts a session |
| 20 | mock battery at 4% on battery during an agent session; mock AC with the lid closed; then with the lid open | `low_battery`; pause; `turn-start` starts nothing; on AC with the lid closed nothing starts; with it open the watcher removes the pause and starts a session without a new event, while a holder works |
| 21 | during an agent session, each of `--duration-seconds 3600`, `--until @now+600`, `--indefinite`, `-w <stand-in PID>` and `-- true` (the last tied to a short `sleep`) | a session with exactly that end (`end_mode`, `deadline_at`, `watch_pid` in `--status-json`), no `agent=claude-code`, no `agent-pause`; when it ends with the mock lid open, an agent session follows; with it closed, one `sleepnow` and no agent session until the lid opens |
| 22 | a session started by hand (`--duration-seconds 60`), then `turn-start` | the session is unchanged (token, end); the debug log shows no refused start by the watcher |
| 23 | `mock-passwordless` off; and, in a sourced shell, `admin_transport` with `AGENT_SESSION=true`, the real `run_as_admin` with `none`, and `run_helper` with `helper_is_ready` stubbed to fail | a lid-open agent session starts, with `agent_note`; `admin_transport` prints `none`; both functions return 1 with `ADMIN_LAST_RESULT=no_password`; a stand-in for `run_with_admin_prompt` fails the test if called |
| 24 | lid-open backend with the mock settings of a leftover lid-closed session | no session starts; `agent_note` names `awake --stop`; the debug log shows no start once a minute |
| 25 | 20 hooks in parallel (`&`) on two keys | every event is in `agent-events` once, one per line; one watcher; one session |
| 26 | a 3 MB `UserPromptSubmit` whose prompt contains `\"agent_id\":\"x\"`; a main-thread `PostToolUse` whose `tool_response` holds a nested `"agent_id":"y"`; a subagent `PostToolUse` with `effort` before `agent_id` | `s:` holders for the first two, `a:` for the third; each hook ends within 2 s |
| 27 | `AWAKE_TEST_AGENT_LIMIT_SECONDS=4` | the session ends as `timeout`; pause until a `turn-start` with the lid open |
| 28 | `AWAKE_TEST_AGENT_ROTATE_BYTES=512` and 50 events; then `kill -9` of the watcher and a `turn-start` | no event lost across the rotation; the new watcher resumes at `agent-offset` |
| 29 | `awake --agent-hook` from a copy of `bin/awake` with a syntax error placed after the fast path, at a path with a space and a `'`, through the shell-form command | exit 0 |

Each check is first shown to fail on `a9cd6d1`, or, where it guards a rule the new code adds, on a deliberate mistake, as faster-start-stop-2.md did (G.5). Examples of such mistakes: `idle_prompt` mapped to `turn-end` (11); the background allowance renewed at every `Stop` (8); no tombstone, or `working` allowed to reopen (12); appending after the alive check (17); no token check in the end (18); no handover (21); `kill -0` without the beat (16); the real `sudo -n` in the dry run (23); the first `agent_id` match anywhere (26).

**`cleanup_state`** (tests/cli/awake-self-test:262-270) also stops a watcher named in `agent-watch`, after checking its PID and start time, and removes the `agent-*` files and `agent-lock/`, so that no watcher carries over into later sections.

**Section 13** (6383): `--help` still fits in 80 columns, and lists `--claude-hooks` but not `--agent-hook`, `--agent-watch` or `--agent-session`.

**CI** runs the self-test with `/bin/bash` 3.2 on macOS (ci.yml:126), so all of 12n runs under Apple's bash, which the probes could not.

### W.6 Mac QA

In `qa-2.5.0.md`, with Claude Code 2.1.199 or later, the native install, password-free mode on, plugged in, the hooks on (K), and `AWAKE_DEBUG=true` set in the environment of a terminal from which `claude` is started:

1. A prompt that runs for about two minutes with tool calls. `awake --status` reads `Awake is on while Claude works.`. After the reply, `--status` reads `Awake is off.` within about 70 s. `grep agent /tmp/keep-awake-lid-closed-$UID/awake-debug.log` shows the events and the last look.
2. The same, with the lid closed after the prompt, and `pmset -g log` read afterwards. The Mac stays awake while Claude works (the work finishes, and the transcript shows no pause) and sleeps about a minute after the reply. `pmset -g log | grep -i sleep` shows the sleep, and `last` says `process_exited`.
3. A permission prompt with the lid open: the status reads `…waits for you…`. Leave it for 11 minutes: the session ends. Approve: a session starts again with the next tool.
4. Remote Control, lid closed: a prompt whose first command needs approval and runs 8 minutes; approve it from the phone at minute 5. The command finishes (the last look at minute 10 reads `busy`).
5. Remote Control, lid closed: send the next prompt from the phone 5 minutes after a reply. It reaches the Mac (B-9).
6. Esc, and on another try Ctrl+C, in the middle of a turn: the session ends at `idle_prompt` (note whether it fired, and after how long) or at 15 minutes.
7. `kill -9` of `claude` mid-turn: the session ends within about 5 s.
8. Two terminals at once, then a background subagent (ask for one), then a plain `/clear` (the session ends within about 70 s), then a plan approved with "clear context" (its run is held).
9. A background `npm run dev`, then three short prompts a few minutes apart, then close the lid: the Mac sleeps within an hour of the first prompt's reply, plus the grace.
10. A `run_in_background` command of five minutes: the session runs on for it.
11. A `/goal` whose second step is a 3-minute command, with the lid closed: the run finishes.
12. Click the icon during an agent session: `Awake is off`; the next tool call starts nothing; the next prompt does. Close the lid after the click and send a prompt from the phone: nothing starts.
13. During an agent session, `awake --duration 1h`: `--status` shows the hour, not an agent session; after `awake --stop` and a new prompt, agent sessions return.
14. A timed session started by hand, then a prompt: the session is unchanged; at its end with the lid open, an agent session follows within 2 s; on another try with the lid closed, the Mac sleeps, and a session follows once the lid opens.
15. Password-free mode off: the next prompt starts a lid-open session, and `--status` explains why. No password dialog appears at any time.
16. With "Require password after screen saver begins or display is turned off" set, close the lid during an agent session, wait 5 minutes, and open it: the password must be asked. If it is not, the owner decides whether agent sessions lock the screen on lid close (section 12).
17. Speed: `time` of 20 hook calls for each verb with a watcher running, through the shell-form command (estimate: under 25 ms each). Also the first `turn-start` with no watcher (estimate: under 80 ms), and the last look (estimate: under 1 s).
18. CPU of the watcher over 10 minutes of work: `ps -o time= -p <watcher>` (estimate: under 1 s, plus the last looks).

### W.7 Docs

In W's commit:

- **README.md, Highlights** (5-10): "With `awake --claude-hooks on`, or `Keep awake while Claude works` in the menu, it keeps the Mac awake, also with the lid closed, while Claude Code works, and lets it sleep about a minute after."
- **README.md:44** (use cases) keeps `awake -- claude -p "<task>"` for one-off headless runs, and adds: "or turn on `Keep awake while Claude works` (see While Claude works)".
- **A new section `## While Claude works`, after `## Usage`.** What it does (5.2-5.5, in user terms). Lid-closed and password-free mode (H-2). What ends a session, and how soon. Waiting, and Remote Control between turns (B-1, B-9). Background work (B-8). Several sessions. A start by hand replaces an agent session, and what a stop does (5.8). That with the lid closed your own timed session still sleeps the Mac at its end, and that agent sessions start only with the lid open (B-4, B-11). Guardrails and the pause (5.9). The 12 h limit. What it does not cover:
  - `/loop` and scheduled tasks between iterations: use a timed session;
  - usage-limit waits: with the lid closed the Mac sleeps, and after more than about 30 minutes asleep across the reset Claude Code waits for Enter (B-10);
  - MCP tools longer than 15 minutes, and a raised `BASH_MAX_TIMEOUT_MS`, unless the last look is available (B-2);
  - an interrupt (Esc or Ctrl+C): up to 15 minutes;
  - folders Claude Code does not trust yet;
  - `disableAllHooks` in your settings or in a project's `.claude/settings.json`, which overrides yours;
  - managed `allowManagedHooksOnly`, from the managed settings file, an MDM profile or the claude.ai console;
  - `claude -p --bare`, which skips hooks (headless.md:37);
  - clamshell mode with an external display, which keeps the Mac awake by itself;
  - Claude Code before 2.1.145 (background work) and before 2.1.199 (Remote Control).
- **Runtime files** (557-589): `agent-events` (and `agent-events.1` during a rotation), `agent-offset`, `agent-watch`, `agent-state`, `agent-pause`, `agent-handover`, `agent-lock/`.
- **Security notes** (91-97): one paragraph. The hooks run `awake` as you. Any program running as you can ask for agent sessions, as it can already run `awake`. Lid-closed agent sessions need password-free mode, with its trade-off (103). The hooks keep no prompt text.
- **`--help`**: the option line (K.7).
- **CHANGELOG.md** (after 2.4.0 ships, R-1): `### Added`:
  ```
  - Awake can keep the Mac awake while Claude Code works: turn it on with
    `awake --claude-hooks on` or `Keep awake while Claude works` in the
    menu bar app. Each Claude turn then keeps the Mac awake, also with the
    lid closed in password-free mode, and the Mac can sleep again about a
    minute after Claude stops, or after 10 minutes of waiting for you or
    for your next message over Remote Control. Background tasks count for
    up to an hour; scheduled /loop runs do not. The usual guardrails
    apply, and each such session ends after 12 hours at most.
  ```

### W.8 Gain and cost

**Gain.** Claude can work with the lid closed without the user choosing a length, and the Mac sleeps about a minute after the work instead of at a guessed end time.

**Cost per hook** (Linux probe; Mac estimates at 1.1 to 1.9 times, from faster-start-stop-2.md's Linux-to-Mac ratios):
- The fast path with a watcher running: about 3 ms for bash, plus the handler's `sh`, `date`, `cat` and `ps`, about 5 to 10 ms more (estimate). On the Mac, about 10 to 25 ms per hook.
- `PreToolUse` (`tool-start`) and `PostToolUse` hooks are async, so Claude never waits for them (hooks.md:3703).
- `UserPromptSubmit` waits for its hook: about 10 to 25 ms. When it has to start a watcher, the full parse and `start_detached` take about 40 to 80 ms (estimate). The session's own start, about half a second with the lid closed (faster-start-stop-2.md:144), runs in the watcher, not in the hook.

**Cost per busy period:**
- one session start and one end, which with the lid closed means one `sudo -n` helper run each, as for any session;
- the watcher's passes: builtins, `kill -0` and one rewrite of `agent-watch` every 2 s, plus one `ps` per holder every 10 s;
- the last look: one `claude agents --json` and one `osascript` at each expiry, usually once per reply (measured in section 9).

### W.9 Risks and rollback

- **The Mac sleeps while Claude works.** A tool longer than 15 minutes without the last look, a hook that does not run (trust, `disableAllHooks`), or an `agent_id` that comes after the content keys (W2, checked in section 9). Shows in Mac QA 1-11. The limits are constants (B-2), and the README names what is not covered.
- **The Mac stays awake when Claude does not work.** After an interrupt, at most 15 minutes. A late async heartbeat cannot reopen an ended turn (W22). A stuck watcher is cut off by the 12 h limit in the root helper (W11), or by 2 h with B-2 (d).
- **The last look misleads.** `claude agents --json` is in research preview. A `busy` that is wrong keeps the holder for one more idle limit, after which it looks again; a failure falls back to the time rules (W21). Section 9 checks its side effects before it is used.
- **Claude Code changes its hooks.** It is documented behaviour, and the README names minimum versions. Section 9 and Mac QA show the events as they are.
- **Bash 3.2.** The watcher's arrays and reads are written for 3.2. CI runs 12n on `/bin/bash`.
- **Rollback:** `awake --claude-hooks off`, or revert the commits. Nothing outside the user's runtime folder, Claude Code's settings and the app's defaults domain changes. The helper is untouched.

## 7. K: connecting Claude Code (`--claude-hooks`)

### K.1 Today

Awake writes nothing outside its own folders, the helper's and the sudoers file (Runtime files, README.md:557-589). Claude Code has no hooks from Awake.

### K.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| K1 | Where | `settings.json` in `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, the user's settings for all projects (hooks.md:257), and in each folder given with `--config-dir DIR` (repeatable). Claude Code's docs suggest several such folders side by side (env-vars.md:418). Every folder that `on` writes to is recorded in the app's defaults domain as `claudeConfigDirs`, a newline-separated string (`write_setting` stores strings, 1184-1190). `status`, `refresh`, `off`, the JSON field and the app use the recorded folders plus the default one, so the app (started by launchd), the installer and the uninstaller, which do not see the user's shell variables, find them all. If a folder is missing, `on` refuses: "Claude Code's settings folder … was not found; start Claude Code once first." | Only `CLAUDE_CONFIG_DIR` from the environment: the app's checkbox would edit `~/.claude/settings.json` while the user's alias reads another folder, and the uninstaller would leave the real handlers behind. Project settings: per repository. Managed settings: an administrator's. A plugin: H-1 (b). |
| K2 | The handler's shape | Shell form: `{"type":"command","command":"<sh_quote(path)> --agent-hook VERB; exit 0","timeout":10}`, with the path quoted by awake's own `sh_quote` (4006-4011). `"async": true` and no `timeout` for `tool-start` and `working` (Claude Code enforces none on async hooks, hooks.md:3730). No `timeout` for `session-end`, as a per-handler timeout would raise the 1.5 s budget that every exit, `/clear` and `/resume` waits on (hooks.md:3391). The awake path is the resolved path of the `awake` that runs the command; the installer's `refresh` (K7) points it at the installed copy, `~/Library/Application Support/Awake/bin/awake` (scripts/install-awake.sh:12-14). The hook's parent is still a shell, so 5.7 does not change. | Exec form with `args`: W13. Running `awake` without `; exit 0`: W13. |
| K3 | Which handlers | The 13 handlers of K.3. | |
| K4 | Telling Awake's handlers apart | A handler is Awake's when its `type` is `command`, it has no `args`, and its `command` is exactly a single-quoted path ending in `/awake`, as `sh_quote` writes it (a `'` in the path appears as `'\''`), then ` --agent-hook `, a verb of lower-case letters and dashes, and `; exit 0`. The pattern is kept in a variable in the JavaScript of K5. There is no marker key, as Claude Code's schema could reject one (settings.md:607). A user's handler that runs some other `awake` command is not touched. | Adrafinil's `_adrafinil` key (NestedJSONHookShape.swift:12-15). |
| K5 | How the file is edited | `osascript -l JavaScript`, already used by `awake` (996, 2317), reads the file. It must be a JSON object, and the hooks must have the documented shape (event → array of groups → `hooks` array). Otherwise `awake` refuses and names the problem, and suggests `--claude-hooks print`. **On and refresh:** for each handler in K.3, Awake's handler is replaced in place in a group with the same matcher, or a new group is appended. Awake handlers for events or matchers that are no longer in the set are removed. **Off:** Awake's handlers are removed from every event; groups and event keys that this left empty are removed. Key order is kept (JavaScript objects keep it). Output is `JSON.stringify(…, null, 2)` and a newline. **Writing:** the link target is resolved, the new text goes to a temporary file next to the target with the target's mode, and a `cmp` against what was read refuses a file that changed meanwhile. Then `mv -f`. Nothing is written when nothing changes. A function `claude_hooks_before_compare`, empty in the shipped code, sits between the read and the `cmp`, so that the self-test can change the file there. | `plutil`: it cannot write JSON `null` (research). `python3` and `jq`: not on every Mac. Writing `{}` over a file that does not parse: what clawake did (section 1). |
| K6 | Output | `on` prints, per folder, what it added, updated or removed, and then warnings (K.3). `status` prints, per known folder, `on`, `partial (N of 13)` or `off`, the file, the awake path, the lid mode, and the same warnings. `refresh` prints what it updated, or nothing. `print` prints the hooks block for pasting by hand. All exit 0, except `on`, `off` and `refresh` when they refuse or fail (exit 1). | |
| K7 | Upgrades and uninstall | The installer, after `--install-helper` (scripts/install-awake.sh:525), runs `awake --claude-hooks refresh` and reports a non-zero exit. `refresh` does nothing, and exits 0, in a folder without Awake handlers. Elsewhere it rewrites the handler set and the path; it never changes the lid mode and never refuses because of password-free mode. It never turns the hooks on by itself. The uninstaller runs `awake --claude-hooks off` for every recorded folder before `stop_active_session_if_needed` (scripts/uninstall-awake.sh:195), so that no hook starts a session between that stop and the removal. `brew uninstall` runs that uninstaller (README.md:204). | Running `on` again at each install: it would switch a user who chose lid-open to lid-closed, or fail for a user without password-free mode. Parsing `status` text in the installer. Leaving the hooks after an uninstall: thanks to K2's `; exit 0` they would stay silent, but they would remain in the file. |
| K8 | Lid mode | `on` takes `--backend awake\|caffeinate` and stores it as `agentBackend` in the app's defaults domain (`write_setting`, 1184-1190), where the watcher reads it (5.2). Without `--backend`, `on` keeps the stored value, and takes `awake` only when nothing is stored. Only `awake` chosen that way, or given explicitly, checks password-free mode: `on` refuses while `helper_runs_without_password` fails (H-2 (a)). Message: "Lid-closed sessions from Claude's hooks need password-free mode: run awake --passwordless on first, or use --backend caffeinate for lid-open sessions." | |
| K9 | Combining options | `--claude-hooks` is a maintenance action, like `--passwordless` (`set_maintenance_action`, 704-713). It takes `--backend` with `on`, and `--config-dir` with every verb but `print`. Everything else is refused, as for the other maintenance actions. The check at 676-680 gets an exception for these pairs. | |
| K10 | Dry run | `--claude-hooks` in the dry run edits the file under `CLAUDE_CONFIG_DIR` or `--config-dir`, one of which must then be set, so that a test never touches a real `~/.claude`. The recorded folders go to the self-test's defaults domain (`AWAKE_TEST_SETTINGS_DOMAIN`, 1166-1175). | |
| K11 | What `off` stops | Besides removing the handlers, `off` ends a running agent session with a stop request, after writing `agent-handover` so that the watcher writes no pause; stops the watcher with TERM, after checking its PID and start time; and removes `agent-events`, `agent-offset`, `agent-watch`, `agent-state`, `agent-pause`, `agent-handover` and `agent-lock/`. | Removing only the handlers: the watcher and its session would run on until the idle limit, the background limit or the 12 h limit. |

### K.3 The handlers

| Event | Matcher | Verb | Async | `timeout` |
|---|---|---|---|---|
| `UserPromptSubmit` | (none) | `turn-start` | no | 10 |
| `SessionStart` | `clear` | `turn-maybe` | no | 10 |
| `Stop` | (none) | `turn-end` | no | 10 |
| `StopFailure` | (none) | `turn-end` | no | 10 |
| `SessionEnd` | (none) | `session-end` | no | (none) |
| `Notification` | `idle_prompt` | `idle` | no | 10 |
| `SubagentStart` | (none) | `agent-start` | no | 10 |
| `SubagentStop` | (none) | `agent-end` | no | 10 |
| `PermissionRequest` | (none) | `waiting` | no | 10 |
| `PreToolUse` | `AskUserQuestion\|ExitPlanMode` | `waiting` | no | 10 |
| `PreToolUse` | (none) | `tool-start` | yes | (none) |
| `PostToolUse` | (none) | `working` | yes | (none) |
| `PostToolUseFailure` | (none) | `working` | yes | (none) |

- `SubagentStop` for Claude Code's internal agents carries an empty `agent_type` (hooks.md:2428), and its `agent_id` matches no holder, so it changes nothing.
- `PermissionRequest` and `PreToolUse` hooks that print nothing and exit 0 leave the decision to the user, as without them (hooks.md:776-790, 1916-1921).
- Warnings that `on` and `status` print, each read with builtins:
  - `disableAllHooks` set in the user's settings;
  - `allowManagedHooksOnly` found in `/Library/Application Support/ClaudeCode/managed-settings.json` (managed-settings.md:40); an MDM profile or the claude.ai console may also set it (managed-settings.md:61-71), which `awake` cannot read;
  - password-free mode off with the lid-closed backend;
  - `CLAUDE_CONFIG_DIR` set, with the folders used.
  The README names untrusted folders (hooks.md:3813-3818), a project's `disableAllHooks` (hooks.md:710) and `claude -p --bare` (headless.md:37); `awake` cannot see them.

### K.4 Security and compatibility

- **The edit touches only Awake's handlers** (K4, K5). A user's handlers in the same groups stay, in their order.
- **Refusals.** A file that does not parse, a file that is not an object, an unexpected shape, or a change during the edit: in each case the file stays as it was.
- **Symlinks** (dotfile managers) are written through, and the mode is kept.
- **Where the JSON is parsed.** JavaScript inside `osascript` parses it, as the user. `awake` passes the file's path as an argument, never its text as code.
- **What the handlers run.** `sh -c` with Awake's path in single quotes, escaped by `sh_quote` (4006-4011), and a fixed verb. A path with spaces, `$` or quotes stays one word. Section 9 item 2 runs a path with a space.
- **Version mix.** A 2.4.0 `awake` that meets these handlers: W.4. Every Claude Code version with hooks runs shell form the same way (hooks.md:466-470).

### K.5 Tests

**`tests/cli/awake-self-test`, a new section 12o**, macOS only: it needs `osascript -l JavaScript`. It is skipped with a note elsewhere, as the emulation has no JXA. Each check uses a temporary `CLAUDE_CONFIG_DIR`:

1. A missing folder: `on` refuses, and nothing is created.
2. A missing file: `on` creates it with the 13 handlers. `status` reads `on`, and `--status-json` has `claude_hooks:"on"`. A second `on` changes no byte.
3. A file with user hooks on `Stop` (two groups, one with a matcher), `PreToolUse` with matcher `Bash`, and other top-level keys: `on` keeps them all, in order. `off` gives back a file that is JSON-equal to the original.
4. A file with a comment (`//`), a trailing comma, an array root, and a `hooks` that is a string: all refused, the file unchanged, exit 1.
5. A symlinked file: the target changes, and the link stays a link. Mode 600 is kept.
6. A stand-in for `claude_hooks_before_compare`, in a sourced shell, that changes the file between the read and the `cmp`: refused, the change kept.
7. Handlers from an older set (one extra event) and an old path: `refresh` replaces the path and removes the extra one.
8. `print`: valid JSON. `--claude-hooks on --min-battery 5`: refused (K9).
9. `--backend awake` with `mock-passwordless` off: refused, with the message from K8.
10. With `caffeinate` stored, `refresh` and `on` without `--backend` keep `caffeinate`. In a folder without Awake handlers, `refresh` changes no byte and exits 0.
11. Two folders, one through `--config-dir`: `status` lists both; `off` with `CLAUDE_CONFIG_DIR` unset still cleans both, as they are recorded.
12. `off` during an agent session in the dry run: the session ends as `stopped` with no `agent-pause`, the watcher is gone, and the `agent-*` files and `agent-lock/` are removed.
13. The `SessionEnd` handler has no `timeout`, and the async handlers have none.

The uninstaller's step (K7), and that it runs before the session stop, are checked in 11c's style (tests/cli/awake-self-test:3923), with a stand-in `awake`.

### K.6 Mac QA

1. `awake --claude-hooks on` on a real `~/.claude/settings.json` with the user's own hooks. Then `claude` in a trusted folder. `/hooks` in Claude Code lists Awake's handlers, and W.6 item 1 passes. A session that was already running picks them up without a restart (settings.md:584).
2. `awake --claude-hooks off`: `/hooks` no longer lists them, and an agent session that ran has ended. `diff` against a copy made before `on`: only formatting differences, if any.
3. With `~/.claude/settings.json` a symlink into a dotfiles folder.
4. With the Homebrew install: `brew upgrade` keeps them on, with the same lid mode, and pointing at the managed path. `brew uninstall awake` removes them.
5. With `disableAllHooks: true`: `status` warns.
6. With a second folder through `--config-dir`: the app's Settings group lists both, and the checkbox turns both off.

### K.7 Docs

- **`--help`**, under the maintenance options:
  ```
    --claude-hooks on|off|refresh|status|print
                           Keep the Mac awake while Claude Code works, through
                           hooks in ~/.claude/settings.json (see README)
  ```
  The lines are under 80 columns, which section 13 checks.
- **README.md, Options** (350-381): one bullet for `--claude-hooks`, with `--backend`, `--config-dir`, K6's output, and that only Awake's handlers are touched. "If you use `CLAUDE_CONFIG_DIR`, run `awake --claude-hooks on --config-dir …` for each folder."
- **README.md, Uninstall** (202-215): the uninstaller also removes Awake's hooks from Claude Code's settings.
- **CHANGELOG.md**, within W.7's `### Added` bullet, or a second bullet for `--claude-hooks status`, `refresh` and `print`.

### K.8 Gain

One command, or one click (M), instead of editing JSON by hand. Upgrades keep the hooks current without changing the user's choices.

### K.9 Risks and rollback

- **Damaging the user's settings.** Covered by K5's refusals and 12o. A second risk is a file rewritten in 2-space indentation when the user used another style. `on` and `off` say they rewrite the file. The README recommends `print` to anyone who keeps it formatted by hand.
- **Claude Code writes the file at the same time** (for example `/config`): the `cmp` refuses. A small window remains between the `cmp` and the `mv`.
- **Rollback:** `awake --claude-hooks off`, which also stops what runs (K11), or delete the handlers by hand. `print` shows exactly which ones.

## 8. M: the menu bar app

### M.1 Today

- The app polls `--status-json` every 10 s (StatusBarController.swift:106-109).
- It shows the status sentence (StatusDescription.swift:22-54), and offers `Add`, `Start default session` or `Stop session`, `Help`, `Settings…`, `Install helper…` and `Quit` (783-850).
- It runs maintenance commands with `performMaintenance` (AwakeCLI.swift:429-445).
- It posts end notifications only for sessions it started, and only on a poll that goes from active to inactive (603-631).
- Its Settings have General, Keyboard shortcut, Guardrails and Session lengths (README.md:257-281).

### M.2 Decisions

| # | Decision |
|---|---|
| M1 | Decode `agent_session`, `agent_phase`, `agent_holders`, `agent_wait_ends_at`, `agent_note`, `agent_paused`, `claude_hooks` and `last_session_token` as optional fields (AwakeCLI.swift:10-88). |
| M2 | `StatusDescription` gets the agent sentences of 5.10, before the `processName` branches (35-38), with the same lid-open endings (47-52). "For up to N more minutes" comes from `agent_wait_ends_at`. |
| M3 | A menu item `Keep awake while Claude works`, with a checkmark when `claude_hooks` is `on` (mixed when `partial`), after `Start default session` (802). It is hidden when `claude_hooks` is null, meaning no Claude Code settings folder. **Turning it on** with the lid-closed backend while `passwordless` is not true shows an alert: "Lid-closed sessions from Claude Code need Start without password. Turn it on now (asks for your password once)?" The buttons are `Turn on and continue`, `Use lid-open instead` and `Cancel`. The first runs `--passwordless on`, then `--claude-hooks on`. **Turning it off** runs `--claude-hooks off`, which covers every recorded folder (K1). Errors go through the usual failure notification. |
| M4 | `Add` is not shown for agent sessions (the condition at 791). |
| M5 | Settings gets a `Claude Code` group, shown when `claude_hooks` is not null. It has the same checkbox, a `Lid mode` popup (`Lid-closed (needs Start without password)` / `Lid-open`), which runs `--claude-hooks on --backend …` while the hooks are on, the folders it manages, and `agent_note` or `agent_paused` as a note. |
| M6 | In `maybeNotifyCompletionTransition`, before the `isAppSession` guard (613-615): when `previousStatus.agentSession == true` and the reason is `low_battery`, `overheated` or `unplugged`, post `postStopped` with the extra sentence "Claude Code may still be working." (B-6). And when the previous poll and this one are both active, their session tokens differ, and `lastSessionToken` equals the previous token, the app runs the same notification and `recordStopTime` (StatusBarController.swift:571) for the previous session, which today's guard at 605-607 would miss. |
| M7 | A click on the icon, `Stop session` and `Stop Awake and quit` stop an agent session like any other. The CLI then pauses agent sessions (5.8), so the app needs no change for that. |

### M.3 Code changes

- `AwakeCLI.swift`: eight fields and their `CodingKeys` (10-88), and the placeholders (90-130).
- `StatusDescription.swift`: M2.
- `StatusBarController.swift`: M3, M4, M6, and an action that runs `performMaintenance`.
- `SettingsWindowController.swift`: M5.
- `InstallSupport.swift`: `postStopped` takes an optional extra sentence (375-431).
- If M6's comparison goes into `CommandResult.swift`, a case in `tests/app/command-result-check.swift`.

### M.4 Security and compatibility

The app runs only `awake` commands that already exist or that K adds. It edits no file itself. An app older than the CLI shows agent sessions as "Awake is on until awake (PID n) exits" and has no menu item. An app newer than the CLI finds no `claude_hooks` and hides the item.

### M.5 Tests

- If `StatusDescription.swift` and `AwakeStatus` compile with Foundation alone, a new `tests/app/status-description-check.swift` checks the agent sentences against the CLI's for the same fields, with a CI step like those at ci.yml:82-96.
- If they pull in AppKit types, that check moves to Mac QA. The CLI's sentences are checked in 12n either way.
- M6's back-to-back case in `tests/app/command-result-check.swift`, if the logic lives in `CommandResult.swift` (ci.yml:91-96).

### M.6 Mac QA

1. The menu item appears only with `~/.claude`.
2. Turning it on with password-free mode off: the alert, then one password dialog, then the checkmark. `Use lid-open instead`: no dialog.
3. The tooltip during W.6 items 1, 3 and 5.
4. A guardrail end: turn on `Stop when unplugged`, let Claude work on AC power, then unplug. One notification with the extra sentence, and with the lid closed the Mac sleeps.
5. `Stop session` during an agent session: W.6 item 12.
6. The Settings group: the popup changes the backend of the next agent session.
7. A 1-minute session from the app, with the lid open, while Claude works: when it ends, the app still posts `Awake finished`, although an agent session follows at once.

### M.7 Docs

README, Menu bar app (240-283):
- the menu item (M3);
- the Settings group (M5);
- the tooltip example `Awake is on while Claude works`;
- the notification (M6).

### M.8 Gain

The owner's "select 'keep awake as long as Claude works'": one click in the menu.

### M.9 Risks and rollback

The app's part is thin. Without it the CLI does the same work. Revert M's commit to remove the item.

## 9. The Mac preflight (before W is written)

About 45 minutes on the owner's Mac, with the installed 2.4.0 and Claude Code 2.1.199 or later, before W's first commit. It needs no Awake build. It checks the Claude Code facts the design rests on, which nobody has seen on this Mac.

1. **A logging hook.** Save as `~/awake-hook-probe.sh`:
   ```bash
   #!/bin/bash
   payload=$(cat)
   {
       printf '%s %s ppid=%s comm=%s pcomm=%s sid=%s rc=%s\n' "$(date +%T)" "$1" "$PPID" \
           "$(ps -o comm= -p "$PPID")" "$(ps -o comm= -p "$(ps -o ppid= -p "$PPID")")" \
           "${CLAUDE_CODE_SESSION_ID:-}" "${CLAUDE_CODE_BRIDGE_SESSION_ID:+rc}"
       printf '  %s\n' "${payload:0:600}"
   } >> /tmp/awake-hook-probe.log
   exit 0
   ```
   Add K.3's events to a copy of `~/.claude/settings.json`, each in shell form as `{"type":"command","command":"'/Users/<you>/awake-hook-probe.sh' EVENT; exit 0"}`, with `"async": true` on `PreToolUse` (no matcher), `PostToolUse` and `PostToolUseFailure`. Then:
   - (a) a short prompt with two tool calls;
   - (b) a permission prompt answered after a minute;
   - (c) a question (`AskUserQuestion`);
   - (d) Esc in the middle of a turn, then waiting 2 minutes;
   - (e) a background subagent;
   - (f) `/clear`;
   - (g) a plan approved with "clear context";
   - (h) a `run_in_background` command;
   - (i) `kill -9` of `claude`;
   - (j) `/goal` with a 3-minute command as its second step;
   - (k) a user `Stop` hook that sleeps 90 s and then exits 2;
   - (l) a background `npm run dev`, then three prompts;
   - (m) Remote Control connected, with a prompt from the phone;
   - (n) Ctrl+C in the middle of a turn, then waiting 2 minutes;
   - (o) the plan run after "clear context" again, timing its first `PreToolUse`.
   Record from the log:
   - which events fire, in which order, and with which gaps (each line also shows that the probe's `cat` returned, so stdin was closed, for the async handlers too);
   - whether `pcomm` (the hook's grandparent, through `sh`) is the `claude` process;
   - whether `CLAUDE_CODE_SESSION_ID` equals `session_id` in each event, `SessionEnd` at `/clear` included;
   - the order of the top-level keys: whether `session_id` and `agent_id` come before `tool_input`, `tool_response` and `prompt`, and where `effort` stands (W2);
   - what `background_tasks` looks like in (e), (h) and (l), and whether `idle_prompt` fires while (l)'s server runs;
   - whether `idle_prompt` fired after (d) and (n);
   - in (j) and (k): whether the continuation fires `UserPromptSubmit`, and when its first `PreToolUse` comes after the `Stop`;
   - in (m): that `rc` shows while connected;
   - in (g) and (o): whether `UserPromptSubmit` fires for the plan run, and the time from `SessionStart` to the first `PreToolUse`.
2. **Shell form with spaces.** One handler with the probe at a path with a space in it, quoted as K2 quotes it. It runs.
3. **`claude agents --json`** (B-7). Run `claude daemon status`, then `time (for i in 1 2 3 4 5 6 7 8 9 10; do claude agents --json > /dev/null; done)`, then `claude daemon status` again: does the call start a supervisor? Record the output during (a), (b), during the approved 3-minute command of (b) (expect `busy`), during (k), and after (d) and (n). Repeat once with `disableAgentView` set.
4. **Claude Code's `caffeinate`.** Run `pmset -g assertions | grep -i caffeinate` and `ps -axo pid,ppid,command | grep [c]affeinate` during (a) and (b): whether it runs while working, and whether it stops while waiting (section 2).

If a fact differs from section 2 or 5, the design changes before W is written. Examples: no `PostToolUse` inside subagents, `agent_id` after `tool_input`, `pcomm` not `claude`, or a supervisor started by `claude agents --json` (then B-7 (b)).

## 10. Order, branch and release

1. **The preflight** (section 9), any time.
2. **W**, in two commits on `dev-2.5` (R-1): the fast path and the watcher with section 12n, then the status and the JSON. Each passes the whole self-test in the emulation and on CI's macOS.
3. **K** in one commit with section 12o and the installer and uninstaller steps.
4. **M** in one commit, with its checks if possible.
5. **After 2.4.0 has shipped,** merge `dev` into `dev-2.5`, add the CHANGELOG entries in one commit (R-1), merge into `dev`, and write `qa-2.5.0.md` from W.6, K.6 and M.6. Then the release, as 2.5.0. No Upgrade note is needed: nothing changes until the user turns the feature on, and the helper does not change.

W and K are independent, except that 12n's checks call `--agent-hook` directly, without K, and 12o's check 12 needs W. M needs both. Nothing here touches the 2.4.0 QA build.

## 11. Risks across items, and rollback

- **Users who never turn it on** see no change. The fast path runs only for `--agent-hook`, and the new JSON fields are `null`. The help gets one option.
- **A wrong turn of the rules could keep a closed Mac awake in a bag.** The guards against it:
  - the helper's own guardrails, unchanged (heat with the lid closed after two checks, battery);
  - the 12 h limit enforced by root;
  - the watcher's PID tie;
  - the 15-minute idle limit, and tombstones that a late heartbeat cannot lift;
  - no agent session starts while the lid is closed (B-11).
  The README's safety warnings (74-89) apply in full, and the new section says so.
- **A wrong turn the other way** sleeps the Mac while Claude works. That is a lost hour, not a hazard. Mac QA 1-11 cover the cases the design knows of.
- **Claude Code's hooks change.** The design uses only documented events and fields. The README names minimum versions. Section 9's probe can be rerun after a Claude Code update.
- **Rollback of the whole feature:** `awake --claude-hooks off` for one user. Reverting W, K and M removes it for everybody. The helper, the protocol and the session files of other sessions are unchanged, so a revert needs no migration.

## 12. Not in this plan (later)

- Codex (`hooks.json`, with its `Interrupt` event) and Gemini CLI, through the same verbs (S-2).
- Polling `claude agents --json` after an interrupt (B-7 (c)), once section 9 and a release with the last look have shown its cost.
- An MCP tool for "keep awake after my reply" (O5).
- Keeping the Mac awake for the whole Remote Control connection (B-9 (c)).
- A rolling root-enforced limit instead of 12 h (B-2 (d)).
- Locking the screen when the lid closes during an agent session, as Adrafinil does by default (Models/AdrafinilSettings.swift:39-41), if W.6 item 16 shows that macOS does not ask for the password, and a chime on lid close (LidActionDecider.swift:37-44).
