# The AI preflight kit

This folder makes section 10 of
[the agent plan](../../docs/plans/agent-keep-awake.md), "The Mac preflight",
quick and safe to run on your Mac before any of the new code is written. It
puts a small probe into each AI agent's hook file, logs when and how each
hook runs, checks the lease with today's Awake, and bundles everything into
one text file for you to read and send back.

**The probe logs no prompt text.** It never logs what you type, tool inputs
or outputs, file contents or Claude's replies. From each hook's input it
keeps only the names of the top-level fields and where they stand, short ids
(session, agent and conversation ids), and type names such as the event,
the tool name (`Bash`, `Read`) and the permission mode. You can read every
log before you send it.

What the kit changes, and how it undoes it:

- It adds its handlers to each agent's user-level hook file, exactly as
  section K.3 lists Awake's own (same events, matchers, timeouts and
  positions), after a timestamped backup that is never overwritten.
  `restore` takes out exactly its own entries and puts back the original
  bytes when nothing else changed; if you or the agent changed something
  else meanwhile, it keeps that and says so.
- It refuses to touch a file it cannot parse (comments, trailing commas) or
  one that changes while it edits it. It writes through symlinks and keeps
  the file's mode.
- For Gemini CLI it links an extension named `awake-probe` from
  `~/awake-preflight/gemini-extension`, as 10.5 asks.
- It never edits Codex's `config.toml`, where Codex keeps its trust, and
  never a project's files.
- Everything else lives in `~/awake-preflight`: the probe, a copy of it in
  `~/awake-preflight/probe with space` (10.1 asks for one handler at a path
  with a space), the logs, the backups, the lease results.
- It uses no network. Only the lease check uses `sudo`, exactly as 10.6
  does: `sudo -n` with Awake's installed helper.

## Before you start (5 minutes)

You need the Command Line Tools (`xcode-select -p` prints a folder; if not,
run `xcode-select --install`), Awake 2.4.0 installed with password-free mode
on, and the Mac plugged in.

Open Terminal and paste these two lines. Paste them again in every new
Terminal window you use for the kit:

```zsh
K=~/Dropbox/Work/LaTeX/awake/tools/ai-preflight
alias pf="/bin/bash $K/probe.sh"
```

Two habits make the results easy to read later:

- **Mark each step** just before you do it: `pf mark "10.2 a"`. The mark
  goes into the log with the time. Add what you saw in a few words after the
  step: `pf mark "10.2 b: approved after 60 s"`.
- **Note what the screen shows** in `~/awake-preflight/notes.txt` (any
  editor), for things the log cannot see: a prompt or card that appeared,
  an error, extra text in the conversation, whether something continued by
  itself. `collect.sh` includes the file. You do not need to read the log
  yourself.

To watch the log live, keep a second Terminal window open with `pf tail`.

When you are away from the Mac for a step, do not touch the keyboard or the
trackpad: the probe records how long ago you last used them.

## Order

| Step | What | Time |
|---|---|---|
| 1 | 10.2: Cursor, the Claude Code panel, Cursor's own agent | 90 to 110 min |
| 2 | 10.6: the lease, with today's Awake | 30 min |
| 3 | 10.3: Claude Code in Terminal, headless, the Desktop app | 30 min |
| 4 | 10.4: Codex, if installed | 25 min |
| 5 | 10.5: Gemini CLI, if installed | 25 min |
| 6 | Collect, send, restore | 10 min |

Section 11 says 10.2 and 10.6 come first. Each step can be done on another
day: the probe stays in place until you restore it, and each step starts a
new log. A step you skip leaves that agent or surface out of the first
release, so note "skipped" rather than guessing.

## 1. 10.2: Cursor, the Claude Code panel, Cursor's own agent

### Set up (10 minutes)

