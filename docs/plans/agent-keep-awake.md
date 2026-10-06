# Plan: keep the Mac awake while AI works

- Status: a plan, not started. Nothing in it is implemented. First written on 2026-10-06 for Claude Code only, and revised the same day after the owner's answers: Awake should do this "for all the current mainstream AIs such as Claude Code, Codex, Cursor, and Gemini"; the timings stay; the 12-hour cap goes, and an automatic session has the same 365-day maximum as any session; what the user decides always overrides the automatics; and the owner asked what a stop by the user should do (B-5). Then revised once more after two reviews of that revision, whose points are applied or answered (see "How this plan was checked"); they added question B-14. Answered questions are marked as such below. The open ones follow the recommended answer until the owner decides. A Mac preflight (section 10) comes before any code: about 55 minutes for the owner's own setup (Cursor with the Claude Code extension, and Cursor's own agent), plus about 20 minutes for each of Codex and Gemini CLI if they are installed. It needs no Awake build, only the agents and a test hook.
- In brief: once the user turns it on (`awake --ai-hooks on`, or `Keep awake while AI works` in the menu), each supported agent's own hooks append one line per event to a file in the user's runtime folder. Four adapters write those hooks: Claude Code (terminal, JetBrains, the VS Code and Cursor extension, the Desktop app), Codex (terminal, `codex exec`, its IDE extension and app), Cursor's own agent (the editor and the `agent` CLI) and Gemini CLI. One agent-neutral core reads the lines: a small watcher keeps a "holder" for each agent conversation and subagent that works, waits for the user, or has background work. While any holder needs it, the watcher runs an ordinary Awake session tied to its own PID (`-w`), lid-closed in password-free mode, with the same 365-day maximum as any session. About a minute after the last holder ends, it ends that session the way `awake --` does, so a closed Mac sleeps. For Claude Code it first asks once whether that session is still busy (`claude agents --json`). What ends an automatic session is the end of the work, the watcher's exit (the PID tie), a guardrail or the user, not its 365-day limit. Whatever the user does wins: a start by hand replaces an automatic session, a stop pauses automatic sessions until the user's next prompt typed at the Mac, a changed setting applies to the running automatic session within 30 s, and the automatics never change a session the user started. The helper does not change (protocol 9), and nothing changes for users who never turn it on.
- Target version: after 2.4.0, the next minor version: 2.5.0. 2.4.0 is in its Mac QA on `dev` now (plan-2.4.0.md:3, faster-start-stop-2.md:3). The feature adds `### Added` entries, so `tools/release.sh` suggests a minor release (tools/release.sh:183-191). The helper does not change: no new command, no new file, not one byte. So the helper protocol stays 9 (bin/awake:172, awake-helper:56), and nobody is asked for a password at the update.
- Written: 2026-10-06, against `dev` at `a9cd6d1`, from the owner's request of that day: "I was not aware of Adrafinil; we should study what they do with AI agents at some point. It would be a nice addition to be able to select 'keep awake as long as Claude works'." Revised the same day against `dev` at `1bbb06f`, whose code is that of `a9cd6d1` (`git diff a9cd6d1 1bbb06f` touches only this plan), from the owner's answers quoted in "Questions for the owner". Bare line numbers are lines of `bin/awake` at that code. Other files are named, for example `awake-helper:851` or `StatusBarController.swift:603`. The agents' sources are cited as "How this plan was checked" describes: `<page>.md:LINE` for Claude Code's docs, `codex-rs/…` for Codex's source, `packages/…` for Gemini CLI's, and `[CD]`, `[FL]` and `[RO]` for a mirror of Cursor's docs and two projects that recorded Cursor's hooks running.
- Words used in this plan: an **automatic session** is a session that Awake starts by itself because an AI agent works; a session **started by hand** is any other (the CLI, the picker, the app, or a command that some program runs). An **adapter** is one agent's part: its hook file, its install and removal, how its events map to the common verbs, and its limits. 5.1 has the rest.
- Scope, checked against the code at `1bbb06f`:
  - W, automatic sessions in the CLI: `bin/awake`. It gets:
    - a builtins-only fast path for hooks right after `set -euo pipefail` (6), with one small table per agent (W2);
    - two internal modes next to `--caffeinate-start` and `--notify-wait` (7007-7071);
    - an internal option `--agent-session` next to `--if-off` (469);
    - `admin_transport` (6916-6926) and `run_as_admin` (4060-4131), so that an automatic start never asks for a password, and a dry-run branch in `helper_runs_without_password` (4052-4055);
    - an optional token argument for `request_helper_session_stop` (4320-4376);
    - the lock helpers `main_lock_is_abandoned` and `take_over_stale_main_lock` (1377-1413), with the lock folder as a parameter;
    - main's start path (7256-7397), for the handover of 5.9, and `--if-off` (7234-7243);
    - main's stop paths (7400-7470), which write the stop pause (5.9);
    - a new `lid_closed_causes_sleep` next to `lid_is_closed` (2385-2391), a copy of the helper's (awake-helper:604-619);
    - `start_detached` (3567-3573), so that the watcher starts with a minimal environment (5.8);
    - `write_session_file` (2785-2799);
    - the status text (2984-3066) and `print_status_json` (3190-3333);
    - new functions after `run_bound_command` (4455-4545);
    - `show_usage` (348-427).
    Tests: `tests/cli/awake-self-test`, a new section 12n after 12m (5992-6382), `cleanup_state` (262-270) and section 13 (6383).
  - K, connecting the agents: `bin/awake` gets `--ai-hooks on|off|refresh|status|print|resume`, with `--agent`, `--backend` and `--config-dir`, as a maintenance action next to `--passwordless` (parse_cli_args 607-624 and the check at 676-680, `run_maintenance_action` 6948-6965). Four adapters edit four files (K.3). Also touched:
    - `scripts/install-awake.sh`: a refresh step after :525;
    - `scripts/uninstall-awake.sh`: a removal step before `stop_active_session_if_needed` at :195;
    - `scripts/homebrew-uninstall.sh`, which runs that uninstaller;
    - `tests/cli/awake-self-test`, a new section 12o.
  - M, the menu bar app (`app/AwakeStatusApp/Sources/`):
    - `AwakeCLI.swift`: the decoded fields, 10-88;
    - `StatusDescription.swift`: the sentences for automatic sessions, 22-54;
    - `StatusBarController.swift`: a menu item and the pause items in `showContextMenu`, 783-850, and the end notifications in `maybeNotifyCompletionTransition`, 603-631;
    - `SettingsWindowController.swift`: an "AI agents" group;
    - `InstallSupport.swift`: the guardrail notification text, 375-431;
    - optionally checks in `tests/app/` with their CI steps (`.github/workflows/ci.yml`, after :96).
  - Docs: `README.md` (Highlights, the use case at :44, a new "While AI works" section, Options, Menu bar app, Runtime files, Security notes, Uninstall), `CHANGELOG.md` (`[Unreleased]`, once 2.4.0 has shipped), and `docs/plans/` (this plan, and later a `qa-2.5.0.md`).
  - Not touched: `bin/awake-helper`, the boot-restore LaunchDaemon, the sudoers rule (4737), the picker `tools/awake-gui-picker.swift` (unless question S-1 is answered (b) or (c)), and `tools/release.sh`. No new shipped file: the hook code lives in `bin/awake` (decision W14). Files Awake generates per user live in its own folder `~/Library/Application Support/Awake/` (the installer's, scripts/install-awake.sh:12-14): `ai-hooks.conf` (K1), the stop pause `agent-pause` (W10) and the Gemini extension `gemini-extension/`, which Gemini CLI sees through a link (H-4).
- Relation to other plans:
  - faster-start-stop-2.md is done and ships in 2.4.0. This plan builds on three of its results:
    - G1: `wake_helper_timer` (4308-4318) and `command-finished`, so an automatic session ends at once and as `process_exited`;
    - H: the status report that a command writes for the app as it exits (`write_status_report`, 3549), which `--ai-hooks` and the watcher's end step also write, so the app's view changes at once;
    - I1: `sudo_without_password` (4047-4050) and `helper_runs_without_password` (4052-4055), which decide whether a lid-closed automatic session can start without a prompt.
  - plan-2.4.0.md's rule "`awake` posts no notifications unless asked" (CHANGELOG.md, `[Unreleased]`) holds for automatic sessions too (decision W16).
  - qa-2.4.0.md does not change.
  - Nothing here conflicts with an open plan.

## The principle: what the user decides wins

The owner, 2026-10-06: "For B-4, I think what the user decides should always override the automatics." Every rule below follows from it.

- **A start by hand replaces an automatic session.** Any start that the user (or a program in the user's name) asks for, with a length, an end time, `--indefinite`, `-w`, `--`, the picker or the app, ends the automatic session and starts exactly the session asked for (the handover, 5.9). It does not add time to the automatic session, and it is not refused. `--if-off` (the app's keyboard shortcut and `Start default session`) still changes nothing while a session the user started runs, as it promises (7234-7243), but it counts an automatic session as off and replaces it, as the app's last poll may have been made before the automatic session began.
- **Added time is a start by hand.** A time option during an automatic session gives the user's own session with that end, not "the automatic session plus some time", and the CLI says so. The app's menu offers `Keep awake for 1 hour` (the length to add from Settings) instead of `Add 1 hour` during an automatic session (M4). Whether "at least an hour" is wanted instead is question B-14.
- **A stop wins, for every agent.** A stop ends the session and pauses automatic sessions for all agents until the user's own next prompt, typed at the Mac after the stop (B-5). `Resume now` in the menu lifts the pause at once. The pause is written by the stop itself, before the session ends, so no automatic start can slip in between (5.9), and it survives a restart (W10).
- **A setting change wins.** Turning the feature off, for all agents or for one, takes effect at once: the hooks go, and an automatic session that only that agent kept ends (K11). A new lid mode or new guardrails reach the running automatic session within 30 s: with the lid open the watcher replaces it with one that has the new settings, and with the lid closed a switch to lid-open lets the Mac sleep (5.9). A session the user started keeps the settings it started with, as today (7280-7287).
- **The automatics never touch the user's own session.** They never extend, shorten, end or replace it, and they start nothing while it runs. When it ends:
  - with the lid open, an automatic session may follow within a pass (2 s) if an agent still works;
  - with the lid closed, the Mac sleeps at its end as the user's session says (awake-helper:850-855), even while an agent works, and no automatic session starts until the lid is open (B-11);
  - when the user stopped it while an agent worked, the stop rule above applies.
- **The user's own session never lifts a pause.** A start by hand, also one an agent runs through its shell tool, runs as asked, but it clears neither a stop pause nor a guardrail pause; only the user's typed prompt, `Resume now` or the cause going away does (5.9, 5.10).
- **The guardrails are the user's settings too.** They end automatic sessions as any session, and automatic sessions then pause until the cause has gone (5.10).
- **What the automatics may do:** start a session only when none runs, no pause stands, the watcher has read how the last one ended, and the lid is open (or the Mac is in closed-display mode, B-11); and end only their own session, checked by token under the main lock (W6).

## Questions for the owner

The owner answered five questions on 2026-10-06; they are marked "Answered". The open ones follow their recommended answer until the owner decides. The section named in each question explains it.

| Question | Answer on 2026-10-06 |
|---|---|
| S-1, a setting or a one-off choice | In effect (a), a setting: "the idea appears to be making 'AI runs -> awake on' and 'AI stops -> awake off' triggers automatic". Say so if (c) is wanted. |
| S-2, which agents | "Awake should offer this functionality for all the current mainstream AIs such as Claude Code, Codex, Cursor, and Gemini. I currently use Cursor as my editor and run Claude Extension inside it." S-4 now asks which surfaces of them. |
| B-1 and B-2, the timings | "I think the timings are appropriate": 60 s after the work ends, 10 minutes of waiting for the user, the 15-minute idle limit, 1 hour of background work. |
| B-2, the session limit | "I would still put the cap in 365, then it is the same as in other use. I guess in the future, it could be possible to have really long automatic AI runs." B-12 asks what then bounds an automatic session. |
| B-4, a session started by hand | "What the user decides should always override the automatics": (a), and the principle above. |
| B-5, a stop by the user | Asked as a question. Answered below with a recommendation, for the owner to confirm. |

S-3, S-4, H-1, H-3 to H-6, B-5, B-12 and B-13 shape the most code. The other open questions, B-14 (added time during an automatic session) among them, change constants or a few branches.

### Scope and names

- **S-1. What does "keep awake while AI works" mean in Awake? (sections 4, 5)** Answered on 2026-10-06, in effect: (a).
  - (a) A setting. Once it is on, every turn of a connected agent keeps the Mac awake, also with the lid closed, and the Mac sleeps again about a minute after the work stops. A checkmark item in the Ctrl-click menu turns it on and off. This is Adrafinil's model, and it matches how agents are used: prompt after prompt, and sometimes with the lid closed. **Recommended, and the owner's answer.**
  - (b) A one-off choice in the picker's `Custom…` step, `While AI works`, next to `For`, `Until` and `While`. It starts a session now and ends it the first time the agents stop working. The next turn starts nothing. It needs the same hooks as (a), and also a new end token and the picker's code (tools/awake-gui-picker.swift, around :938).
  - (c) Both. (a)'s code, plus (b)'s picker work and a "one-off" marker the watcher clears when it ends the session.

- **S-2. Which agents? (sections 1, 2)** Answered on 2026-10-06: all current mainstream agents, Claude Code, Codex, Cursor and Gemini, with the owner's own setup (Cursor as the editor, the Claude Code extension inside it, and Cursor's own agent) as the first worked example (section 6). The hook verbs, the holder keys and the event log were already not tied to Claude Code; the revision adds one adapter per agent (5.2, K.3). S-4 asks which surfaces.

- **S-3. Names, and where the switch lives. (sections 8, 9)**
  - (a) "AI". The menu item `Keep awake while AI works`, with a checkmark, shown when any supported agent is found on the Mac. The CLI: `awake --ai-hooks on|off|refresh|status|print|resume`, with `--agent claude|codex|cursor|gemini|all` (all agents found, by default) and `--config-dir DIR` for an agent's extra settings folder. A README section `While AI works`. A Settings group `AI agents`, with one row per agent, a lid-mode popup and the pause. The status names the agents at work: `Awake is on while Claude works.`, `Awake is on while Claude and Cursor work.` "AI" is the owner's own word, short, and clear to users who do not think of their assistant as an "agent". It also keeps the user's option apart from the internal `--agent-hook`. **Recommended.**
  - (b) "Agents": `Keep awake while agents work`, `--agent-hooks`. The usual technical word, but less plain, and one letter from the internal `--agent-hook`.
  - (c) One option per agent: `--claude-hooks`, `--codex-hooks`, `--cursor-hooks`, `--gemini-hooks`, each with the same verbs, and one menu item per agent. Each reads plainly, but the help grows by four options, each new agent adds another, the lid mode they share would be set in four places, and the owner's setup needs two of them.
  - (d) "Coding agents": `Keep awake while coding agents work`. Precise, and longer in a menu.

- **S-4. Which agents and surfaces in the first release? (2.1, K.3)** The matrix in 2.1 lists every surface with the signal it gives.
  - (a) The four the owner named, on every surface where the agent runs on the Mac and documents a hook that Awake can use:
    - Claude Code: the terminal (also inside Cursor's, VS Code's or JetBrains' terminal), the VS Code and Cursor extension, and the Desktop app's local sessions, all through the same `~/.claude/settings.json` (hooks.md:13; vs-code.md:525; desktop.md:906);
    - Codex: the terminal, `codex exec`, and its IDE extension and desktop app, all through `~/.codex/hooks.json` once the user has trusted the hooks (H-3);
    - Cursor's own agent: the editor (Agent chat, Cmd+K, local agents) and the interactive `agent` CLI, through `~/.cursor/hooks.json`;
    - Gemini CLI: the terminal, headless `gemini -p`, and ACP mode in Zed and JetBrains, through an extension folder (H-4).
    Surfaces without a usable hook get the manual paths that work today: `awake -- COMMAND`, `awake -w PID` or `While` in the picker, or a timed session. Cloud sessions of every agent need nothing from the Mac. **Recommended.**
  - (b) Claude Code and Cursor's agent first, the owner's own setup, then Codex and Gemini CLI in a later minor version. Less to test in 2.5.0, but the owner asked for all four.
  - (c) (a), plus GitHub Copilot, whose one file `~/.copilot/hooks/awake.json` covers Copilot CLI and VS Code's Copilot agent (github/docs@8f330f1 content/copilot/reference/hooks-reference.md:36-40; vscode-docs@279a4a7 docs/agent-customization/hooks.md:130-141), and Google Antigravity as an experiment. More reach, but Copilot's VS Code payloads differ from its CLI's (vscode-docs hooks.md:186), and Antigravity's sources disagree about its events (2.5).

### Setup

- **H-1. How do Awake's hooks get into each agent? (section 8)**
  - (a) `awake --ai-hooks on` writes Awake's handlers into each agent's own user-level hook file, the way that agent documents it, one handler at a time, and leaves every other handler alone:
    - Claude Code: `~/.claude/settings.json`, and each `--config-dir` folder: 13 handlers;
    - Codex: `~/.codex/hooks.json`: 10 handlers, in groups of their own at the end of each event (H-3);
    - Cursor: `~/.cursor/hooks.json`: 7 entries;
    - Gemini CLI: an extension that Awake keeps in its own folder and links into Gemini CLI: 6 handlers (H-4).
    Each handler is one shell-form command, `'<awake path>' --agent-hook AGENT VERB >/dev/null 2>&1; exit 0`, which every agent runs through a shell (K2). It refuses a file it cannot parse or that changes while it works. It writes through a symlink and keeps the file's mode. `off` removes only Awake's handlers, and also ends an automatic session that only those agents kept. The installer runs `refresh`, which updates the handlers and the path only where they are already on, and the uninstaller runs `off` for every agent and folder Awake wrote to. `print` prints each block for pasting by hand. **Recommended.**
  - (b) A plugin or extension for each agent where one exists: a Claude Code plugin with Awake's repository as its own marketplace (`/plugin marketplace add anttikaenmaki/awake`, discover-plugins.md:180-213; hooks in `hooks/hooks.json`, plugins/components.md:745-779), a Codex plugin, a Cursor plugin (Cursor installs hooks "through plugins from Customize" too, [CD] hooks.md:9), a Gemini extension. Awake would edit fewer files, but:
    - a plugin's version is not tied to the installed `awake`, and its script must find `awake`;
    - installing needs each agent's own command or a step inside a session, and the app's checkbox would have to drive them;
    - a Codex plugin still needs the trust step, plus a marketplace step (codex-rs/hooks/src/engine/discovery.rs:244-295).
  - (c) Only `print`: the user pastes each block themselves. There is no risk to their files, but there is no menu switch either, and every update that changes a hook set needs a manual edit in up to four files.

- **H-2. Lid mode of automatic sessions, and password-free mode. (5.3, W12, K8)** One choice for all agents.
  - (a) Lid-closed by default. That needs password-free mode, because a hook has no terminal and must never pop a password dialog in the middle of a turn (hooks.md:720; Codex also starts each hook in a new session, codex-rs/hooks/src/engine/command_runner.rs:412-413).
    - The first `--ai-hooks on`, and any `on --backend awake`, refuses while password-free mode is off, and names `awake --passwordless on`.
    - The app's checkbox offers to turn password-free mode on first, which asks for the password once, as turning it on always does.
    - `--ai-hooks on --backend caffeinate` chooses lid-open sessions instead. The choice is stored, and `on` without `--backend` and `refresh` keep it.
    - If password-free mode is turned off later, automatic sessions fall back to lid-open, and `--status` says why.
    **Recommended.**
  - (b) Lid-closed when password-free mode works, otherwise lid-open, with no refusal at setup. Less friction, but a user who never turned password-free mode on closes the lid and finds that the Mac slept.
  - (c) Lid-open only. No password-free mode is needed. But some agents already keep the Mac from idle sleep while they work: Claude Code with its own `caffeinate -i` (section 1), and reportedly Cursor with a wakelock (a forum snippet only, section 1). For them lid-open sessions add little: only the waits and the minute between turns. Codex holds none by default and Gemini CLI none at all (section 1), so for them lid-open sessions are worth more.

- **H-3. Codex's trust step. (K.3.2)** By Codex 0.130.0 (not at 0.125.0; the release tags in between were not checked, 2.3) a hook from the user's files runs only after the user has trusted it. The trust is a hash per handler, stored in `~/.codex/config.toml` under a key made of the file, the event's snake_case label (`user_prompt_submit`) and the handler's group and position, and untrusted or changed hooks are skipped without an error (codex-rs/hooks/src/engine/discovery.rs:666-736, 796-823; codex-rs/hooks/src/lib.rs:95-123). At startup Codex's terminal UI shows "Hooks need review", with "Trust all and continue", which asks for an explicit confirmation (codex-rs/tui/src/startup_hooks_review.rs:46-50, 266-271), and `/hooks` reviews them too.
  - (a) Awake writes its handlers and never trusts them for the user. `on` ends with "Start codex in a terminal once and choose Trust all and continue, then confirm (or run /hooks); in the Codex app or IDE extension, review hooks there if it offers it. Until then Codex skips Awake's hooks." `status` reads `installed, not trusted yet` while the trust entries are missing, and `installed, review again in Codex` after a `refresh` that changed a handler's text (K13). Awake's handlers stay byte for byte the same across upgrades unless the awake path changes, and its groups never move, so the trust survives `refresh`. **Recommended**: the review is Codex's security control, and Adrafinil makes the same choice (adrafinil@6e4eece AdrafinilShared/Sources/AdrafinilShared/Installer/Integrations/CodexIntegration.swift:28-32).
  - (b) Awake writes the trust entries itself. No step for the user, but it bypasses Codex's review, and it needs a TOML writer and Codex's canonical hash (discovery.rs:768-794; codex-rs/config/src/fingerprint.rs:54-66).
  - (c) The system layer, `/etc/codex/hooks.json`, which Codex counts as managed and runs without review (discovery.rs:715-720, 825-833). Machine-wide, and it needs an administrator. Not recommended.

- **H-4. Gemini CLI: an extension, or the settings file? (K.3.4)**
  - (a) An extension, with `gemini-extension.json` and `hooks/hooks.json` (gemini-cli@fb972b2 docs/extensions/reference.md:240-244), kept in a folder Awake owns, `~/Library/Application Support/Awake/gemini-extension/`, and registered as a linked extension: `on` runs `gemini extensions link <folder> --consent` when it finds a `gemini` executable (packages/cli/src/commands/extensions/link.ts:64-78), and says that the user's `on` is the consent Gemini would ask for ("This extension contains Hooks which can automatically execute commands", packages/cli/src/config/extensions/consent.ts:322); otherwise it writes only `${GEMINI_CLI_HOME:-$HOME}/.gemini/extensions/awake/.gemini-extension-install.json` with `{"source": "<awake folder>", "type": "link"}`, the record `link` writes (extension-manager.ts:438-443), from which Gemini loads the extension's files (extension-manager.ts:762-764). Never a bare folder with the files under `~/.gemini/extensions`: while `security.allowedExtensions` is set, in any settings file, an extension without that record aborts Gemini CLI's startup ("An unexpected critical error occurred"; extension-manager.ts:725-731, 612-672; packages/cli/src/config/config.ts:675; packages/cli/index.ts:137-168), whereas a linked one that the allowlist does not match is only skipped with a warning (extension-manager.ts:746-750). Never `type: "local"` with Awake's folder as its own source, as an update would first delete it (extension-manager.ts:568-576). Gemini loads every folder there (extension-manager.ts:628-639) and aborts on two that declare the same name (:645-651), so `on` refuses when another folder already declares `awake`. Awake never edits the user's `settings.json`, which may hold comments that Gemini accepts (packages/cli/src/config/settings.ts:786-787) and JavaScript's `JSON.parse` refuses. Removal deletes the link folder and Awake's folder. Extension hooks also run in folders Gemini does not trust (packages/core/src/hooks/hookRegistry.ts:188-198; hookRunner.ts:64-79), where hooks from the settings files do not (hookRegistry.ts:172-186). **Recommended.**
  - (b) Merge into `~/.gemini/settings.json`, like the other agents. One mechanism everywhere, but files with comments are refused, and the hooks are skipped in every folder not yet trusted, the default since v0.24.0 (docs/changelogs/index.md:572-574).
  - (c) Only `print` for Gemini.

- **H-5. Cursor's agent also runs Claude Code's hooks. (K.3.3, W2)** Cursor's own agent and its CLI run the hooks in `~/.claude/settings.json` too, with Cursor's payloads, while "Include Third-Party Plugins, Skills, and Other Configs" is on, which it is by default (mehmetbaykar/cursor-docs-skill@116359f skills/cursor-docs/references/reference__third-party-hooks.md:17, 21-41; cli__changelog.md:421).
  - (a) Native Cursor handlers in `~/.cursor/hooks.json`, and Awake's Claude Code handlers do nothing for a Cursor payload: one whose fields before the first content key hold `"conversation_id"`, a key Cursor sends with every agent event, first in the captured payloads ([CD] hooks.md:814-846; [RO] cursor-logs.txt:12, 62), and Claude Code never sends (0 matches in hooks.md). Each Cursor turn then counts once, under Cursor, whatever the user's Cursor setting. The price: while the import is on, Cursor also runs Awake's Claude Code `PreToolUse` handler as its own `preToolUse`, a permission hook that Cursor always waits for ([CD] hooks.md:198, 701-712: no `async` option), so each Cursor tool call waits for two short Awake processes, and a rollback for Cursor must cover both files (K.9). **Recommended.**
  - (b) No Cursor handlers: let Cursor run Awake's Claude Code handlers. One file fewer, but it depends on a Cursor setting, gets no `afterAgentThought`, the first sign of a follow-up turn ([FL] docs/providers/cursor-agent.md:57, 2.4), no `postToolUseFailure` (not in Cursor's mapping, third-party-hooks.md:205-220), and every Cursor turn would be named Claude's in the status.
  - (c) Both, without the stand-down. Every Cursor turn would arrive twice, half of it under Claude's keys. Not recommended.

- **H-6. An agent installed after the feature was turned on. (K.3, M3)**
  - (a) `on` covers the agents found at that moment. An agent found later is not turned on by itself: Settings lists it as off, with its own checkbox, and `status` reads `off` for it while others are on. The installer's `refresh` never adds an agent. **Recommended**: Awake edits another tool's files only when the user asks.
  - (b) The app turns on every newly found agent while the feature is on. Nothing to remember, but Awake writes into a new tool's settings without being asked, and for Codex the trust step still waits for the user.
  - (c) `refresh` adds them at each Awake update. The same objection, at a time the user does not expect.

### Behaviour

- **B-1. Waiting for the user: a permission prompt, a question, a plan to approve. (5.6)** Answered on 2026-10-06: (a), as part of the timings. No hook in Claude Code, Codex or Gemini CLI fires when a prompt is answered (section 2), and Cursor has no waiting signal at all (2.4). So after a waiting event the holder stays `waiting` until the approved tool has run and its post-tool event arrives. One exception from the reviews: Codex runs `PermissionRequest` before its automatic reviewer too, so with `approvals_reviewer = "auto_review"` it fires although nobody is asked (codex-rs/core/src/tools/approvals.rs:505-525; codex-rs/protocol/src/config_types.rs:178-189), and its payload does not say which (codex-rs/hooks/src/schema.rs:301-318). Codex's `PermissionRequest` is therefore a heartbeat (`tool-start`), and an approval nobody answers there costs the 15-minute idle limit, as Cursor's approval cards do; only Codex's question tool counts as waiting (5.2).
  - (a) Stay awake for 10 minutes of waiting, then, for Claude Code, take the last look (B-7): if Claude Code reports that session `busy` (the prompt was answered and the tool runs), the holder goes back to working, and otherwise the Mac may sleep. For agents without a last look the 10 minutes are the end (B-13). The 10 minutes let an answer from a phone over Remote Control reach a Mac whose lid is closed. Adrafinil's default is the same (adrafinil@6e4eece AdrafinilShared/…/Models/AdrafinilSettings.swift:3-15, 52-57). **Recommended, and the owner's answer.**
  - (b) 10 minutes and nothing more, also for Claude Code. A tool approved at minute 5 that runs 8 minutes is cut off at minute 10, and a closed Mac sleeps in the middle of it.
  - (c) Stay awake while waiting, as while working, up to the 15-minute idle limit. Simpler (no `waiting` hooks), but a forgotten prompt keeps a closed Mac awake for 15 minutes.
  - (d) Sleep after the end grace (60 s). The Mac sleeps soonest, but a phone answer after a minute finds it asleep.

- **B-2. Timings. (5.5, 5.6, 5.10)** Answered on 2026-10-06: (a), with the session limit at 365 days. All are constants in `bin/awake`, with shorter values in the dry run:
  - the end grace after the last holder ends: 60 s;
  - the idle limit without any sign of work: 15 min;
  - the waiting allowance: B-1; the background allowance: B-8;
  - each automatic session's own time limit: 365 days, the maximum of every session (`MAX_DURATION_SECONDS`, 121-122), which the root helper also enforces (awake-helper:57-59). The first version had 12 hours here.
  - (a) As listed, with no setting in the app. **Recommended, and the owner's answer.** The idle limit is longer than a foreground Bash call of Claude Code (10 minutes at most by default, tools-reference.md:160-161), and it counts from the start of the running tool, as each agent's pre-tool event sends a heartbeat (5.6). MCP tools of Claude Code may run for about 28 hours (`MCP_TOOL_TIMEOUT`, env-vars.md:483), and the user can raise `BASH_MAX_TIMEOUT_MS`: with the last look such a tool reads `busy` and goes on, up to the quiet limit (B-12), and without it the README lists it as not covered.
  - (b) A 5-minute idle limit. The Mac sleeps sooner after an interrupt that no hook reports. Safe only with the last look: without it, a 6-minute build would end the session while it runs.
  - The other options on the limit (none, or a rolling root-enforced limit) are now part of B-12.

- **B-3. Which guardrails do automatic sessions use? (5.10)**
  - (a) The app's Guardrails settings: `Stop when too hot`, `Stop at low battery` with its level, and `Stop when unplugged`. The CLI reads them from the app's defaults domain, as it already reads the picker's settings (1156-1191). When they are not set, the CLI's defaults apply (5%, on, off). **Recommended.**
  - (b) Always the CLI's defaults: 5%, thermal guard on, unplug guard off. No new reads, but the app's settings do not apply to automatic sessions.
  - (c) As (a), but with the unplug guard on by default for automatic sessions. A Mac carried off while an agent works then sleeps within 5 to 10 seconds of unplugging (README.md:61). It surprises users who work on battery, though: a session started on battery is affected only after the Mac has been plugged in (README.md:61).

- **B-4. A session the user started by hand. (5.9)** Answered on 2026-10-06: (a), "what the user decides should always override the automatics", now the principle at the top. In every option a start by hand during an automatic session (a time option, `-w`, `--`, the picker) replaces the automatic session instead of adding time to it or being refused (the handover, 5.9), and an automatic session starts only when no session runs.
  - (a) Automatic sessions never change the user's session. When it ends while an agent still works:
    - with the lid open, an automatic session follows within a pass (2 s);
    - with the lid closed, the Mac still sleeps at your session's end, even while the agent works (awake-helper:850-855), and the agent's turn stalls until you open the lid. Then an automatic session follows (B-11).
    The README says this plainly. **Recommended, and the owner's answer.**
  - (b) While an agent works, the user's timed session is extended past its end. The Mac stays awake with the lid closed, but a session the user timed no longer ends when they said.
  - (c) While a holder works and the lid is closed, the watcher adds 5 minutes at a time to the user's timed session. The turn does not stall, but it still changes a session the user timed.

- **B-5. What happens when the user stops the automatic session while the AI still works? (5.9)** The owner, 2026-10-06: "What if the user stops the automatic session? Does it start again automatically (given Claude is still working)? This sounds logical, but is it good in practise?" A stop is a click on the icon, `Stop session`, `awake --stop` or plain `awake`, of an automatic session or of the user's own while an agent works. Stop or Esc inside an agent's window is not a stop of Awake: in the Claude Code extension it ends only the current turn, and background agents keep running (vs-code.md:172).

  The short answer: not at once, and not in the same run. Starting again while the work goes on is logical on paper, but in practice it makes the stop look broken and undoes the reasons people stop. The cases:

  | Case | (a) Pause until your next prompt | (b) Start again at once | (c) Off until turned on again | (d) Pause for a fixed time (1 h) |
  |---|---|---|---|---|
  | You stop, close the lid and leave, while Claude still works | The Mac sleeps; nothing starts again: no key or click came after your click on the icon, and the lid is closed; the turn stalls until you are back and type | The next tool call, seconds later, starts a session again. If it comes before the lid closes, the Mac stays awake in the bag (B-11 stops only starts with the lid already closed) | The Mac sleeps | The Mac sleeps; after the hour nothing starts with the lid closed |
  | You stop to save battery and keep working with the lid open | Off until your next prompt to an agent; a scheduled or background turn that happens to start while you type elsewhere also lifts it (the next row); while you use the Mac with the lid open, a session changes little, and the battery guard applies | The stop does nothing you can see | Off for good | Back after an hour, while you may still be on battery |
  | You stop, keep working in other apps, and a `/loop` iteration or a background report starts while you type | The pause lifts: the hook cannot tell this turn from a typed one, and you used the Mac a moment ago. A session runs while the work goes on, and the menu shows it. If you then close the lid and leave, the Mac stays awake until the work ends, as after any prompt | The same, and sooner | Stays off | Starts again after the hour |
  | You stop by mistake | `Resume now` in the menu, or your next prompt | Undone by itself | You have to find the setting | Back after an hour |
  | Claude in the Cursor panel and Codex in a terminal at once | One stop pauses both; your next prompt to either lifts it | The other agent's next tool call starts a session again | Both off | Both back after an hour |
  | You stop at night with the lid open; a `/loop` or scheduled task runs overnight | Stays off: nobody touches the Mac, so those turns lift nothing | The next iteration starts a session, and the Mac stays awake all night | Stays off | Starts again an hour later, for the rest of the night |
  | A phone prompt over Remote Control after you stopped and closed the lid | Nothing starts (lid closed, and no input at the Mac) | Nothing starts (B-11) | Nothing starts | Nothing starts |
  | You restart the Mac during a pause | The pause stands until your next prompt (W10) | No pause to keep | Stays off | Back after the hour |

  - (a) The stop ends the session and pauses automatic sessions for every agent until the user starts a new prompt themselves, at the Mac, after the stop. The pause is written by the stop itself (5.9). It is not lifted by the turn that was still running, nor by a turn that starts while nobody uses the Mac (a scheduled task, a `/loop` iteration, a background subagent's report, a message from another session, a usage-limit resume, a Codex `/goal` continuation, a Cursor follow-up, `/goal` continuation, `/loop` iteration or background-task wakeup), nor by anything while the lid is closed and closing it sleeps the Mac (B-11), nor by a start by hand, also one an agent runs. While it stands, the menu shows `Paused until your next prompt` and `Resume now`, `--status` adds `AI sessions are paused until your next prompt.`, and Settings shows the same. `Resume now`, or turning the feature off and on, also clears it. It survives a restart (W10). **Recommended.** Why:
    - The stop is the user's clearest signal; the next moment they act again is their next prompt, which is also when they would expect the feature back.
    - Stopping and leaving is safe: after a stop, a session starts again only if somebody uses the Mac and an agent's turn starts within seconds of that, so "stop, close the lid and leave" never restarts one. The one case it lets through is the third row: a turn that is not typed but starts while the user types elsewhere, which the menu then shows.
    - One pause for all agents, because there is one session for all of them: a pause per agent would let another agent start it again at once.
    - A stop by mistake costs one click (`Resume now`) or nothing (the next prompt).
    - Adrafinil, the closest tool, separates the same two things: "force release" lets the next agent hook hold again, and a "Let it sleep" pause stays until the user resumes, also across a restart (adrafinil@6e4eece AdrafinilShared/Sources/AdrafinilShared/IPC/DaemonProtocol.swift:20, 28; Models/PersistedDaemonState.swift:3-6).

    How "a prompt the user typed" is told apart differs per agent (5.9, 2.2-2.5):
    - Claude Code runs `UserPromptSubmit` also for a scheduled task or `/loop` iteration, a background subagent's report and a message from another session (hooks.md:1325-1329), in the extension and the Desktop app also for turns it starts on its own (agent-sdk/hooks.md:153), and for the continuation after a usage limit (interactive-mode.md:688). Its payload has no field that tells them apart (hooks.md:728-744, 1337-1351). A typed prompt runs it at once, as it blocks the prompt until the hook returns (hooks.md:1331).
    - Codex runs `UserPromptSubmit` for each user input, also input typed while a turn runs, but not for a `/goal` continuation or a message between agents (codex-rs/core/src/hook_runtime.rs:677-714; codex-rs/ext/goal/src/runtime.rs:474-485). It runs after pre-turn compaction and MCP startup, so it can come many seconds after Enter (codex-rs/core/src/session/turn.rs:184-379). Its app's automations probably run it too (not verified).
    - Cursor runs `beforeSubmitPrompt` "right after user hits send" ([CD] hooks.md:1243-1245), not for a follow-up turn ([FL] cursor-agent.md:57). Cursor also has `/goal` continuations, `/loop` iterations and background tasks that wake the agent ([CD] agent__overview.md:132-142; skills.md:51; release-notes__agents-window.md:190, 296); which hooks they fire: not found (section 10.2 (u)).
    - Gemini CLI runs `BeforeAgent` at the start of a prompt's turn, before any compression (packages/core/src/core/client.ts:924-946, 165-193), and again only for a continuation that another hook forces (client.ts:1031-1047).
    So the pause lifts on a `turn-start` of a main conversation (no subagent id) when all of these hold, tested in `main` (W26):
    - the lid is open, or the Mac is in closed-display mode (`lid_closed_causes_sleep` is false, B-11);
    - the Mac's last keyboard or mouse input came at least 2 s after the stop, so the click that made the stop does not count: the time now, less the input idle time, is at least the pause's `since` plus 2;
    - the input idle time is at most 5 s, or 60 s for Codex, whose hook can lag Enter. A typed prompt runs the hook within a second of Enter in Claude Code, Cursor and Gemini CLI (above); section 10 measures it and may narrow or widen the 5 s;
    - the idle time could be read: if `ioreg` fails or times out, the pause stays, and `Resume now` remains.
    macOS reports that idle time as `HIDIdleTime` in `ioreg -c IOHIDSystem` (a design assumption, measured in section 10). A phone prompt with nobody at the Mac does not lift it, which matches "typed at the Mac". A prompt queued in the Claude Code panel while a turn runs may run its hook only when it is taken up, more than 5 s after the typing (not found, measured in 10.2); it then does not lift the pause, and the README says to use `Resume now`.
  - (b) No pause: the next tool call starts a session again. See the table: a stop seems not to work, and "stop and close the lid" can leave the Mac awake in a bag.
  - (c) The pause stays until the user turns the feature off and on, or chooses `Resume now`. Safe, but it turns "stop now" into a setting change the user did not make, and the next day's work runs without the feature until they remember.
  - (d) A pause for a fixed time, such as an hour. The timer is invisible, and the session comes back while the user may be away with the lid open.
  - (e) The first version's rule: the pause lifts on the next turn of any kind that starts while the lid is open. No input check, but an overnight `/loop` or a background report starts again the session the user stopped.

- **B-6. Notifications. (5.12)**
  - (a) None for an automatic session's start or its normal end, as both come with every turn. When a guardrail ends an automatic session (low battery, too hot, unplugged), the app posts it and says that the agents may still be working, by name ("Claude Code may still be working."). The CLI posts none, by 2.4.0's rule. **Recommended.**
  - (b) Also `Claude finished` (or the agent's name) when a session ends normally. That is useful once, but with the lid open it comes after every turn.
  - (c) None at all, guardrail ends included.

- **B-7. A last look before the Mac may sleep, for Claude Code. (5.6, W21)** When a time rule would end the last Claude Code holder that keeps an automatic session (the end grace, the waiting allowance, the idle limit, the background allowance), and when a tool starts for a session whose turn had ended and whose holder was dropped, the watcher runs `claude agents --json` once. That is "the supported way to read session state from outside Claude Code" (agent-view.md:779), and it gives each live session's `pid` and `status`, `busy`, `waiting` or `idle` (agent-view.md:764-777). A main-conversation holder whose process reads `busy` goes back to working; subagent holders share their session's process (hooks.md:269), so the last look never revives them. Anything else, or a failed call, lets the time rule apply. A holder whose process a successful call does not list gets B-7 (b)'s timings from then on, and so does a holder whose hooks ran with another `CLAUDE_CONFIG_DIR`, whose sessions a supervisor of the default folder does not see (agent-view.md:817). Codex, Cursor and Gemini CLI document nothing like it (2.3-2.5): their holders follow the time rules alone (B-13).
  - (a) Yes, if section 10 shows that it works with the installed Claude Code, lists the sessions of the extension inside Cursor (the owner's setup, not documented), starts no background supervisor, and takes under 1 s; otherwise (b). The docs say that `claude agents` starts the supervisor on demand, a background service that also restarts sessions (agent-view.md:758, 802-809, 918, 932); whether the `--json` form does is checked with `claude daemon status` before and after (10.3 (f)). If it does, expect (b) to become the default, or the last look to run only while a supervisor already runs. It covers what no hook signals: a prompt answered (B-1), a `/goal` or Stop-hook continuation that starts its first tool late, a plan run that thinks before its first tool, an MCP tool longer than the idle limit. It is one call at each expiry, not polling. **Recommended.**
  - (b) No. Time rules only, with the waiting allowance at 20 minutes (B-1) and the end grace at 3 minutes, so that a slow Stop hook or a plan run is covered more often. Each normal reply then keeps a closed Mac awake 3 minutes instead of 1.
  - (c) As (a), and also poll it during gaps of 2 minutes or more without hooks. The Mac sleeps sooner after an interrupt, which matters most in the extension, where no `idle_prompt` fires (2.2). But each poll starts `claude`, on a feature in research preview (agent-view.md:22).

- **B-8. Background work and scheduled wakeups after a turn, for Claude Code. (5.6, W9)** `Stop` reports `background_tasks` (shells, subagents, monitors, workflows) and `session_crons` (scheduled wakeups and `/loop`) (hooks.md:2583-2605). Local background commands have no time limit (tools-reference.md:186, 190), so a dev server or `tail -f` can run for days. Codex's `Stop` (codex-rs/hooks/src/schema.rs:585-601), Cursor's `stop` ([CD] hooks.md:1304-1324) and Gemini's `AfterAgent` report no background work, so for them background work after a turn does not count. Cursor also has background tasks that wake the agent later ([CD] release-notes__agents-window.md:190), unreported in `stop`.
  - (a) Background tasks keep the Mac awake for 1 hour, counted from the first `Stop` that reports some. Later `Stop`s that still report some do not renew it; only a `Stop` with none resets it. Scheduled wakeups never keep the Mac awake between iterations, and the README suggests a timed session for a `/loop` that should run with the lid closed. A long-lived dev server then costs at most one hour, once. **Recommended, and the owner's timing.**
  - (b) 1 hour, renewed at every `Stop` that reports background work. A dev server started once then keeps a closed Mac awake for an hour after every turn.
  - (c) As (a), and a non-empty `session_crons` counts as background work, under the same allowance.
  - (d) None. Only background subagents keep the Mac awake, through their own holders (5.7). A background build ends with the Mac asleep if the lid is closed.

- **B-9. Remote Control between turns, for Claude Code. (5.6)** Remote Control from a phone is a main reason to keep a closed Mac awake while away. A sleeping Mac drops the session until it wakes (remote-control.md:16-18). Codex can also be driven from the ChatGPT app through its daemon (codex-rs/app-server-daemon/README.md:166-177), but its hook payloads carry no marker for it, so Codex turns get the plain 60 s.
  - (a) As for any turn: the Mac may sleep 60 s after each reply, so the phone cannot send the next prompt to a closed Mac. The README points to `awake -w <claude PID>`.
  - (b) While Remote Control is connected, the end of a turn keeps the holder for the waiting allowance (10 minutes) instead of 60 s. A phone prompt within those 10 minutes reaches the Mac, and its turn starts the next 10 minutes. Hooks see `CLAUDE_CODE_BRIDGE_SESSION_ID` exactly while the connection is up (env-vars.md:220, since 2.1.199), so this costs one builtin test in the hook. With "Enable Remote Control for all sessions" (remote-control.md:180-193) every turn gets 10 minutes. **Recommended.**
  - (c) Keep the Mac awake for the whole connection. No hook reports the connection's end, so the holder would need a time limit anyway.

- **B-10. Usage-limit and API-error waits. (5.6)** A claude.ai usage limit stops Claude in the middle of a task. Claude Code then waits and goes on by itself at the reset, which is on by default for subscriptions (interactive-mode.md:657), through a prompt that runs `UserPromptSubmit` (interactive-mode.md:688). `/goal` retries by itself after an overloaded server (goal.md:145). A Codex turn that fails on an API error or a usage limit fires neither `Stop` nor `Interrupt` (codex-rs/core/src/session/turn.rs:824-840), so its holder stays working until the idle limit, whatever is chosen here.
  - (a) `StopFailure` ends the turn like `Stop`. With the lid closed the Mac sleeps a minute later. If it sleeps more than about 30 minutes across the reset, Claude Code waits for Enter (interactive-mode.md:671). The README says so. **Recommended**: the wait can last hours, and nothing signals its end before the reset.
  - (b) As (a) for `rate_limit`, but `StopFailure` with `overloaded` or `server_error` (hooks.md:2679) keeps the holder for the waiting allowance, so that `/goal`'s retries run on a closed Mac.
  - (c) Keep the Mac awake until the reset.

- **B-11. May an automatic session start while the lid is closed? (5.10, W20)**
  - (a) No, unless the Mac is in closed-display mode. An automatic session starts only while the lid is open, or closed on an external display (macOS's closed-display mode), which "the lid is open" means below. Once a session runs it goes on with the lid closed. So a `/loop` iteration, a scheduled task, a Desktop catch-up run on wake (desktop-scheduled-tasks.md:74) or a background report that fires while a sleeping Mac is briefly awake never starts a session in a bag. Neither does a holder that outlived a sleep, nor the end of the user's own session with the lid closed (B-4). The test is the helper's own: the lid is closed and `AppleClamshellCausesSleep` is `Yes` (awake-helper:604-619), which `bin/awake` gets as `lid_closed_causes_sleep`; today's `lid_is_closed` tests only `AppleClamshellState` (2385-2391) and would block every docked MacBook. A docked Mac needs the feature too: closed-display mode prevents only the sleep that closing the lid causes, and idle sleep still follows the Energy settings unless "Prevent automatic sleeping on power adapter when the display is off" is on (a user forum, https://discussions.apple.com/thread/254721961; Apple's own pages are blocked here), while Codex holds no idle-sleep assertion by default and Gemini CLI none (section 1). **Recommended.**
  - (b) Yes, except after a stop by the user or after a session ended with the lid closed, until the lid has been open. A wakeup after a normal end can still start a lid-closed session in a bag.
  - (c) Yes, always.
  - (d) As (a), but closed-display mode counts as closed. Simpler to explain, but a docked MacBook never gets an automatic session, and a typed prompt there never lifts a stop pause.

- **B-12. What ends an automatic session, now that it may run 365 days? (5.10, W11)** The 12-hour limit was the one bound that root enforced whatever the watcher did. With the owner's 365 days it bounds nothing in practice, so safety rests on what ends a session when the work ends or the watcher fails. These hold in every option:
  - the work's end: each holder ends at a turn's end (plus 60 s), after 10 minutes of waiting, 1 hour of background work, or 15 minutes without any sign of work (B-1, B-2, B-8);
  - the watcher's PID tie: the session is tied to the watcher's PID, so the helper or the Caffeine runner ends it within 2 s when the watcher exits or is killed (awake-helper:1393-1398; 6029-6041);
  - the agent's process: a holder whose process exits is dropped at once (5.8);
  - the guardrails, which the helper checks on its own (awake-helper:1357-1400; B-3), and no start with the lid closed (B-11);
  - the user: a stop, or `--ai-hooks off`.
  - (a) These, plus two bounds in the watcher. The quiet limit: the last look can keep a holder that has had no hook event for at most 2 hours, after which the time rule applies whatever it reads. And a stuck watcher is replaced: every external program it runs goes through `run_with_timeout` (2341), and when two hooks at least 5 s apart find a live watcher with the same beat, more than 90 s old, longer than any call it waits for, the second ends it (TERM, then KILL, after checking its start time) and starts a new one, so its session ends through the PID tie. Two looks, because a watcher that the Mac's sleep froze beats again within a pass after the wake (W27). The session's own limit is 365 days, as for any session. **Recommended.** A long `/goal` or agent run goes on for as long as its events arrive, which is what the owner asked for.
  - (b) As (a), plus a rolling limit of 2 hours that root enforces: the watcher renews it through the add-time path, only while fresh hook events arrive (the first version's B-2 (d)). A watcher that is alive but wrong, a bug that keeps a holder, is then cut off by root within 2 hours. It costs one helper run (`sudo -n`) per renewal, an internal path that extends only the watcher's own session, and a `deadline_at` that moves.
  - (c) As (a), without the quiet limit: a holder lives as long as the last look reads `busy`. A Claude Code MCP tool of a day (env-vars.md:483) is covered, but a wrong `busy` keeps a closed Mac awake until a guardrail or the user ends the session.

- **B-13. Timings for the agents without a last look: Codex, Cursor and Gemini CLI. (5.6, W7)** For them the time rules decide alone.
  - (a) The same values as for Claude Code: 60 s, 10 minutes of waiting, the 15-minute idle limit, as the owner chose. The Mac sleeps soonest. Not covered, and named in the README:
    - a tool approved after a wait that runs past the 10-minute allowance (Codex and Gemini CLI, whose waiting events B-1 uses);
    - a continuation that starts its first tool more than 60 s after the turn's end, with the lid closed;
    - a single tool call longer than 15 minutes, which sends no event while it runs. Gemini's shell tool is killed only after 300 s without output (packages/cli/src/config/settingsSchema.ts:1646-1654), so a chatty build can run past it; for Codex and Cursor the tool limits were not found.
    Cursor sends nothing while an approval card waits ([FL] cursor-agent.md:10-13), and Codex's `PermissionRequest` cannot tell the user's approval from its automatic reviewer's (B-1), so in both a wait counts as a running tool, up to the idle limit. **Recommended**: the owner's answer, and the cases are rare.
  - (b) For these agents, B-7 (b)'s fallback: waiting 20 minutes and grace 3 minutes. Fewer cut-off tools, but each reply keeps a closed Mac awake 3 minutes instead of 1.

- **B-14. Added time during an automatic session. (5.9, M4)** New from the reviews. The user clicks the app's time item, or runs `awake --duration 1h`, while an automatic session runs.
  - (a) Exactly that: the user's own session of 1 hour replaces the automatic one (the handover), and ends after the hour even if an agent still works; with the lid open an automatic session then follows, with the lid closed the Mac sleeps (B-4 (a)). The app's item reads `Keep awake for 1 hour`, not `Add 1 hour`, and the CLI says "Replaced the automatic session: Awake now ends in 1 hour, also if the AI is still working." **Recommended**: it is the principle as the owner put it, and the item says what it does.
  - (b) At least that: the session lasts an hour, or until the agents stop if that is later. Closer to what "add" suggests, but with the lid closed it breaks B-4 (a): a session the user timed would run past its end. It also needs a new kind of session end.
  - (c) The app hides the item during automatic sessions, as the previous revision did. The user loses the control, and the CLI still has to do (a) or (b).

### Release

- **R-1. Where does the code go while 2.4.0 is in its QA? (section 11)**
  - (a) A branch `dev-2.5` from `dev`, with a draft PR into `dev` so that CI runs. It is merged once 2.4.0, and any 2.4.x, has shipped, as faster-start-stop-2.md question X-2 (a) described. The CHANGELOG entries go in one commit after that merge (faster-start-stop-2.md X-4 (a)). **Recommended.**
  - (b) No code until 2.4.0 ships, then on `dev`.
  - (c) Into 2.4.0. That changes the build under QA. Not recommended.

## How this plan was checked

- **Code.** Written on Linux, from the code at `a9cd6d1`, which `1bbb06f` does not change. Every line number in `bin/awake`, `bin/awake-helper`, the app and the scripts was read at that code.
- **Sources of the first version.** Three research passes: Adrafinil and the other tools, Claude Code's hooks, and Awake's own code. Their notes and copies are in the scratch folder `agent-plan/research-*`.
- **Sources of the revision.** Five more passes on 2026-10-06, one per agent and one for the others, with their copies in the scratch folder `agent-plan2/research-*`:
  - Claude Code on every surface, the VS Code and Cursor extension included. The pages the first version cites were downloaded again and are byte for byte the same.
  - Codex, from its source code: openai/codex at `551bd409` (main on 2026-10-06; the latest release is 0.160.1 of 2026-10-05, https://github.com/openai/codex/releases). Release versions come from the files at each `rust-v*` tag.
  - Cursor, through a mirror of its docs and through projects that recorded its hooks running (below).
  - Gemini CLI from its source at gemini-cli@fb972b2 (main on 2026-10-06; for hooks the same as v0.62.0 of 2026-09-29), and Antigravity from another project's captures.
  - GitHub Copilot, Windsurf and Devin, Cline, Roo Code, Amp, opencode, Aider, Zed and Junie, from their sources or third-party integrations.
- **How sources are cited.**
  - Claude Code docs: `<page>.md:LINE`, lines of the raw pages `https://code.claude.com/docs/en/<page>.md`, downloaded on 2026-10-06. Agent SDK pages are `agent-sdk/<page>.md`, the plugin page `plugins/components.md`. Claude Code's changelog is `cc-changelog.md:LINE`, lines of `https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md` that day (top entry 2.1.291).
  - Codex: `codex-rs/…` paths at openai/codex@551bd409.
  - Cursor: `[CD] <page>.md:LINE` is `https://github.com/mehmetbaykar/cursor-docs-skill/blob/116359fdc3ac324909e0bcff53c261895cd4fc4d/skills/cursor-docs/references/<page>.md`, a mirror that copies cursor.com's docs every 3 hours (it took hooks.md on 2026-09-14). `[FL]` is Niclassslua/Flotilla@087b834 docs/providers/cursor-agent.md, a live probe of every hook event of the `agent` CLI 2026.10.01 on 2026-10-06. `[RO]` is griddynamics/rosetta@5441232 docs/hooks/cursor.md and cursor-logs.txt, captured in the Cursor editor 3.9.16 on 2026-06-29.
  - Gemini CLI: paths at gemini-cli@fb972b2. Antigravity: `acc@6a47099` is automatis-tools/agents-can-communicate at that commit, whose captures cover `agy` 1.2.7 to 1.2.16 and the desktop app 2.19.1 on macOS, 2026-09-20 to 2026-10-05.
  - Adrafinil: `adrafinil@6e4eece path:lines`, which means `https://github.com/kageroumado/adrafinil/blob/6e4eece4dd5a3155eea93ef71d3c785716114b1b/path#Llines`. In section 1, paths under `AdrafinilShared/Sources/AdrafinilShared/` are shortened to their last parts, such as `Policy/CutoutLatch.swift`. Other repositories are cited at the commits named where they appear.
- **No code was copied.** This plan describes Awake's own design. It takes ideas and observed behaviour from Adrafinil (MIT) and the other projects, never their code.
- **Probes.** Two probes from the research ran today's `awake` in the dry run under the Linux macOS emulation (`agent-plan/research-awake/lease-probe.sh` and `holders-probe.sh`, scratch). Three more ran for the first version (`agent-plan/draft/probe`, scratch), on bash 5.2 only, as no bash 3.2 build was at hand:
  - a fast path at the top of a copy of `bin/awake`: 3.0 ms per run, against 2.9 ms for `bash -c 'exit 0'` and 24.7 ms for `awake --version` (50 runs each);
  - reading a hook's stdin with one `cat` and pulling out top-level fields with regular expressions: 7 to 8 ms for a `Stop` payload, and 72 ms for a 3 MB prompt, in which a quoted `\"agent_id\":\"evil\"` did not match;
  - incremental reads of an append-only file through a descriptor kept open, which also showed that a line not yet ended by a newline is consumed by `read` (decision W3).
  None of this ran on macOS, under Apple's bash 3.2, or with any agent. Section 10's preflight checks the facts the design rests on before any code is written.
- **Reviews of the first version.** Two reviews on 2026-10-06. One checked about 60 of the file:line citations and found them accurate; it found seven holes in the design (starts by hand during an automatic session, exec form on older Claude Code, lost events and stale locks, an end that could hit the user's session, real `sudo` in the dry run, restarts in a bag, the installer switching the lid mode) and a dozen smaller points. The other downloaded every source again and found the claims about other tools accurate, with two wrong and two stretched citations; it found six cases where the holder rules surprise a user and several missing owner questions. All of their points were applied, four of them adapted: the cut of the payload at its first content key (W2), the 2-second rule between `tool-start` and `working` (W22), one rule for the lid instead of a pause after a lid-closed end (B-11), and a verb of its own for a plain `/clear` (5.7).
- **What the revision changed besides the owner's answers.** The research found these facts, which change the design:
  - In the Claude Code extension and the Desktop app, `idle_prompt` never fires: Claude Code sends it "from interactive UI that SDK sessions don't run" (agent-sdk/hooks.md:655-660), and both host Claude Code through the Agent SDK (hooks.md:2327). So in the owner's setup the `idle` verb never comes, and after Stop or Esc only the last look at the idle limit ends a working holder (2.2, 5.5).
  - Cursor's own agent runs Claude Code's hooks too, by default (H-5), so Awake's Claude Code handlers must stand down for its payloads.
  - Cursor sends the conversation's id first but its `session_id` after the content fields ([RO] cursor-logs.txt:61; cursor.md:565-579), so the Cursor adapter keys on `conversation_id` (W2).
  - In Claude Code's `Stop`, `background_tasks` comes after `last_assistant_message` (hooks.md:2577), a content key at which W2 cuts the payload. The first version did not say how the flag was then found; W2 now searches the whole `Stop` payload for that one key, which is safe there (W2).
  - Codex: its hooks are stable and on by default by 0.125.0 (codex-rs/features/src/lib.rs:1296-1301; under development and off at 0.120.0, 2.3), it has an `Interrupt` event for Esc, and the current code runs hooks in `codex exec` too (codex-rs/exec/tests/suite/hooks.rs:8-42), against Adrafinil's note that `codex exec` ignores them (CodexIntegration.swift:24-27), which is probably older. The trust check is enforced in codex-rs/hooks/src/engine/discovery.rs:715-736; the first version's S-2 cited config_rules.rs:33-60, which only merges the stored state. The startup review offers "Trust all and continue", one action rather than one approval per handler.
  - Gemini CLI's hooks are on by default since v0.26.0 (2.5), so it can be an adapter now, and Gemini shows a hook's stderr to the user when stdout is empty, even at exit 0 (packages/core/src/hooks/hookRunner.ts:455-478), so every handler sends stderr to `/dev/null` too (K2).
- **Reviews of the revision.** Two more reviews on 2026-10-06. One read Awake's code and Claude Code's, Codex's and VS Code's sources again; the other downloaded every agent's sources again (Claude Code's docs were byte for byte the same except two lines no citation uses; Codex's latest release is still 0.160.1; Gemini CLI's v0.62.0; the Cursor mirror at its HEAD) and judged B-5 as a user. Both agreed with B-5's recommendation and found that its first rule for lifting the pause let a background turn lift it right after the stop click. Every point was checked against the sources named in it. What changed:
  - the stop pause: written by the stop itself under the main lock, lifted only by input after the stop and a turn that starts within 5 s of it (60 s for Codex), never by a start by hand, and kept across a restart (B-5, 5.9, W10, W26);
  - closed-display mode counts as an open lid (B-11);
  - a changed lid mode or guardrail reaches the running automatic session within 30 s (5.9, W28);
  - Codex's `PermissionRequest` is a heartbeat, as it also runs before the automatic reviewer (B-1);
  - Gemini's extension is linked from Awake's own folder, never left as a bare folder that an allowlist turns into a startup failure (H-4, K14);
  - Cursor runs Awake's Claude Code `PreToolUse` as a permission hook, which the cost and the rollback now count (H-5, K.9); its subagents are marked unverified (2.4);
  - VS Code's Copilot agent with `chat.useClaudeHooks` gets the same stand-down as Cursor (W25);
  - no lost event at the watcher's exit or a rotation, a sleep-frozen watcher is not killed, the watcher runs with a minimal environment, the last look revives only main conversations, the fast path runs in the C locale, and the dry run feeds raw outputs to the real parsers (W3, W4, W14, W18, W21, W27);
  - the app offers `Keep awake for 1 hour` instead of hiding the time item, and `--if-off` replaces an automatic session (M4, B-14);
  - Codex: the trust key's format, a stale trust after `refresh`, inline TOML hooks, and placeholders on every removal (K5, K13); versions are now "by" a release, as the clone holds only some release tags (2.3);
  - corrected citations (2.1, 2.2, 2.4).
  Every point held when checked; some were applied in another form: a 5 s window for Claude Code instead of 3 s, until section 10 measures it; 5 s instead of 60 s for Cursor and Gemini CLI, as both fire their prompt hook at submit (and Cursor's automatic turns are not yet known); two pause files instead of two fields in one, as two processes write them; the stop pause kept in a file in Awake's own folder rather than in the app's defaults, so the fast path can test it with builtins; a second look by a later hook instead of a 3-second wait (which would hold up a prompt) or `kern.waketime` for a watcher frozen by sleep; `claude` found from the holder's own process instead of a path the hook records; no last look for a holder of another `CLAUDE_CONFIG_DIR` instead of running it with that folder; the watcher's own 30 s check instead of the app running `--ai-hooks refresh` after a settings change; Codex's stale trust found by comparing the stored hashes instead of a manual `--trusted` flag; the helper's existing mock key `clamshell_causes_sleep` instead of a new `clamshell_sleep`; closed-display mode decided in B-11 (a), with (d) as the alternative, instead of a separate question; and Codex's versions written as "present by" without narrowing them with more tags.
- **Not readable.** Blocked by the proxy, and read another way where possible:
  - cursor.com (docs, changelog) and forum.cursor.com: the docs through the [CD] mirror; forum threads only as search snippets, which the plan marks.
  - developers.openai.com and learn.chatgpt.com (Codex docs): Codex's source instead. marketplace.visualstudio.com and open-vsx.org: the IDE extensions of Codex and Claude Code could not be inspected; Codex's extension and app are closed source, and their behaviour is inferred from the open app-server code.
  - antigravity.google, the Gemini Code Assist docs on developers.google.com and docs.cloud.google.com, and geminicli.com: Antigravity from acc@6a47099, Code Assist from Gemini CLI's a2a-server source, PR #16080 and a search snippet of https://developers.google.com/gemini-code-assist/docs/use-agentic-chat-pair-programmer, Gemini CLI from its repository's docs.
  - support.apple.com and www.howtogeek.com: what closed-display mode does from a user forum (https://discussions.apple.com/thread/254721961) and Awake's own helper (B-11).
  - docs.github.com, code.visualstudio.com, docs.windsurf.com, docs.devin.ai, docs.cline.bot, docs.roocode.com, ampcode.com, opencode.ai, aider.chat, zed.dev and junie.jetbrains.com: their GitHub sources or npm packages instead, or third-party integrations where nothing else was open.
  - The GitHub API for repositories not attached to the session, and GitHub issue pages through curl: issues were read through a summarising fetch, so their full threads were not seen.
  - The comment threads of Adrafinil's GitHub issues: only the opening reports. Fixes were confirmed from commits.
  Where a fact rests on one of these, the plan says so, or "not found".

## 1. What other tools do

### Adrafinil

Adrafinil keeps a MacBook awake, also with the lid closed, only while at least one agent session holds it. With no holder the Mac sleeps normally, lid close included (adrafinil@6e4eece README.md:38-46, 63). It is MIT-licensed, needs macOS 26.4 or later, and ships as a notarized DMG and an official Homebrew cask (README.md:76-85, 224). It integrates Claude Code, Codex and Cursor, each in its own file under `…/Installer/Integrations/`.

- **What it hooks in Claude Code.** It writes handlers into `~/.claude/settings.json` (…/Installer/Integrations/ClaudeCodeIntegration.swift:61-104):
  - `UserPromptSubmit` acquires and `Stop` releases;
  - `Notification` with matcher `idle_prompt` releases, as a fast path it does not rely on;
  - `SubagentStart` and `SubagentStop` acquire and release per `agent_id`;
  - `SessionEnd` releases;
  - `SessionStart` with matcher `clear` acquires;
  - an optional `PreToolUse` on `Bash` holds `run_in_background` commands, with a time limit (:117-132).
- **Codex and Cursor.** For Codex it surfaces the trust step and does not trust on the user's behalf (CodexIntegration.swift:28-32). For Cursor it hooks `beforeSubmitPrompt` and `stop` in `~/.cursor/hooks.json`, and gives each hold a 1-hour time limit, refreshed at each prompt, because "each hold attaches to the single long-lived Cursor app process, so process-death cleanup never fires" (CursorIntegration.swift:3-19).
- **Why per turn and not per session.** An earlier version held the Mac from `SessionStart` to `SessionEnd`, so it was also awake while the session sat idle at the prompt (commit ffda975; ClaudeCodeIntegration.swift:5-10). Its Cursor file says the same of Cursor's long-lived chats (CursorIntegration.swift:6-9).
- **Leases.** Hook calls are idempotent leases in a per-user LaunchAgent daemon, keyed `<tool>:<session_id>`. The id comes from the hook's stdin JSON, with `$CLAUDE_CODE_SESSION_ID` as the fallback, on purpose: `SessionEnd` carries the retiring session's id on stdin and `SessionStart` the new one (ClaudeCodeIntegration.swift:26-28, 43-47, 93-96). Sleep is blocked while any lease exists (AssertionRegistry.swift:40-42, 64-107; AcquireCommand.swift:125-139).
- **Safety nets for a missed release:**
  - an exit watch on the owning agent process, found by walking up the parent processes (ProcessResolver.swift:16-29; ProcessWatcher.swift:28-81);
  - a sweep every 30 s that releases a lease whose process tree stays under 3% CPU for 90 s, where Claude Code's own `caffeinate` child counts as working (IdleReleaseEvaluator.swift:9-41, 86-166; PowerAssertionReader.swift:4-49; Models/AdrafinilSettings.swift:62). This sweep is also what ends the hold after a plain `/clear` ("a bounded cost", ClaudeCodeIntegration.swift:36-39);
  - time limits, and a 24 h backstop.
- **Waiting for the user.** It reads Claude Code's internal `~/.claude/sessions/<pid>.json` (status busy, idle or waiting) every 10 s (ClaudeSessionStatus.swift:3-79). By default it keeps the Mac awake for 10 minutes of waiting (SessionWaitEvaluator.swift:18-137).
- **Hooks never fail the agent.** Acquire and release exit 0 on every failure, as exit 2 on `UserPromptSubmit` would block and erase the user's prompt (AcquireCommand.swift:8-16).
- **Installing.** Per handler, and in place: other handlers in the same group survive. Files that are not a parseable JSON object, or that change during the edit, are refused. Writes go through symlinks and keep the file's permissions. Uninstalling strips only Adrafinil's handlers, from every event (NestedJSONHookShape.swift:90-106, 163-217; ConfigFileIO.swift:7-11, 29-62).
- **The user's controls.** "Force release" drops every hold, and the agents' next hooks hold again. A separate "Let it sleep" pause ignores agent hooks until the user chooses "Resume", and survives a restart (IPC/DaemonProtocol.swift:19-28; Models/PersistedDaemonState.swift:3-6). B-5 weighs the same choice.
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
- **peon-ping** (PeonPing/peon-ping@de4ada7) followed Amp and others by watching their transcript folders with idle timers before their plugin APIs existed (adapters/amp.sh:1-24). The others pass rejects that for Awake (4, O10).
- **What the agents do themselves.** None keeps a closed Mac awake:
  - Claude Code spawns `caffeinate` while it works. Its changelog for 2.1.83 says "Fixed `caffeinate` process not properly terminating when Claude Code exits, preventing Mac from sleeping" (cc-changelog.md:5904). Issue reporters see `caffeinate -i -t 300`, renewed while a session is busy (https://github.com/anthropics/claude-code/issues/64522, closed as not planned; #85261 and #21432 are open). `caffeinate -i` prevents idle sleep only, not sleep on lid close (README.md:25). Whether the extension and the Desktop app spawn it too: not found. The Desktop app has a "Keep computer awake" setting, and "Closing the laptop lid still puts it to sleep" (desktop-scheduled-tasks.md:70).
  - Codex has an experimental `prevent_idle_sleep`, off by default. It holds an IOPM assertion "Codex is running an active turn" of the type `PreventUserIdleSystemSleep`, which does not cover a closed lid (codex-rs/features/src/lib.rs:1942-1959; codex-rs/utils/sleep-inhibitor/src/macos.rs:23-26).
  - Cursor holds an Electron wakelock while an agent runs, which does not survive a lid close (a Cursor staff reply on forum.cursor.com thread 159837, seen as a search snippet only). For Remote Control and My Machines, Cursor offers "Keep this computer awake", which prevents sleep "while the computer is plugged in" ([CD] cloud-agent__mobile.md:107).
  - Gemini CLI holds no sleep assertion of its own: no `caffeinate` or IOPM call in its packages (gemini-cli@fb972b2).
  - Zed asks the system not to idle-sleep "While an agent thread is running", "not while it waits for your confirmation" (zed-industries/zed@fdc1005 docs/src/ai/agent-panel.md:106-112).

### What to take, and what to avoid

| From | Take | Avoid, or do differently |
|---|---|---|
| Adrafinil | Hold per turn, not per session, for every agent. Release on session end, and mark Claude Code's `SessionStart` `clear`, for a plan approved with a cleared context. Hold subagents by their own id. Take ids from stdin first. Hooks always exit 0, print nothing, and never ask for anything. Watch the agent's process. Give waits a grace. Latch after a guardrail end. Install per handler and remove only our own handlers. Refresh the hooks at upgrade. Never trust Codex hooks for the user. Separate "let go now" from "stay off until I resume" (B-5). | No always-running daemon or LaunchAgent: Awake's watcher runs only while there is agent work. No new root code: Awake's helper, guardrails and boot-restore do the `pmset` part. No marker key in the agents' files, as Claude Code shows a Settings Error for a value its schema rejects (settings.md:607) and Codex refuses unknown top-level keys (codex-rs/config/src/hook_config.rs:10-17): Awake's handlers are found by their command. No CPU or network heuristics (Adrafinil reverted an open-socket rule that pinned the Mac, commit 9115653). No reading of `~/.claude/sessions/*.json`, whose format is not documented (claude-directory.md:1562): `claude agents --json` is the documented way (B-7). No MCP server in version 1. |
| keepawake | A count that a crash cannot leak. | `flock`: macOS has no `flock(1)`, and one watcher with an event log (W3) needs none. |
| clawake | Heartbeats as a fallback signal, with a time limit. | Writing over a file it cannot parse. Sessions held for 15 minutes after the work. |
| peon-ping | | Watching transcripts with guessed idle timers (O10). |
| Codex | Its `Interrupt` hook (2.3). | Its idle-sleep assertion as a signal: off by default, and lid-open only. |
| The agents' own idle-sleep holds | Lid-open automatic sessions add little where they exist (H-2). | Using them as a signal (O6). |

## 2. What the agents give a keep-awake tool

### 2.1 The integration matrix

Each agent runs on several surfaces. The table says where the agent's work runs, which signal Awake uses there, and what that covers. "Release 1" follows S-4 (a).

| Agent | Surface | Runs on the Mac | Signal Awake uses | What works | What does not, and the fallback | Release 1 |
|---|---|---|---|---|---|---|
| Claude Code | CLI in any terminal: Terminal, iTerm, the integrated terminal of Cursor, VS Code or JetBrains (the JetBrains plugin runs `claude` there, jetbrains.md:32-36), headless `claude -p` | Yes | Hooks in `~/.claude/settings.json` (hooks.md:257) | Turns, tools, waiting, subagents, background work, Remote Control, `idle_prompt` after a reply, the last look | An interrupt fires no hook (up to the idle limit). Folders not yet trusted run no hooks (hooks.md:3817). `claude -p --bare` skips hooks (headless.md:37): `awake -- claude -p` | Yes |
| Claude Code | The VS Code and Cursor extension (the owner's setup) | Yes: a bundled `claude` (vs-code.md:23), one process per open conversation (inferred from vs-code.md:217, 296; 10.2 records it) | The same file, "shared between the extension and CLI" (vs-code.md:525) | As the CLI | No `idle_prompt` (agent-sdk/hooks.md:655-660), so an interrupt costs up to the idle limit. Whether the last look lists these sessions: not found (section 10). Remote-SSH, WSL and container windows run Claude Code on the remote host (inferred: VS Code runs workspace extensions there; cc-changelog.md:1977 names a workspace that exists only on the remote host) | Yes |
| Claude Code | Desktop app, Code tab, local sessions | Yes, the same engine (desktop.md:857) | The same file (desktop.md:906) | As the extension | As the extension. SSH sessions run on the remote machine (desktop.md:686-688) | Yes |
| Claude Code | Cloud: claude.ai/code, the mobile app, Desktop's Cloud sessions, `claude --cloud`, routines | No (claude-code-on-the-web.md:13) | None | Nothing is needed: the work goes on while the Mac sleeps | | Nothing to do |
| Codex | Terminal UI (`codex`), by default attached to a shared background daemon by 0.157.0 (codex-rs/features/src/lib.rs:992-996) | Yes | Hooks in `~/.codex/hooks.json`, once trusted (H-3) | Turns, tools that succeed, waiting, Esc (`Interrupt`), subagents, session end | A failed turn fires nothing (idle limit). No last look. The process Awake watches is the daemon, which outlives the window and keeps running the turn | Yes |
| Codex | `codex exec` | Yes | The same hooks, if trusted (codex-rs/exec/tests/suite/hooks.rs:8-42) | As the terminal UI | Untrusted hooks are skipped silently. `awake -- codex exec` works with no hooks | Yes |
| Codex | IDE extension in VS Code and Cursor | Yes (inferred: it runs `codex app-server`, codex-rs/app-server/src/main.rs:48-55) | The same file, as app-server runs Codex's core (inferred; closed source) | As the terminal UI (inferred) | Whether it shows a review screen: not found; the trust given in the terminal applies through the shared `config.toml` (codex-rs/hooks/src/config_rules.rs:8-29) | Yes, after the preflight |
| Codex | Desktop app (Codex.app, codex-rs/cli/src/desktop_app/mac.rs:8-12) | Yes | The same file (inferred; closed source) | As the terminal UI (inferred) | Whether its automations look like prompts: not found | Yes, after the preflight |
| Codex | Cloud tasks (`codex cloud`, codex-rs/cli/src/main.rs:227-229) | No | None | Nothing is needed | | Nothing to do |
| Cursor's agent | The editor: Agent chat, Cmd+K, local agents in the Agents Window | Yes, in the window's extension host ([RO] cursor-logs.txt:13-20) | Hooks in `~/.cursor/hooks.json` ([CD] hooks.md:111, 649-650) | Turns, tools, thinking blocks, Stop and cancel (`stop` with `aborted`), session end | No waiting signal and no last look. The process Awake watches is the window's extension host, which outlives the work | Yes |
| Cursor's agent | `agent` CLI, interactive | Yes | The same file ([FL]:21) | As the editor, without `sessionStart` ([FL]:38) | No waiting signal | Yes |
| Cursor's agent | `agent -p` | Yes | None: it runs project hooks only ([FL]:21) | | `awake -- agent -p "<task>"` | Manual |
| Cursor's agent | `agent acp`, for ACP clients such as JetBrains IDEs and Zed ([CD] cli__acp.md:9-25) | Yes | Whether user hooks run there: not found | | `awake -w <agent PID>` or a timed session | Manual |
| Cursor's agent | Remote Control and My Machines: the loop in the cloud, the tools on the Mac ([CD] cloud-agent__mobile.md:95, 101) | Partly | None: workers run project hooks only ([CD] cloud-agent__self-hosted__pool.md:315-321) | | Cursor's own "Keep this computer awake" while plugged in ([CD] cloud-agent__mobile.md:107), or `awake -w <worker PID>` | Manual |
| Cursor's agent | Cloud agents | No ([CD] hooks.md:93-101) | None | Nothing is needed | | Nothing to do |
| Gemini | Gemini CLI in any terminal, also Cursor's or VS Code's with the Companion extension, which only shares editor context (docs/ide-integration/index.md:9-12) | Yes | Hooks in an extension Awake keeps in its own folder and links into Gemini CLI (H-4) | Turns, tools, waiting (`ToolPermission`), session end | Esc while a tool runs, or a declined prompt, ends no turn (the waiting allowance or the idle limit). No last look. `--sandbox` blocks the hook's write (2.5) | Yes |
| Gemini | `gemini -p`, and ACP mode for Zed and JetBrains (docs/cli/acp-mode.md:1-12) | Yes | The same hooks (packages/cli/src/acp/acpSessionManager.ts:426) | As the terminal (ACP fires no session start or end) | The ACP process lives as long as the editor | Yes |
| Gemini | Gemini Code Assist agent mode in VS Code (IntelliJ: not found) | Yes | Not verified: Google's docs say agent mode is powered by Gemini CLI and loads `~/.gemini/extensions` (a search snippet, the page is blocked); the a2a-server at fb972b2 loads extensions without hooks and skips a linked folder that has no `gemini-extension.json` of its own (packages/a2a-server/src/config/extension.ts:80-125; config.ts:351-407) | | `awake -w <PID>` or a timed session | Manual, until 10.5 shows otherwise |
| Gemini | Antigravity: the `agy` CLI and the desktop app | Yes | Its own `~/.gemini/config/hooks.json`, with few events (2.5) | | Later, as an experiment (S-4 (c)) | No |
| Others | GitHub Copilot, opencode, Amp, Cline, Junie CLI, Windsurf and Devin; Aider, Roo Code, Zed's agent, Junie in JetBrains IDEs | | 2.6 | | `awake -- COMMAND`, `awake -w PID`, a timed session | No |

### 2.2 Claude Code

What the design rests on:

- **Hooks fire wherever Claude Code runs:** the terminal, IDE extensions, the Desktop app, and cloud sessions (hooks.md:13). Cloud sessions do not read the local `~/.claude/settings.json` (hooks.md:265), which does not matter here. Hooks also run inside subagents, whose tool events carry `agent_id` and `agent_type` (hooks.md:269).
- **Three cadences** (hooks.md:21-25):
  - per session: `SessionStart` and `SessionEnd`;
  - per turn: `UserPromptSubmit`, and `Stop` or `StopFailure`;
  - per tool call: `PreToolUse` and `PostToolUse`.
- **How handlers run.** All matching hooks run in parallel, and identical handlers from several settings files run once (hooks.md:412). They run in the session's current folder, with Claude Code's environment (hooks.md:414). The default timeout is 600 s for command hooks, and it is not enforced on an async command hook (hooks.md:426, 3730).
- **`UserPromptSubmit`** also fires for a scheduled task or `/loop` iteration, for a background subagent reporting back, and for a message from another session (hooks.md:1324-1329). It blocks the prompt until the hook returns, with a 30 s default timeout (hooks.md:1331). Exit 2 blocks the prompt. Any other non-zero exit is a non-blocking error (hooks.md:776-850). Plain stdout of `UserPromptSubmit` and `SessionStart` hooks is added to Claude's context (hooks.md:786), so Awake's hooks must print nothing.
- **`Stop`** "does not run if the stoppage occurred due to a user interrupt". API errors fire `StopFailure` instead (hooks.md:2567-2569; hooks-guide.md:960). Since 2.1.145 (cc-changelog.md:4540), `Stop` and `SubagentStop` carry `background_tasks` and `session_crons`, after `last_assistant_message`, which are meant to tell "session is done" from "paused waiting for background work" (hooks.md:2577, 2583-2605). `/goal` is a session-scoped prompt-based `Stop` hook after which Claude starts another turn (hooks.md:2571-2573; goal.md:9, 120). Whether such a continuation fires `UserPromptSubmit`: not found.
- **`StopFailure`** carries `error`: `rate_limit`, `overloaded`, `server_error` and others (hooks.md:2675-2679).
- **`SessionEnd`** fires on exit, `/clear` and an in-session `/resume`. All `SessionEnd` hooks share a budget of 1.5 s, which a per-handler `timeout` in a settings file raises to match, up to 60 s (hooks.md:3388-3393).
- **Subagents.** `SubagentStart` and `SubagentStop` carry `agent_id` (hooks.md:2390, 2426). Subagents run in the background by default (hooks.md:1762). `SubagentStop` also fires for internal agents, with an empty `agent_type` (hooks.md:2428).
- **The top-level fields.** Every event carries `session_id`, and inside a subagent `agent_id`; the common fields also include `effort`, an object, on tool events, `Stop` and `SubagentStop` (hooks.md:730-743). Tool events add `tool_name`, `tool_input` and `tool_response`. Inside any JSON string a quote is escaped, so an unescaped `"agent_id":` can only be a key: at the top level, or nested in `tool_input` or `tool_response`.
- **Waiting signals.**
  - `PermissionRequest` fires the moment Claude Code is about to ask for permission. `Notification` `permission_prompt` fires only after about 6 s (hooks.md:1916-1921, 2298).
  - `PreToolUse` matches `AskUserQuestion` and `ExitPlanMode` (hooks.md:1580). A question stays open until it is answered, unless `askUserQuestionTimeout` is set, and permission prompts never close on their own (tools-reference.md:131-137).
  - `idle_prompt` fires when "Claude finished responding about 60 seconds ago and you haven't typed since", and only if no background agent still runs; not while Claude Code waits for a usage limit to reset (hooks.md:2299, 2321). In the terminal only: see the extension below.
- **Tools.** A foreground Bash call runs 2 minutes by default and at most 10, unless `BASH_MAX_TIMEOUT_MS` is raised (tools-reference.md:157-161). MCP tools time out after about 28 hours by default (env-vars.md:483). Background commands of a local session have no time limit and outlive the reply (tools-reference.md:186, 190).
- **Environment.** Hooks get `CLAUDE_CODE_SESSION_ID`, which "matches the `session_id` field in the hook JSON input and is updated on `/clear`" (env-vars.md:371). `CLAUDE_CODE_CHILD_SESSION=1` is set only by Claude Code itself, since 2.1.172 (env-vars.md:223). `CLAUDE_CODE_BRIDGE_SESSION_ID` is set while Remote Control is connected and removed when it ends, since 2.1.199 (env-vars.md:220; hooks.md:416). `CLAUDE_CONFIG_DIR` moves the settings folder, "useful for running multiple accounts side by side" (env-vars.md:418).
- **No terminal.** Command hooks run "in their own session without a controlling terminal" and cannot open `/dev/tty` (hooks.md:720).
- **Forms.** A command hook runs in exec form when `args` is set and in shell form, `sh -c` on macOS, when it is not (hooks.md:466-470). `args` exists since 2.1.139 (cc-changelog.md:4758); what an older version does with it: not found. A command hook with `"async": true` runs in the background and cannot block anything. In `-p` mode it is killed at teardown (hooks.md:3703-3735).
- **Settings files.** Claude Code watches them and applies hook edits to a running session (settings.md:584). A file with "a value the schema rejects" is a Settings Error, and the session may go on without it (settings.md:607).
- **Where hooks do not run:**
  - in an interactive session, hooks from every settings file, `~/.claude/settings.json` included, wait until the folder is trusted (hooks.md:3813-3818);
  - managed `allowManagedHooksOnly` blocks user and plugin hooks (hooks.md:270-280), and managed settings can come from a file, an MDM profile or the claude.ai console (managed-settings.md:61-71);
  - `disableAllHooks` turns them off, and a project's value overrides the user's (hooks.md:706-712);
  - `claude -p --bare` skips hooks (headless.md:37).
- **`claude agents --json`** lists every live session with `pid` and `status` (`busy`, `waiting` or `idle`), `waitingFor` and `sessionId` (agent-view.md:762-777). It is "the supported way to read session state from outside Claude Code" (agent-view.md:779). Agent view is in research preview (agent-view.md:22). The docs say that `claude agents` starts the supervisor on demand (agent-view.md:758, 802, 918, 932), a background service that keeps background sessions running and restarts sessions that exit (agent-view.md:802-809); whether the `--json` form does is checked in 10.3 (f). With `CLAUDE_CONFIG_DIR` the supervisor is a separate instance with its own sessions (agent-view.md:817), so a session of another folder is missing from the list, which is not a failed call. Whether `disableAgentView` (agent-view.md:836) turns the command off, and whether it lists sessions hosted by the extension or the Desktop app: not found.
- **Remote Control.** "If your laptop sleeps" the session reconnects when it wakes, and "your computer has to stay on" (remote-control.md:16-18).
- **Usage limits.** Claude Code waits for a claude.ai usage limit to reset and goes on by itself; after a sleep of more than about 30 minutes across the reset it waits for Enter (interactive-mode.md:655-671, 688).

**The extension in VS Code and Cursor, and the Desktop app.** They run the same hooks from the same files, with these differences, which matter for the owner's setup:

- **How it runs.** The extension bundles its own copy of the CLI and does not put `claude` on the PATH (vs-code.md:23, 593, 617); its version number is the bundled CLI's (vs-code.md:35). It installs in Cursor from its own link (vs-code.md:31). Both the extension and the Desktop app host Claude Code through the Agent SDK (hooks.md:2327), which starts the CLI as a child process with stream-json input and output and ends it by closing its stdin, then SIGTERM, then SIGKILL 5 s later (npm @anthropic-ai/claude-agent-sdk 0.3.291, sdk.mjs). There is one such process per open conversation (inferred from vs-code.md:217, 296; 10.2 records it).
- **`Notification` types.** In these sessions only `permission_prompt` (since 2.1.233, about 6 s after the ask, not held back by typing) and the elicitation-completion types fire; `idle_prompt` comes "from interactive UI that SDK sessions don't run" (agent-sdk/hooks.md:655-660; hooks.md:2327-2333). So after Stop or Esc nothing but the idle limit and the last look ends a working holder.
- **Trust.** SDK sessions "never show the dialog and treat the folder as trusted" (hooks.md:3818).
- **Turns not typed.** `UserPromptSubmit` fires also for "a turn Claude Code starts on its own" (agent-sdk/hooks.md:153).
- **Stop and Esc in the panel** end the current turn; background agents keep running (vs-code.md:172, since 2.1.286). No hook fires for it.
- **Reloads.** After Reload Window or a restart, the conversation comes back in a new process with the same session id, and a step the reload interrupted continues by itself (vs-code.md:291-300, since 2.1.274). Whether that continuation fires `UserPromptSubmit`: not found. One conversation can also be open in two processes after "Open here anyway" (vs-code.md:217).
- **Extra settings folders.** The extension setting `environmentVariables` can set `CLAUDE_CONFIG_DIR`, as an absolute path only (vs-code.md:554). It lives in the editor's user `settings.json`, for VS Code on macOS probably `~/Library/Application Support/Code/User/settings.json` (the docs name only that folder's `globalStorage`, vs-code.md:817); Cursor's path was not verified (10.2 checks it).
- **Past bugs.** Reports of hooks not firing in the extension, all closed as duplicates or not planned: `UserPromptSubmit` in VS Code and Cursor (anthropics/claude-code#15021, 2.0.75), `PostToolUse`, `PermissionRequest` and `Notification` (#31285, 2.1.69), user-level hooks dropped (#53774, 2.1.120), `Stop` (#49851, #77480), no `SessionEnd` on `/clear` (#50808, 2.1.114), `Notification` (#83577, 2.1.220). The current docs say the hooks fire; section 10 runs the probe in Cursor's Claude Code panel itself.

What Claude Code does not give:
- no hook for an interrupt (Esc, or Ctrl+C, which "interrupts a running operation", interactive-mode.md:21);
- no documented hook when the terminal window or a panel tab is closed, or the process is killed;
- no hook when a permission prompt is answered;
- no hook for the end of a background shell: none was found in hooks.md (`TaskCompleted`, hooks.md:2509-2513, is for tasks and teammates).

### 2.3 Codex

From the source at `551bd409`.

- **Hooks, stable and on by default** by 0.125.0 (feature key `hooks`, legacy alias `codex_hooks`; codex-rs/features/src/lib.rs:1296-1301; under development and off by default at 0.120.0). Twelve events: PreToolUse, PermissionRequest, PostToolUse, PreCompact, PostCompact, SessionStart, SessionEnd, UserPromptSubmit, SubagentStart, SubagentStop, Stop and Interrupt (codex-rs/hooks/src/lib.rs:23-36).
- **Where.** `$CODEX_HOME/hooks.json` (default `~/.codex/hooks.json`), or inline `[hooks]` in `config.toml`; every config layer can have them (codex-rs/hooks/src/engine/discovery.rs:94-206, 339-400). When one layer has both, Codex loads both and warns (discovery.rs:154-164). The shape is Claude Code's: event, then groups with a `matcher`, then a `hooks` array of `{type, command, timeout, async}` (codex-rs/config/src/hook_config.rs:10-200). The top level allows only `description` and `hooks`, and a parse error skips the whole file with a warning (hook_config.rs:10-17; discovery.rs:359-367), which would also silence the user's own hooks.
- **Trust.** By 0.130.0 (no `trusted_hash` at 0.125.0) a user, project or plugin hook runs only after the user has trusted it, by a `trusted_hash` stored in the user's `config.toml` under `[hooks.state."<file>:<event label>:<group index>:<handler index>"]`, where the label is the event's snake_case name, such as `user_prompt_submit` or `pre_tool_use` (discovery.rs:666-736, 796-823; codex-rs/hooks/src/lib.rs:95-123). Untrusted hooks, and hooks whose stored hash differs (`Modified`), are skipped without an error (discovery.rs:715-736, 806-820). The hash covers the handler's text, so a changed command, timeout or async flag needs a new review, and the key holds the handler's position, so a group inserted before others breaks their trust. Trust is read from the user and session layers only, so trust given once applies to every surface that uses the same `CODEX_HOME` (config_rules.rs:8-29).
- **How handlers run.** As `<user's shell> -c "<command>"`, not a login shell (codex-rs/core/src/session/mod.rs:5129-5137), in a new session with no terminal (codex-rs/hooks/src/engine/command_runner.rs:412-413), in the session's folder, with the JSON on stdin, which is then closed (command_runner.rs:259-268). At its timeout a hook's process group is killed, but helpers it detached survive (command_runner.rs:276-357), as Awake's watcher does. Exit 2 on UserPromptSubmit blocks the prompt, and plain stdout becomes model context (codex-rs/hooks/src/events/user_prompt_submit.rs:157-250), as in Claude Code. Async handlers run in the background, at most 8 at a time per session, and are aborted when the session shuts down (codex-rs/hooks/src/engine/dispatcher.rs:115-188; command_runner.rs:54, 188-196).
- **Events for Awake** (codex-rs/hooks/src/schema.rs:275-638):
  - Turn start: UserPromptSubmit, for each user input, also input typed while a turn runs; not for a `/goal` continuation or a message between agents (codex-rs/core/src/hook_runtime.rs:677-714; codex-rs/ext/goal/src/runtime.rs:474-485). It runs after pre-turn compaction and MCP startup, so it can come seconds after Enter (codex-rs/core/src/session/turn.rs:184-379).
  - Turn end: Stop, only when a top-level turn completes normally (turn.rs:661-669), with no background field. Interrupt, by 0.150.0 (absent at 0.148.0), when a top-level turn is aborted as interrupted (codex-rs/core/src/tasks/mod.rs:806-819). A turn that fails on an API error or a usage limit fires neither (turn.rs:824-840).
  - Waiting: PermissionRequest runs before the request goes to the automatic reviewer or to the user (codex-rs/core/src/tools/approvals.rs:505-525), and with `approvals_reviewer = "auto_review"` (alias `guardian_subagent`, codex-rs/protocol/src/config_types.rs:178-189) nobody is asked, so Awake counts it as a heartbeat (B-1). The waiting signal is PreToolUse for the question tool `request_user_input`, which only a person answers (codex-rs/core/src/tools/handlers/request_user_input_spec.rs:9; by code reading, as a function tool, registry.rs:140-149; section 10 checks it). No hook fires when an approval is answered.
  - Heartbeats: PreToolUse for every function tool, PostToolUse only when a tool succeeds (codex-rs/core/src/tools/registry.rs:140-149, 716-739).
  - Subagents: SubagentStart and SubagentStop, with `agent_id`; `session_id` is shared by a conversation and its subagents (codex-rs/core/src/session/session.rs:663-666).
  - Session end: SessionEnd, by 0.145.0 (absent at 0.140.0), for top-level threads, always synchronous, with a 1 s default and 3 s maximum timeout (codex-rs/hooks/src/events/session_end.rs:20-23).
- **Payloads** are compact JSON in declaration order, so `session_id`, `turn_id`, `agent_id` and `tool_name` come before `prompt`, `tool_input`, `tool_response` and `last_assistant_message` (schema.rs:278-297). There is no environment variable for the session.
- **The daemon.** By 0.157.0 (not at 0.155.0) the terminal UI attaches by default to a shared app-server daemon, and the hooks run inside it (codex-rs/features/src/lib.rs:992-996; codex-rs/tui/src/daemon_startup.rs:61-125). The hook's grandparent is then the long-lived daemon, which keeps running a turn after its window closes (codex-rs/app-server/src/request_processors/thread_lifecycle.rs:427-443): the turn's `Stop` still arrives, so keeping the Mac awake meanwhile is right, but Awake's watch on the process cannot see a closed window. With `--no-daemon` the grandparent is the `codex` process.
- **No last look.** `codex agents` is interactive only (codex-rs/cli/src/main.rs:148-149, 337-351).
- **Not usable as signals:** the legacy `notify` program, which runs only at a turn's end (codex-rs/hooks/src/legacy_notify.rs:13-73); OpenTelemetry, off by default; the app-server's JSON-RPC status, which needs a client on the daemon's socket.
- **Versions.** Present by: hooks 0.125.0, trust 0.130.0, SessionEnd 0.145.0, Interrupt 0.150.0, the daemon by default 0.157.0. The clone holds only some release tags (0.120.0, 0.125.0, 0.130.0, 0.135.0, 0.140.0, 0.145.0, 0.148.0, 0.150.0, 0.152.0, 0.155.0, 0.157.0 to 0.160.1), so each feature came at that release or in the gap before it; as minimum versions these are safe, if conservative.

### 2.4 Cursor's own agent

- **Hooks** since Cursor 1.7 (2025-09-29, beta; grimoire-rs/grimoire@4650ad8 .agents/research/hooks_vendor_reports/cursor.md:16-27; the 1.7 changelog seen only as a search snippet). Today: 18 agent events ([CD] hooks.md:28-48). The latest editor version is 3.23 ([CD] release-notes__ide.md:11). The CLI has hooks since January 2026 ([CD] cli__changelog.md:419-421).
- **Files.** `~/.cursor/hooks.json` for the user, which applies "globally" ([CD] hooks.md:111, 649-650); also project, team and enterprise levels, all of which run ([CD] hooks.md:630). The format is `{"version":1,"hooks":{"<event>":[{"command":…,"timeout":N}]}}`, flat arrays without Claude Code's group level ([CD] hooks.md:697-712). Cursor reloads the file when it changes ([CD] hooks.md:171).
- **Output.** For permission hooks such as `preToolUse`, "invalid JSON or a response that doesn't match the hook's schema blocks the action" ([CD] hooks.md:198), while no output counts as a failure, which blocks only with `failClosed` ([CD] hooks.md:711). An empty stdout at exit 0 let `beforeSubmitPrompt` and `preToolUse` proceed in the editor 3.9.16 ([RO] cursor-logs.txt:7-64, 382-569) and in the CLI 2026.10.01 ([FL]:23). Section 10 checks it on the owner's version.
- **Payloads.** Every payload has `conversation_id`, "stable across many turns", and `generation_id`, which "changes with every user message" ([CD] hooks.md:814-846); `session_id` equals `conversation_id` ([CD] hooks.md:1349). In captured payloads `conversation_id` comes first, while `session_id`, `hook_event_name` and `cursor_version` come after the content fields ([RO] cursor-logs.txt:12, 62; cursor.md:565-579).
- **Events for Awake:**
  - Turn start: `beforeSubmitPrompt`, "right after user hits send" ([CD] hooks.md:1243-1245). A turn submitted by a stop hook's `followup_message` fires none; its first sign is `afterAgentThought` ([FL]:57). With queued messages, only the last one fires it (forum.cursor.com thread 155183, Cursor 2.6.20, a search snippet only). Turns Cursor starts by itself, a `/goal` continuation, a `/loop` iteration ("Runs a prompt or skill repeatedly at a specified interval") or a background task that wakes the agent ([CD] agent__overview.md:132-142; skills.md:51; release-notes__agents-window.md:190, 296): which hooks they fire, not found (10.2 (u)).
  - Heartbeats: `preToolUse` for every tool, `postToolUse`, `postToolUseFailure` ([CD] hooks.md:850-958), and `afterAgentThought` after each thinking block ([CD] hooks.md:1282-1302).
  - Turn end: `stop`, "when the agent loop ends", with `status` `completed`, `aborted` or `error` ([CD] hooks.md:1304-1324). A cancel is reported, unlike in Claude Code: in the CLI, Ctrl+C gives `stop` with `aborted` and then `error` ([FL]:63).
  - Session end: `sessionEnd`, with reasons including `window_close` and `user_close` ([CD] hooks.md:1360-1390).
  - `afterAgentResponse` can arrive after `stop` ([FL]:62).
  - Waiting: no event. An open approval card and a plan fire nothing ([FL]:10-13, 74).
  - Subagents: unverified. The previous revision assumed that the parent's `Task` tool call brackets a subagent, so that the parent's holder covers it, but nothing documents that. Cursor's docs describe subagents with their own conversation and transcript, and parallel workers: `subagentStop` receives `child_conversation_id`, "the ID of the subagent's own conversation" ([CD] release-notes__agents-window.md:111; hooks.md:992, 1038), and `subagentStart` was not fired by the `Task` tool in the CLI 2026.10.01 ([FL]:61). If a subagent's tool hooks carry its own `conversation_id`, each subagent makes a `cursor:s:<child>` holder that no `stop` ends, and with no last look it would keep a closed Mac awake up to the idle limit after every turn that used one. 10.2 (t) records it; 5.7 says what the adapter then adds.
- **Environment.** Hooks get `CURSOR_PROJECT_DIR`, `CURSOR_VERSION` and, for Claude Code compatibility, `CLAUDE_PROJECT_DIR` ([CD] hooks.md:1453-1466); no session variable.
- **The process.** In the editor, hooks are spawned by the window's extension host (`CURSOR_EXTENSION_HOST_ROLE=agent-exec`, [RO] cursor-logs.txt:13-20), which lives as long as the window; 3.23 restarts a host that hangs for about a minute ([CD] release-notes__ide.md:28). In the CLI it is the `agent` process.
- **The CLI.** The interactive `agent` reads `~/.cursor/hooks.json` and fires `beforeSubmitPrompt` and `stop`, but never `sessionStart` ([FL]:21, 38, 56-64). `agent -p` runs project hooks only and fires neither `beforeSubmitPrompt` nor `stop` ([FL]:21; beep-effect/beep-effect@2208622 explorations/cursor-agent-pool/RESEARCH.md:82-84).
- **Claude Code's hooks.** Cursor's agent also runs `~/.claude/settings.json` hooks by default, mapping `UserPromptSubmit`, `Stop`, `SessionStart`, `SessionEnd`, `PreToolUse`, `PostToolUse`, `SubagentStop` and `PreCompact`, but not `Notification` or `PermissionRequest`, with Cursor's payloads and Cursor's tool names ([CD] reference__third-party-hooks.md:17, 143-156, 205-247). A mapped `PreToolUse` becomes Cursor's `preToolUse`, a permission hook that runs synchronously, as Cursor has no `async` option ([CD] hooks.md:198, 701-712), and several of Cursor's tool names (`Read`, `Write`, `Grep`, `Task`, `WebFetch`) are also Claude Code's, so a matcher cannot keep Cursor out. That is H-5.
- **Cursor's hooks do not see the Claude Code extension's work.** They are the "Agent hooks (Cmd+K/Agent Chat)" of Cursor's own loop ([CD] hooks.md:28); the extension runs its own `claude`, which reads only Claude Code's files.

### 2.5 Gemini CLI, Gemini Code Assist and Antigravity

**Gemini CLI**, from its source at `fb972b2`:
- **Hooks, on by default since v0.26.0** (2026-01-28): `hooksConfig.enabled`, default true (packages/cli/src/config/settingsSchema.ts:2558-2566). Live captures by acc@6a47099 confirm them on 0.37.0, 0.55.1 and 0.57.0 (packages/adapter-gemini-cli/COMPATIBILITY.md:13-16).
- **Events:** SessionStart, SessionEnd, BeforeAgent, AfterAgent, BeforeModel, AfterModel, BeforeToolSelection, BeforeTool, AfterTool, PreCompress and Notification (packages/core/src/hooks/types.ts:43-55).
- **Where:** `${GEMINI_CLI_HOME:-$HOME}/.gemini/settings.json` under `hooks`, or an extension's `hooks/hooks.json` (docs/extensions/reference.md:240-244). The shape is Claude Code's, with a `name` per handler and `timeout` in milliseconds (docs/hooks/reference.md:26-42).
- **How handlers run.** Through `bash -c`, with the session's folder as the working folder and the JSON on stdin (packages/core/src/hooks/hookRunner.ts:335-367, 401-414). All are synchronous (docs/hooks/index.md:9-10). A hook's stdout, or its stderr when stdout is empty, is shown to the user as a message unless it is JSON, even at exit 0 (hookRunner.ts:455-478). Hooks get `GEMINI_SESSION_ID`, equal to `session_id` (hookRunner.ts:353). The hook registry loads once at startup, so running sessions need a restart (packages/core/src/hooks/hookSystem.ts:175-178).
- **Events for Awake:**
  - Turn start: BeforeAgent, once per prompt; tool continuations reuse the prompt's id and do not fire it again (packages/core/src/core/client.ts:165-193; packages/cli/src/ui/hooks/useGeminiStream.ts:2184-2194). A continuation that another hook forces fires it again (client.ts:1031-1047).
  - Heartbeats: BeforeTool, before the confirmation (packages/core/src/scheduler/scheduler.ts:635), and AfterTool.
  - Waiting: Notification, whose only type is `ToolPermission`, right before the CLI waits for an answer (packages/core/src/scheduler/confirmation.ts:153-173). Questions and plan approval take the same path (by code reading).
  - Turn end: AfterAgent, once per turn (docs/hooks/reference.md:163-181). It does not fire when Esc is pressed while a tool runs or a prompt is declined, nor after a quota-driven model switch (useGeminiStream.ts:2105-2171).
  - Session end: SessionEnd, best effort; "The CLI will not wait for this hook" (docs/hooks/reference.md:260-270). `/clear` fires it under the old id (packages/cli/src/ui/commands/clearCommand.ts:28-62).
- **Payloads** start with `session_id` (packages/core/src/hooks/hookEventHandler.ts:82-90; acc@6a47099 packages/adapter-gemini-cli/fixtures/BeforeTool-0.57.0.json). There is no subagent id: subagents are foreground tools inside the parent's turn (packages/core/src/agents/agent-scheduler.ts:78).
- **Where hooks do not run:** settings hooks in a folder Gemini does not trust (packages/core/src/hooks/hookRegistry.ts:172-186), the default for new folders since v0.24.0 (docs/changelogs/index.md:572-574), while extension hooks still run (hookRegistry.ts:188-198); with `hooksConfig.enabled: false`; and under `--sandbox` on macOS, whose profile lets a hook write only to the project and a few folders (packages/cli/src/utils/sandbox-macos-permissive-open.sb:72-83), not to Awake's runtime folder.
- **No last look:** nothing reports a session's state from outside.

**Gemini Code Assist agent mode** in VS Code is "powered by Gemini CLI" and "looks for extensions in" `~/.gemini/extensions` (Google's docs, seen only as a search snippet of https://developers.google.com/gemini-code-assist/docs/use-agentic-chat-pair-programmer). It appears to run on Gemini CLI's a2a-server (PR #16080 names Code Assist as relying on it), which builds its configuration without `hooks` (packages/a2a-server/src/config/config.ts:351-407), loads extensions without hooks, and skips a folder without its own `gemini-extension.json`, such as Awake's link folder (packages/a2a-server/src/config/extension.ts:80-125). So by code reading Awake's hooks do not run there, but whether the shipped Code Assist uses this code is not verified (10.5). IntelliJ: not found.

**Antigravity** (`agy` and the 2.0 desktop app) has hooks of another shape: a namespace per tool at the top level of `~/.gemini/config/hooks.json`, `timeout` in seconds, and one unknown top-level key drops the whole file (acc@6a47099 packages/adapter-antigravity/COMPATIBILITY.md:22-38, 82-87). On `agy` 1.2.7 only SessionStart, PreInvocation (before every model call), PostInvocation and Stop loaded (COMPATIBILITY.md:155-166); other projects report that `agy`'s bundled docs list PreToolUse and PostToolUse (mksglu/context-mode#1206; kiril6/vibeaudio#47), which acc's capture could not load. Another source names a different global file (tanaikech's gist of 2026-10-02). With no tool, waiting or session-end events, and these conflicts, it waits for a later version (S-4 (c)).

### 2.6 Other agents

Five more have a documented start and end of a turn, and could get adapters later on the same verbs:
- **GitHub Copilot CLI** and VS Code's Copilot agent read the same user folder, `~/.copilot/hooks/*.json`, so one file Awake owns covers both; their events include `userPromptSubmitted`, `agentStop`, `permissionRequest`, and notifications for background shells ending (github/docs@8f330f1 content/copilot/reference/hooks-reference.md:36-40, 255-275, 810-815; vscode-docs@279a4a7 docs/agent-customization/hooks.md:130-141). VS Code's Local agent runs no Stop hook after a cancel (microsoft/vscode-copilot-chat@5863f5a src/extension/intents/node/toolCallingLoop.ts:1055-1059), and with `chat.useClaudeHooks` on (off by default) it also runs the hooks of `~/.claude/settings.json`, Awake's included, ignoring their matchers (vscode-docs hooks.md:135-137, 187). That happens in release 1 for anyone who turned the setting on, so W25 makes Awake's Claude Code handlers stand down for VS Code's payloads too, which carry a `timestamp` that Claude Code's never do (vscode-docs docs/agents/reference/hooks-reference.md:67-76; hooks.md:726-744).
- **opencode** and **Amp**: TypeScript plugins with busy and idle states, and both report a cancel (sst/opencode@4ac0d9c packages/opencode/src/session/run-state.ts:77-86; npm @ampcode/plugin index.d.ts:1600-1653).
- **Cline**: one executable file per event, and the user must tick "Enable Hooks" (cline/cline@cd80a20 .clinerules/hooks/README.md:12-16).
- **Junie CLI**: Claude-style hooks in `~/.junie/config.json`, but `session_id` only on two events (stablyai/orca#16472).
- **Windsurf**: its Cascade hooks were replaced by Devin Local in Devin Desktop 3.9.19 (cisco-ai-defense/defenseclaw#915), and whether Devin CLI's hooks fire inside Devin Desktop was not found.

Four have no turn signal: Aider (a notify program at the end of a reply only, Aider-AI/aider@5dc9490 aider/args.py:825-841), Roo Code (an in-process extension API only), Zed's own agent (no hooks; its idle-sleep hold above) and Junie inside JetBrains IDEs (ACP, which runs no hooks, GitGuardian/ggshield#1451). Claude running inside Zed through ACP loads the user's Claude Code settings (zed-industries/claude-code-acp@0724b17 src/acp-agent.ts:9471), so the Claude Code adapter should cover it; that is inferred, not tested.

For all of these the manual paths remain: `awake -- COMMAND`, `awake -w PID` or `While` in the picker, or a timed session.

### 2.7 What the agents leave to Awake

| Gap | Claude Code | Codex | Cursor's agent | Gemini CLI | Covered by |
|---|---|---|---|---|---|
| An interrupt (Esc, Ctrl+C, a Stop button) | No hook; `idle_prompt` in the terminal only | `Interrupt` | `stop` with `aborted` | Not while a tool runs | The idle limit; for Claude Code the last look at its end |
| A failed turn | `StopFailure` | Nothing | `stop` with `error` | Partly | The idle limit |
| A prompt answered | No hook | No hook; an approval does not count as waiting, as its hook also fires for the automatic reviewer (B-1) | No waiting signal at all | No hook | The waiting allowance, or for Codex's approvals and Cursor the idle limit; for Claude Code the last look |
| Background work after a turn | `background_tasks` | Not reported | Not reported | Not reported | B-8, Claude Code only |
| A closed window or a killed process | No hook | No hook | `sessionEnd` on a window close | No hook | The watch on the agent's process (5.8), weak where that process is an editor or a daemon |
| A last look from outside | `claude agents --json` | None | None | None | B-7, B-13 |

## 3. Awake today

What already works, with no change:

- **Headless runs.** `awake -- claude -p "<task>"` keeps the Mac awake, also with the lid closed, for the whole run, and exits with the agent's status (README.md:44, 371). The same holds for `awake -- codex exec "<task>"`, `awake -- gemini -p "<task>"` and `awake -- agent -p "<task>"`. This is the exact fit for one-off headless work, and it needs no hooks. For `agent -p`, whose user hooks never load ([FL]:21), it is the only way.
- **The whole lifetime of an interactive agent.** `awake -w <PID>`, or `While` in the picker, which lists the user's terminal commands (tools/awake-gui-picker.swift:526-596), keeps the Mac awake for the process's whole life. That includes the time it waits at the prompt. It ends with `process_exited`, and with the lid closed the helper then sleeps the Mac (awake-helper:850-855). For an agent inside an editor the process is the editor's, which lives all day, so this is right only as the user's own explicit choice.

What is missing for "while AI works":

- **A tie to the agents' turns, not their processes.** A session can watch one PID (555-562, 7083-7100) or end at a time. It cannot follow turns.
- **A start without a terminal and without a prompt.** A hook has no terminal, so `awake` runs in GUI mode (7144-7172). A lid-closed start would then show the macOS password dialog, unless password-free mode or a valid sudo ticket covers it (`run_helper` 4133-4207, `run_as_admin` 4060-4131).
- **Calls that run side by side.** State changes take a `mkdir` lock with 100 tries of 0.1 s, then fail with "Another awake command is already changing the session state." (1416-1463, 1446). Hooks of parallel sessions, subagents and agents run at the same time (hooks.md:412).
- **A cheap call.** Parsing all of `bin/awake` costs about 23 ms before anything runs (lease-probe, research), and that would come on every tool call; Gemini CLI's hooks are all synchronous (docs/hooks/index.md:9-10), so it would also slow every Gemini tool call.

Facts the design reuses:

- **How a session tied to a process works.**
  - For a lid-closed session, the root helper's timer checks the watched PID every 2 s with `kill -0`, and every 10 s also its start time (awake-helper:86, 537-548, 1393-1398). The guard checks it too once the timer is gone (awake-helper:1503).
  - For a lid-open session, the Caffeine runner does the same (6029-6041).
  - The helper checks that the PID is the user's own, and records `watch_pid` and `watch_started` in its session file (awake-helper:934-944, 769-770). A lid-open session records the same in its state file (6384-6387).
  - A session tied to a process "has no time limit unless a time option gives one" (7083-7092); with `--duration-seconds` it has both ends.
- **The longest session.** `MAX_DURATION_SECONDS` is 31536000, "365 days: the longest session, and the latest end time, from now" (121-122), checked for `--duration-seconds` (511-512), and the helper has the same bound for sessions with an end time (awake-helper:57-59). So `--duration-seconds 31536000` needs no change anywhere.
- **How such a session ends at once.**
  - Lid-closed: `request_helper_session_stop command-finished` writes `command-finished` and wakes the timer through the FIFO (4320-4376, 4308-4318). The helper ends any session of that user as `process_exited` when the file exists; it only tests whether the file exists, and never reads the token in it (awake-helper:39-46, 1353-1356, 1495-1497). `request_helper_session_stop` writes whatever token is current when it is called (4342-4350).
  - Lid-open: `command-finished` with the token, then TERM to the worker, which then records `process_exited` (4486-4504, `caffeinate_stop_reason` 4446-4453).
  - `finish_session` sleeps the Mac with the lid closed only for `timeout`, `low_battery`, `overheated`, `unplugged` and `process_exited`, never for a user's `stopped` (awake-helper:845-856). Clearing the sleep settings alone does not sleep a closed Mac: "macOS decides on clamshell sleep only when the lid, the power source or the displays change" (awake-helper:621-624).
- **One lid-closed session per Mac.** A second start is refused with exit 3 (awake-helper:962).
  - A `-w` or `--` start while a session runs is refused (7262-7266).
  - A time option instead adds time (7268-7377), or, for a session with no end time, says "Awake already runs until NAME (PID n) exits." (7299-7310). `--indefinite` removes the end time (`run_helper … extend UID none`, 6737).
- **The main lock** has a pid file with the holder's start time and a takeover of a stale lock (1377-1463). `acquire_main_lock` exits after its 100 tries, and sets an `EXIT` trap that writes the status report and releases the lock (1444-1448, 1462; `finish_main_run` 1311-1314).
- **Status.** A session tied to a process reads `Awake is on until NAME (PID n) exits[, with at most X left]` (3042-3045). The JSON has `watch_pid`, `watch_command` and `end_mode` (3190-3333). The app mirrors the sentences, and a comment asks to keep them in sync (StatusDescription.swift:22-54; 3038). In the app, `schemaVersion` and `active` are required and the other fields optional (AwakeCLI.swift:10-20).
- **Notifications.** The CLI posts none unless asked, except `Awake failed` for a refused start that no terminal shows (25-37, `report_start_failure` 4590-4607). The app posts end notifications only for the sessions it started, and only when a poll goes from active to inactive (StatusBarController.swift:604-606, 613-615). It polls every 10 s (StatusBarController.swift:106-109).
- **The helper protocol** is 9 in both files (172; awake-helper:56). A different number makes `run_helper` install the helper behind a password prompt (4160-4172). A hook must never get there.
- **Password-free mode** lets the user run the helper with any arguments without a password (4737). README.md:103 states the trade-off: "any program running as you can then change the sleep settings the way Awake does (keep the Mac awake for up to 365 days, or without an end time, …)".
- **The dry run.** `helper_is_ready` accepts the copy of the helper next to the script and skips the admin-only checks (3947-3961), and `run_helper` returns before `run_as_admin` (4145-4159). `helper_runs_without_password` runs the real `/usr/bin/sudo -n` (4052-4055); its only caller skips it in the dry run (7599-7600). GitHub's macOS runners have passwordless `sudo` (https://raw.githubusercontent.com/github/docs/main/content/actions/reference/runners/github-hosted-runners.md, line 77).
- **Detached processes.** `start_detached` starts an internal mode of `awake` in its own process group with `nohup`, and prints the child's PID on its stdout (3567-3573). It does not change folder.
- **Time limits on other programs.** `run_with_timeout` runs a command with a limit and kills it at the end (2339-2363).
- **The probes.**
  - A watcher stand-in tied to the session with `--start -w`, which exits once no holder file names a live process, kept the session through the release of one of two holders. It ended it as `process_exited`, with one mock `sleepnow`, about 3 s after the last holder's process died. All of this ran on today's code (`holders-probe.sh`).
  - Repeated `--start --until @now+300` calls also work as a lease. But each one runs the helper, and it silently extends a session the user started (`lease-probe.sh`, steps 1-3 and 10).

## 4. Design options

| # | Option | For | Against |
|---|---|---|---|
| O1 | **Each agent's hooks drive holders through an adapter, with one watcher, time limits and, for Claude Code, a last look** (recommended). Each agent's turn, tool, subagent and session events map to a few common verbs (5.2). One user-level watcher runs a session tied to its own PID while any holder needs it, and ends it about a minute after the last one. The agent's process exit and the time limits cover missed events. | Documented events, so the session follows the agents' turns. It reuses `-w`, `command-finished` and the helper as they are, with protocol 9. Several agents, sessions and subagents are just several holders. The helper ends the session within 2 s if the watcher dies. | A one-time setup per agent (H-1), with a trust step in Codex (H-3). Interrupts are covered unevenly (2.7). Lid-closed needs password-free mode (H-2). |
| O2 | **Hooks renew a lease:** `awake --start --until @now+N` on each event (design A of the research). | Almost no new code (`lease-probe.sh`). | Every renewal runs `sudo` and the helper with its own battery and thermal reads (awake-helper:1078-1113). A tool call longer than N ends the session mid-call. It extends a session the user timed, against the principle. No early end that sleeps the Mac. |
| O3 | **`awake -w <agent pid>`**, by hand or from a session-start hook. | Works today (3). | Covers the whole process life, idle time at the prompt included, which is the session-scoped mistake Adrafinil moved away from (ffda975). For the agents inside an editor the process is the editor's, which lives all day (2.3, 2.4). |
| O4 | **`awake -- <agent> -p "<task>"`** for headless runs. | Works today for all four, needs no hooks, and passes the exit status through (README.md:44, 371). | Headless runs only. Documented as the way for one-off runs, next to O1. |
| O5 | **An MCP tool** (`keep_awake(minutes, pid)`, `release_awake`), as Adrafinil has (adrafinil@6e4eece AdrafinilCLI/MCP/MCPServer.swift:4-126). | The model can hold the Mac for work that outlives its reply. | Only when the model decides to call it, so it cannot follow turns. JSON-RPC in Bash 3.2 is a project of its own. With the handover (5.9), an agent can already run `awake --duration 1h` or `awake -w $!` through its shell tool where permissions allow. |
| O6 | **No hooks: follow the agents' own idle-sleep holds**: Claude Code's `caffeinate` child, Codex's assertion, Cursor's wakelock, Zed's. | No setup. Zed documents its hold (agent-panel.md:106-112). | Claude Code's is not documented, Codex's is off by default, Cursor's was seen only in a forum snippet. It needs a process that always polls `pmset -g assertions`, scoped to the agent's processes (adrafinil@6e4eece AdrafinilDaemon/Monitors/PowerAssertionReader.swift:30-33), and a lid closed within one poll still sleeps the Mac. Later at most (section 13). |
| O7 | **No hooks: poll `claude agents --json`.** | Documented as the supported interface, with busy, waiting and idle per PID (agent-view.md:762-779). | Claude Code only, research preview, and each poll starts `claude`. It needs an always-running poller to start sessions. O1 uses it only for a last look at each expiry (B-7 (a)). |
| O8 | **A menu bar choice.** | What the owner asked for: "be able to select". | Not a mechanism of its own. It is the switch for O1 (S-1 (a), S-3), or a one-off choice in the picker on top of O1 (S-1 (b)). |
| O9 | **Plugins or extensions** that carry O1's hooks, per agent. | The agent owns the configuration. | See H-1 (b). Gemini's extension is the exception that pays (H-4). |
| O10 | **Generic heuristics**: the CPU or the child processes of an agent's process tree, or its transcript files with idle timers (as peon-ping did). | Works for agents without hooks. | An agent that is thinking computes on the server while its local process sits nearly idle (adrafinil@6e4eece AdrafinilDaemon/Monitors/PowerAssertionReader.swift:7-10), so the Mac would sleep mid-turn; editors use CPU for other reasons; transcript formats are not documented; Adrafinil needed three fixes to its CPU rule (section 1). And a poller must run all the time. |
| O11 | **Cursor through Claude Code's hooks**: no Cursor adapter, as Cursor's agent runs Claude Code's handlers by default. | One file fewer. | H-5 (b). |

Recommended: O1 for the four agents, switched on and off from the menu (O8), with O4 documented for headless runs and O3 for agents without hooks. Version 1 has no MCP tool (O5), and O6 and O10 are not among its signals.

## 5. The recommended design: behaviour

### 5.1 Words

- **Automatic session:** a session that Awake starts by itself because an agent works. It is lid-closed (or lid-open, H-2), tied to the watcher's PID, with the 365-day limit of any session. Internally it is started with `--agent-session`.
- **Agent:** one of `claude` (Claude Code on every surface), `codex`, `cursor` (Cursor's own agent) and `gemini` (Gemini CLI). Shown to the user as Claude, Codex, Cursor and Gemini.
- **Adapter:** one agent's part: its hook file and how Awake installs and removes its handlers (K.3), how its events map to the common verbs and where the ids are (5.2, W2), its agent process (5.8), and its limits (2.7).
- **Holder:** one reason to stay awake. Its key names the agent: `claude:s:<session_id>` for a main conversation and `claude:a:<agent_id>` for a subagent, and the same with `codex:`, `cursor:` and `gemini:`. So two agents that happen to use the same id never share a holder. It has a state (5.6), the agent's process ID and start time, and the times of its last events.
- **Watcher:** an internal `awake --agent-watch` process, started by a hook when needed. It reads the hooks' events, keeps the holders of every agent, and starts and ends automatic sessions. Only one runs per user.
- **Event:** one line that a hook appends to `agent-events` in the user's runtime folder (W3).
- **Tombstone:** the time of a key's last `turn-end`, `agent-end` or `session-end`, kept until that key's next turn starts (5.6).
- **Last look:** one `claude agents --json` call before a time rule lets the Mac sleep, for Claude Code holders (B-7, W21).
- **Pause:** a record that stops automatic sessions from starting. The stop pause, `agent-pause` in Awake's own folder, is written by a stop by the user and lasts until the user's next typed prompt (B-5, 5.9). The guardrail pause, `agent-guard` in the runtime folder, is written by the watcher after a guardrail end and lasts until the cause has gone (5.10). Each is lifted only by its own rule.

### 5.2 The core, and one adapter per agent

What every agent shares, in `bin/awake`: the verbs, the event log, the holders and their rules, the watcher, the automatic session and its end, the pause, the lid rule and the status. What each adapter adds is small: a table in the hook's fast path that says where its ids are and which events it may drop, and a block in `--ai-hooks` that writes its file.

**Verbs.** Each handler passes its agent and one verb, `'<awake>' --agent-hook AGENT VERB`:

| Verb | Meaning | Starting verb | Claude Code | Codex | Cursor's agent | Gemini CLI |
|---|---|---|---|---|---|---|
| `turn-start` | A prompt starts a turn | yes | `UserPromptSubmit` | `UserPromptSubmit` | `beforeSubmitPrompt` | `BeforeAgent` |
| `turn-maybe` | A turn may follow without a prompt | no | `SessionStart` `clear` | | | |
| `turn-end` | The turn ended | no | `Stop`, `StopFailure` | `Stop`, `Interrupt` | `stop`, any status | `AfterAgent` |
| `session-end` | The conversation ended | no | `SessionEnd` | `SessionEnd` | `sessionEnd` | `SessionEnd` |
| `idle` | No reply typed for 60 s | no | `Notification` `idle_prompt` (terminal only, 2.2) | | | |
| `agent-start` | A subagent starts | yes | `SubagentStart` | `SubagentStart` | | |
| `agent-end` | A subagent ends | no | `SubagentStop` | `SubagentStop` | | |
| `waiting` | The agent waits for the user | yes | `PermissionRequest`; `PreToolUse` for `AskUserQuestion` or `ExitPlanMode` | `PreToolUse` for `request_user_input` | (none, 2.4) | `Notification` (`ToolPermission`) |
| `tool-start` | A tool, or for Cursor a thinking block, starts | yes | `PreToolUse` for other tools (async) | `PreToolUse` for other tools (async); `PermissionRequest` (B-1) | `preToolUse`, `afterAgentThought` | `BeforeTool` |
| `working` | A tool finished | yes | `PostToolUse`, `PostToolUseFailure` (async) | `PostToolUse` (async) | `postToolUse`, `postToolUseFailure` | `AfterTool` |

`afterAgentThought` is Cursor's `tool-start` because it is the first sign of a follow-up turn, which fires no `beforeSubmitPrompt` ([FL]:57); `afterAgentResponse`, which can come after `stop` ([FL]:62), is not used. Each event line also carries the hook's start time, the agent's process ID, `BG=1` when a Claude Code `Stop` reports background tasks (B-8), `RC=1` while Claude Code's Remote Control is connected (B-9), and `CFG=1` when Claude Code's hooks see a `CLAUDE_CONFIG_DIR` (B-7); for the other agents all three are 0.

**What differs per adapter:**

| | Claude Code | Codex | Cursor's agent | Gemini CLI |
|---|---|---|---|---|
| Holder ids | `session_id`, `agent_id` | `session_id`, `agent_id` | `conversation_id` | `session_id` |
| Fallback when stdin has none | `CLAUDE_CODE_SESSION_ID` | none | none | `GEMINI_SESSION_ID` |
| Also read | `tool_name` (to drop `tool-start` for the waiting tools), `background_tasks` on `Stop`, `CLAUDE_CODE_BRIDGE_SESSION_ID`, `CLAUDE_CONFIG_DIR` | `tool_name` (to drop `tool-start` for `request_user_input`) | `child_conversation_id` on `subagentStop`, only if 10.2 (t) shows that subagents have their own ids (5.7) | |
| Stands down for | a Cursor payload (`conversation_id` before the first content key, H-5), and a VS Code payload (`timestamp` before it, 2.6) | | | |
| The agent's process (5.8) | `claude`, or the extension's bundled copy | the shared daemon, the extension's `codex app-server`, or `codex` | the window's extension host, or `agent` | `node` |
| Last look | `claude agents --json`, for main conversations | none | none | none |
| Input window for lifting a stop pause (W26) | 5 s | 60 s | 5 s | 5 s |

The watcher treats every holder alike, whatever its agent. Only the last look, the background allowance, Remote Control and `idle` exist for Claude Code alone, because only Claude Code gives those signals (2.7).

### 5.3 When a session starts

1. A hook runs. It appends its event (W3). If its verb may start work (5.2) and no live watcher answers, it goes on to `main`, which starts one (W4). It then exits 0, in about 10 to 25 ms on a Mac (estimate, W14, W.8).
2. The watcher reads the event and creates or updates the holder. It starts an automatic session when all of these hold:
   - a holder that may start a session exists: `working`, `waiting`, `background` or `remote` (5.6);
   - no session runs, which the watcher reads from the helper's session file and the lid-open state file with builtins on each pass, so it never runs a start that would be refused, and never touches a session the user started;
   - the watcher has looked for the end record of every session it last saw running (`completion_reason_for_token`, 4431-4444), so that a guardrail end is noticed before anything starts (5.10);
   - no pause stands, neither `agent-pause` nor `agent-guard` (5.9, 5.10);
   - the lid is open, or the Mac is in closed-display mode: `lid_closed_causes_sleep` is false (B-11).
   The start itself also refuses, under the main lock, while either pause file exists (W10), so a stop that lands between these checks and the start still wins. The hook never waits for this, so the prompt is not held up by the session's start, which takes about half a second with the lid closed (faster-start-stop-2.md:144).
3. The start is `awake --agent-session -w <watcher PID> --duration-seconds 31536000 --backend B --min-battery N --thermal-guard T --unplug-guard U --keep-display off --no-notifications`, run by the watcher as a child under `run_with_timeout` (2341).
   - `31536000` is `MAX_DURATION_SECONDS`, the 365 days of every session (B-2, B-12).
   - `B` is the stored lid mode (H-2, K8), and lid-closed only when `helper_runs_without_password` succeeds (4052-4055); in the dry run a mock decides (W12).
   - `N`, `T` and `U` are the guardrails (B-3), read at each start and every 30 s while the session runs (W28).
   - `--agent-session` makes the start ask for nothing: no password dialog, no helper install (W12). It also records the session as automatic.
4. A start that fails anyway (for example "Another awake command is already changing the session state", 1446) is tried again at most once a minute.
5. With the lid-open backend, sleep settings left by an earlier lid-closed session would first need `run_helper restore` (7625-7641), which the automatic transport refuses. The watcher then starts nothing, sets `agent_note` to "Run awake --stop to restore the sleep settings.", and does not try again until they are gone.

### 5.4 How it is kept alive

- The session is tied to the watcher's PID, so neither the helper nor the Caffeine runner ends it while the watcher runs (awake-helper:1393-1398; 6029-6041).
- The watcher keeps it while at least one holder of any agent keeps it (5.6). Hooks only append events. They never change the session.
- The 365-day limit is the session's own time limit, the same as for any session, which the root helper ends on its own. It is not a promise about the agents' work, so the status sentence does not show it; `--status-json` has it as `deadline_at`. A start by hand replaces the automatic session (5.9) instead of moving this limit, and the app's time item reads `Keep awake for 1 hour` during an automatic session (M4, B-14).

### 5.5 When and how it ends

1. **The work stops.** When no holder keeps the session any more, after the last look for Claude Code holders (B-7), the watcher ends it at once (W6). It takes the main lock, checks that the running session is its own (its `watch_pid` is the watcher's PID and its `watch_started` the watcher's start time), and asks for the end with that session's token: `command-finished` for a lid-closed session, or `command-finished` and TERM to the worker for a lid-open one, as `run_bound_command` does (4486-4511). The reason recorded is `process_exited`, so with the lid closed the helper sleeps the Mac (awake-helper:850-855). The end grace of 60 s is part of the holder rules (5.6), so a quick next prompt, or a Stop hook that continues the turn, does not end a session only to start a new one.
2. **The watcher dies** (killed, or a bug). The helper or the runner finds its PID gone within 2 s and ends the session as `process_exited` (awake-helper:1393-1398; 6033-6040). This needs no change. A watcher that hangs is ended by a later hook, at its second look (5.8), which then comes to the same thing.
3. **The 365-day limit:** `timeout`, which sleeps a closed Mac, as for any session. No pause follows: with the lid open and an agent still at work, a new automatic session starts within a pass; with the lid closed, B-11 holds.
4. **A guardrail:** `low_battery`, `overheated` or `unplugged`, as for every session. Automatic sessions then pause until the cause has gone (5.10).
5. **A stop by the user:** `stopped`, as today. That does not force sleep (awake-helper:847-849). The stop writes the stop pause before it ends the session, and automatic sessions stay paused, for every agent, until the user's next typed prompt (5.9, B-5).
6. **An interrupt** (Esc, Ctrl+C, a Stop button):
   - Codex sends `Interrupt` and Cursor `stop` with `aborted`: the turn ends as usual.
   - Claude Code sends nothing (2.2). In the terminal, the `idle` verb from `idle_prompt` ends a working holder whose last event is at least 50 s old, if it fires; Adrafinil found that it often does not (ClaudeCodeIntegration.swift:12-18). In the extension and the Desktop app it never fires (2.2). The backstop is the 15-minute idle limit, after which the last look reads `idle` and the holder ends.
   - Gemini CLI sends no `AfterAgent` when Esc stops a running tool (2.5): the waiting allowance or the idle limit ends the holder.
7. **A start by hand:** the handover of 5.9 ends the automatic session as `stopped`, with no pause.
8. **`--ai-hooks off`:** for all agents, the same stop as a handover, then the watcher is stopped and its files removed; for one agent, that agent's holders are dropped, and the session ends only if no other agent's holder keeps it (K11).

The watcher exits once no holder is left and no session of its own runs, under the exit protocol of W3, which loses no event that arrives meanwhile.

### 5.6 Holder states, and the rules

**States.**

| State | Entered by | Keeps a running automatic session | May start one | Left by |
|---|---|---|---|---|
| working | `turn-start`, `agent-start`; `tool-start` or `working` (rules below) | while the last sign of work is under 15 min old (the idle limit, B-2), then the last look (Claude Code) | yes | `turn-end`, `agent-end`, `session-end`, `waiting`, `idle` (if the last event is at least 50 s old), process exit, the idle limit |
| waiting | `waiting` | for 10 min (B-1), then the last look (Claude Code) | yes | `tool-start` or `working` at least 2 s later (the tool ran after the answer), `turn-start`, `turn-end`, `session-end`, process exit, the 10 min |
| background | `turn-end` with `BG=1` (Claude Code) | until 1 h after `bg_since` (B-8), then the last look | yes | `turn-end` with `BG=0`, `turn-start`, `tool-start` or `working` at least 2 s later, `session-end`, process exit, the 1 h |
| remote | `turn-end` with `RC=1` and `BG=0` (Claude Code, B-9) | for 10 min (the waiting allowance) | yes | `turn-start`, `tool-start` or `working` at least 2 s later, `session-end`, process exit, the 10 min |
| ended | `turn-end` with `BG=0` and `RC=0`, `agent-end`, `session-end`, `turn-maybe` | for the end grace (60 s), then the last look (Claude Code) | no | `turn-start`, `agent-start`, `tool-start` at least 2 s later (or `working`, for a `turn-maybe` holder, which has no tombstone); dropped after the grace |

**Rules.**

- **The 2-second rule.** Async hooks of the previous tool can finish after the sync event that followed them. So `tool-start` and `working` change a holder that is `waiting`, `background`, `remote` or `ended` only when their time is at least 2 s later than the event that put it there. An answer within 2 s followed by a short tool is caught by the next event. Gemini CLI's hooks are all synchronous (docs/hooks/index.md:9-10), so for Gemini the rule only costs 2 s in rare cases.
- **Tombstones.** `turn-end`, `agent-end` and `session-end` leave a tombstone for their key. `turn-start` or `agent-start` for that key removes it, and it expires after the idle limit.
  - `working` never reopens or recreates a key with a tombstone: after a turn has ended, a late heartbeat of its last tool cannot keep a closed Mac awake.
  - `tool-start` can: a Stop hook or `/goal` that continues a Claude Code turn starts its next tool, and `PreToolUse` runs before every tool call (hooks.md:1580, 2571-2577); a Cursor follow-up turn starts with `afterAgentThought`. Within the end grace, a `tool-start` at least 2 s after the tombstone puts the holder back to working. After the holder was dropped, for Claude Code it creates it again only if the last look reads that session `busy`; for the other agents, and for Claude Code without the last look (B-7 (b)), the 2-second rule alone decides.
  - `turn-maybe` creates an `ended` holder without a tombstone.
- **Dropping.** A holder is dropped when its time runs out and the last look does not keep it, or at once when its agent process has exited (5.8). A key dropped by the waiting allowance has no tombstone, so answering a prompt on the Mac after the 10 minutes starts a session again with that tool's `tool-start`.
- **`idle`** ends only a `working` Claude Code holder whose last event is at least 50 s old: the case of an interrupt. It changes nothing in the other states, so `idle_prompt` during background work (hooks.md:2299, 2321) never cuts off a background build.
- **Background work.** `bg_since` is the time of the first `turn-end` with `BG=1` since the holder was created or since the last `turn-end` with `BG=0`; later ones do not move it (B-8). A background subagent also has its own `a:` holder, with its own events (5.7). Whether a background shell's end fires any hook: none was found in hooks.md, and section 10 records what fires. Scheduled wakeups (`session_crons`) do not count (B-8).
- **The last look**, for Claude Code main-conversation holders (`claude:s:`). When the times of one or more of them that keep a running session run out in a pass, and no other holder keeps it, the watcher runs `claude agents --json` once (W21). Each such holder whose process (by `pid`, else by `sessionId`) reads `busy` goes back to working, with a fresh idle limit. A holder that reads `waiting` or `idle`, or a failed call, lets the time rule apply. A live holder that a successful call does not list is marked `unlisted` and gets B-7 (b)'s timings (grace 3 min, waiting 20 min) from then on, as does a holder with `CFG=1` (B-7). Subagent holders (`claude:a:`) share their session's process (hooks.md:269), so a `busy` session says nothing about them: they end by their own events and times and are never revived. One call answers for every holder in that pass.
- **The quiet limit** (B-12). The last look can keep a holder that has had no hook event of its own for at most 2 hours. After that the time rule applies whatever it reads. A long run of work sends events all the time, so this cuts off only a single silent tool call longer than 2 hours, or a wrong `busy`.
- **Agents without a last look** (Codex, Cursor, Gemini CLI): their holders follow the same times, and the time rule simply applies at each expiry (B-13).
- **The session runs** while any holder keeps it, and starts only for a holder that may start one (5.3).

### 5.7 Several agents, sessions and subagents

- Each conversation of each agent has its own holder: several terminals, the extension's tabs, the Desktop app, Codex's windows, Cursor's chats, Gemini sessions. Each subagent of Claude Code and Codex has its own `a:` holder. Gemini's subagents run inside the parent's tool call, so the parent's holder covers them (2.5). For Cursor's subagents this is unverified (2.4): if 10.2 (t) shows that a subagent's tool hooks carry its own `conversation_id`, the Cursor adapter also hooks `subagentStop` as `agent-end`, keyed by its `child_conversation_id` (`cursor:s:<child>`), so each subagent's holder ends with it; `subagentStart` stays out, as it is a permission hook ([CD] hooks.md:198) and was not seen firing ([FL]:61). Otherwise the parent's holder covers them, as assumed so far.
- One watcher and one automatic session serve them all, so the owner's Claude Code panel and Cursor's agent working at once keep one session. The one-lid-closed-session rule (awake-helper:962) holds by itself.
- `session-end` ends only the holder of the conversation that ends. A background subagent survives `/clear` (Adrafinil's note, ClaudeCodeIntegration.swift:20-41) and keeps its own holder.
- **Claude Code's `SessionStart` with matcher `clear`** gives the new session an `ended` holder (`turn-maybe`). This is for a plan approved with a cleared context: according to Adrafinil, that plan's run bypasses `UserPromptSubmit`, and no `Stop` fires for the old session (ClaudeCodeIntegration.swift:20-41). That is Adrafinil's finding, not documented; section 10 checks it. The run's first `tool-start` puts the holder to working, and a run that thinks longer than the grace before its first tool reads `busy` in the last look. A plain `/clear` costs at most the 60 s grace, and nothing when no session runs, as `turn-maybe` cannot start one. In the extension, `/clear` has been reported to fire no `SessionEnd` and a `SessionStart` with `startup` instead of `clear` (#50808, 2.1.114); the holder of the old session then ends by its own time rules.
- **One conversation in two processes.** In the extension a conversation can be open in two processes after "Open here anyway", and a reload starts a new process for the same session id (vs-code.md:217, 291-300). Each event records its process, and the holder follows the most recent one; the exit of a process the holder no longer records changes nothing. If the old process exits before the new one sends an event, the holder is dropped, and the continued step's first `tool-start` makes it again.
- **Codex's input to a subagent** carries `agent_id`, so it lands on the subagent's `a:` holder, never on the main conversation's (2.3).

### 5.8 Crashes, restarts and stale state

- **The agent's process.** Each holder records the process the hook ran under. The hook's parent is the shell that runs the handler's command (K2), which ends with the hook, so the hook passes that shell's parent, read with one `/bin/ps -o ppid= -p $PPID`. The watcher walks further up past `sh`, `bash`, `zsh`, `dash` and `fish` (Codex runs hooks in the user's own shell, codex-rs/core/src/session/mod.rs:5129-5137), at most three levels, to the first other process, and records its start time with one `ps` (`process_start_time`, 2366-2376).
  - Every pass checks it with `kill -0`, and every 10 s also its start time (`process_is_same`, 2379-2383). This covers `kill -9`, a crash, a closed terminal, and a closed extension tab (the SDK ends its `claude` then, 2.2).
  - Where the process outlives the work (Cursor's extension host, Codex's daemon, Gemini's ACP process), the watch only notices the editor or the daemon quitting; the turn's end events and the idle limit do the rest.
  - A process that is not the user's, or PID 1, is not recorded, and the holder then relies on its events and time limits.
- **The watcher's environment.** `start_detached` passes the caller's environment on (3567-3573), so a watcher would keep, for its whole life, the environment of whichever hook started it: `CLAUDECODE=1`, `CLAUDE_CODE_CHILD_SESSION=1`, one session's `CLAUDE_CODE_SESSION_ID`, `CURSOR_*`, an editor's `PATH` (env-vars.md:190, 223, 371). The watcher is therefore started through `/usr/bin/env -i` with only `HOME`, `USER`, `LOGNAME`, `TMPDIR`, `LANG`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, and `AWAKE_DRY_RUN`, `AWAKE_DEBUG` and the `AWAKE_TEST_*` variables. The last look finds `claude` from the holder's own process (W21), not from a `PATH`.
- **A watcher from an older Awake.** With sessions of up to 365 days and continuous work, a watcher started before an upgrade could run on for days with old rules and an old `agent-state` format. `agent-watch` records `version=`, and `agent-state` a `format=` line. A hook's `main`, and `awake --ai-hooks refresh` (the installer's step), replace a watcher of another version while the lid is open (or the Mac is in closed-display mode): TERM after the usual checks, then a new watcher, with no pause; the session ends through the PID tie as `process_exited`, which with the lid open sleeps nothing, and the new watcher starts one within a pass. With the lid closed the old watcher runs on until the lid opens, as ending it would sleep the Mac in the middle of the work.
- **The watcher killed:** 5.5, item 2. Its record `agent-watch` stays, but the watcher rewrites it on every pass with `beat=<time>`, and a hook trusts it only while `kill -0` answers and the beat is at most 10 s old, so a PID that another process reuses does not fool it; `main` also checks the start time. The next starting hook starts a new watcher, which resumes at the saved line count (W3) and drops events older than the idle limit.
- **The watcher stuck** (B-12 (a)). Every program the watcher runs goes through `run_with_timeout` (2341), with 5 s for `ps`, `ioreg` and the last look and 60 s for a session's start or end. A beat between 10 and 90 s old means a watcher busy in such a call: `main` then leaves it alone, as the event is in the log. A beat more than 90 s old can also mean that the Mac slept: every process is frozen then, and the beat counts wall-clock time, so a healthy watcher wakes with an old beat and beats again within a pass. So `main` records the stale beat it saw in `agent-stale` (`beat=`, `seen=`) and acts only when a hook at least 5 s later still finds the same beat, more than 90 s old, from the same process: it sends it TERM, then KILL after 2 s, after checking its PID and start time, and starts a new watcher. The session, tied to the old watcher, ends within 2 s as `process_exited`; with the lid open, the new watcher starts a new one if an agent works. No hook waits for the second look.
- **A hook killed while it holds `agent-lock/`.** Claude Code and Codex cancel a sync hook at its timeout (K2 sets 10 s). The lock records its holder's PID and start time, and a waiter takes over a lock whose holder is gone, or whose record has been missing for 5 s (`LOCK_ABANDONED_SECONDS`, 232), as the main lock does (1377-1413).
- **The Mac restarts.** The watcher is gone. Recorded agent processes fail their start-time check and are dropped. The helper's boot-restore handles a lid-closed session cut short, as today.
- **`/tmp` cleanup** after 3 days: the watcher touches its files every 6 h (`KEEPALIVE_TOUCH_SECONDS`, 166-168), as the runner does (6043-6046). Between busy periods no watcher runs and the runtime files may go; nothing there needs to outlive that but the stop pause, which therefore lives in Awake's own folder (W10).

### 5.9 The user's decisions: their own session, a start by hand, a stop, a setting

This is the principle at the top, applied.

- **The user's own session is never changed** by automatic sessions (B-4 (a)). While it runs, the watcher keeps its holders and does not try to start.
  - When it ends while a holder may start a session: with the lid open, the watcher starts an automatic session within a pass. With the lid closed, the helper has already put the Mac to sleep for a `timeout` or `process_exited` end (awake-helper:850-855), and no automatic session starts until the lid is open (B-11). The agent's turn stalls meanwhile, and the README says so.
  - When it ends by a guardrail, automatic sessions also pause, as after their own guardrail end (5.10). When the user stopped it while a holder was active, the stop rule below applies.
  - `awake -- claude -p "<task>"` (or any agent's headless run) with the hooks on: the run's own turns make holders while the session tied to it runs. When the run ends, its holders are `ended`, which cannot start a session, so the end of `awake --` sleeps a closed Mac as today.
  - It never lifts a pause, also when an agent starts it through its shell tool: a stop pause stays until a typed prompt or `Resume now`, and a guardrail pause until its cause has gone. So an agent's `awake -- npm test` after the user's stop runs as asked, and when it ends no automatic session follows it.
- **A start by hand during an automatic session (the handover).** To `main`, an automatic session would otherwise be a running session, so a time option would add time to it and `-w` or `--` would be refused (7262-7377). Then the watcher would end that session a minute after the work stops, and the user's request would be lost. Instead:
  1. After it reads the state under the main lock (7196-7216), `main` counts a session as automatic when the running record's `watch_pid` is the PID in `agent-watch`, that process is the same (`process_is_same`), and the session file says `agent=auto`.
  2. For any start that is not `--agent-session` (a time option, `-w`, `--`, `--start` with the picker's answer, and `--if-off`, for which an automatic session counts as off), `main` skips the add-time branch and the refusal of a session tied to a process. Once the user's choice is known, after the picker if one shows, it writes `agent-handover` (`session_token=<the automatic session's token>`, mode 600), stops the automatic session with a plain stop request (`request_helper_session_stop`, or `request_active_session_stop` for lid-open), waits for its end and resets its state, as the branch for a session that ended while time was added does (7378-7397), and starts the user's session with the user's own options and transport. `stopped` never forces sleep, and clearing the settings alone does not sleep a closed Mac (awake-helper:621-624), so the change of sessions does not sleep it either. The CLI says what happened, for example "Replaced the automatic session: Awake now ends in 1 hour, also if the AI is still working." (B-14).
  3. The watcher sees an end it did not cause, with reason `stopped` and an `agent-handover` that names its token. It removes the marker, keeps its holders, and waits for the user's session like any other.
  So `awake --duration 2h`, `--until 18:00`, `--indefinite`, `-w PID` and `awake -- make` all do what they say during an agent's turn, also when an agent runs them through its shell tool. `--if-off` still changes nothing while a session the user started runs (7234-7243); during an automatic session it starts the app's default session through the handover, as the user asked for a start and the app's last poll, up to 10 s old (StatusBarController.swift:106), may predate the automatic session.
- **A stop by the user** (plain `awake`, `--stop`, the icon, `Stop session`, `Stop Awake and quit`) pauses automatic sessions for every agent until the user's next typed prompt (B-5 (a)). The stop itself writes the pause, so nothing has to be inferred later and no automatic start can slip in between:
  1. Main's stop paths (the lid-open branch at 7400-7421, the lid-closed branch after it, and `--stop` at 7463 onward), under the main lock and before the stop request, write `agent-pause` (`since=<now>`, mode 600) in Awake's own folder (W10) when `agent-watch` names a live watcher (`process_is_same`) and either the session being stopped is automatic or `agent-state` says that a holder may start a session (`startable=1`). Otherwise there is nothing automatic to hold back, and no pause is written. The handover (above) and `--ai-hooks off` (K11) stop sessions through their own paths, which write no pause.
  2. The watcher, on its next pass, sees the end and the pause. It keeps its holders and starts nothing while the pause stands. An `--agent-session` start also refuses under the main lock while `agent-pause` exists (W10), so a start that the watcher decided on just before the stop fails instead of undoing it.
  3. Hooks go on appending events as usual, so the holders stay current. A `turn-start` with no subagent id also goes on to `main` while the pause stands. Under `agent-lock/`, `main` removes the pause only when W26's test passes: the lid is open or the Mac is in closed-display mode, the last keyboard or mouse input came at least 2 s after `since`, and that input is at most 5 s old (60 s for Codex). Otherwise it leaves it. The event is in the log either way.
  4. Once the pause is gone, the watcher starts a session within a pass if a holder of any agent may start one.
  5. `awake --ai-hooks resume` (the menu's `Resume now`) removes the pause at once, with the same effect. Turning the feature off and on also removes it. A start by hand does not.
  Stop or Esc inside an agent is not a stop of Awake (B-5).
- **A setting change.** `--ai-hooks off` takes effect at once (5.5, item 8; K11). The lid mode (`agentBackend`) and the four guardrail settings reach the running automatic session within 30 s (W28): the watcher reads them every 30 s and, when one differs from what its session started with:
  - with the lid open, or the Mac in closed-display mode, it ends its session (W6, `process_exited`, which sleeps nothing with the lid open) and starts one with the new settings in the same pass, with no pause;
  - with the lid closed, a switch to lid-open ends the session the same way, so the closed Mac sleeps, as the user just chose; changed guardrails take effect at the next lid open, as a start with the lid closed is not allowed (B-11).
  A session the user started keeps the settings it started with, as today (7280-7287).

### 5.10 Guardrails, the lid, and what bounds a session

- **Automatic sessions are ordinary sessions,** so every guardrail works as for any other. That covers 5% battery, critical and serious-with-the-lid-closed heat, and the optional unplug guard, both at the start (7575-7595; awake-helper:949-954) and while the session runs (awake-helper:1357-1400).
- **After a guardrail end, automatic sessions pause** (`agent-guard`, `reason=low_battery|overheated|unplugged`, written by the watcher in the runtime folder, apart from the stop pause, which it never overwrites). Otherwise the agent's next hook would start a session again within seconds (Adrafinil's latch, CutoutLatch.swift:3-12). The watcher keeps running and keeps its holders without a session, and checks every 30 s:
  - `low_battery` and `unplugged`: the Mac is on AC power (`power_source`, 2419);
  - `overheated`: the thermal state is below serious (`thermal_state`, 2311).
  Hooks make no guardrail reads: `thermal_state` runs `osascript` with a 10 s timeout (2311-2320, 149), and turn-start hooks block the prompt until they return (hooks.md:1331). When the cause has gone and a holder may still start a session, the watcher removes the pause and starts one, with the lid open only, and only if no stop pause stands. Turning the feature off and on also clears it. A start by hand does not: after an `unplugged` end, a session the user starts on battery runs as asked, but the following automatic session waits for AC power, as the unplug guard does not cover a session started on battery (README.md:61).
- **The lid (B-11).** The watcher starts an automatic session only while `lid_closed_causes_sleep` is false, that is, with the lid open or in closed-display mode, checked right before each start (one `ioreg`; the mock keys `lid` and `clamshell_causes_sleep` in the dry run, as the helper reads them, awake-helper:610-615). A running automatic session goes on with the lid closed. So after any end with the lid closed (the user's session, a guardrail, the 365-day limit), a wakeup of a sleeping Mac in a bag never starts a session; with the lid open again, a holder that still works gets one within a pass.
- **What bounds an automatic session** (B-12). Not the 365 days, which is only the limit every session has. These end it:
  - the work's end, through each holder's time rules (5.6), with the quiet limit on the last look;
  - the watcher's PID tie, through the helper or the runner, within 2 s of the watcher's exit (5.5, item 2), and the replacement of a stuck watcher (5.8);
  - the agent's process exit (5.8);
  - the guardrails, which the helper checks on its own while the session runs;
  - the user: a stop, or `--ai-hooks off`.
  And B-11 keeps one from starting in a bag.
- **Starts that keep failing** are tried again at most once a minute (5.3).

### 5.11 What `--status`, `--status-json` and the app show

The status names the agents whose holders keep the session, in the most active phase, as Claude, Codex, Cursor and Gemini; two are joined with "and", three or more as "Claude, Codex and Cursor".

| State | `awake --status` | JSON (new fields) | App |
|---|---|---|---|
| Automatic session, working | `Awake is on while Claude works.`, or `Awake is on while Claude and Cursor work.` | `agent_session: true`, `agent_phase: "working"`, `agent_names: ["claude"]`, `agent_holders: 1`, `agent_wait_ends_at: null`, `agent_note: null`, plus the existing `end_mode: "duration"`, `deadline_at` (365 days out), `watch_pid` (the watcher) and `watch_command: "awake"` | The same sentence in the tooltip and at the top of the menu; the icon bold |
| …all holders waiting | `Awake is on while Claude waits for you, for up to 9 more minutes.` | `agent_phase: "waiting"`, `agent_wait_ends_at: <epoch>` | The same |
| …waiting for the next message over Remote Control | `Awake is on while Claude waits for your next message, for up to 9 more minutes.` | `agent_phase: "remote"` | The same |
| …background tasks only | `Awake is on while Claude's background tasks run, for up to 52 more minutes.` | `agent_phase: "background"` | The same |
| …in the end grace | `Awake is on for up to 1 more minute after Claude's last turn.` (with several agents: `after the last turn`) | `agent_phase: "ending"` | The same |
| …lid-open after a fallback | `Awake is on while Claude works (keep the lid open; the display may sleep).` | `agent_note: "Password-free mode is off, so automatic sessions keep the Mac awake only while the lid is open."` | The sentence, and the note in the AI agents group of Settings |
| Paused after a stop | `Awake is off.`, and a second line `AI sessions are paused until your next prompt.` | `agent_paused: "stopped"` | `Awake is off`; in the menu `Paused until your next prompt` and `Resume now`; the note in Settings |
| Paused after a guardrail | `Awake is off.`, and `AI sessions are paused until the Mac is on power.` (or `…until the Mac has cooled down.`) | `agent_paused: "low_battery"` (or `unplugged`, `overheated`) | `Awake is off`, and the note in the menu and in Settings |
| Hooks on, nothing running | `Awake is off.` | `ai_hooks: {"claude": "on", "cursor": "on"}` | Checkmark at `Keep awake while AI works` |

- The lid-open sentences end in `(keep the lid open; the display may sleep)`, because automatic sessions start with `--keep-display off` (3058-3061; StatusDescription.swift:47-52).
- `agent_phase` is the most active state among the holders that keep the session: `working`, then `waiting`, `remote`, `background`, `ending`. `agent_names` lists the agents of the holders in that phase. `agent_wait_ends_at` is the latest end of their allowances when no holder works, and `null` otherwise, so the app can compute "for up to N more minutes" as the CLI does.
- `agent_paused` is `stopped` while the stop pause stands, whatever else does, and otherwise the guardrail pause's reason; both are read with builtins, the stop pause from Awake's own folder (W10), so it shows also before any watcher has run since a restart.
- `agent_*` fields are `null` when the watcher has written no record. `ai_hooks` has one key per agent found on the Mac, `on`, `partial`, `off` or, for Codex, `untrusted` (installed, but no trust entries found, H-3) or `review` (trusted before a `refresh` changed the handlers, K13), and is `null` when no supported agent is found. `--status-json` computes it with builtins only (W15), as the app polls every 10 s (StatusBarController.swift:106).
- `last_session_token`, the token of the record that `last_completion_reason` comes from, lets the app see that a session ended even when the next poll finds another one running (M6).
- All new fields are added before `"error"`. `schema_version` stays 1: the app decodes every field it does not require as optional, and only `schemaVersion` and `active` are required (AwakeCLI.swift:10-20), so older apps ignore the new ones.
- The sentences live in one place in `build_status_text` (3013-3066) and are mirrored in `StatusDescription.swift`.

### 5.12 Notifications

- **None for an automatic session's start or normal end** (B-6 (a)). The child start passes `--no-notifications`, which also stops `Awake failed` for a refused start (`report_start_failure`, 4590-4607). Without it, a low battery would post one at every turn.
- **The app** posts a notification when an automatic session ends by a guardrail. The title is the usual one (InstallSupport.swift:418-431). The body adds the agents by name, from the last poll's `agent_names`: "Claude Code may still be working." The rule is in `maybeNotifyCompletionTransition`, as an exception next to `isAppSession` (StatusBarController.swift:603-631).
- **Sessions back to back.** A session the app started that ends with the lid open can be followed by an automatic session within 2 s, so the next poll sees "active" twice and today's check (StatusBarController.swift:605-607) misses the end. With `last_session_token`, the app notices it (M6).
- **The CLI** posts nothing for automatic sessions. `awake --status` names the last reason (`last_completion_reason`).

### 5.13 Examples

Section 6 walks through the owner's setup. More cases:

1. **Lid closed during a long task.** The user types a prompt in Claude Code, closes the lid and leaves.
   - `UserPromptSubmit` starts the watcher and a lid-closed automatic session.
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
5. **`/goal` with a slow check.** After each turn, `/goal`'s Stop hook asks a model whether the goal is met (goal.md:120). If not, Claude goes on, and its next tool's `PreToolUse` puts the holder back to working, even when that comes later than the grace: the last look reads `busy`. A `/goal` that runs for days keeps its session for days, as its events keep coming (B-12).
6. **The user's own 2-hour session with the lid closed.** An agent still works at the end of the 2 hours. The helper ends the session as `timeout` and sleeps the Mac (B-4 (a)). No automatic session starts in the bag (B-11). When the user opens the lid, the turn goes on and an automatic session starts within a pass.
7. **Esc in Codex.** `Interrupt` ends the turn like `Stop`; 60 s later the session ends. A Codex turn that fails on a usage limit sends nothing, and its holder ends at the 15-minute idle limit (B-10).
8. **Gemini CLI with a declined prompt.** `BeforeTool`, then `Notification` puts the holder in `waiting`. The user declines: no `AfterAgent` comes (2.5), so the holder ends after the 10-minute allowance. Had the user approved, `AfterTool` would have put it back to working.
9. **A stop while two agents work.** The Claude Code panel and Codex in a terminal both work; the user clicks the icon. The session ends as `stopped`, and the pause stands for both. Codex's next tool call starts nothing. An hour later the user types a prompt into the Claude Code panel: the lid is open, and the Enter key came after the stop and a moment before the hook, so the pause goes, and a session starts for both agents' holders.
10. **A docked MacBook.** The lid is closed on an external display, and Codex works in a terminal. Closed-display mode counts as open (B-11), so `UserPromptSubmit` starts a session, which keeps the Mac from idle sleep while the display sleeps. The user unplugs the display and leaves: the session runs on until the work ends, as after any prompt, and then the Mac sleeps.
11. **Turning on `Stop when unplugged` before leaving.** An automatic session runs, started without the unplug guard. Within 30 s the watcher replaces it with one that has the guard (W28); unplugging then ends it within 5 to 10 seconds (README.md:61), and the guardrail pause holds automatic sessions back until the Mac is on power again.

## 6. Worked example: the owner's setup

The owner: "I currently use Cursor as my editor and run Claude Extension inside it." Cursor's own agent is there too. This is the first setup that must work, and section 10.2 checks it before any code.

### 6.1 What gets installed

The owner turns on `Keep awake while AI works` in the menu, or runs `awake --ai-hooks on`. With password-free mode off, the app first offers to turn it on (M3), and the CLI refuses with the message of K8 (H-2 (a)).

1. Awake finds `~/.claude` (Claude Code, also used by the extension) and `~/.cursor` with `/Applications/Cursor.app` (Cursor). It finds no `~/.codex` and no `~/.gemini`, so it says that Codex and Gemini CLI are not found and changes nothing for them (H-6).
2. It adds 13 handlers to `~/.claude/settings.json` (K.3.1), leaving the owner's own hooks as they are. For example, under `UserPromptSubmit`:
   ```json
   {"type": "command", "command": "'/Users/<you>/Library/Application Support/Awake/bin/awake' --agent-hook claude turn-start >/dev/null 2>&1; exit 0", "timeout": 10}
   ```
   The extension reads this file, "shared between the extension and CLI" (vs-code.md:525), and applies the change to running conversations (settings.md:584; section 10 checks it in the panel).
3. It adds 7 entries to `~/.cursor/hooks.json` (K.3.3), creating the file with `"version": 1` if it is missing. For example:
   ```json
   {"version": 1, "hooks": {"beforeSubmitPrompt": [{"command": "'/Users/<you>/Library/Application Support/Awake/bin/awake' --agent-hook cursor turn-start >/dev/null 2>&1; exit 0", "timeout": 10}], "…": []}}
   ```
   Cursor reloads the file when it changes ([CD] hooks.md:171); one project needed a new conversation before the hooks ran ([RO] cursor.md:664-666).
4. It stores the lid mode and prints, per agent, what it did:
   ```
   Claude Code: on (13 handlers in ~/.claude/settings.json)
   Cursor: on (7 entries in ~/.cursor/hooks.json)
   Codex: not found
   Gemini CLI: not found
   Automatic sessions: lid-closed (password-free mode is on)
   ```

### 6.2 What fires

| The owner does | What runs | Events Awake logs | What happens |
|---|---|---|---|
| Types a prompt in the Claude Code panel | The panel's own `claude` process (one per conversation, vs-code.md:217) runs `UserPromptSubmit` | `turn-start claude:s:<uuid>` | The hook starts a watcher; the watcher starts an automatic session (lid open) |
| Claude runs tools | `PreToolUse`, `PostToolUse`, async | `tool-start`, `working` | The holder stays working |
| Claude asks for permission | `PermissionRequest` (and `Notification` `permission_prompt` 6 s later, which Awake does not hook) | `waiting` | Up to 10 minutes, then the last look (B-1) |
| Claude finishes | `Stop` | `turn-end` | 60 s grace, then the last look, then the session ends; a closed Mac sleeps |
| Presses Stop or Esc in the panel | Nothing: no hook, and no `idle_prompt` in the panel (2.2) | none | The holder stays working until the 15-minute idle limit, then the last look reads `idle` and the session ends |
| Types a prompt in Cursor's Agent chat | Cursor runs `beforeSubmitPrompt` from `~/.cursor/hooks.json`, and also Awake's Claude Code handler from `~/.claude/settings.json` (H-5) | `turn-start cursor:s:<conversation_id>`; the Claude Code handler sees `conversation_id` and writes nothing | One holder for the Cursor conversation; the same automatic session serves both agents |
| Cursor's agent thinks and runs tools | `afterAgentThought`, `preToolUse`, `postToolUse`; with the third-party import on, also Awake's Claude Code `PreToolUse` and `PostToolUse` handlers, which stand down | `tool-start`, `working` | The holder stays working; each tool call waits for two short Awake processes (H-5) |
| Cursor's agent shows an approval card | Nothing ([FL]:10-13) | none | It counts as a running tool, up to the 15-minute idle limit |
| Presses Stop in Cursor's agent | `stop` with `aborted` | `turn-end` | 60 s grace, then the end (no last look for Cursor) |
| Closes the Cursor window | The SDK ends the panel's `claude` (2.2); Cursor runs `sessionEnd` with `window_close` | `session-end cursor:…`; the Claude holder's process is gone | Both holders end; the session ends after the grace |
| Reloads the window | The panel's `claude` restarts with the same session id, and continues an interrupted step by itself (vs-code.md:291-300) | `tool-start claude:s:<uuid>` from the new process | The holder follows the new process (5.7) |
| Runs `claude` in Cursor's integrated terminal | The standalone CLI, a terminal session (2.1) | as in the panel, plus `idle` from `idle_prompt` | As in the panel, but an interrupt ends sooner |
| Clicks the Awake icon while Claude works | The stop writes `agent-pause` before the session ends (5.9) | none | `Awake is off`; the pause stands for both agents until the owner types the next prompt in either, with the lid open; Claude's next tool calls start nothing (B-5) |
| Clicks `Keep awake for 1 hour` while Claude works | `awake --start --duration-seconds 3600` through the handover | none | The owner's own hour replaces the automatic session (B-14) |

The work is the same whether the conversation sits in the sidebar, in an editor tab or in a separate window, as each runs its own `claude` process.

### 6.3 What the owner sees

- The menu: `Keep awake while AI works`, checked. During a pause also `Paused until your next prompt` and `Resume now`.
- The tooltip and the menu's first line: `Awake is on while Claude works.`, `Awake is on while Cursor works.`, or `Awake is on while Claude and Cursor work.`, and the waiting and ending sentences of 5.11.
- Settings, `AI agents`: Claude Code on, with `~/.claude/settings.json`; Cursor on, with `~/.cursor/hooks.json`; Codex and Gemini CLI "Not found"; the lid mode; and any note or pause.
- In the agents themselves, nothing: the hooks print nothing, so no message appears in Claude's panel or in Cursor's chat. The extension's Hooks dialog lists Awake's handlers among the owner's (vs-code.md:132), and the owner can delete them there too; `awake --ai-hooks status` then reads `partial`.

### 6.4 What does not work in this setup, and what to do

- An interrupt in the Claude Code panel keeps the Mac awake up to 15 minutes (above). B-7 (c) would shorten it, at a cost.
- An approval card of Cursor's agent left open keeps it awake up to 15 minutes, and then lets it sleep while the card waits.
- A Remote-SSH, WSL or container window runs Claude Code on the remote host (inferred: VS Code runs workspace extensions there; cc-changelog.md:1977), so its hooks never reach the Mac; for Cursor's agent in such a window, where user hooks run was not found (Cursor only names a variable for remote workspaces, [CD] hooks.md:1463). If the connection itself should survive, `awake -w <Cursor's PID>` or a timed session covers it.
- Cursor's `agent -p` and Cursor's Remote Control and My Machines run no user hooks: `awake -- agent -p "<task>"`, Cursor's own "Keep this computer awake", or `awake -w <worker PID>` (2.1).
- If the owner installs Codex's or Gemini's extension or CLI later, `Settings` lists it as found and off (H-6).
- Whether the last look lists the panel's sessions, and whether the panel runs every hook it should, is checked in section 10.2. A panel holder that a working last look does not list is marked `unlisted` and follows B-7 (b)'s timings (5.6), so this holds even if only some sessions are listed.
- Whether Cursor's subagents have their own conversation ids is checked in 10.2 (t); until then a turn that used one may keep a closed Mac awake up to the idle limit (2.4).
- With Cursor's third-party import on, each Cursor tool call also runs Awake's Claude Code `PreToolUse` handler synchronously (H-5). To roll back a Cursor problem, turn off both: `awake --ai-hooks off --agent cursor --agent claude`, or Cursor Settings → Agents → Third-Party Imports (K.9).

## 7. W: automatic sessions in the CLI

### W.1 Today

See section 3. In short: sessions tied to one process (`-w`, `--`), with an end through `command-finished`. There is nothing for an agent's turns, no way to start a lid-closed session that is sure not to prompt, and every call parses all of `bin/awake`.

### W.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| W1 | What starts and ends the holding | Each agent's hooks, through its adapter (2, 5.2), with the agent process's exit, the time limits and, for Claude Code, the last look as safety nets (5.5-5.8). | Polling (O6, O7) and heuristics (O10): undocumented, in research preview, or wrong while the agent thinks, and they need a process that always runs. A lease (O2): a helper run per renewal, mid-call ends, and it extends the user's sessions. |
| W2 | Holder keys and the payload | The key is `AGENT:s:<id>` or `AGENT:a:<id>`, with `AGENT` from the handler's command and each id matching `^[A-Za-z0-9._-]{1,128}$`. Anything else is dropped at the hook. The hook cuts the payload at the first content key of any agent (`"prompt"`, `"tool_input"`, `"tool_response"`, `"tool_output"`, `"last_assistant_message"`, `"text"`, `"attachments"`, `"prompt_response"`, `"message"`, `"details"`, `"llm_request"`) and looks for its ids only before it, with patterns such as `"agent_id"[[:space:]]*:[[:space:]]*"([A-Za-z0-9._-]{1,128})"` kept in variables (`[[ $s =~ $re ]]`, as at 4067). Per agent: Claude Code and Codex take `session_id`, `agent_id` and `tool_name`; Cursor takes `conversation_id`, which it sends first, as its `session_id` comes after the content ([RO] cursor-logs.txt:61); Gemini CLI takes `session_id`, its first key. The fallbacks `CLAUDE_CODE_SESSION_ID` and `GEMINI_SESSION_ID` are used only when stdin has no id. A Claude Code `turn-end` also looks for `"background_tasks"[[:space:]]*:[[:space:]]*\[[[:space:]]*\{` in the whole payload: the key comes after `last_assistant_message` (hooks.md:2577), a `Stop` carries no tool input or output, and every quote inside its strings is escaped, so an unescaped match is that key. If 10.2 (t) shows that Cursor's subagents have their own ids, Cursor's `subagentStop` takes `child_conversation_id` instead of `conversation_id`, one more entry in Cursor's table (5.7). Section 10 checks the key order of each agent. | The variable first: Claude Code's "is updated on `/clear`" (env-vars.md:371), so a `SessionEnd` might name the new session, while stdin carries the retiring one (ClaudeCodeIntegration.swift:93-96). A pattern anchored at the payload's start that allows no `{` before the key: `effort`, an object, is a common field of exactly the tool events that need `agent_id` (hooks.md:736). The first match anywhere: a main-thread event would be filed under an `agent_id` from a tool's output. Cursor's `session_id`: it comes after the prompt. |
| W3 | How hooks talk to the watcher | One append-only file, `agent-events`, mode 600, in the user's runtime folder. Each line is `VERB KEY EPOCH AGENT_PID BG RC`, in ASCII, with the agent in `KEY`. The protocol: (1) every hook appends first, with one `printf >>`, which for a line this short is a single `write` with `O_APPEND`, and checks the watcher after; (2) the watcher reads new lines through a descriptor it keeps open (`exec 4<`), with `LC_ALL=C` and builtins; a line not yet ended by a newline is consumed by `read` (probe), so the watcher keeps the piece and puts it in front of the next one; (3) on every pass it saves the number of complete lines it has read in `agent-offset`, and a new watcher skips that many lines and drops events older than the idle limit by their time (bash 3.2 cannot report a byte offset); (4) it exits only under `agent-lock/`: it removes `agent-watch`, reads to the end once more, and if a line arrived it writes `agent-watch` again and goes on; otherwise it saves the line count it has read, releases the lock and exits, leaving the file as it is, so that a line a hook appends after that last read is read by the next watcher, which skips only the saved count; (5) past 64 KB, under `agent-lock/`, it rotates with no moment at which the file is missing: it creates `agent-events.new` (mode 600), hard-links `agent-events` to `agent-events.1`, renames `agent-events.new` over `agent-events` (`mv -f`, atomic), waits one pass for a hook that opened the old file just before, reads `.1` to its end through descriptor 4, which still holds the old file, deletes `.1`, and opens descriptor 4 on the new file; `agent-offset` names the file its count belongs to, so a watcher killed during a rotation resumes in `.1` first. (6) When `main` starts a watcher, it appends the starting event again, whether the fast path wrote it or not: a duplicate changes nothing, and a starting event lost in a race still reaches the new watcher. Lines with an unknown verb, agent or key, or bad numbers are skipped, so a newer `awake`'s hooks cannot confuse an older watcher. | One file per holder, with modification times: bash 3.2 has no builtin for a file's time, and `-nt` compares whole seconds. A socket or FIFO to a watcher: a hook would block or fail while no watcher reads. Appending only after seeing a live watcher: a watcher that exits just then never reads the event. One file per agent: one watcher reads them all anyway. Emptying the file at exit, and rotating through `mv` and a new empty file, as the previous revision did: hooks append without `agent-lock/`, so a line written after the last read, or into a file created or truncated mid-rotation, was lost, and a lost `turn-start` left the new watcher with no holder. |
| W4 | The watcher | An internal mode, `awake --agent-watch`, started with `start_detached --agent-watch >/dev/null` (3567-3573) through `/usr/bin/env -i` and a short list of variables (5.8), so that it never carries one hook's agent environment for its whole life: its own process group, under `nohup`, so a hook's end, or an agent killing an async hook at teardown (hooks.md:3732-3735; codex-rs/hooks/src/engine/command_runner.rs:188-196), does not end it, and the PID that `start_detached` prints does not reach any agent's context. It runs `cd /` first, so it never holds a project folder. `agent-lock/` lets only one starter at a time decide; it has the main lock's scheme, with the holder's PID and start time in `agent-lock/pid` and a takeover of a stale lock, through `main_lock_is_abandoned` and `take_over_stale_main_lock` with the lock folder as a parameter (1377-1413). A starter waits up to about 1 s for it. The watcher records `pid=`, `started=`, `version=` and `beat=` in `agent-watch` and rewrites it on every pass; a watcher of another version is replaced while the lid is open (5.8). A pass every 2 s (0.5 s in the dry run). | The caller's environment, as `start_detached` passes it today: one hook's agent variables and `PATH` for the watcher's whole life (5.8). A LaunchAgent that always runs, like Adrafinil's: install and uninstall steps, a process all the time, and no dry-run test. The hook itself waiting for the work: a hook has to end within milliseconds. A lock without a holder record: a hook killed at its timeout would leave it for good. |
| W5 | How a session follows the watcher | The watcher runs `awake --agent-session -w $$ …` as a child (5.3), the path that `awake -w` uses for any process. Nothing new in the helper or the runner. | A new helper command for automatic sessions: protocol 10, a password prompt for every user at the update (4160-4172). |
| W6 | How a session ends | `agent_end_session` runs in a subshell: it takes the main lock (`acquire_main_lock` waits up to 10 s, and exits the subshell on failure, so the watcher simply tries again on its next pass, 1416-1463); it counts the session as its own only when the running record (the helper's session file, or the state file for lid-open) has `watch_pid` equal to the watcher's `$$`, `watch_started` equal to its start time, and the user's `uid`; and it passes that record's token to `request_helper_session_stop command-finished TOKEN`, a new optional argument that makes it return 1 without writing anything when the current token differs. For lid-open it makes the same check before writing `command-finished` with the token and calling `request_active_session_stop`. The reason is `process_exited`, so a closed Mac sleeps (awake-helper:850-855). `run_bound_command` (4505-4508) can pass its token too, which closes the same small window for `awake --`. | Ending without the lock: a stop and start by the user just before the request would end the user's new session as `process_exited` and sleep a closed Mac, as the helper never reads the token in `command-finished` (awake-helper:39-46, 1353-1356), against the principle. Reading the token after the start: it can adopt a session the user just started. A stop request: `stopped` never sleeps a closed Mac (awake-helper:847-849). A new reason, such as `agent_idle`: the lid-open stop waiter accepts only the known reasons (3811), the CLI's and the app's texts need it, and lid-closed sessions need a helper change. |
| W7 | Timings | End grace 60 s, idle limit 15 min, waiting 10 min, background 1 h, quiet limit 2 h, the session's limit `MAX_DURATION_SECONDS` (365 days, 121-122), the 2-second rule, `idle`'s 50 s, the input windows of W26 (5 s, and 60 s for Codex, with input at least 2 s after the stop), a stuck watcher's 90 s and the 5 s between its two looks, retry 60 s, guardrail and settings checks 30 s, the beat's 10 s, rotation at 64 KB. As constants after `WATCH_IDENTITY_CHECK_SECONDS` (165). In the dry run: grace 2 s, idle 5 s, waiting 3 s, background 5 s, quiet 6 s, stuck 5 s with 1 s between the looks, settings checks 1 s, the session's limit from `AWAKE_TEST_AGENT_LIMIT_SECONDS`, 1 s for the 2-second rule, 2 s for `idle`, retry 1 s, checks 1 s, beat 3 s, rotation from `AWAKE_TEST_AGENT_ROTATE_BYTES`; the `AWAKE_TEST_*` values are read only in the dry run. Without the last look (B-7 (b)), for Claude Code: waiting 20 min and grace 3 min. The same values for every agent (B-13). (B-1, B-2, B-12.) | Settings in the app: more UI, for values few users would change. The first version's 12 h: the owner's answer (B-2). |
| W8 | Waiting | 5.6. Claude Code: `PermissionRequest` and `PreToolUse` with matcher `AskUserQuestion\|ExitPlanMode`. Codex: `PreToolUse` with matcher `request_user_input`; its `PermissionRequest` is a `tool-start`, as it also fires before the automatic reviewer (B-1). Gemini CLI: `Notification`. Cursor: none (2.4). The way back to working is `tool-start` and `working` under the 2-second rule, or, for Claude Code, the last look. A `tool-start` for the waiting tools themselves is dropped at the hook (by `tool_name`), so it cannot undo the `waiting` from the same tool. | Reading `~/.claude/sessions/<pid>.json`: undocumented (claude-directory.md:1562). Codex's `PermissionRequest` as `waiting`, as the previous revision had: with the automatic reviewer it marks a holder waiting although nobody is asked, the status says Codex waits for you, and an auto-approved command longer than 10 minutes is cut off with the lid closed. |
| W9 | Background work | B-8 (a), Claude Code only: `BG=1` puts the holder in `background`, with `bg_since` from the first such `Stop`; only `BG=0` resets it. | Ignoring it: the Mac sleeps under a background build (adrafinil issue #7). Renewal at every `Stop`: a dev server holds a closed Mac for an hour after every turn. No limit: a forgotten `tail -f` holds it for good. |
| W10 | Pause | 5.9, 5.10. Two files, as two different processes write them. **The stop pause**, `agent-pause` (`since=<epoch>`), lives in Awake's own folder `~/Library/Application Support/Awake/` (the dry-run runtime folder in the dry run), mode 600, so that it survives a restart and macOS's 3-day cleanup of `/tmp` (166-168), as Adrafinil's "Let it sleep" does (Models/PersistedDaemonState.swift:3-6). Main's stop paths write it under the main lock before the stop request (5.9); `main`'s hook path removes it under `agent-lock/` when W26's test passes; `--ai-hooks resume` and `--ai-hooks off` remove it. Nothing else does, a start by hand included. The fast path tests it with builtins (`-f`, `! -L`, `-O`). **The guardrail pause**, `agent-guard` (`reason=low_battery\|overheated\|unplugged`, `since=`), lives in the runtime folder; only the watcher writes and removes it, when the cause has gone, and it needs to outlive no restart, as a new start checks the guardrails anyway. An `--agent-session` start refuses under the main lock while either file exists, so the watcher can never start a session past a pause written a moment before. Hooks append as usual during a pause; the watcher starts nothing while one stands. During a stop pause a `turn-start` without a subagent id also goes on to `main`, which lifts the pause under W26's test. | Dropping events during the pause, as the first version did: `Resume now` would find no holders, and a prompt that lifts the pause would start a session only for its own agent. Clearing the holders and doing nothing more: the next tool call would start a session again. The watcher inferring the stop from the session's end record, as the previous revision did: a pass that saw no session and a working holder could start a new session before it noticed the stop, a session started and stopped within one pass was never seen, and a later lid-open stop removes the status file that holds the record (6241). One file with both kinds: the stop's writer and the watcher would overwrite each other. A start by hand that clears the pause: an agent's own `awake -- npm test` would undo the user's stop, and a session started on battery after an `unplugged` end would let the next automatic session run on battery. The stop pause in the runtime folder: it would end at a restart or after 3 days without a watcher, and the next scheduled turn would start sessions without a typed prompt. |
| W11 | Time limit | `--duration-seconds $MAX_DURATION_SECONDS` with `-w`: 365 days, the limit of any timed session, enforced by the helper as for any session (awake-helper:57-59). What bounds the session is B-12 (a): the holder rules with the quiet limit, the PID tie, the replacement of a stuck watcher, the agent's process, the guardrails and the user. | 12 h: the owner wants long automatic runs to go on (B-2). No end time at all (`-w` alone, `end_mode` `none`): the same in practice, but not "the same as in other use", and an older app would read it as "until awake exits". A rolling 2 h limit enforced by root: B-12 (b). |
| W12 | Never a password prompt | A new transport `none`. `admin_transport` (6916-6926) returns it for `--agent-session`. `run_as_admin` (4060-4131) then fails at once with `ADMIN_LAST_RESULT=no_password`, for a start and for a helper install alike, as `run_helper` reaches the install through `run_as_admin` (4160-4172). The watcher picks lid-closed only when `helper_runs_without_password` succeeds. In the dry run that function never runs `sudo`: it reads `passwordless=on\|off` from a mock file `mock-passwordless` in the dry-run runtime folder, off by default, like `mock-battery` and `mock-thermal` (225-226). `passwordless_is_configured` stays false in the dry run. | Relying on the check alone: a sudoers rule removed between the check and the start would show the dialog. The real `sudo -n` in the dry run: it succeeds on GitHub's macOS runners, which have passwordless `sudo`, and fails on a developer's Mac. |
| W13 | A hook never fails an agent | Every handler is one shell-form command, `'<awake path>' --agent-hook AGENT VERB >/dev/null 2>&1; exit 0` (K2). So even a syntax error in a later `bin/awake`, a crash, or a missing `awake` exits 0 and prints nothing, and exit 2, which blocks and erases the prompt on Claude Code's and Codex's `UserPromptSubmit` (hooks.md:776-850; codex-rs/hooks/src/events/user_prompt_submit.rs:157-250), cannot happen. Gemini CLI would show any stderr text as a message (hookRunner.ts:455-478), and Claude Code and Codex would add stdout to the model's context, which the redirections rule out. `awake` itself also exits 0 on every path of `--agent-hook` and prints nothing. Diagnostics go to the debug log only (`--debug` or `AWAKE_DEBUG=true`). | Exec form with `args`: Claude Code before 2.1.139 does not know `args` (cc-changelog.md:4758), and the same file is read by every Claude Code on the Mac and by Cursor (H-5). Running `awake` directly: an `awake` that is gone after an uninstall would put a hook error in every transcript. |
| W14 | Speed | A builtins-only fast path right after `set -euo pipefail` (6), run only when the script is executed, not sourced: `if [[ "${1:-}" == --agent-hook && "${BASH_SOURCE[0]}" == "$0" ]]; then agent_hook_fast_path "$@"; set -euo pipefail; fi`. Its first statement sets `LC_ALL=C`, so that bash 3.2's pattern matching and `=~` on a payload of several MB run byte by byte, fast, and never fail on bytes that are not valid UTF-8 in the agent's locale; `bin/awake` sets `LC_ALL` today only for single commands (1653, 1709, 2371). The function's `set +e +u` and `LC_ALL` change the whole shell (bash 3.2 has no `local -`), so both are restored before `main`. Bash runs a script one command at a time, so an `exit` there means the other 7,800 lines are never parsed (probe: 3.0 ms against 24.7 ms on Linux). Only a starting verb that finds no live watcher, or a `turn-start` during a stop pause, goes on to `main`, with the parsed fields in variables, as its stdin has been read. | A separate small script: no faster, as the probe's fast path cost what a bare `bash` costs, and a new shipped file for the installer, Homebrew and `release.sh`. The fast path without the `BASH_SOURCE` test: the self-test sources `bin/awake` with arguments (tests/cli/awake-self-test:418, 941). |
| W15 | Status | 5.11. The watcher writes `agent-state` (phase, agent names, holders, wait end, note, session token) when they change. `--status` reads it with builtins. A session is automatic when the session file says `agent=auto`, which `write_session_file` (2785-2799) adds for `--agent-session`. `ai_hooks` comes from one `while read` pass over `ai-hooks.conf` in Awake's own folder, which lists each agent's recorded files (K1), and one over each of those files, counting the lines that hold Awake's quoted path and `--agent-hook <agent> <verb> >/dev/null 2>&1; exit 0`: all of the agent's handlers (13, 10, 7 or 6) means `on`, some `partial`, none `off`. For Codex, `untrusted` when `config.toml` lacks a `[hooks.state."<hooks.json path>:<event label>:<group>:<handler>"]` line for one of Awake's handlers (an existence check, not the hash, H-3), and `review` while the `trusted_hash` values under those keys are still the ones `ai-hooks.conf` saved when a `refresh` changed a handler's text (K13). | Telling it by `watch_pid` alone: a reused PID. Parsing the files with `osascript` on every status read: the app polls every 10 s. The recorded folders in the app's defaults domain, as the previous revision had them: reading them needs a `defaults` process on every poll. |
| W16 | Notifications | 5.12. | |
| W17 | Helper | Unchanged, protocol 9. The root helper reads no new file. | |
| W18 | Dry run | Everything runs in the dry run with the existing mocks: lid (with `clamshell_causes_sleep`, which the helper's dry run already reads, awake-helper:610-615; tests/cli/awake-self-test:4991), battery, thermal, `sleepnow` (tests/cli/awake-self-test:4330-4424), plus `mock-passwordless` (W12), `mock-claude-agents` for the last look (W21), `mock-input-idle` for W26, and the test's settings domain for W28. The mocks hold the raw output, and the shipped parsers read it: `mock-claude-agents` holds JSON in the documented shape (agent-view.md:764-777), with `cwd` and `name` values that contain braces and quotes, or the word `fail`; `mock-input-idle` holds a line as `ioreg -c IOHIDSystem` prints it, with `HIDIdleTime` in nanoseconds. On macOS (CI) the shipped JXA parser reads the JSON mock; the Linux emulation has no JXA (as for 12o) and uses a dry-run stand-in that reads only the `pid` and `status` pairs of the test's JSON. The agent's process is the hook's parent, or `AWAKE_TEST_AGENT_PID`. Five seams hold the watcher or `main` at a race point or stop it: `AWAKE_TEST_AGENT_EXIT_PAUSE` between the watcher's last read and saving its count (W3), `AWAKE_TEST_AGENT_ROTATE_PAUSE` between the hard link and the rename of a rotation (W3), `AWAKE_TEST_AGENT_END_PAUSE` between deciding to end and asking for the end (W6), `AWAKE_TEST_AGENT_START_PAUSE` between the watcher's "no session runs" read and its start (W10), and `AWAKE_TEST_AGENT_HANG`, which stops its beat (W27). All are read only in the dry run (as `AWAKE_TEST_SETTINGS_DOMAIN`, 1166-1175). | Mocks that replace a parser as well as a program (`<pid> busy`, a number of seconds), as the previous revision had: the JSON and `HIDIdleTime` parsers would first run in Mac QA. |
| W19 | A start by hand during an automatic session | The handover of 5.9. | Adding time to the automatic session or refusing `-w` and `--`: the watcher ends the session a minute after the work stops, and the user's request is lost. |
| W20 | The lid | B-11 (a): no automatic session starts while `lid_closed_causes_sleep` is true: the lid is closed and closing it sleeps the Mac, `AppleClamshellState` and `AppleClamshellCausesSleep` both `Yes`. A new function in `bin/awake`, a copy of the helper's (awake-helper:604-619) with its dry-run keys `lid` and `clamshell_causes_sleep`. It decides the starts, the lifting of a stop pause (W26), the restart after a guardrail pause, the settings change (W28) and the replacement of an older watcher (5.8). | A pause only after a stop or a lid-closed end: a wakeup in a bag after a normal end can still start one. `lid_is_closed` (2385-2391), which tests only `AppleClamshellState`: a docked MacBook in closed-display mode would never get an automatic session, and a typed prompt there would never lift a stop pause. |
| W21 | The last look | B-7 (a), for Claude Code main-conversation holders (`claude:s:`) only, as subagents share their session's process (hooks.md:269). `claude agents --json`, run under `run_with_timeout` 5 s (2341). `claude` is the holder's own process executable, from `ps -o comm=` (10.2 checks that it gives the path): the extension's bundled copy, which is not on any `PATH` (vs-code.md:617), or the native install's binary, whose file name may be a version number (Adrafinil's commit 3d7f687). When that process is not a `claude` binary (for example `node`), the holder gets B-7 (b)'s timings. It runs with the watcher's minimal environment (5.8), so no `CLAUDE_CODE_CHILD_SESSION` or one session's id reaches it; a holder whose events carry `CFG=1` gets no last look, as a supervisor of another config folder lists other sessions (agent-view.md:817). Its output is parsed with `osascript -l JavaScript`, as K5 parses settings, and never evaluated. A successful call that does not list a live holder's process marks that holder `unlisted`, with B-7 (b)'s timings from then on; a missing session is not a failed call. The watcher stops using the last look for the rest of its life after a call fails, and falls back to B-7 (b)'s timings. | Parsing the JSON with patterns: a `cwd` or `name` can hold any text, braces included. The `claude` on an inherited `PATH`: the watcher's environment is that of whichever hook started it, an editor's `PATH` in the extension, and the preflight's terminal run would not show the difference. Reviving `a:` holders by their session's `busy`: a subagent that ended would go back to working whenever its parent works, up to the quiet limit. A per-watcher fallback only after a failed call: a working call that lacks the panel's sessions would give them the 60 s grace with no last look. |
| W22 | Ordering | The 2-second rule and tombstones (5.6), with `tool-start` and `working` told apart. | Whole-second order alone: an async heartbeat that starts a second late reopens an ended holder. A tombstone that no event can lift until the next prompt: a Stop hook or `/goal` that continues the turn would lose its hold. |
| W23 | Guardrail reads | Only the watcher, every 30 s during a guardrail pause (5.10). | In hooks: `osascript` with a 10 s timeout in front of every prompt, and a hook killed at its own timeout while it holds `agent-lock/`. |
| W24 | Adapters in the code | One small table per agent inside `bin/awake`: its name, its id keys, its fallback variable, the tools whose `tool-start` it drops, and whether it has a last look; and one block per agent in `--ai-hooks` (K.3). The watcher has no agent-specific code but the last look. | A file per adapter: new shipped files, and the fast path must not source anything (W14). |
| W25 | Claude Code's handlers in Cursor and in VS Code's agent | The Claude Code adapter writes nothing when the payload before its first content key holds `"conversation_id"` (Cursor, H-5 (a)) or `"timestamp"` (VS Code's Local agent with `chat.useClaudeHooks` on, which runs `~/.claude/settings.json` hooks with its own common fields, `timestamp` among them, and ignores their matchers; vscode-docs docs/agent-customization/hooks.md:135-137, 187; docs/agents/reference/hooks-reference.md:67-76). Claude Code's payloads carry neither key (hooks.md:726-744). Section 10 records the key order of Cursor's payloads, and of VS Code's if VS Code with Copilot is installed. | Telling them apart by the environment: Cursor sets `CLAUDE_PROJECT_DIR` too ([CD] hooks.md:1464), and whether the extension's `claude` inherits Cursor's `CURSOR_VERSION` was not found; section 10 records both. No stand-down for VS Code: every Copilot turn would count as Claude's, and as matchers are ignored every tool call would also mark the holder `waiting` and every session start would run the `clear` handler. |
| W26 | Lifting a stop pause | A `turn-start` of a main conversation lifts it in `main`, under `agent-lock/`, when all of these hold (B-5 (a)): `lid_closed_causes_sleep` is false (W20); the last input came at least 2 s after the pause's `since` (now less the idle time is at least `since` + 2), so the click that made the stop does not count; the idle time is at most the agent's window, 5 s for Claude Code, Cursor and Gemini CLI, whose prompt hooks fire at submit (hooks.md:1331; [CD] hooks.md:1243-1245; packages/core/src/core/client.ts:924-946), and 60 s for Codex, whose `UserPromptSubmit` comes after pre-turn compaction and MCP startup (codex-rs/core/src/session/turn.rs:184-379) but only for user input (codex-rs/core/src/hook_runtime.rs:677-714); and the idle time was read. It is read with one `ioreg -c IOHIDSystem` under `run_with_timeout`, parsed with builtins; if the call fails or times out, the pause stays. In the dry run the same parser reads `mock-input-idle`. Section 10 measures the delay from Enter to the hook for each agent and may change the windows. | Any `turn-start` with the lid open: a `/loop` iteration or a background report would start again the session the user stopped (B-5 (e)). One window of 60 s for every agent, without the after-the-stop test, as the previous revision had: the click on the icon is itself input, so a background turn in the next minute would lift the pause, and "stop, close the lid and leave" could restart a session just before the lid closes. A 3 s window for Claude Code: tighter, but the hook's start in the extension has not been timed; 10.2 may narrow 5 s to it. A test inside the fast path: an `ioreg` in front of every prompt, not only during a pause. |
| W27 | A stuck watcher and the quiet limit | B-12 (a). Every program the watcher runs goes through `run_with_timeout`. A hook's `main` that finds `agent-watch` naming a live, same process whose beat is more than 90 s old (longer than the 60 s of its longest call) records that beat in `agent-stale`; a hook at least 5 s later that finds the same beat from the same process sends it TERM, then KILL after 2 s, and starts a new watcher (5.8). The last look keeps no holder whose last own event is more than 2 hours old. | A watchdog process next to the watcher: more machinery for the same case, as hooks come while agents work. B-12 (b)'s rolling limit: a helper run per renewal. Killing at the first look: a watcher frozen by the Mac's sleep wakes with an old beat, and the first hook after the wake would kill it and churn the session. A hook that waits 3 s to look again: it would hold up a prompt. `kern.waketime`: one more process and an output format to parse, for what a second look settles. |
| W28 | A changed setting during an automatic session | The watcher reads `agentBackend` and the four guardrail settings (`minBatteryPercent`, `lowBatteryGuardEnabled`, `thermalGuardDisabled`, `unplugGuardEnabled`) every 30 s with one `defaults read` of the app's domain under `run_with_timeout`, parsed with builtins, and compares them with what its running session started with. On a change: with `lid_closed_causes_sleep` false, it ends its session (W6) and starts one with the new settings in the same pass, with no pause; with it true, a switch to lid-open ends the session as `process_exited`, so the closed Mac sleeps as the user chose, and changed guardrails wait for the lid to open (5.9). The app's Settings write the domain as today; the change shows within 30 s. | Applying the change only from the next automatic session, as the previous revision did: with continuous work and a 365-day limit that may be days away, so a user who turns on `Stop when unplugged` before leaving would keep the old behaviour, against the principle. A restart with the lid closed: a start with the lid closed breaks B-11, and a stop that succeeds before a start that fails would leave a closed Mac awake with no session (awake-helper:621-624). |

### W.3 Code changes

Line numbers are at `1bbb06f` (the same as `a9cd6d1`).

1. **The fast path, after 6** (W14). It uses builtins, plus `/bin/date +%s`, one `/bin/cat` for stdin and one `/bin/ps` for the agent's process. Every path ends in `exit 0`, except a starting verb that hands over to `main`. In order:
   1. Set `LC_ALL=C`, keeping the old value to restore before `main` (W14). Check the agent (`claude`, `codex`, `cursor` or `gemini`) and the verb against fixed lists; anything else exits 0.
   2. Pick the runtime folder from `AWAKE_DRY_RUN` and bash's `UID`. Go on only if the folder passes `-d`, `! -L` and `-O`, which is the kernel's owner check, so a forged `UID` in the environment only makes the hook do nothing. `main` makes the folder with mode 700 (`ensure_state_dir`, 985). If it is missing, a starting verb goes on to `main` and the others exit.
   3. Read stdin with one `/bin/cat` unless it is a terminal (`-t 0`). Every agent passes the JSON on stdin (hooks.md:406; [CD] hooks.md:9; codex-rs/hooks/src/engine/command_runner.rs:259-268; packages/core/src/hooks/hookRunner.ts:401-414). Codex and Gemini CLI then close it (the same lines); that Claude Code and Cursor close it is checked in section 10, where the probe's own `cat` must return. For sync handlers the handler's `timeout` (K2) bounds a writer that does not close it; for Claude Code's async handlers no timeout is enforced (hooks.md:426, 3730), so the only bound is that it closes stdin.
   4. Read the agent's process: the parent of the handler's shell (`$PPID`), with one `/bin/ps -o ppid= -p $PPID` (5.8).
   5. Cut the payload at the first content key and take the agent's ids and `tool_name` (W2). For `claude`: stand down on a Cursor or VS Code payload (W25); for `turn-end`, set `BG` from `background_tasks`; set `RC=1` when `CLAUDE_CODE_BRIDGE_SESSION_ID` is non-empty, and `CFG=1` when `CLAUDE_CONFIG_DIR` is. Drop a `tool-start` for the agent's waiting tools (W8).
   6. Read the time with `/bin/date +%s`.
   7. Append the event to `agent-events`, if that file passes `-f`, `! -L` and `-O`. If it does not, a starting verb hands over to `main`, and the others exit.
   8. If the stop pause `agent-pause` exists in Awake's own folder (`$HOME/Library/Application Support/Awake/`, checked with `-f`, `! -L` and `-O`) and the event is a `turn-start` without a subagent id, hand over to `main` (5.9).
   9. Read `agent-watch`. If its PID answers `kill -0` and its `beat` is at most 10 s older than step 6's time, exit 0.
   10. Otherwise a starting verb hands over to `main`, and the others exit 0: their event is in the file, and the next watcher reads it.
2. **The internal modes, in main's early `case` (7007-7071):**
   - `--agent-hook AGENT VERB`, reached only from the fast path. It runs `cd /`, takes `agent-lock/` (W4), and then: for a `turn-start` under the stop pause, removes the pause when W26's test passes; appends the event if the fast path could not; checks the watcher with its start time (`process_is_same`), its beat and its version, records a stale beat in `agent-stale` and replaces the watcher at the second look (W27), and replaces one of another version while the lid is open (5.8); and, if none runs, appends the starting event again (W3 (6)) and starts one through `/usr/bin/env -i` with `start_detached --agent-watch >/dev/null` (W4). It makes no guardrail read. The whole handler runs in a subshell with its output sent to `/dev/null` and its status ignored, then `exit 0` (W13).
   - `--agent-watch`. `cd /`, `LC_ALL=C`; it records itself in `agent-watch` under `agent-lock/`, or exits if another watcher is alive. Then each pass, in this order: read the events (W3); update the holders (5.6); check the processes; notice an end it did not cause and read its record (`completion_reason_for_token`, 4431-4444), before anything can start, and act on it (a handover: wait; a guardrail: write `agent-guard`; the limit: nothing; a stop: the stop already wrote `agent-pause`); every 30 s read the settings (W28) and, during a guardrail pause, the guardrails (5.10); take the last look when main-conversation holders of Claude Code run out of time (W21); then start (5.3) or end (5.5, W6) the session; write `agent-state` (with `startable=` and `format=`); rewrite `agent-watch`; save `agent-offset`; rotate the log; touch files every 6 h; and exit as W3 says. Every external program runs under `run_with_timeout` (W27).
   - Holders are kept in indexed arrays, as bash 3.2 has no associative ones.
   - Like `--caffeinate-start`, neither mode runs `require_macos` (7006-7007).
3. **New functions, after `run_bound_command` (after 4545):**
   - `agent_parse_payload`, with the adapter tables (W24);
   - `agent_append_event`;
   - `agent_lock_acquire` and `agent_lock_release`;
   - `agent_watch_alive` (PID, start time and beat) and `agent_watch_replace` (W27);
   - `agent_resolve_process` (5.8);
   - `agent_read_events` (W3, with the leftover piece, the count and the rotation);
   - `agent_update_holders` (5.6, with tombstones, the 2-second rule and the quiet limit);
   - `agent_session_needed` and `agent_other_session_running` (builtins over the two session records);
   - `agent_last_look` (W21);
   - `agent_input_idle_seconds` (W26), with its builtin parser of `ioreg`'s line;
   - `lid_closed_causes_sleep` (W20), next to `lid_is_closed` (2385-2391);
   - `agent_settings_check` (W28);
   - `agent_start_session`, which chooses the backend (W12) and reads the guardrails (B-3);
   - `agent_end_session` (W6);
   - `agent_pause_set` (for main's stop paths), `agent_pause_check`, `agent_pause_lift`, `agent_guard_set`, `agent_guard_lift`, `agent_write_state`, `agent_drop_agent` (for `--ai-hooks off --agent X`) and `agent_cleanup` (for `--ai-hooks off` and the self-test).
   The guardrail reads use `read_setting` (1177-1182) for `minBatteryPercent`, `lowBatteryGuardEnabled`, `thermalGuardDisabled` and `unplugGuardEnabled`, with the app's rules (InstallSupport.swift:130-166). A comment asks to keep them in sync.
4. **Changed functions:**
   - `request_helper_session_stop` (4320-4376): an optional second argument, the expected token (W6).
   - `main_lock_is_abandoned` already takes the folder as `$1` (1377-1385); `take_over_stale_main_lock` (1392-1413) gets the lock folder, its pid file and its takeover folder as arguments, with today's values as defaults.
   - `helper_runs_without_password` (4052-4055): the dry-run mock (W12).
   - `start_detached` (3567-3573), or a variant of it, for the minimal environment of the watcher (5.8).
   - Main's stop paths (7400-7470): before the stop request, `agent_pause_set` when a live watcher is named and the session is automatic or `agent-state` says `startable=1` (5.9).
5. **`--agent-session`, internal, after `--if-off` (469-471).** It sets `AGENT_SESSION=true` and `START_ONLY=true`. It needs `-w`, and is refused with `--` or with maintenance actions.
   - `admin_transport` (6916-6926) returns `none` when it is set.
   - `run_as_admin` gets a `none)` case: `ADMIN_LAST_RESULT=no_password; return 1`.
   - main's terminal check (7596-7604) does not apply, as the transport is not `terminal`.
   - After the main lock is taken, the start refuses with exit 1 while `agent-pause` or `agent-guard` exists (W10).
6. **The handover in main** (5.9, W19), after the state is read (7196-7216): the `agent_running` test, then, for a start that is not `--agent-session`, the add-time branch (7268-7397) and the refusal at 7262-7266 are skipped, and the automatic session is stopped right before the new session starts, after any picker, with `agent-handover` written first, and the CLI says that it replaced the automatic session (B-14). `--if-off` (7234-7243) counts an automatic session as off and takes the same path. A start by hand removes no pause.
7. **`write_session_file` (2785-2799)** writes `agent=auto` for `--agent-session`.
8. **The status.**
   - `running_status_text` (2984-3011) reads `agent` from the session record and `agent-state`.
   - `build_status_text` (3013-3066) gets the sentences of 5.11, with the agents' display names, before the `watch_label` branches at 3042-3045, with the lid-open endings at 3058-3061.
   - `print_current_status` (3335-3423) adds the pause line of 5.11 to `--status`.
   - `print_status_json` (3190-3333) gets `agent_session`, `agent_phase`, `agent_names`, `agent_holders`, `agent_wait_ends_at`, `agent_note`, `agent_paused`, `ai_hooks` (W15) and `last_session_token` before `"error"`.
   - `watched_process_label` (4398-4418) names the watcher `awake`, so `watch_command` reads `awake`. Today it would read `bash` (holders-probe).
9. **`show_usage` (348-427).** One option, `--ai-hooks`, under the maintenance options (K.7). The internal modes and `--agent-session` are not listed, as with `--if-off` (467-468).

Not changed:
- `bin/awake-helper`;
- `HELPER_PROTOCOL_VERSION` (172) and `MAX_DURATION_SECONDS` (121-122);
- the stop waiter's list of reasons (3811);
- `announce_completion` (5449-5496).

### W.4 Security and compatibility

- **No new root power.** The root helper's commands, arguments and checks do not change:
  - `start` with a `WATCH_PID` that it checks is the user's own (awake-helper:934-944);
  - its own battery and thermal checks;
  - the existence-only tests of `stop-request` and `command-finished` (awake-helper header, 39-46).
  The helper never reads, stats or follows `agent-events`, `agent-watch`, `agent-state`, `agent-pause`, `agent-guard`, `agent-stale`, `agent-offset`, `agent-handover` or `ai-hooks.conf`. Only the user's own processes read them.
- **User-writable files.** All new files are in the user's runtime folder (mode 700, owner checked, symlinks refused, 806-927) or in Awake's own folder in the user's Library, which the user owns; they are created mode 600 (`create_private_runtime_file`, 4547-4552), and the fast path trusts the stop pause only after `-f`, `! -L` and `-O`. A program running as the user that deletes the stop pause lifts it, as it could run `awake --ai-hooks resume`. Any program running as the user can append events, and by appending them without end it could keep the Mac awake with the lid closed in password-free mode, up to the 365 days. It can do the same today with `awake --indefinite`, and README.md:103 says so. Without password-free mode such sessions are lid-open only (W12). With the 12-hour cap gone this is no larger than what password-free mode already allows.
- **Untrusted input.** Hook payloads hold prompts, tool output and thinking text. The hook keeps only two ids, a tool name and one flag, all checked against fixed patterns, and only from the part of the payload before any content (W2), except the one `background_tasks` key of a Claude Code `Stop`. It never evaluates them, writes no payload text anywhere, and logs only verbs, keys and numbers. The watcher checks every field of every line again (W3). The last look's JSON is parsed as data by JavaScript's `JSON.parse` (W21).
- **Never a prompt** (W12, W13).
- **Older versions.**
  - A 2.4.0 `awake` given `--agent-hook` exits 1 with "Unknown option" (641). Through the handler's redirections and `; exit 0` (W13), the agent sees exit 0 and no output. This only happens if the hooks were written by 2.5.0 and `awake` was then replaced by an older copy.
  - A 2.4.0 app with a 2.5.0 CLI ignores the new JSON fields. For it, an automatic session reads as a session tied to the watcher, with its 365-day limit: "Awake is on until awake (PID n) exits, with at most 365 days left" (3042-3043). It shows `Add 1 hour`, as the session has a `deadline_at` (StatusBarController.swift:790-801), and that runs a start with a duration (186-215), which the 2.5.0 CLI turns into the handover: the user's own hour replaces the automatic session, while the old app reports added time. Its next poll shows the new end.
  - The helper protocol stays 9, so every mix of CLI and helper works as today.
- **Agent versions.**
  - Claude Code: shell-form command hooks work in every version with hooks. `background_tasks` needs 2.1.145 (cc-changelog.md:4540), Remote Control's variable 2.1.199 (env-vars.md:220), `permission_prompt` in the extension 2.1.233 (cc-changelog.md:2879). The extension's version is its bundled CLI's (vs-code.md:35).
  - Codex: present by 0.125.0 for hooks, 0.130.0 for trust, 0.145.0 for `SessionEnd`, 0.150.0 for `Interrupt` (2.3; conservative minimums). The README names 0.150.0.
  - Cursor: the version that added `preToolUse`, `postToolUse`, `afterAgentThought` and `sessionEnd` was not found; captures exist for the editor 3.9.16 and the CLI 2026.10.01 (2.4). The README names the version the preflight sees.
  - Gemini CLI: hooks on by default from v0.26.0 (2.5).

### W.5 Tests

**`tests/cli/awake-self-test`, a new section 12n** after 12m (before 6383): "Verifying sessions while an AI agent works (dry-run hooks)". In the dry run, an agent is played by a stand-in process that runs the hooks as its children, through the same shell-form command as K2 (`/bin/sh -c "'AWAKE' --agent-hook AGENT VERB >/dev/null 2>&1; exit 0"`), then `exec sleep 300`. The test writes each agent's payload files, with the key orders of section 2 (and of section 10, once known), and sets `CLAUDE_CODE_SESSION_ID` or `GEMINI_SESSION_ID` only where a check needs it. That also tests how the hook finds the agent's process through the handler's `sh`. `AWAKE_TEST_AGENT_PID` stands in for an agent process with no shell parent, and the mocks of W18 for the lid, password-free mode, the last look and the input idle time. Checks:

| # | What it does | What it asserts |
|---|---|---|
| 1 | `--agent-hook claude turn-end` with no watcher | exits 0 at once, prints nothing on stdout or stderr, starts no watcher |
| 2 | `--agent-hook` with a bad key (`../x`), an unknown agent, a missing runtime folder, and a folder owned by someone else (as in 12i); in a sourced shell, the `-t 0` branch, using `/dev/tty` only when it opens; and `source bin/awake --agent-hook claude turn-start` | exit 0 and nothing written; sourcing runs no fast path |
| 3 | `turn-start`, lid open, `mock-passwordless` on | within 3 s a lid-closed session runs, tied to the watcher, `agent=auto`, with `deadline_at` 31536000 s after its start; `--status` reads `Awake is on while Claude works.`; `--status-json` has `agent_session:true`, `agent_phase:"working"`, `agent_names:["claude"]` |
| 4 | mock lid closed, `turn-end`, then wait (last look `idle`) | the session ends after the dry-run grace with `process_exited`; one mock `sleepnow`; the watcher exits; `agent-watch` is gone, and `agent-offset` holds the number of lines in `agent-events` |
| 5 | `turn-end`, then `turn-start` within the grace | the session runs on (same token) |
| 6 | two `s:` holders; end one | the session runs on; ending the other ends it |
| 7 | `agent-start` (with `agent_id`), then the main `turn-end` | the session runs on while the `a:` holder works; `agent-end` ends it after the grace |
| 8 | `turn-end` with `background_tasks:[{…}]` after a long `last_assistant_message`, then another 3 s later, under a 5 s background limit | the session ends 5 s after the first, plus the grace; a `turn-end` with `[]` in between resets `bg_since`; a `last_assistant_message` that contains the escaped text `\"background_tasks\":[{` does not count |
| 9 | `waiting`, then nothing; once with the last look `waiting`, once `busy`, once with a JSON mock that lists other PIDs only | `--status` reads `…waits for you…`; with `waiting` the session ends after the dry-run allowance; with `busy` it runs on, `agent_phase:"working"`; in the third case the holder is `unlisted` and gets B-7 (b)'s dry-run timings |
| 10 | `waiting`, then `working` 0 s later, then `tool-start` for `AskUserQuestion`, then `working` 1 s (the dry-run 2 s) later | the first two change nothing; the last puts the holder to working |
| 11 | `idle` for a working holder whose last event is older than the dry-run 50 s; `idle` during `background` | the first ends the holder; the second changes nothing, and the session runs until the background limit |
| 12 | `turn-end`, then `working` 1 s later; then `tool-start` 1 s later; then, after the holder was dropped, `tool-start` with the last look `busy`, and once with `idle`; then an `a:` holder that ended while its session reads `busy` | `working` never reopens it; `tool-start` within the grace does; after the drop, `busy` recreates it and `idle` does not; the `a:` holder is not revived |
| 13 | `turn-maybe`, then nothing; `turn-maybe` with no session running; `turn-maybe`, then `tool-start` | ends after the grace; starts no session; the holder works |
| 14 | `turn-end` with `CLAUDE_CODE_BRIDGE_SESSION_ID` set | `agent_phase:"remote"`; the session ends after the dry-run waiting allowance |
| 15 | kill the stand-in agent process (`kill -9`); and, for one key, events from two stand-in processes, then the first one killed | its holder is dropped within two passes and the session ends; in the second case the holder follows the newer process and stays |
| 16 | kill the watcher (`kill -9`); then write an `agent-watch` that names the test shell's own PID with an old beat; then leave `agent-lock/` with a dead PID | the helper ends the session within about 3 s with `process_exited` (as holders-probe); after each of the other two, a `turn-start` still starts a watcher |
| 17 | `AWAKE_TEST_AGENT_EXIT_PAUSE` holds the watcher between its final read and saving its count; a `turn-start` meanwhile | a session runs afterwards, and the event is read once |
| 18 | `AWAKE_TEST_AGENT_END_PAUSE` holds the watcher between its decision and its request; meanwhile `--stop`, then `--duration-seconds 60` | the user's session survives, with no mock `sleepnow` |
| 19 | `awake --stop` at time t during an automatic session; then `working` and `tool-start` of two agents; then `turn-start`s of `claude`: with the mock lid closed; with it open and the input mock at 1 s (that is, the stop's click); at 300 s; then, with input 4 s after the stop, at 1 s; a `codex` `turn-start` at 10 s with input after the stop; a `claude` one at 10 s; the input mock failing; and an agent-run `--duration-seconds 2` during the pause | reason `stopped`; `agent-pause` exists before the session has ended (written by the stop); nothing starts for the lid closed, the click, 300 s, the `claude` at 10 s, the failing mock or the agent-run session; the `claude` at 1 s with input after the stop, and the `codex` at 10 s, each remove the pause (in separate runs) and a session starts; `agent_holders` counts both agents' holders throughout |
| 20 | a stop pause; a `turn-start` with an `agent_id` (input mock after the stop, 1 s); then `awake --ai-hooks resume` | the first leaves the pause; `resume` removes it and a session starts while a holder works |
| 21 | mock battery at 4% on battery during an automatic session; mock AC with the lid closed; then with the lid open | `low_battery`; pause; `turn-start` starts nothing; on AC with the lid closed nothing starts; with it open the watcher removes the pause and starts a session without a new event, while a holder works |
| 22 | during an automatic session, each of `--duration-seconds 3600`, `--until @now+600`, `--indefinite`, `-w <stand-in PID>`, `-- true` (the last tied to a short `sleep`) and `--start --if-off --duration-seconds 60`; then `--if-off` during a session started by hand; then a `-- true` run during a stop pause, and one during an `unplugged` guardrail pause on mock battery | a session with exactly that end (`end_mode`, `deadline_at`, `watch_pid` in `--status-json`), no `agent=auto`, no `agent-pause`, and the CLI's "Replaced the automatic session" line; when it ends with the mock lid open, an automatic session follows; with it closed, one `sleepnow` and no automatic session until the lid opens; `--if-off` leaves the user's session unchanged; both pauses survive the `-- true` runs, and no automatic session follows them |
| 23 | a session started by hand (`--duration-seconds 60`), then `turn-start` | the session is unchanged (token, end); the debug log shows no refused start by the watcher |
| 24 | `mock-passwordless` off; and, in a sourced shell, `admin_transport` with `AGENT_SESSION=true`, the real `run_as_admin` with `none`, and `run_helper` with `helper_is_ready` stubbed to fail | a lid-open automatic session starts, with `agent_note`; `admin_transport` prints `none`; both functions return 1 with `ADMIN_LAST_RESULT=no_password`; a stand-in for `run_with_admin_prompt` fails the test if called |
| 25 | lid-open backend with the mock settings of a leftover lid-closed session | no session starts; `agent_note` names `awake --stop`; the debug log shows no start once a minute |
| 26 | 20 hooks in parallel (`&`) on two keys of two agents | every event is in `agent-events` once, one per line; one watcher; one session |
| 27 | with `LANG=en_US.UTF-8` exported: a 3 MB `UserPromptSubmit` whose prompt contains `\"agent_id\":\"x\"`; a main-thread `PostToolUse` whose `tool_response` holds a nested `"agent_id":"y"` and bytes that are not valid UTF-8; a subagent `PostToolUse` with `effort` before `agent_id` | `claude:s:` holders for the first two, `claude:a:` for the third; each hook ends within 2 s under CI's `/bin/bash` |
| 28 | `AWAKE_TEST_AGENT_LIMIT_SECONDS=4` while a holder works, mock lid open | the session ends as `timeout`; no `agent-pause`; a new automatic session follows within a pass |
| 29 | `AWAKE_TEST_AGENT_ROTATE_BYTES=512` and 50 events; then 20 hooks in parallel while `AWAKE_TEST_AGENT_ROTATE_PAUSE` holds a rotation between the hard link and the rename; then `kill -9` of the watcher during a held rotation, and a `turn-start` | no event lost across the rotations, and `agent-events` never missing; the new watcher resumes in `agent-events.1` at `agent-offset`, then in `agent-events` |
| 30 | `awake --agent-hook` from a copy of `bin/awake` with a syntax error placed after the fast path, at a path with a space and a `'`, through the shell-form command | exit 0, nothing on stdout or stderr |
| 31 | `--agent-hook claude turn-start` and `turn-end` with Cursor payloads (`conversation_id` first, `session_id` after `prompt`), and `turn-start`, `waiting` and `turn-maybe` with VS Code payloads (`timestamp` first) | nothing written (W25) |
| 32 | the same id as `claude` and as `cursor` | two holders; ending one leaves the other |
| 33 | Codex payloads: `turn-end` from `Interrupt`; `UserPromptSubmit` with `agent_id`; `tool-start` for `request_user_input` after a `waiting`; `PermissionRequest` (as `tool-start`) for a working holder | the turn ends; a `codex:a:` holder; the `tool-start` is dropped; the holder stays working, and `--status` never says Codex waits |
| 34 | Cursor payloads: `turn-start` keyed by `conversation_id`; `turn-end`, then `tool-start` (from `afterAgentThought`) 1 s later | a `cursor:s:<conversation_id>` holder; the `tool-start` puts it back to working within the grace |
| 35 | Gemini payloads: `turn-start` with `session_id` first; a payload without it and `GEMINI_SESSION_ID` set | `gemini:s:` holders in both cases |
| 36 | a Claude Code holder, the last look always `busy`, no events | the holder is dropped after the dry-run quiet limit, and the session ends |
| 37 | `AWAKE_TEST_AGENT_HANG` during an automatic session, then a `turn-start` after the dry-run 5 s | the stuck watcher is ended, a new one starts, the old session ends as `process_exited` and a new one starts |
| 38 | holders of `claude` and `codex`; `--ai-hooks off --agent codex` in the dry run (with the edit stubbed); then `--agent claude` | the session runs on after the first; the second ends it as `stopped` with no pause |
| 39 | a working holder and no session; `AWAKE_TEST_AGENT_START_PAUSE` holds the watcher after its "no session runs" and "no pause" reads; meanwhile `--duration-seconds 60`, then `awake --stop` | the held start refuses under the main lock: no automatic session, `agent-pause` exists |
| 40 | mock `lid=closed` with `clamshell_causes_sleep=no`: `turn-start`; then a stop and a typed `turn-start` (input after the stop, 1 s); then the same with `clamshell_causes_sleep` unset | in closed-display mode a session starts and the typed prompt lifts the pause; with the lid closed and causing sleep, neither |
| 41 | in the test's settings domain, change `minBatteryPercent` during an automatic session, mock lid open; then switch `agentBackend` to `caffeinate` with the mock lid closed | a new session token within the dry-run check interval, with the new `min_battery_percent`, and no `agent-pause`; with the lid closed, the session ends as `process_exited`, one `sleepnow`, and nothing starts until the lid opens |
| 42 | `kill -STOP` of the watcher past the dry-run stuck limit, then `kill -CONT` together with a `turn-start` | the watcher survives with the same session token (one stale look, then a fresh beat); check 37's hung watcher is still replaced at the second look |
| 43 | a hook run with `CLAUDECODE=1`, `CLAUDE_CODE_CHILD_SESSION=1`, `CLAUDE_CODE_SESSION_ID` and a `PATH` with an extra folder starts the watcher | the watcher's environment (its debug line at start, or `/proc/<pid>/environ` in the emulation) has none of them and the minimal `PATH` |
| 44 | with `AWAKE_TEST_AGENT_VERSION=0` (dry run only) a watcher runs an automatic session; then a normal `turn-start`, mock lid open; again with the lid closed | with the lid open the old watcher is replaced, its session ends as `process_exited`, a new one starts within a pass, no pause; with the lid closed it is left running |
| 45 | a stop pause; the watcher killed; the runtime folder removed (a restart); `--status-json`; then a `turn-start` with the input mock at 300 s; then one with input after the stop | `agent_paused:"stopped"` before any watcher runs; nothing starts for the first; the second lifts the pause |
| 46 | with a stop pause standing and a holder working, a session started by hand that ends on `unplugged` (mock battery after AC), then mock AC | `agent-guard` is written beside `agent-pause`, which it does not change; on AC the watcher removes only `agent-guard`, and nothing starts until a typed prompt lifts the stop pause |

Each check is first shown to fail on `1bbb06f`, or, where it guards a rule the new code adds, on a deliberate mistake, as faster-start-stop-2.md did (G.5). Examples of such mistakes: the watcher inferring the stop instead of the stop writing the pause (39); `lid_is_closed` for the lid test (40); settings read only at a start (41); killing at the first stale look (42); the inherited environment (43); a start by hand that clears the pause (22, 19); the input test without the after-the-stop part (19); emptying `agent-events` at exit (17); a rotation through `mv` and a new file (29); `idle_prompt` mapped to `turn-end` (11); the background allowance renewed at every `Stop` (8); no tombstone, or `working` allowed to reopen (12); appending after the alive check (17); no token check in the end (18); no handover (22); `kill -0` without the beat (16); the real `sudo -n` in the dry run (24); the first `agent_id` match anywhere (27); no stand-down (31); keys without the agent (32); the pause lifted without the input test (19); no quiet limit (36).

**`cleanup_state`** (tests/cli/awake-self-test:262-270) also stops a watcher named in `agent-watch`, after checking its PID and start time, and removes the `agent-*` files and `agent-lock/`, so that no watcher carries over into later sections.

**Section 13** (6383): `--help` still fits in 80 columns, and lists `--ai-hooks` but not `--agent-hook`, `--agent-watch` or `--agent-session`.

**CI** runs the self-test with `/bin/bash` 3.2 on macOS (ci.yml:126), so all of 12n runs under Apple's bash, which the probes could not.

### W.6 Mac QA

In `qa-2.5.0.md`, with password-free mode on, plugged in, the hooks on for every installed agent (K), and `AWAKE_DEBUG=true` set where it reaches the hooks (for the extension, through `claudeCode.environmentVariables`, vs-code.md:554; for Codex's daemon, before it starts, codex-rs/app-server-daemon/README.md:22-24).

**Claude Code in a terminal** (2.1.199 or later):
1. A prompt that runs for about two minutes with tool calls. `awake --status` reads `Awake is on while Claude works.`. After the reply, `--status` reads `Awake is off.` within about 70 s. `grep agent /tmp/keep-awake-lid-closed-$UID/awake-debug.log` shows the events and the last look.
2. The same, with the lid closed after the prompt, and `pmset -g log` read afterwards. The Mac stays awake while Claude works and sleeps about a minute after the reply; `last` says `process_exited`.
3. A permission prompt with the lid open: the status reads `…waits for you…`. Leave it for 11 minutes: the session ends. Approve: a session starts again with the next tool.
4. Remote Control, lid closed: a prompt whose first command needs approval and runs 8 minutes; approve it from the phone at minute 5. The command finishes (the last look at minute 10 reads `busy`).
5. Remote Control, lid closed: send the next prompt from the phone 5 minutes after a reply. It reaches the Mac (B-9).
6. Esc, and on another try Ctrl+C, in the middle of a turn: the session ends at `idle_prompt` (note whether it fired, and after how long) or at 15 minutes.
7. `kill -9` of `claude` mid-turn: the session ends within about 5 s.
8. Two terminals at once, then a background subagent, then a plain `/clear` (the session ends within about 70 s), then a plan approved with "clear context" (its run is held).
9. A background `npm run dev`, then three short prompts a few minutes apart, then close the lid: the Mac sleeps within an hour of the first prompt's reply, plus the grace.
10. A `/goal` whose second step is a 3-minute command, with the lid closed: the run finishes.

**The owner's setup: Cursor with the Claude Code extension, and Cursor's agent** (section 6):
11. A prompt in the Claude Code panel with tool calls, with the lid closed after it: as items 1 and 2. The status names Claude.
12. Stop in the panel mid-turn: note when the session ends (expect the 15-minute idle limit and a last look reading `idle`).
13. A prompt in Cursor's Agent chat: the status names Cursor; the debug log shows `cursor:s:` events and no `claude:` events for it (H-5). Repeat with Cursor's third-party import turned off: the same.
14. Both at once: `Awake is on while Claude and Cursor work.`; stop the icon: neither starts a session again until a prompt is typed in either panel.
15. Cursor's Stop button mid-turn: the session ends about a minute later. An approval card left open: the session ends at about 15 minutes.
16. Reload Window during a Claude turn, and close the window during a Cursor turn: the holders follow and end as 6.2 says.

**Codex** (0.150.0 or later), if installed:
17. `awake --ai-hooks on --agent codex`, then `codex`: "Hooks need review"; trust them; `status` changes from `installed, not trusted yet` to `on`. A prompt with tool calls and the lid closed: as item 2. Esc mid-turn: the session ends about a minute later. `codex exec "<task>"`: held. The IDE extension in Cursor and the Codex app, if installed: held.

**Gemini CLI** (v0.26.0 or later), if installed:
18. `awake --ai-hooks on --agent gemini`, then `gemini` in an untrusted folder: a prompt with tool calls and the lid closed: as item 2. A declined permission prompt: the session ends after 10 minutes. Nothing appears in Gemini's output.

**Every agent:**
19. Click the icon during an automatic session: `Awake is off`, `Paused until your next prompt`; the next tool call starts nothing; a `/loop` iteration starts nothing while nobody touches the Mac; the next typed prompt does. `Resume now` does at once. Close the lid right after the click and send a prompt from the phone: nothing starts. Restart the Mac during a pause: the menu still shows it. Queue a prompt in the Claude Code panel during a turn after a stop: note whether it lifts the pause (B-5).
20. During an automatic session, `awake --duration 1h`: `--status` shows the hour, not an automatic session; after `awake --stop` and a new prompt, automatic sessions return.
21. A timed session started by hand, then a prompt: the session is unchanged; at its end with the lid open, an automatic session follows within 2 s; on another try with the lid closed, the Mac sleeps, and a session follows once the lid opens.
22. Password-free mode off: the next prompt starts a lid-open session, and `--status` explains why. No password dialog appears at any time.
23. With "Require password after screen saver begins or display is turned off" set, close the lid during an automatic session, wait 5 minutes, and open it: the password must be asked. If it is not, the owner decides whether automatic sessions lock the screen on lid close (section 13).
24. Speed: `time` of 20 hook calls for each verb with a watcher running, through the shell-form command (estimate: under 25 ms each). Also the first `turn-start` with no watcher (estimate: under 80 ms), a `turn-start` during a stop pause (estimate: under 120 ms, with the `ioreg`), the last look (estimate: under 1 s), and the delay a Cursor tool call gets from Awake's two synchronous handlers with the third-party import on (estimate: under 50 ms).
25. CPU of the watcher over 10 minutes of work: `ps -o time= -p <watcher>` (estimate: under 1 s, plus the last looks and a `defaults read` every 30 s).
26. Closed-display mode: the lid closed on an external display, plugged in, the display set to sleep after 1 minute, and Codex or Gemini CLI working for 10 minutes: an automatic session starts and the Mac does not idle-sleep. Unplug the display: the session runs on until the work ends.
27. During an automatic session, turn on `Stop when unplugged` in Settings: within 30 s `--status-json` shows a new session with the unplug guard; unplug: it ends within 10 s, and `Paused until the Mac is on power` appears. Switch the lid mode to lid-open during a lid-closed session: a new lid-open session within 30 s.
28. Put the Mac to sleep (lid closed) during a lid-open automatic session for 5 minutes, then open the lid while Claude still works: the watcher keeps running (the debug log shows one stale look and no replacement).

### W.7 Docs

In W's commit:

- **README.md, Highlights** (5-10): "With `awake --ai-hooks on`, or `Keep awake while AI works` in the menu, it keeps the Mac awake, also with the lid closed, while Claude Code, Codex, Cursor's agent or Gemini CLI works, and lets it sleep about a minute after."
- **README.md:44** (use cases) keeps `awake -- claude -p "<task>"` for one-off headless runs, names `codex exec`, `gemini -p` and `agent -p` next to it, and adds: "or turn on `Keep awake while AI works` (see While AI works)".
- **A new section `## While AI works`, after `## Usage`.** What it does, in user terms (5.3-5.6). The agents and surfaces it covers, and those it does not, with the manual path for each (the matrix of 2.1, shortened). Lid-closed and password-free mode (H-2). What ends a session, and how soon. Waiting, and Remote Control between turns (B-1, B-9). Background work (B-8). Several agents at once. The rule that you decide: a start by hand replaces an automatic session, a stop pauses them until your next typed prompt, `Resume now`, and with the lid closed your own timed session still sleeps the Mac at its end; automatic sessions start only with the lid open (the principle, B-4, B-5, B-11). Guardrails and the pause (5.10). That an automatic session has the 365-day limit of any session, and ends when the work ends, the watcher stops, a guardrail trips or you stop it. Codex's trust step (H-3). What it does not cover:
  - an interrupt (Esc, Ctrl+C) in Claude Code and in Gemini CLI while a tool runs: up to 15 minutes; in the Claude Code extension and Desktop app always up to 15 minutes, as `idle_prompt` does not fire there;
  - Cursor's approval cards, which send nothing, and Codex's approvals, whose hook cannot tell the user from its automatic reviewer (B-1): up to 15 minutes;
  - a tool approved late that runs past the 10 minutes of waiting, for Gemini CLI and Codex's questions (B-13), and a single tool call longer than 15 minutes, or for Claude Code with the last look longer than 2 hours (B-12);
  - `/loop` and scheduled tasks between iterations: use a timed session;
  - usage-limit waits: with the lid closed the Mac sleeps, and after more than about 30 minutes asleep across the reset Claude Code waits for Enter (B-10); a Codex turn that fails sends nothing, so up to 15 minutes;
  - folders Claude Code does not trust yet; `disableAllHooks` in your settings or in a project's `.claude/settings.json`; managed `allowManagedHooksOnly`; `claude -p --bare` (headless.md:37);
  - Codex hooks not yet trusted (H-3); Cursor's `agent -p`, Remote Control and My Machines; Gemini CLI under `--sandbox`, and Gemini Code Assist;
  - Remote-SSH, WSL and container windows, Desktop SSH sessions and cloud sessions of every agent, which run elsewhere;
  - (said next to this list) closed-display mode is covered: with the lid closed on an external display, automatic sessions start as with the lid open (B-11); outside a session, macOS may idle-sleep such a Mac once its display sleeps, unless "Prevent automatic sleeping on power adapter when the display is off" is on;
  - VS Code's Copilot agent with `chat.useClaudeHooks` on: Awake's Claude Code handlers ignore its turns (W25), so Copilot work is not covered; use `awake -- COMMAND`, `-w` or a timed session;
  - a prompt queued in the Claude Code panel while a turn runs may not lift a stop pause (B-5): use `Resume now`;
  - a turn that is not typed (a `/loop` iteration, a background report) but starts while you type elsewhere lifts a stop pause, as the hook cannot tell it from a typed prompt (B-5);
  - the minimum versions of W.4.
- **Runtime files** (557-589): `agent-events` (and `agent-events.new` and `agent-events.1` during a rotation), `agent-offset`, `agent-watch`, `agent-state`, `agent-guard`, `agent-stale`, `agent-handover`, `agent-lock/`; and in `~/Library/Application Support/Awake/`: `agent-pause`, `ai-hooks.conf` and `gemini-extension/`.
- **Security notes** (91-97): one paragraph. The hooks run `awake` as you. Any program running as you can ask for automatic sessions, as it can already run `awake`. Lid-closed automatic sessions need password-free mode, with its trade-off (103). The hooks keep no prompt text. Awake never trusts Codex hooks for you.
- **`--help`**: the option line (K.7).
- **CHANGELOG.md** (after 2.4.0 ships, R-1): `### Added`:
  ```
  - Awake can keep the Mac awake while an AI agent works: Claude Code
    (in a terminal, in VS Code and Cursor, and in its Desktop app),
    Codex, Cursor's own agent and Gemini CLI. Turn it on with `awake --ai-hooks on` or `Keep
    awake while AI works` in the menu bar app. Each turn then keeps the
    Mac awake, also with the lid closed in password-free mode, and the
    Mac can sleep again about a minute after the work stops, or after 10
    minutes of waiting for you. Starting, stopping or timing a session
    yourself always wins: a stop pauses these sessions until your next
    prompt. The usual guardrails apply.
  ```

### W.8 Gain and cost

**Gain.** Any of the four agents can work with the lid closed without the user choosing a length, and the Mac sleeps about a minute after the work instead of at a guessed end time. A run of days goes on as long as it works.

**Cost per hook** (Linux probe; Mac estimates at 1.1 to 1.9 times, from faster-start-stop-2.md's Linux-to-Mac ratios):
- The fast path with a watcher running: about 3 ms for bash, plus the handler's shell, `date`, `cat` and `ps`, about 5 to 10 ms more (estimate). On the Mac, about 10 to 25 ms per hook.
- Claude Code's and Codex's tool hooks are async, so the agent never waits for them (hooks.md:3703; codex-rs/hooks/src/engine/dispatcher.rs:115-188). Gemini CLI's hooks are all synchronous, so each Gemini tool call waits about 10 to 25 ms twice. Cursor must wait for `preToolUse`, as a permission hook can block the tool ([CD] hooks.md:198, 701-712: no `async` option), and while its third-party import is on it also runs Awake's Claude Code `PreToolUse` handler as one (H-5): two synchronous hook processes per tool call, about 20 to 50 ms there.
- Turn-start hooks wait: about 10 to 25 ms. When one has to start a watcher, the full parse and `start_detached` take about 40 to 80 ms (estimate); during a stop pause, the `ioreg` adds about as much (section 10 measures it). The session's own start, about half a second with the lid closed (faster-start-stop-2.md:144), runs in the watcher, not in the hook.

**Cost per busy period:**
- one session start and one end, which with the lid closed means one `sudo -n` helper run each, as for any session;
- the watcher's passes: builtins, `kill -0` and one rewrite of `agent-watch` every 2 s, plus one `ps` per holder every 10 s;
- the last look: one `claude agents --json` and one `osascript` at each expiry of a Claude Code holder, usually once per reply (measured in section 10).

### W.9 Risks and rollback

- **The Mac sleeps while an agent works.** A tool longer than the limits of B-12 and B-13, a hook that does not run (trust, `disableAllHooks`, Codex's review, a bug in an extension, 2.2), or ids after the content keys (W2, checked in section 10). Shows in Mac QA. The limits are constants, and the README names what is not covered.
- **The Mac stays awake when no agent works.** After an interrupt, at most 15 minutes; a late async heartbeat cannot reopen an ended turn (W22). A watcher that dies or hangs: the PID tie and W27. A watcher that is alive but wrong, with the 12-hour cap gone, is not cut off by root (B-12 (a)); the guardrails still apply, and 12n's checks guard each rule. B-12 (b) is the fallback if the owner wants a root-enforced bound.
- **The last look misleads.** `claude agents --json` is in research preview. A `busy` that is wrong keeps the holder for one more idle limit, after which it looks again, at most up to the quiet limit; a failure falls back to the time rules (W21).
- **An agent changes its hooks.** Each adapter uses only documented events and fields, except Cursor's key order (W2) and Antigravity, which is left out. The README names minimum versions. Section 10 and Mac QA show the events as they are, and the probe can be rerun after an agent's update.
- **Bash 3.2.** The watcher's arrays and reads are written for 3.2. CI runs 12n on `/bin/bash`.
- **A typed-looking turn lifts a stop pause.** A `/loop` iteration or background report that starts while the user types elsewhere lifts it (B-5); the menu then shows the session. Shows in Mac QA (W.6 item 19); section 10 may narrow the window.
- **Rollback:** `awake --ai-hooks off`, or revert the commits. Nothing outside the user's runtime folder, Awake's own folder, the agents' hook files and the app's defaults domain changes. The helper is untouched.

## 8. K: connecting the agents (`--ai-hooks`)

### K.1 Today

Awake writes nothing outside its own folders, the helper's and the sudoers file (Runtime files, README.md:557-589). No agent has hooks from Awake.

### K.2 Decisions

| # | Decision | Choice and why | Rejected, and why |
|---|---|---|---|
| K1 | Where | Each agent's user-level file, never a project's: Claude Code `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json` (hooks.md:257); Codex `${CODEX_HOME:-$HOME/.codex}/hooks.json` (codex-rs/hooks/src/engine/discovery.rs:94-206); Cursor `~/.cursor/hooks.json` ([CD] hooks.md:649-650); Gemini CLI the link record in `${GEMINI_CLI_HOME:-$HOME}/.gemini/extensions/awake/`, pointing to Awake's own folder (H-4, K14). `--config-dir DIR` (repeatable, with one `--agent`) adds an extra folder for Claude Code (`CLAUDE_CONFIG_DIR`, "useful for running multiple accounts side by side", env-vars.md:418), Codex (`CODEX_HOME`) or Gemini CLI (`GEMINI_CLI_HOME`). Every folder that `on` writes to is recorded in `ai-hooks.conf` in Awake's own folder, `~/Library/Application Support/Awake/` (mode 600, one `claude_dir=`, `codex_dir=` or `gemini_dir=` line per folder), which `--status-json` reads with builtins (W15) and the uninstaller removes with the folder (scripts/uninstall-awake.sh:292). `status`, `refresh`, `off`, the JSON field and the app use the recorded folders plus the default ones, so the app (started by launchd), the installer and the uninstaller, which do not see the user's shell variables, find them all. `status` also searches the editors' user `settings.json` for a `CLAUDE_CONFIG_DIR` that the Claude Code extension may set (vs-code.md:554; the path, 2.2; Cursor's path is checked in section 10) and names a folder found there without Awake's hooks. | Only the variables from the environment: the app's checkbox would edit `~/.claude/settings.json` while the user's alias reads another folder, and the uninstaller would leave the real handlers behind. Project files: per repository, and a committed project hook would also run in cloud sessions (cloud-environments.md:272). Managed and system files: an administrator's (H-3 (c)). `--config-dir` for Cursor: whether `CURSOR_CONFIG_DIR` moves `hooks.json` was not found ([CD] cli__reference__configuration.md:15-25). |
| K2 | The handler's shape | Every command is `<sh_quote(path)> --agent-hook AGENT VERB >/dev/null 2>&1; exit 0`, with the path quoted by awake's own `sh_quote` (4006-4011). It uses only syntax that `sh`, `bash`, `zsh` and `fish` read alike, because Claude Code runs it with `sh -c` (hooks.md:466-470), Codex with the user's shell (codex-rs/core/src/session/mod.rs:5129-5137), Gemini CLI with `bash -c` (hookRunner.ts:335-367), and Cursor as "a shell string" ([CD] hooks.md:654-661; which shell: not found). Per agent, K.3 gives the rest: `"timeout": 10` for sync handlers (Gemini: `10000`, in milliseconds); `"async": true` and no timeout for the tool heartbeats of Claude Code and Codex (Claude Code enforces none on async hooks, hooks.md:3730); no timeout for Claude Code's `SessionEnd`, as a per-handler timeout would raise the 1.5 s budget that every exit, `/clear` and `/resume` waits on (hooks.md:3391), and none for Codex's `SessionEnd` and `Interrupt`, whose defaults are 1 s (codex-rs/hooks/src/events/session_end.rs:20-23; discovery.rs:742-766). The awake path is the resolved path of the `awake` that runs the command; the installer's `refresh` (K7) points it at the installed copy, `~/Library/Application Support/Awake/bin/awake` (scripts/install-awake.sh:12-14). For Gemini CLI a path with `$` is refused, as Gemini substitutes variables in hook commands (packages/core/src/hooks/hookRunner.ts:511-529). | Exec form with `args`: W13. Running `awake` without the redirections and `; exit 0`: W13. |
| K3 | Which handlers | K.3: 13 for Claude Code, 10 for Codex, 7 for Cursor, 6 for Gemini CLI. | |
| K4 | Telling Awake's handlers apart | A handler is Awake's when its `command` is exactly a single-quoted path ending in `/awake`, as `sh_quote` writes it (a `'` in the path appears as `'\''`), then ` --agent-hook `, a known agent, a verb of lower-case letters and dashes, and ` >/dev/null 2>&1; exit 0`; for Claude Code and Codex also `type` `command` and no `args`. The pattern is kept in a variable in the JavaScript of K5. There is no marker key: Claude Code's schema could reject one (settings.md:607), and Codex refuses unknown top-level keys (codex-rs/config/src/hook_config.rs:10-17). A user's handler that runs some other `awake` command is not touched. | Adrafinil's `_adrafinil` key (NestedJSONHookShape.swift:12-15). |
| K5 | How the files are edited | `osascript -l JavaScript`, already used by `awake` (996, 2317), reads each JSON file. It must be a JSON object with the documented shape: for Claude Code and Codex, event → array of groups → `hooks` array; for Codex also nothing at the top level but `description` and `hooks`; for Cursor, `version` and `hooks` → event → array of entries. Otherwise `awake` refuses and names the problem, and suggests `--ai-hooks print`. **On and refresh:** for each handler in K.3, Awake's handler is replaced in place, or added: in Claude Code to a group with the same matcher, or a new group at the end; in Codex always in a group of its own at the end of the event's array, never inside a user's group, so the positions, and so the trust, of the user's groups never move (H-3); in Cursor as an entry at the end. Awake handlers for events or matchers no longer in the set are removed. A new Cursor file gets `"version": 1`. **Off:** Awake's handlers are removed from every event. **Every removal**, by `on`, `refresh` or `off`: groups and event keys left empty are removed, except a Codex group that is not the last in its array, which stays as `{"hooks": []}` (valid: `hooks` defaults to an empty list, codex-rs/config/src/hook_config.rs:154-159) so that the user's later groups keep their positions, and with them their trust (codex-rs/hooks/src/lib.rs:113-123); an empty group that is last in its array is removed, as that shifts no one. **Codex's inline hooks:** `on --agent codex` refuses, with exit 1, when the `config.toml` of the same `CODEX_HOME` has inline hook groups (a builtin line scan for `[[hooks.<Event>]]` tables, which skips `[hooks.state.…]`), as Codex would then warn at every start that it loads hooks from both files (codex-rs/hooks/src/engine/discovery.rs:154-164); it names `awake --ai-hooks print --agent codex`, which prints Awake's handlers both as JSON and as `[[hooks.<Event>]]` and `[[hooks.<Event>.hooks]]` tables to paste into that file (the shape of codex-rs/config/src/requirements_layers/stack_tests.rs:1095-1100). `status` counts Awake's handler lines in `config.toml` too. Key order is kept (JavaScript objects keep it). Output is `JSON.stringify(…, null, 2)` and a newline. **Writing:** the link target is resolved, the new text goes to a temporary file next to the target with the target's mode, and a `cmp` against what was read refuses a file that changed meanwhile. Then `mv -f`. Nothing is written when nothing changes. A function `ai_hooks_before_compare`, empty in the shipped code, sits between the read and the `cmp`, so that the self-test can change the file there. **Gemini CLI:** Awake writes its two files whole, in a folder it creates (K14). | `plutil`: it cannot write JSON `null` (research). `python3` and `jq`: not on every Mac. Writing `{}` over a file that does not parse: what clawake did (section 1). Writing Codex's trust entries: H-3 (b). |
| K6 | Output | `on` prints, per agent and folder, what it added, updated or removed, and then warnings (K.3), ending with Codex's trust step where it applies (H-3). `status` prints, per agent: `on`, `partial (N of M)`, `off`, `installed, not trusted yet` or `installed, review again in Codex` (Codex, K13) or `not found`, with the file and the awake path; then the lid mode, any pause, and the warnings. `refresh` prints what it updated, or nothing. `print` prints each agent's block for pasting by hand. `resume` prints `AI sessions resume with the next work.` or `AI sessions are not paused.`. All exit 0, except `on`, `off` and `refresh` when they refuse or fail (exit 1). | |
| K7 | Upgrades and uninstall | The installer, after `--install-helper` (scripts/install-awake.sh:525), runs `awake --ai-hooks refresh` and reports a non-zero exit. `refresh` does nothing, and exits 0, for an agent or a folder without Awake handlers. Elsewhere it rewrites the handler set and the path; it never changes the lid mode, never adds an agent (H-6) and never refuses because of password-free mode. For Codex it changes a handler only when its text would change, and says that Codex will ask for review again (K13). It also replaces a watcher of another version while the lid is open (5.8). The uninstaller runs `awake --ai-hooks off` for every agent and recorded folder before `stop_active_session_if_needed` (scripts/uninstall-awake.sh:195), so that no hook starts a session between that stop and the removal. It also removes Antigravity's copy of the Gemini extension, `~/.gemini/antigravity-cli/plugins/awake`, which Antigravity makes of every Gemini extension on its first run and does not use (acc@6a47099 packages/adapter-antigravity/COMPATIBILITY.md:566-575), when it holds only Awake's files and the `plugin.json` Antigravity adds. `brew uninstall` runs that uninstaller (README.md:204). | Running `on` again at each install: it would switch a user who chose lid-open to lid-closed, fail for a user without password-free mode, and add agents the user did not choose. Parsing `status` text in the installer. Leaving the hooks after an uninstall: thanks to K2 they would stay silent, but they would remain in four files. |
| K8 | Lid mode | One for all agents. `on` takes `--backend awake\|caffeinate` and stores it as `agentBackend` in the app's defaults domain (`write_setting`, 1184-1190), where the watcher reads it at each start and every 30 s (5.3, W28). Without `--backend`, `on` keeps the stored value, and takes `awake` only when nothing is stored. Only `awake` chosen that way, or given explicitly, checks password-free mode: `on` refuses while `helper_runs_without_password` fails (H-2 (a)). Message: "Lid-closed automatic sessions need password-free mode: run awake --passwordless on first, or use --backend caffeinate for lid-open sessions." | |
| K9 | Combining options | `--ai-hooks` is a maintenance action, like `--passwordless` (`set_maintenance_action`, 704-713). It takes `--agent NAME` (repeatable; `claude`, `codex`, `cursor`, `gemini` or `all`) with every verb but `resume`, `--backend` with `on`, and `--config-dir` with `on`, `off`, `refresh` and `status` and exactly one `--agent` of `claude`, `codex` or `gemini`. Everything else is refused, as for the other maintenance actions. The check at 676-680 gets an exception for these pairs. | |
| K10 | Dry run | `--ai-hooks` in the dry run edits only folders given by the variables or `--config-dir`, and for Cursor only the folder in `AWAKE_TEST_CURSOR_DIR` (read only in the dry run); an agent whose folder is not given that way is skipped, so that a test never touches a real `~/.claude`, `~/.codex`, `~/.cursor` or `~/.gemini`. `ai-hooks.conf`, the stop pause and the Gemini extension's own folder go to the dry-run runtime folder, and the settings to the self-test's defaults domain (`AWAKE_TEST_SETTINGS_DOMAIN`, 1166-1175); in the dry run `on --agent gemini` never runs `gemini` and writes the link record. | |
| K11 | What `off` stops | For all agents: besides removing the handlers, `off` ends a running automatic session with a stop request, after writing `agent-handover` so that the watcher writes no pause; stops the watcher with TERM, after checking its PID and start time; and removes `agent-events`, `agent-offset`, `agent-watch`, `agent-state`, `agent-guard`, `agent-stale`, `agent-handover` and `agent-lock/`, and the stop pause in Awake's own folder. For some agents only: it appends an internal `agent-off` line naming them to `agent-events` (a verb no hook can pass, W3), on which the watcher drops those agents' holders; the session then ends, as a handover would, only if no other agent's holder keeps it. | Removing only the handlers: the watcher and its session would run on until the idle or background limit. |
| K12 | Which agents are found | Claude Code: its settings folder exists (or a recorded one); Codex: `${CODEX_HOME:-~/.codex}` exists; Cursor: `~/.cursor` or `/Applications/Cursor.app` exists, as Adrafinil checks (CursorIntegration.swift:21-24); Gemini CLI: `${GEMINI_CLI_HOME:-~}/.gemini` exists and a `gemini` executable is found on the `PATH` or in `/opt/homebrew/bin`, `/usr/local/bin` or npm's global prefix, as Antigravity and Gemini Code Assist create and use `~/.gemini` too (acc@6a47099 packages/adapter-antigravity/COMPATIBILITY.md:22-38, 566-575; Google's Code Assist docs, a search snippet); otherwise `status` prints "Gemini CLI: not found (~/.gemini is there, probably from Antigravity or Gemini Code Assist)". `on` without `--agent` covers the agents found, and says which it skipped. `on --agent X` for an agent not found refuses: "Codex was not found (no ~/.codex); start it once first." | Installing for every supported agent: Awake would create folders for tools the user does not have. |
| K13 | Codex's trust | Never written by Awake (H-3 (a)). `status` and `--status-json` read `config.toml` with builtins for one `[hooks.state."<absolute hooks.json path>:<snake_case event label>:<group index>:<handler index>"]` line per Awake handler, such as `…:user_prompt_submit:3:0` (codex-rs/hooks/src/lib.rs:95-123); the exact line format is checked in section 10. A stored hash that differs from the handler's makes Codex skip it as `Modified` (codex-rs/hooks/src/engine/discovery.rs:715-736, 806-820), which an existence check cannot see. So when `refresh` or `on` changes a Codex handler's text (a new awake path), it saves in `ai-hooks.conf` the `trusted_hash` values then stored under Awake's keys, and `status` reads `installed, review again in Codex` while they are unchanged; a new review stores new hashes, and `status` reads `on` again. | Computing Codex's hash in Awake: its canonical form (codex-rs/config/src/fingerprint.rs:54-66) and a SHA in Bash, for a status line. |
| K14 | Gemini's extension | Awake's own folder `~/Library/Application Support/Awake/gemini-extension/` holds `gemini-extension.json`, `{"name": "awake", "version": "<awake's version>", "description": "Keeps the Mac awake while Gemini CLI works. Written by Awake; remove with awake --ai-hooks off --agent gemini."}`, and `hooks/hooks.json`, `{"hooks": {…}}` (docs/extensions/reference.md:240-244). `on` refuses when another folder under the extensions folder already declares the name `awake`, in its own `gemini-extension.json` or in the one its link record points to (a builtin text scan), as Gemini aborts at startup on a duplicate name (packages/cli/src/config/extension-manager.ts:645-651). It then registers the folder: with a `gemini` executable found (K12), `gemini extensions link <folder> --consent` under `run_with_timeout` 30 s (packages/cli/src/commands/extensions/link.ts:64-78), and prints that the user's `on` is the consent that Gemini otherwise asks for (consent.ts:322); without one, or when that fails, it writes only `${GEMINI_CLI_HOME:-$HOME}/.gemini/extensions/awake/.gemini-extension-install.json` = `{"source": "<Awake's folder>", "type": "link"}`, the record `link` writes (extension-manager.ts:438-443). Gemini checks the integrity record that `link` also stores only at an update (packages/cli/src/config/extensions/update.ts:57), so the hand-written record loads (10.5 checks it). Never a bare folder with the files under `~/.gemini/extensions` (H-4: with `security.allowedExtensions` set it aborts Gemini's startup), and never `type: "local"` with Awake's folder as its own source (an update would delete it, extension-manager.ts:568-576). A link whose target is gone is skipped with a warning (extension-manager.ts:995-1001). `off` deletes the link folder when it holds only Awake's link record (or what `link` wrote for Awake's folder), and Awake's folder when it holds only Awake's two files; otherwise it refuses and names them. With `security.allowedExtensions` set, `on` and `status` say that Awake's folder must match it, or Gemini skips the extension. | A bare folder in `~/.gemini/extensions/awake/`, as the previous revision had: with `security.allowedExtensions` set in any settings file, an administrator's included, Gemini CLI would refuse to start (`An unexpected critical error occurred`; extension-manager.ts:725-731; packages/cli/src/config/config.ts:675; packages/cli/index.ts:137-168), and it skips the hooks warning Gemini shows at install. Always running `gemini extensions link`: Gemini may not be on the `PATH` the app or the installer sees. |

### K.3 The handlers

#### K.3.1 Claude Code, in `settings.json`

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
- `PermissionRequest` and `PreToolUse` hooks that print nothing and exit 0 leave the decision to the user, as without them (hooks.md:776-790, 1916-1921). In the extension, a `PermissionRequest` hook runs alongside the host, and "whichever decides first applies" (hooks.md:1918); one that prints nothing decides nothing.
- The `Notification` handler fires only in terminal sessions (2.2). It is kept for them.
- Cursor's agent runs these handlers too, with Cursor's payloads; they stand down (W25). Cursor tests the `PreToolUse` matcher against its own tool names, so the waiting handler never matches there ([CD] reference__third-party-hooks.md:233-247).
- Warnings that `on` and `status` print, each read with builtins:
  - `disableAllHooks` set in the user's settings;
  - `allowManagedHooksOnly` found in `/Library/Application Support/ClaudeCode/managed-settings.json` (managed-settings.md:40); an MDM profile or the claude.ai console may also set it (managed-settings.md:61-71), which `awake` cannot read;
  - password-free mode off with the lid-closed backend;
  - `CLAUDE_CONFIG_DIR` set, with the folders used, and a folder named in an editor's `claudeCode.environmentVariables` (K1).
  The README names untrusted folders (hooks.md:3813-3818), a project's `disableAllHooks` (hooks.md:710) and `claude -p --bare` (headless.md:37); `awake` cannot see them. It also says that the extension and the Desktop app run hooks without a trust prompt (hooks.md:3818).

#### K.3.2 Codex, in `hooks.json`

Each handler in a group of its own, appended at the end of its event's array (K5):

| Event | Matcher | Verb | Async | `timeout` |
|---|---|---|---|---|
| `UserPromptSubmit` | (none) | `turn-start` | no | 10 |
| `Stop` | (none) | `turn-end` | no | 10 |
| `Interrupt` | (none) | `turn-end` | no | (none: 1 s) |
| `SessionEnd` | (none) | `session-end` | no (always sync) | (none: 1 s) |
| `SubagentStart` | (none) | `agent-start` | no | 10 |
| `SubagentStop` | (none) | `agent-end` | no | 10 |
| `PermissionRequest` | (none) | `tool-start` (B-1) | no | 10 |
| `PreToolUse` | `request_user_input` | `waiting` | no | 10 |
| `PreToolUse` | (none) | `tool-start` | yes | (none) |
| `PostToolUse` | (none) | `working` | yes | (none) |

- `PermissionRequest` is a heartbeat, not `waiting`: Codex runs it before its automatic reviewer as well as before asking the user (codex-rs/core/src/tools/approvals.rs:505-525), and its payload does not say which (codex-rs/hooks/src/schema.rs:301-318).
- `SessionStart` is left out: it fires only when the first turn starts (codex-rs/core/src/hook_runtime.rs:130-181), which `turn-start` already covers.
- A matcher of letters, digits and `_` matches the tool name exactly; an empty matcher matches all (codex-rs/hooks/src/engine/matcher.rs:12-40).
- After `on`: "Start codex in a terminal once and choose Trust all and continue, then confirm (or run /hooks); in the Codex app or IDE extension, review hooks there if it offers it. Until then Codex skips Awake's hooks." (H-3). A user with only the app or the IDE extension may have no `codex` command; 10.4 records whether those surfaces offer a review.
- Refusal: inline hook groups in the same layer's `config.toml` (K5), as Codex would warn at every start (discovery.rs:154-164).
- Warnings: `[features] hooks = false` or `codex_hooks = false` in `config.toml`; `allow_managed_hooks_only` in `requirements.toml` (openai/codex@551bd409 docs/config.md:9-15; discovery.rs:84-116).

#### K.3.3 Cursor, in `~/.cursor/hooks.json`

| Event | Verb | `timeout` |
|---|---|---|
| `beforeSubmitPrompt` | `turn-start` | 10 |
| `afterAgentThought` | `tool-start` | 10 |
| `preToolUse` | `tool-start` | 10 |
| `postToolUse` | `working` | 10 |
| `postToolUseFailure` | `working` | 10 |
| `stop` | `turn-end` | 10 |
| `sessionEnd` | `session-end` | 10 |

- No matcher, no `failClosed` (default false, [CD] hooks.md:711), no `loop_limit`. Nothing is printed, which for `preToolUse` lets the tool proceed (2.4); section 10 checks it on the owner's version, because a wrong answer there would block every tool, and Awake's Claude Code `PreToolUse` handler, which Cursor runs as a `preToolUse` too while its third-party import is on (H-5), prints nothing in the same way. Awake never prints a `permission` field, which would change the user's approvals.
- Left out: `sessionStart` (never fires in the CLI, [FL]:38), `afterAgentResponse` (can come after `stop`, [FL]:62), `beforeShellExecution` and `afterShellExecution` (`preToolUse` and `postToolUse` already fire for the same call), `beforeReadFile` (its payload carries the whole file), `subagentStart` (a permission hook, [CD] hooks.md:198, not seen firing, [FL]:61), `subagentStop` (unless 10.2 (t) shows that subagents have their own ids; then it is added as `agent-end`, 5.7), `workspaceOpen`.
- A project's `.cursor/hooks.json` is never touched.

#### K.3.4 Gemini CLI, in `~/Library/Application Support/Awake/gemini-extension/hooks/hooks.json`, linked into `~/.gemini/extensions/awake/`

| Event | Verb | Handler `name` | `timeout` (ms) |
|---|---|---|---|
| `BeforeAgent` | `turn-start` | `awake-turn-start` | 10000 |
| `BeforeTool` | `tool-start` | `awake-tool-start` | 10000 |
| `AfterTool` | `working` | `awake-working` | 10000 |
| `Notification` | `waiting` | `awake-waiting` | 10000 |
| `AfterAgent` | `turn-end` | `awake-turn-end` | 10000 |
| `SessionEnd` | `session-end` | `awake-session-end` | 10000 |

- Matchers are empty, which matches everything (docs/hooks/index.md:90). `Notification` has only one type, `ToolPermission` (docs/hooks/reference.md:272-285).
- `name` lets the user turn one off with Gemini's own `/hooks disable <name>` (docs/hooks/index.md:162-168).
- Left out: `SessionStart` (not needed), `BeforeModel` and `AfterModel` (`AfterModel` fires for every streamed chunk, docs/hooks/reference.md:236), `BeforeToolSelection`, `PreCompress`.
- Warnings, from a text search of `~/.gemini/settings.json`, `/Library/Application Support/GeminiCli/settings.json` and `/Library/Application Support/GeminiCli/system-defaults.json` (packages/cli/src/config/settings.ts:106-128): `hooksConfig.enabled: false`, `tools.enableHooks: false`, `admin.extensions.enabled: false` (extension-manager.ts:623-626), and `security.allowedExtensions` (K14). And: "Gemini CLI sessions that are already running pick this up after a restart."

### K.4 Security and compatibility

- **The edit touches only Awake's handlers** (K4, K5). A user's handlers in the same groups stay, in their order, and in Codex in their positions, so their trust stays.
- **Refusals.** A file that does not parse, a file that is not an object, an unexpected shape, an unknown top-level key in Codex's file, or a change during the edit: in each case the file stays as it was.
- **Symlinks** (dotfile managers) are written through, and the mode is kept.
- **Where the JSON is parsed.** JavaScript inside `osascript` parses it, as the user. `awake` passes the file's path as an argument, never its text as code.
- **What the handlers run.** The agent's shell with Awake's path in single quotes, escaped by `sh_quote` (4006-4011), and a fixed agent and verb. A path with spaces, `$` or quotes stays one word; for Gemini a `$` is refused (K2). Section 10 runs a path with a space.
- **Codex's review** stays the user's: Awake never writes trust entries (H-3).
- **The Gemini extension** lives in Awake's own folder and holds no code but the command lines; Gemini sees it through a link record, the form an allowlist can skip without aborting Gemini's startup (K14). Deleting the link folder and Awake's folder is the whole removal.
- **Version mix.** A 2.4.0 `awake` that meets these handlers: W.4.

### K.5 Tests

**`tests/cli/awake-self-test`, a new section 12o**, macOS only: it needs `osascript -l JavaScript`. It is skipped with a note elsewhere, as the emulation has no JXA. Each check uses temporary folders for every agent (K10):

1. Missing folders: `on --agent claude` refuses, and nothing is created; `on` without `--agent` covers only the agents whose folders exist.
2. Missing files: `on` creates Claude Code's with 13 handlers, Codex's with 10, Cursor's with 7 and `"version": 1`, and Awake's Gemini folder with its two files plus the link record under the test's Gemini home (K14). `status` reads `on` for Claude Code, Cursor and Gemini and `installed, not trusted yet` for Codex, and `--status-json` has the same in `ai_hooks`. A second `on` changes no byte.
3. Files with user hooks: Claude Code's with two `Stop` groups, one with a matcher, `PreToolUse` with matcher `Bash`, and other top-level keys; Codex's with two user groups under `Stop`; Cursor's with another tool's entries. `on` keeps them all, in order, and adds Codex's groups after the user's. `off` gives back files that are JSON-equal to the originals.
4. Codex: a user group added after Awake's, then `off`: Awake's group becomes `{"hooks": []}`, and the user's group keeps its index. A fake `[hooks.state."…"]` line for each of Awake's handlers in `config.toml`: `status` reads `on`.
5. A file with a comment (`//`), a trailing comma, an array root, a `hooks` that is a string, and a Codex file with an extra top-level key: all refused, the file unchanged, exit 1.
6. A symlinked file: the target changes, and the link stays a link. Mode 600 is kept.
7. A stand-in for `ai_hooks_before_compare`, in a sourced shell, that changes the file between the read and the `cmp`: refused, the change kept.
8. Handlers from an older set (one extra event) and an old path: `refresh` replaces the path and removes the extra one, for each agent.
9. `print`: valid JSON for each agent. `--ai-hooks on --min-battery 5` and `--config-dir` without `--agent` or with `--agent cursor`: refused (K9).
10. `--backend awake` with `mock-passwordless` off: refused, with the message from K8.
11. With `caffeinate` stored, `refresh` and `on` without `--backend` keep `caffeinate`. For an agent without Awake handlers, `refresh` changes no byte and exits 0, and adds nothing.
12. Two Claude Code folders, one through `--config-dir`: `status` lists both; `off` with `CLAUDE_CONFIG_DIR` unset still cleans both, as they are recorded in `ai-hooks.conf`.
13. `off` during an automatic session in the dry run: the session ends as `stopped` with no `agent-pause`, the watcher is gone, and the `agent-*` files and `agent-lock/` are removed.
14. The `SessionEnd` handlers of Claude Code and Codex, and Codex's `Interrupt`, have no `timeout`, and the async handlers have none.
15. Gemini: a link folder `awake` that holds another file: `off --agent gemini` refuses and names it. An awake path with `$`: `on --agent gemini` refuses. Another extension folder that declares `awake`: `on` refuses and names it. Without a `gemini` executable, `on` writes exactly `{"source": "<Awake's folder>", "type": "link"}` and no other file under the extensions folder. A `~/.gemini` without a `gemini` executable: `status` reads `not found` with K12's note.
16. Codex: an obsolete Awake group in the middle of an event's array, then `refresh`: it becomes `{"hooks": []}` and the user's later group keeps its index; an empty group that is last is removed.
17. Codex: a `config.toml` with a `[[hooks.Stop]]` table: `on --agent codex` refuses with exit 1 and names `print`; `print --agent codex` prints valid JSON and TOML; a `config.toml` with only `[hooks.state.…]` lines is not refused.
18. Codex: after `on` and fake trust lines, a `refresh` that changes the awake path: `status` reads `installed, review again in Codex`; new `trusted_hash` values: `on`.
19. `resume` with and without a stop pause: K6's two messages; the pause file in Awake's folder is gone after the first.

The uninstaller's step (K7), and that it runs before the session stop, are checked in 11c's style (tests/cli/awake-self-test:3923), with a stand-in `awake`.

### K.6 Mac QA

1. `awake --ai-hooks on` on the owner's real files, with their own hooks. Then `claude` in a trusted folder: `/hooks` lists Awake's handlers. In Cursor's Claude Code panel, the Hooks dialog lists them (vs-code.md:132). A conversation that was already running picks them up without a restart (settings.md:584); note whether the panel does.
2. In Cursor, a new Agent chat runs the Cursor entries (W.6 item 13).
3. `awake --ai-hooks off`: no agent lists Awake's handlers, and an automatic session that ran has ended. `diff` against copies made before `on`: only formatting differences, if any.
4. With `~/.claude/settings.json` a symlink into a dotfiles folder.
5. With the Homebrew install: `brew upgrade` keeps them on, with the same lid mode, pointing at the managed path, and Codex does not ask for review again unless the path changed. `brew uninstall awake` removes them all.
6. With `disableAllHooks: true`: `status` warns.
7. With a second Claude Code folder through `--config-dir`: the app's Settings group lists both, and turning Claude Code off cleans both.
8. Codex: the review screen after `on`; `status` before and after trusting; after a `refresh` that changes the path, `review again in Codex`, and the review screen again. Gemini: `gemini extensions list` shows `awake` as linked, `gemini` uses it after a restart, and `off` removes it. With `"security": {"allowedExtensions": ["^nomatch$"]}` in `~/.gemini/settings.json`, `gemini` still starts (and skips Awake's extension with a warning).

### K.7 Docs

- **`--help`**, under the maintenance options:
  ```
    --ai-hooks on|off|status|refresh|print|resume
                           Keep the Mac awake while AI agents work (Claude
                           Code, Codex, Cursor, Gemini CLI) through their
                           hooks; --agent NAME for one agent (see README)
  ```
  The lines are under 80 columns, which section 13 checks.
- **README.md, Options** (350-381): one bullet for `--ai-hooks`, with `--agent`, `--backend`, `--config-dir`, K6's output, the files each agent gets, Codex's trust step, and that only Awake's handlers are touched. "If you use `CLAUDE_CONFIG_DIR`, `CODEX_HOME` or `GEMINI_CLI_HOME`, run `awake --ai-hooks on --agent … --config-dir …` for each folder."
- **README.md, Uninstall** (202-215): the uninstaller also removes Awake's hooks from every agent's files and the Gemini extension folder.
- **CHANGELOG.md**, within W.7's `### Added` bullet.

### K.8 Gain

One command, or one click (M), instead of editing up to four files in three formats by hand. Upgrades keep the hooks current without changing the user's choices or Codex's trust.

### K.9 Risks and rollback

- **Damaging the user's files.** Covered by K5's refusals and 12o. A second risk is a file rewritten in 2-space indentation when the user used another style. `on` and `off` say they rewrite the file. The README recommends `print` to anyone who keeps a file formatted by hand.
- **An agent writes its file at the same time** (Claude Code's `/config`, the extension's Hooks dialog, Codex's `/hooks`, which writes `config.toml`, not `hooks.json`): the `cmp` refuses. A small window remains between the `cmp` and the `mv`.
- **Cursor blocks tools if its rule for empty output changes.** The probe in section 10 and Mac QA show it. While Cursor's third-party import is on, Awake's Claude Code `PreToolUse` handler runs there as a permission hook too (H-5), so the rollback is `awake --ai-hooks off --agent cursor --agent claude`, or turning off Cursor Settings → Agents → Third-Party Imports ([CD] reference__third-party-hooks.md:17); `off --agent cursor` alone does not undo it.
- **Codex's trust lost at an upgrade** if Awake's handler text changes; `refresh` says so (K7).
- **Rollback:** `awake --ai-hooks off`, which also stops what runs (K11), or delete the handlers by hand. `print` shows exactly which ones.

## 9. M: the menu bar app

### M.1 Today

- The app polls `--status-json` every 10 s (StatusBarController.swift:106-109).
- It shows the status sentence (StatusDescription.swift:22-54), and offers `Add`, `Start default session` or `Stop session`, `Help`, `Settings…`, `Install helper…` and `Quit` (783-850).
- It runs maintenance commands with `performMaintenance` (AwakeCLI.swift:429-445).
- It posts end notifications only for sessions it started, and only on a poll that goes from active to inactive (603-631).
- Its Settings have General, Keyboard shortcut, Guardrails and Session lengths (README.md:257-281).

### M.2 Decisions

| # | Decision |
|---|---|
| M1 | Decode `agent_session`, `agent_phase`, `agent_names`, `agent_holders`, `agent_wait_ends_at`, `agent_note`, `agent_paused`, `ai_hooks` (a dictionary of strings) and `last_session_token` as optional fields (AwakeCLI.swift:10-88). |
| M2 | `StatusDescription` gets the sentences of 5.11, with the agents' display names from `agent_names`, before the `processName` branches (35-38), with the same lid-open endings (47-52). "For up to N more minutes" comes from `agent_wait_ends_at`. |
| M3 | A menu item `Keep awake while AI works`, after `Start default session` (802), with a checkmark when `ai_hooks` has any agent `on`, `partial`, `untrusted` or `review`. It is hidden when `ai_hooks` is null, meaning no supported agent is found. **Turning it on** runs `--ai-hooks on`, for every agent found. With the lid-closed backend while `passwordless` is not true, it first shows an alert: "Lid-closed automatic sessions need Start without password. Turn it on now (asks for your password once)?" The buttons are `Turn on and continue`, `Use lid-open instead` and `Cancel`. The first runs `--passwordless on`, then `--ai-hooks on`. If Codex is among the agents, a second alert tells the user to trust the hooks in Codex once (H-3). **Turning it off** runs `--ai-hooks off`, which covers every agent and recorded folder (K1). **During a stop pause** (`agent_paused` is `stopped`), the item is followed by a disabled `Paused until your next prompt` and by `Resume now`, which runs `--ai-hooks resume`. During a guardrail pause the disabled line reads `Paused until the Mac is on power` or `Paused until the Mac has cooled down`, with no `Resume now`, as the next start would meet the same guardrail. Errors go through the usual failure notification. |
| M4 | During an automatic session (`agentSession == true`), the time item at 790-801 reads `Keep awake for <length to add>` instead of `Add <length>`, and runs the same start (`performStart` with that duration, 186-215), which the CLI turns into the handover: the user's own session of that length replaces the automatic one (B-14 (a)). The app's message after it says so, from the CLI's line (5.9). For other sessions the item is unchanged. |
| M5 | Settings gets an `AI agents` group, shown when `ai_hooks` is not null. One row per supported agent: its name (Claude Code, Codex, Cursor, Gemini CLI), its state (On, Off, Not found, or for Codex "Installed; trust it once in Codex"), a checkbox that runs `--ai-hooks on\|off --agent X`, and its files. Below: a `Lid mode` popup (`Lid-closed (needs Start without password)` / `Lid-open`), which runs `--ai-hooks on --backend …` while the hooks are on; `agent_note`; and the pause with `Resume now`. A changed lid mode or guardrail reaches a running automatic session within 30 s (W28); the group says so under the popup. |
| M6 | In `maybeNotifyCompletionTransition`, before the `isAppSession` guard (613-615): when `previousStatus.agentSession == true` and the reason is `low_battery`, `overheated` or `unplugged`, post `postStopped` with the extra sentence "<names> may still be working.", built from the previous poll's `agentNames` (B-6). And when the previous poll and this one are both active, their session tokens differ, and `lastSessionToken` equals the previous token, the app runs the same notification and `recordStopTime` (StatusBarController.swift:571) for the previous session, which today's guard at 605-607 would miss. |
| M7 | A click on the icon, `Stop session` and `Stop Awake and quit` stop an automatic session like any other. The CLI then pauses automatic sessions (5.9), and the next poll shows the pause items (M3). |

### M.3 Code changes

- `AwakeCLI.swift`: nine fields and their `CodingKeys` (10-88), and the placeholders (90-130).
- `StatusDescription.swift`: M2, with one function that joins the display names.
- `StatusBarController.swift`: M3, M4, M6, and actions that run `performMaintenance` for `--ai-hooks on`, `off` and `resume`.
- `SettingsWindowController.swift`: M5.
- `InstallSupport.swift`: `postStopped` takes an optional extra sentence (375-431).
- If M6's comparison goes into `CommandResult.swift`, a case in `tests/app/command-result-check.swift`.

### M.4 Security and compatibility

The app runs only `awake` commands that already exist or that K adds. It edits no file itself. An app older than the CLI shows automatic sessions as "Awake is on until awake (PID n) exits, with at most 365 days left" and has no menu item; its `Add 1 hour` replaces the automatic session with a one-hour session of the user's, while it reports added time (W.4). An app newer than the CLI finds no `ai_hooks` and hides the item.

### M.5 Tests

- If `StatusDescription.swift` and `AwakeStatus` compile with Foundation alone, a new `tests/app/status-description-check.swift` checks the sentences against the CLI's for the same fields, with one, two and three agents, with a CI step like those at ci.yml:82-96.
- If they pull in AppKit types, that check moves to Mac QA. The CLI's sentences are checked in 12n either way.
- M6's back-to-back case in `tests/app/command-result-check.swift`, if the logic lives in `CommandResult.swift` (ci.yml:91-96).

### M.6 Mac QA

1. The menu item appears with any of `~/.claude`, `~/.codex`, `~/.cursor` (or Cursor.app) and `~/.gemini` with a `gemini` executable (K12), and not without them.
2. Turning it on with password-free mode off: the alert, then one password dialog, then the checkmark. `Use lid-open instead`: no dialog.
3. The tooltip during W.6 items 1, 3, 5 and 14, naming the right agents.
4. A guardrail end: turn on `Stop when unplugged`, let an agent work on AC power, then unplug. One notification with the extra sentence naming the agent, and with the lid closed the Mac sleeps.
5. `Stop session` during an automatic session: `Paused until your next prompt` and `Resume now` appear; `Resume now` brings the session back within a pass while the agent works (W.6 item 19).
6. The Settings group: each agent's row and checkbox, Codex's trust note, and the popup changing the backend of the running automatic session within 30 s.
7. During an automatic session the menu shows `Keep awake for 1 hour`; choosing it gives a one-hour session with the app's message, and `--status` shows the hour.
8. A 1-minute session from the app, with the lid open, while an agent works: when it ends, the app still posts `Awake finished`, although an automatic session follows at once.

### M.7 Docs

README, Menu bar app (240-283):
- the menu item and the pause items (M3);
- the Settings group (M5);
- the tooltip examples `Awake is on while Claude works` and `Awake is on while Claude and Cursor work`;
- the notification (M6).

### M.8 Gain

The owner's "select 'keep awake as long as Claude works'", for every agent the owner uses: one click in the menu.

### M.9 Risks and rollback

The app's part is thin. Without it the CLI does the same work. Revert M's commit to remove the items.

## 10. The Mac preflight (before W is written)

On the owner's Mac, with the installed 2.4.0, before W's first commit. It needs no Awake build. It checks the facts each adapter rests on, which nobody has seen on this Mac: about 55 minutes for the owner's setup (10.2), about 15 for Claude Code in a terminal (10.3), and about 20 each for Codex (10.4) and Gemini CLI (10.5) if they are installed or worth installing for the test.

### 10.1 The probe

Save as `~/awake-hook-probe.sh`, and make it executable:
```bash
#!/bin/bash
payload=$(cat)
idle=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print int($NF / 1000000000); exit}')
gp=$(ps -o ppid= -p "$PPID")
{
    printf '%s %s %s ppid=%s comm=%s gp=%s gcomm=%s idle=%ss\n' "$(date +%T)" "$1" "$2" \
        "$PPID" "$(ps -o comm= -p "$PPID")" "$gp" "$(ps -o comm= -p "$gp")" "$idle"
    printf '  env: ccsid=%s child=%s entry=%s rc=%s cursor=%s gsid=%s cfg=%s\n' \
        "${CLAUDE_CODE_SESSION_ID:-}" "${CLAUDE_CODE_CHILD_SESSION:-}" "${CLAUDE_CODE_ENTRYPOINT:-}" \
        "${CLAUDE_CODE_BRIDGE_SESSION_ID:+rc}" "${CURSOR_VERSION:-}" "${GEMINI_SESSION_ID:-}" "${CLAUDE_CONFIG_DIR:-}"
    printf '  %s\n' "${payload:0:600}"
} >> /tmp/awake-hook-probe.log
exit 0
```
Each handler runs it in K2's form: `'/Users/<you>/awake-hook-probe.sh' AGENT EVENT >/dev/null 2>&1; exit 0`, in each agent's file, with the events, matchers, `async` flags and timeouts of K.3 (in a copy of each file kept to restore). Each line shows that the probe's own `cat` returned, so stdin was closed, for the async handlers too; `comm` is the shell that ran the handler, `gcomm` the process Awake would watch (5.8), and `idle` the input idle time of W26. One handler sits at a path with a space, quoted as K2 quotes it.

### 10.2 The owner's setup: Cursor, the Claude Code extension, Cursor's agent

Put the probe in `~/.claude/settings.json` (K.3.1) and `~/.cursor/hooks.json` (K.3.3). Note the extension's version (the Extensions view, vs-code.md:35) and Cursor's.

In the Claude Code panel in Cursor:
- (a) a short prompt with two tool calls;
- (b) a permission prompt answered after a minute, and the approved command running 3 minutes;
- (c) a question (`AskUserQuestion`);
- (d) Stop in the panel in the middle of a turn, then waiting 2 minutes; and Esc on another try;
- (e) a background subagent;
- (f) `/clear`;
- (g) a plan approved with "clear context";
- (h) a `run_in_background` command;
- (i) closing the conversation's tab in the middle of a turn;
- (j) Reload Window in the middle of a turn;
- (k) quitting Cursor in the middle of a turn;
- (l) `/goal` with a 3-minute command as its second step;
- (m) Remote Control connected, with a prompt from the phone, if the owner uses it.

In Cursor's own agent, first with "Include Third-Party Plugins, Skills, and Other Configs" on (the default), then off:
- (n) a prompt with tool calls;
- (o) the Stop button in the middle of a turn;
- (p) an approval card left open 2 minutes, then answered;
- (q) a message queued while the agent works;
- (r) a plan's Build;
- (s) closing the chat, then the window;
- (t) a prompt that spawns a subagent, and one that uses parallel workers;
- (u) `/goal` with a two-step goal, `/loop 1m`, and a background shell that wakes the agent.

Record from the log:
- which events fire, in which order, and with which gaps;
- `gcomm` for the panel (expected: the bundled `claude`) and for Cursor's agent (expected: Cursor's extension host);
- the key order: Claude Code's `session_id` and `agent_id` before `tool_input`, `tool_response` and `prompt`, and where `effort` stands; Cursor's `conversation_id` first (W2);
- whether Cursor's agent runs the Claude Code probe (expected with the setting on), with which payload, and whether `conversation_id` is in it before the content (W25);
- whether the panel's hooks see `CURSOR_VERSION`, and whether `CLAUDE_CODE_SESSION_ID` equals `session_id`, at `/clear` too;
- in (d): that nothing fires, and that no `idle_prompt` comes;
- in (i), (j), (k), (s): whether `SessionEnd` or `sessionEnd` fires, and whether the continuation after (j) fires `UserPromptSubmit`;
- in (l), (g): whether the continuation fires `UserPromptSubmit`, and when its first `PreToolUse` comes after `Stop`;
- in (q) and (r): which events start the turn (expected: `afterAgentThought` without `beforeSubmitPrompt`);
- in (t): the `conversation_id` in the subagent's `preToolUse` and `postToolUse` against the parent's, and whether `subagentStop` fires with `child_conversation_id`, and where that key stands (5.7);
- in (u): whether each automatic turn fires `beforeSubmitPrompt`, or only `afterAgentThought` and `preToolUse`, and its `idle=` (B-5);
- that an empty output on `preToolUse` never blocks a Cursor tool, for the Cursor probe and, with the third-party import on, separately for the Claude-format `PreToolUse` probe; and how long a Cursor tool call waits with both (H-5);
- Cursor's user `settings.json` path, and whether the extension's `claudeCode.environmentVariables` are stored there (K1);
- that the hooks apply without restarting the panel or opening a new Cursor chat.

Then:
- **The last look in the panel** (B-7). Find the bundled `claude` from `gcomm`'s path, and run it as `<path> agents --json` during (a), during (b)'s approved command (expect `busy`), and after (d) (expect `idle`): are the panel's sessions listed at all? Run `<path> daemon status` before and after: does the call start a supervisor? Time 10 calls. Run it once more as the watcher will, through `/usr/bin/env -i HOME="$HOME" USER="$USER" PATH=/usr/bin:/bin:/usr/sbin:/sbin <path> agents --json`, and once from inside the probe hook in the background (with the hook's environment, `CLAUDE_CODE_CHILD_SESSION=1` included), and compare the outputs with the terminal run (W21, 5.8). If the sessions are not listed, Claude Code holders in the panel use B-7 (b)'s timings.
- **The input idle time** (W26): `idle=` on a typed prompt's turn-start in the panel and in Cursor's chat (expected 0 to 2 s; this sets the 5 s window, or narrows it to 3 s), on a prompt queued in the panel during a turn, on a `/loop` iteration and a background subagent's report while away from the Mac (expected large) and while the owner types in another app (expected small: the case B-5 lets through), on a phone prompt, and on a usage-limit resume if one happens.
- **`ps -o comm=`** of the panel's `claude` and of a terminal `claude`: does it print the full path that the last look runs (W21)?
- **VS Code**, if installed with Copilot: with `chat.useClaudeHooks` on, a Copilot prompt runs the Claude-format probe; record its payload's first keys (`timestamp` expected before the content, W25), then turn the setting off again.
- **The agents' own holds:** `pmset -g assertions` during (a) and (n): whether the panel spawns `caffeinate`, and what Cursor holds while its agent works (section 1).

### 10.3 Claude Code in a terminal

With the probe in `~/.claude/settings.json`, in a trusted folder:
- (a) Esc in the middle of a turn, then waiting 2 minutes; (b) Ctrl+C the same way: whether `idle_prompt` fires after each, and when;
- (c) a user `Stop` hook that sleeps 90 s and then exits 2: whether the continuation fires `UserPromptSubmit`;
- (d) a background `npm run dev`, then three prompts: what `background_tasks` looks like, and whether `idle_prompt` fires while the server runs;
- (e) `kill -9` of `claude`;
- (f) `claude agents --json` as in 10.2, and once with `disableAgentView` set; `claude daemon status` before and after the first call on a Mac with no supervisor running: does `--json` start one (B-7)? Once more with `CLAUDE_CONFIG_DIR` set for the session and not for the call: is that session listed?

### 10.4 Codex

With the probe in `~/.codex/hooks.json` (K.3.2), on Codex 0.150.0 or later:
- start `codex`: does "Hooks need review" appear? Choose "Trust all and continue", and confirm. Record the `[hooks.state."…"]` lines it writes in `config.toml` (K13: the path, the snake_case label, the indices); then change the probe's path in one handler: does the review appear again, and is the handler skipped until then?
- a prompt with tool calls; a permission prompt; a `request_user_input` question (does it fire `PreToolUse`?); Esc and Ctrl+C in the middle of a turn (does each fire `Interrupt`?); the delay from Enter to `UserPromptSubmit`;
- `gcomm`: the daemon, or `codex` with `--no-daemon`; close the terminal in the middle of a turn: does `Stop` still come?
- `codex exec "<task>"`: do the trusted hooks run?
- edit `hooks.json` while a session runs: does it pick the change up?
- the IDE extension in Cursor and the Codex app, if installed: do they run the trusted hooks, which process is `gcomm`, and do they show a review screen of their own?
- with `approvals_reviewer = "auto_review"`, a command that needs approval: `PermissionRequest` fires with no prompt shown (B-1).

### 10.5 Gemini CLI

With the probe as an extension named `awake-probe` (its `gemini-extension.json` says `"name": "awake-probe"`, never `awake`, as two folders with one name stop Gemini from starting, K14), kept in a folder outside `~/.gemini` and registered with `gemini extensions link <folder> --consent`, on v0.26.0 or later:
- `gemini --version`; does Gemini load the linked folder without `gemini extensions enable`? Then the same with only a hand-written link record (K14), after `gemini extensions uninstall awake-probe`;
- with `"security": {"allowedExtensions": ["^nomatch$"]}` in `~/.gemini/settings.json`: `gemini` still starts and skips the probe; remove the setting again;
- in an untrusted folder: a prompt with tool calls; a permission prompt approved, and one declined; `ask_user`; Esc during streaming and during a tool; `/clear`; Ctrl+C twice; `kill -9`;
- the key order (`session_id` first), `gcomm` (expected: `node`), and that nothing appears in Gemini's output;
- once with `--sandbox`: does the probe's write to `/tmp` fail, as 2.5 expects?
- if Gemini Code Assist is installed in VS Code: a prompt in its agent mode: does the probe log anything (2.1)?
- at the end, `gemini extensions uninstall awake-probe` and delete the probe's folder, so that nothing named like Awake's extension is left.

### 10.6 What changes the design

If a fact differs from sections 2 or 5, the design changes before W is written. Examples:
- the panel's hooks miss an event the design uses, or its sessions are not in `claude agents --json` (then those holders are `unlisted`, with B-7 (b)'s timings), or `claude agents --json` starts a supervisor (then B-7 (b), or the last look only while one runs);
- Cursor's subagents carry their own `conversation_id` (then `subagentStop` as `agent-end`, 5.7), or Cursor's automatic turns fire `beforeSubmitPrompt` (then B-5's list and W26's Cursor window change);
- Cursor's agent runs the Claude Code handlers without `conversation_id` before the content (then W25 needs another test, such as `CURSOR_VERSION` set without `CLAUDE_CODE_SESSION_ID`);
- an empty output blocks a Cursor tool (then the Cursor adapter leaves `preToolUse` out, and the README says to turn off Cursor's third-party import, as Awake's Claude Code `PreToolUse` handler would block there too; no `{}` and no `permission` field, whose effect on Cursor's schema and approvals is not known);
- `agent_id` or `conversation_id` after the content keys, or `gcomm` not the expected process;
- Codex's extension or app does not run the trusted hooks (then those surfaces are documented as manual);
- the input idle time does not tell a typed prompt from others (then the stop pause lifts only with `Resume now`, and B-5 says so), or a typed prompt's hook comes later than the window (then the window grows for that agent).

## 11. Order, branch and release

1. **The preflight** (section 10), any time; 10.2 first.
2. **W**, in two commits on `dev-2.5` (R-1): the fast path, the adapter tables and the watcher with section 12n, then the status and the JSON. Each passes the whole self-test in the emulation and on CI's macOS.
3. **K**, in two commits with section 12o: the Claude Code and Cursor adapters with the installer and uninstaller steps (the owner's setup), then Codex and Gemini CLI.
4. **M** in one commit, with its checks if possible.
5. **After 2.4.0 has shipped,** merge `dev` into `dev-2.5`, add the CHANGELOG entries in one commit (R-1), merge into `dev`, and write `qa-2.5.0.md` from W.6, K.6 and M.6. Then the release, as 2.5.0. No Upgrade note is needed: nothing changes until the user turns the feature on, and the helper does not change.

W and K are independent, except that 12n's checks call `--agent-hook` directly, without K, and 12o's checks 13 and 19 need W. M needs both. Nothing here touches the 2.4.0 QA build.

## 12. Risks across items, and rollback

- **Users who never turn it on** see no change. The fast path runs only for `--agent-hook`, and the new JSON fields are `null`. The help gets one option.
- **A wrong turn of the rules could keep a closed Mac awake in a bag.** With the 12-hour cap gone (B-2), the guards against it are:
  - the helper's own guardrails, unchanged (heat with the lid closed after two checks, battery);
  - the watcher's PID tie, and the replacement of a stuck watcher (W27);
  - the holder rules: the 15-minute idle limit, the quiet limit on the last look, and tombstones that a late heartbeat cannot lift;
  - no automatic session starts while the lid is closed and closing it sleeps the Mac (B-11), and none during a pause after the user's stop (B-5), which the stop itself writes, which a start by hand cannot clear, and which only a turn within seconds of the user's own input lifts.
  A watcher that is alive and wrong is not bounded by root (B-12); 12n's checks guard each rule, and B-12 (b) adds a root-enforced bound if the owner wants one. The README's safety warnings (74-89) apply in full, and the new section says so.
- **A wrong turn the other way** sleeps the Mac while an agent works. That is a lost hour, not a hazard. Mac QA covers the cases the design knows of.
- **Four agents' hooks change on their own schedules.** The design uses documented events and fields, except Cursor's key order, which section 10 records. The README names minimum versions, and section 10's probe can be rerun after an update. An agent that breaks can be turned off on its own (`--ai-hooks off --agent X`) while the others go on.
- **Editing other tools' files.** K5's refusals, Codex's positions and trust (K.3.2), and Gemini's own folder (H-4) keep the edits small and reversible.
- **Rollback of the whole feature:** `awake --ai-hooks off` for one user. Reverting W, K and M removes it for everybody. The helper, the protocol and the session files of other sessions are unchanged, so a revert needs no migration.

## 13. Not in this plan (later)

- More adapters on the same verbs (2.6): GitHub Copilot first (one file covers Copilot CLI and VS Code's Copilot agent), then opencode and Amp (a small plugin in TypeScript each), Cline, and Junie CLI. Release 1 already makes the Claude Code handlers stand down for VS Code's payloads when `chat.useClaudeHooks` is on (W25), so a Copilot adapter adds only its own file.
- Antigravity, as an experiment, once a preflight shows which events load (2.5); and Windsurf and Devin, once Devin Desktop's hooks settle.
- Following an agent's own idle-sleep request (O6), opt-in and Zed first, which documents its hold.
- Polling `claude agents --json` after an interrupt (B-7 (c)), which matters most in the extension, once section 10 and a release with the last look have shown its cost.
- An MCP tool for "keep awake after my reply" (O5).
- Keeping the Mac awake for the whole Remote Control connection (B-9 (c)).
- A rolling root-enforced limit as a second bound under the 365 days (B-12 (b)).
- Locking the screen when the lid closes during an automatic session, as Adrafinil does by default (Models/AdrafinilSettings.swift:39-41), if W.6 item 23 shows that macOS does not ask for the password, and a chime on lid close (LidActionDecider.swift:37-44).