1. Make a scratch folder: `mkdir -p ~/awake-preflight/scratch`. In Cursor,
   open it (File > Open Folder). Open the Claude Code panel and start a
   conversation, and open a Cursor Agent chat and send it one prompt ("What
   is 2 + 2?"), so that both are already running when the probe goes in.
2. Install the probe for Claude Code and Cursor:
   `pf install claude cursor --extra`. (`--extra` adds one handler beyond
   K.3, Cursor's `subagentStop`, which only 10.2 (t) needs.)
   Then `pf status` should say `on` for both.
3. Start this step's log: `pf new-run 10.2-panel`.
4. Open https://cursor.com/docs/agent/hooks and
   https://cursor.com/docs/reference/third-party-hooks. Skim them against
   the plan's [CD] citations in sections 2.4 and K.3.3 (the events, the
   `{"version":1,"hooks":{...}}` format, the third-party mapping table). In
   notes.txt write today's date and "same" or what differs.
5. In notes.txt write: Cursor's version (Cursor > About Cursor), the Claude
   Code extension's version (the Extensions view), and Cursor's agent run
   mode (Cursor Settings > Agents). `collect.sh` also looks these up.

### In the Claude Code panel (35 minutes)

Before each step type `pf mark "10.2 X"` in Terminal, then go back to
Cursor.

- **(a)** Ask: "Run `sleep 30` in the shell, then list the files here."
  While it sleeps, in Terminal: `pf assertions "10.2 a"` and `pf last-look`.
  Note: nothing, unless something looks odd. (The first prompt after the
  install also shows whether the panel picked the hooks up without a
  restart.) If `pf last-look` says it found no claude, give it the path
  that the log shows as `gcomm=` for this step, for example
  `pf last-look ~/.cursor/extensions/…/claude`, here and below.
- **(b)** Ask: "Run `sleep 180 && echo done` in the shell with a timeout
  of 5 minutes." (Without one, Claude Code stops a command that starts
  with `sleep` after 2 minutes.) When the permission prompt appears, wait
  one full minute, then approve. While the command runs, in Terminal:
  `pf last-look` (the panel's session should be listed as busy). Mark when
  you approve: `pf mark "10.2 b approved"`.
- **(c)** Ask: "Use AskUserQuestion to ask me whether I prefer tea or
  coffee, then stop." Answer after about 30 seconds.
- **(d)** Ask: "Run `sleep 120` in the shell." After 10 seconds press the
  panel's Stop button. Wait 2 minutes without typing anything anywhere.
  Then in Terminal: `pf last-look` (the session should be idle). Then ask
  the same again and press Esc after 10 seconds instead. Note: anything the
  panel showed after the stop.
- **(e)** Ask: "Start a background subagent that runs `sleep 60` and then
  reports the date. Tell me when you have started it." Keep your hands off
  the Mac until its report arrives. Then ask the same again, and this time
  type something in another app (Notes, say) until the report arrives.
- **(f)** Type `/clear`.
- **(g)** Switch the panel to plan mode, and ask: "Plan how to add the line
  hello to /tmp/awake-plan-test.txt, then do it." When the plan appears,
  approve it with the option that clears the context. Note: whether the
  work then started by itself. (If no such option shows, recent versions
  hide it unless `"showClearContextOnPlanAccept": true` is in your
  settings; you can add that line to `~/.claude/settings.json`, and restore
  keeps it, or note "no clear-context option" and go on.)
- **(h)** Ask: "Run `sleep 300` with run_in_background, then answer right
  away." Wait one more minute after the answer.
- **(i)** Ask: "Run `sleep 60`." After 10 seconds close the conversation's
  tab.
- **(j)** In a new conversation ask: "Run `sleep 60`, then say done." After
  10 seconds run Developer: Reload Window (Cmd+Shift+P). Note: whether the
  step went on by itself after the reload.
- **(k)** Ask: "Run `sleep 60`." After 10 seconds quit Cursor (Cmd+Q), then
  open it again.
- **(l)** Type: `/goal First run date, then run sleep 180 with a timeout of
  5 minutes, then say done.` Wait until it is done.
- **(m)** Only if you use Remote Control: connect it (`/remote-control`)
  and, from the phone, ask it to run `sleep 30`. Otherwise note "no Remote
  Control".

### In Cursor's own agent (40 minutes)

Start a new log: `pf new-run 10.2-cursor-agent`. Check that "Include
Third-Party Plugins, Skills, and Other Configs" is on in Cursor Settings >
Agents > Third-Party Imports, as it is by default. Run (n) first in the
Agent chat you opened before the install (that shows whether Cursor picked
the hooks up without a new chat), then use a new Agent chat for each step,
and mark each step as before.

- **(n)** Ask: "Run `sleep 20` in the terminal, then list the files here."
  While it runs: `pf assertions "10.2 n"`.
- **(o)** Ask: "Run `sleep 60` in the terminal." Press Stop after 10
  seconds.
- **(p)** Ask for a command that needs your approval in your run mode, for
  example "Run `sleep 30` in the terminal". Leave the approval card open 2
  minutes, then approve. If no card appears, note "no approval card".
- **(q)** Ask: "Run `sleep 60` in the terminal." While it runs, send a
  second message: "Then print the date."
- **(r)** Switch to Plan mode, ask "Plan adding the line hello to
  /tmp/awake-plan-test.txt", then press Build.
- **(s)** Ask: "Run `sleep 60` in the terminal." After 10 seconds close the
  chat. Then start another chat with the same request and close the whole
  window (Cmd+Shift+W) after 10 seconds. Open the scratch folder again.
- **(t)** Ask: "Use a subagent to count the files in this folder." Then, if
  your Cursor offers parallel workers, ask for a small task with two
  parallel workers.
- **(u)** Three automatic turns, each while you keep your hands off the
  Mac: type `/goal First run date, then run sleep 30, then say done.`; then
  `/loop 1m print the date`, let it run three times, then stop it; then ask
  "Start `sleep 60; echo finished` as a background shell, and tell me when
  it has finished."

Then turn "Include Third-Party Plugins, Skills, and Other Configs" off, run
`pf new-run 10.2-cursor-agent-no-third-party`, and do (n) to (u) again
(about 15 minutes). Turn the setting back on afterwards.

If your usual run mode is not "Auto-Run in Sandbox", switch to it, run
`pf new-run 10.2-sandbox`, and do at least (n) and (o) again; note whether
the probe lines arrive (`pf tail`). Switch back afterwards.

### The other surfaces (15 minutes)

Each ships only if it runs here; skip what you do not have and note it.

- **(v)** The `agent` CLI in Terminal, if installed: `pf new-run 10.2-v`,
  then in the scratch folder run `agent`, ask "Run `sleep 20`, then list the
  files", then ask the same and press Ctrl+C after 10 seconds.
- **(w)** VS Code with the Claude Code extension, if installed: `pf new-run
  10.2-w`, then do (a) and (d) in its Claude Code panel.
- **(x)** Cmd+K: `pf new-run 10.2-x`. In a scratch file, select a line,
  press Cmd+K and ask "add a comment above this line". Then once more with
  "add a comment with the first line of README.md" (so that it has to read
  a file).
- **(y)** A local agent in the Agents Window, if you use it: `pf new-run
  10.2-y`, then (n) there.
- **(z)** `claude` in Cursor's integrated terminal: `pf new-run 10.2-z`. In
  Cursor's terminal, in the scratch folder, run `claude`, ask "Run `sleep
  60`", press Esc after 10 seconds, and wait 2 minutes without typing.

### The remaining checks (15 minutes)

- **The last look from inside a hook** (W21): `pf last-look-hook on`, then
  one prompt in the Claude Code panel ("What is 2 + 2?"), then
  `pf last-look-hook off`.
- **The input idle time across the lid and a sleep** (W31, B-18): start a
  lid-closed Awake session, `awake --backend awake --duration 15m`, and in
  a second Terminal window run `pf idle-watch 900 15`. In the first window:
  `pf mark "B-18 lid closed"`, close the lid for 3 minutes, open it, and
  `pf mark "B-18 lid opened"`. Then `awake --stop` (a lid-closed session
  keeps the Mac from sleeping, even from Apple menu > Sleep), `pf mark
  "B-18 sleep"`, choose Apple menu > Sleep, wait 2 minutes, wake the Mac,
  and `pf mark "B-18 woke"`. Let `idle-watch` finish or press Ctrl+C.
- **More turns you did not type** (W26), in the Claude Code panel: ask
  "Run `sleep 30`", and while it runs send a second message, "Then print
  the date"; then type `/loop 1m print the date`, keep your hands off the
  Mac for three runs, and stop it (Esc, or close the conversation's tab).
- **VS Code with Copilot**, if installed: turn on `chat.useClaudeHooks` in
  VS Code's settings, run `pf new-run 10.2-copilot`, send one Copilot agent
  prompt, then turn the setting off again.

The probe records the rest of 10.2's list by itself: which events fire and
in what order, `gcomm`, the field order, `CURSOR_VERSION` and
`CLAUDE_CODE_SESSION_ID` in each hook, `idle=` on every prompt, and how long
each hook ran.

## 2. 10.6: the lease, with today's Awake (30 minutes)

This needs no probe. Plug the Mac in, keep the lid open, make sure no Awake
session runs (`awake --status`), and disconnect any external display (with
one, closing the lid does not sleep the Mac). Then run, under Apple's bash
as 10.6 asks:

```zsh
/bin/bash $K/lease-check.sh
```

- It first runs (f), the `-ef` test, by itself.
- It asks "Start?": answer `y`. Then it runs (a), (b), (d) and (e) by
  itself, about 10 minutes: lid-closed sessions of 120 seconds tied to a
  stand-in process and renewed every 30 seconds with `sudo -n` and the
  helper, exactly as 10.6 writes them. Keep the lid open meanwhile. It
  runs the installed copy of `awake` (the one the `awake` command runs),
  whose own messages appear as they would in Terminal; the results file
  records `awake --status` after each start.
- **(c)**: it asks "Run (c) now?": answer `y`. When it says **"Close the
  lid NOW"**, close the lid and leave it closed for 5 minutes. Open it, log
  in if asked, and press Enter.
- **(g)**: the same, with the lid closed for 9 minutes.

It never starts while another session runs, asks before it starts one,
and on exit, also on Ctrl+C (pressed once or more), it stops its own
session and ends its helper processes. The results go to
`~/awake-preflight/lease/`; each step says PASS or FAIL and why. You can
run one step alone: `/bin/bash $K/lease-check.sh c` (or `g` or `f`).

Note in notes.txt: anything unexpected on screen, and whether the Mac
seemed asleep when you opened the lid in (c) and (g).

## 3. 10.3: Claude Code in Terminal (30 minutes)

`pf new-run 10.3`. The probe for Claude Code is still in place from 10.2.
Use the scratch folder; at the first `claude` there, accept the trust
question. Before you start `claude`, type `tty` in that window and note the
name (for example `/dev/ttys003`).

- **(a)** Start `claude`, ask "Run `sleep 60`", press Esc after 10 seconds,
  then wait 2 minutes without typing.
- **(b)** The same with Ctrl+C instead of Esc (once; a second Ctrl+C quits).
- **(c)** First leave Cursor's chats and the Claude Code panel idle (or
  quit Cursor): every program that reads `~/.claude/settings.json` runs
  this hook. Then `pf stop-block on`, and in `claude` in Terminal ask "Say
  hello." The hook holds the end of that turn for 90 seconds, then Claude
  goes on and runs `date`. When it is done, `pf stop-block off` right away.
  Note: whether Claude went on. (The hook acts only for `claude` in
  Terminal, only on the first Stop of each session, and only for 20 minutes
  after `on`; the log says why it let any other Stop through.)
- **(d)** Ask: "Start `python3 -m http.server 8765 --bind 127.0.0.1` in
  the background, then answer." Then send three short prompts a minute
  apart ("What is 2 + 2?"), and wait 2 more minutes. Then ask it to stop
  the server.
- **(e)** In another window: `ps -t ttys003 -o pid,comm` (your tty name
  without `/dev/`) lists that window's processes; `kill -9` the `claude`
  one (its name may be a version number).
- **(f)** In another window: `pf last-look terminal` (`terminal` means the
  `claude` you run in Terminal: it looks on the PATH, then in
  `~/.local/bin` and `~/.claude/local`), then
  `pf last-look terminal --no-agent-view` (the same with
  `disableAgentView` set). If you are willing to log in once more: start
  `CLAUDE_CONFIG_DIR=$HOME/.claude-preflight claude` in one window and run
  `pf last-look terminal` in another; note whether it lists that session
  (the log says how many sessions it saw). Delete `~/.claude-preflight`
  afterwards.
- **(g)** If the Desktop app is installed: `pf new-run 10.3-desktop`. In its
  Code tab, a local session in the scratch folder: ask "Run `sleep 20`, then
  list the files"; ask for a command that needs permission and approve it;
  ask "Run `sleep 60`" and press Stop after 10 seconds.
- **(h)** `pf new-run 10.3-headless`, then in Terminal, in the scratch
  folder (headless mode cannot ask for permission, so the two commands are
  allowed up front):

  ```zsh
  claude -p "Run date, then list the files here." --allowedTools "Bash(date),Bash(ls),Bash(ls *)"; pf mark "10.3 h exited $?"
  ```

## 4. 10.4: Codex (25 minutes)

If Codex is not installed, note "no Codex" and skip this.

1. `pf install codex`, then `pf new-run 10.4`.
2. `codex --version` and `codex features list | grep -i hook`: note both.
3. Before trusting, in the scratch folder (which is not a git repository,
   so `codex exec` needs `--skip-git-repo-check` or it stops before the
   turn starts):

   ```zsh
   cd ~/awake-preflight/scratch && codex exec --skip-git-repo-check "Run date."; pf mark "10.4 exec before trust, exit $?"
   ```

   The log should show nothing from Codex, and the exit should be 0.
4. Start `codex` in the scratch folder. Note whether "Hooks need review"
   appears. Choose "Trust all and continue", and confirm.
5. `pf codex-touch` (it points one handler, Stop, at the other copy of the
   probe, so Codex sees a changed hook). Quit and start `codex` again: does
   the review come back? Trust again. Run `pf install codex` to put the
   handler back, then start `codex` and trust once more.
6. In `codex`: ask "Run `sleep 20`, then list the files" and keep your
   hands off the Mac for a few seconds after Enter (the log's `idle=` then
   shows how long after Enter the hook ran); ask for a command that needs
   your approval and approve it; ask "Ask me a question with
   request_user_input, then stop", and answer; ask "Run `sleep 60`" and
   press Esc after 10 seconds; the same with Ctrl+C.
7. Ask "Run `sleep 60`" and close the Terminal window after 10 seconds.
   Then start `codex --no-daemon` in a new window and ask "Run date".
   Note whether any text appeared in the conversation that you did not
   expect.
8. After trusting, the same command again:

   ```zsh
   cd ~/awake-preflight/scratch && codex exec --skip-git-repo-check "Run date."; pf mark "10.4 exec after trust, exit $?"
   ```

   Now the log should show Codex's hooks.
9. Ask "Use a subagent to run `sleep 60`." Press Esc while the subagent
   works.
10. While `codex` runs, `pf codex-touch` in another window, then ask "Run
    date" in `codex`: note whether it showed the review or picked up the
    change. If the review appears, or Stop lines stop coming (the changed
    handler is skipped until you trust it), Codex picked the change up; if
    Stop lines still come with `copy=main`, it did not; if they come with
    `copy=space` and no review, it ran the changed handler untrusted (note
    that). `pf install codex` to put it back.
11. If the Codex extension in Cursor or the Codex app is installed: a prompt
    with a tool call in each; note whether they showed a review screen.
12. Start `codex -c approvals_reviewer='"auto_review"'` and ask for a
    command that would need approval. Note whether you were asked.

`collect.sh` lists the trust entries Codex wrote. The kit never edits
`config.toml`.

## 5. 10.5: Gemini CLI (25 minutes)

If Gemini CLI is not installed, note "no Gemini CLI" and skip this.

1. `pf install gemini` (it links an extension named `awake-probe` from
   `~/awake-preflight/gemini-extension` with `gemini extensions link
   --consent`), then `pf new-run 10.5`. Note `gemini --version`.
2. `mkdir -p ~/awake-preflight/scratch-gemini && cd
   ~/awake-preflight/scratch-gemini`. Start `gemini`; when it asks whether
   to trust the folder, say no. Ask "What is 2 + 2?" and quit. Note whether
   the probe logged it without `gemini extensions enable`.
3. `pf gemini-record` (it uninstalls the link and writes the link record by
   hand). Start `gemini`, ask "What is 2 + 2?", quit: logged?
4. `pf gemini-allowlist on`, start `gemini`: it should start and skip the
   probe. Quit, then `pf gemini-allowlist off`.
5. In the untrusted folder: ask "Run `sleep 10`, then list the files";
   approve one permission prompt and decline another; ask "Use ask_user to
   ask me tea or coffee"; press Esc while it streams a reply and once while
   a tool runs; type `/clear`; press Ctrl+C twice to quit. Start it again
   and `kill -9` it from another window (`pgrep -fl gemini`). Note: whether
   anything from the probe appeared in Gemini's output.
6. `gemini --sandbox`, ask "Run date": note whether it worked.
7. `gemini -p "Run date."`
8. If Zed or a JetBrains IDE is installed: one prompt through Gemini CLI's
   ACP mode there. If Gemini Code Assist is installed in VS Code: one
   prompt in its agent mode.
9. `pf restore gemini`, as 10.5 asks, so that nothing named like Awake's
   extension stays behind. The logs, and the probe's entries as they were
   installed, stay for the final collect.

## 6. Collect, send, restore (10 minutes)

1. Collect, before you restore (so that the installed entries are listed):

   ```zsh
   /bin/bash $K/collect.sh
   ```

   It prints where it wrote the file, in `~/awake-preflight/results/`. Read
   it, then send it. It has the versions, the probe's own hook entries (not
   your other settings), the logs and a summary of them, your notes and
   the lease results, with your home folder written as `~`.
2. Restore every agent's files: `pf restore all`, then `pf status`: every
   agent should read `off`, `no file` or `not installed`. The Gemini
   extension's link and folder are removed too.
3. Optional: Codex's trust entries for the probe stay in
   `~/.codex/config.toml`. They are harmless; you can delete the
   `[hooks.state."…/.codex/hooks.json:…"]` tables by hand.
4. After the results have arrived: `pf purge` deletes `~/awake-preflight`
   (it refuses while any agent still has the probe).

If anything misbehaves at any point, `pf restore all` takes the probe out
at once. Every file's original is in `~/awake-preflight/backups/`.

## If the kit refuses

- "is not plain JSON": the file has comments or trailing commas. Add the
  handlers by hand from `pf print claude` (or `cursor`, `codex`), or make
  the file plain JSON first.
- "changed while the kit was editing it": another program wrote the file at
  the same moment. Run the command again.
- "is read-only": make the file writable, or add the handlers by hand.
- "lone surrogate escape": the file holds text the kit cannot write back
  exactly. Add the handlers by hand from `pf print`.
- "probe handler(s) from another preflight folder": an earlier install used
  another `AWAKE_PREFLIGHT_DIR`. Run the restore command the message shows.
- "python3 was not found" or "Command Line Tools are not installed": run
  `xcode-select --install`.

## What is in this folder

| File | What it does |
|---|---|
| `probe.sh` | The main command: install, restore, status, marks, logs, and the helpers named above (`pf help` lists them) |
| `kit.py` | The JSON side of `probe.sh` and `collect.sh`, run with `/usr/bin/python3` |
| `awake-hook-probe.sh` | The probe each handler runs, in K2's form: `'<path>' AGENT EVENT >/dev/null 2>&1; exit 0` |
| `awake-hook-probe-facts.py` | Reads a hook's input with a time limit and prints only the privacy-safe facts |
| `awake-stop-block.sh` | 10.3 (c)'s Stop hook, put in place by `pf stop-block on` |
| `lease-check.sh` | 10.6 |
| `collect.sh` | Bundles the results into one file |
| `tests/run-tests.sh` | The kit's own tests, with stand-ins for the agents and Awake (runs on Linux too) |

The probe always exits 0 at once and prints nothing, so an agent never sees
it fail or say anything. It reads the input idle time first, then its input
with a time limit of 0.8 s, and logs whether the input ended ("stdin eof
after N ms", the hard gate of 10.1) or was still open ("stdin STILL OPEN");
it writes those facts at once, and the processes and the environment after
them, each in one write. If Python cannot run there, it reads the input
itself and still logs how long that took. A watchdog stops it after 3 s. If
it cannot write its log (under a sandbox), it writes to a file in `$TMPDIR`
or `/tmp` instead, and `collect.sh` gathers those too.
