#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# Tests for tools/ai-preflight, with stand-ins, so that they run on Linux
# (they are written to run on a Mac as well):
#
#   tests/run-tests.sh [probe] [install] [lease] [collect] [lint]
#
# BASH32=/path/to/bash-3.2 also runs the scripts under that bash (macOS's
# /bin/bash is 3.2.57). SHELLCHECK=/path/to/shellcheck names shellcheck when
# it is not on the PATH. AWAKE_PREFLIGHT_PYTHON=/path/to/python3 runs the kit
# with another Python (the Mac's Command Line Tools have 3.9). Stand-ins for
# awake, the helper, sudo, pmset, log, /usr/bin/time, gemini and claude are
# in tests/mock-bin. Each test uses its own temporary HOME; nothing outside
# it is touched but /tmp's write-test file, which the probe always tries,
# and the probe's /tmp fallback log, which one test makes and removes.

set -uo pipefail

HERE=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
KIT=$(dirname -- "$HERE")
MOCK=$HERE/mock-bin
PAY=$HERE/payloads
BASH5=$(command -v bash)
BASH32=${BASH32:-}
WORK=$(mktemp -d "${TMPDIR:-/tmp}/preflight-tests.XXXXXX")
REAL_HOME=$HOME
PASS=0
FAIL=0
N=0
export AWAKE_PREFLIGHT_TEST=1

pass() {
    PASS=$((PASS + 1))
    printf 'ok    %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL  %s\n' "$1"
    if [[ -n "${2:-}" ]]; then
        printf '%s\n' "$2" | sed 's/^/      /' | head -n 40
    fi
}

# check NAME COMMAND...: passes when the command succeeds.
check() {
    local name=$1
    shift
    if "$@"; then
        pass "$name"
    else
        fail "$name"
    fi
}

has() { grep -qF -- "$2" "$1"; }
# The permission bits of a file, as GNU or BSD stat prints them.
mode_of() { stat -c %a "$1" 2>/dev/null || stat -f %Lp "$1"; }
count_files() { find "$1" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' '; }
# The last of its arguments in sort order (the newest timestamped file).
newest() { printf '%s\n' "$@" | sort | tail -n 1; }
hasnt() { ! grep -qF -- "$2" "$1"; }
same() { cmp -s "$1" "$2"; }

new_home() {
    N=$((N + 1))
    HOME=$WORK/home$N
    mkdir -p "$HOME"
    export HOME
    unset CLAUDE_CONFIG_DIR CODEX_HOME GEMINI_CLI_HOME AWAKE_PREFLIGHT_DIR
    export AWAKE_PREFLIGHT_GEMINI=""
    export TMPDIR=$WORK/tmp$N
    mkdir -p "$TMPDIR"
    PRE=$HOME/awake-preflight
    LOG=$PRE/logs/current.log
}

# kitsh [SHELL] ARGS: probe.sh under bash 5, or under $SH when set.
kitsh() {
    "${SH:-$BASH5}" "$KIT/probe.sh" "$@"
}

pyq() {
    # pyq FILE EXPR: evaluates EXPR with d = the JSON in FILE; true on truthy.
    python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
sys.exit(0 if eval(sys.argv[2]) else 1)' "$1" "$2"
}

ms_now() {
    python3 -c 'import time; print(int(time.time() * 1000))'
}

# --------------------------------------------------------------- the probe

# run_hook PROBE AGENT LABEL PAYLOAD [INTERPRETER]: runs a handler in K2's
# form through sh -c, as Claude Code does; prints the handler's output.
run_hook() {
    local cmd
    cmd="'$1' $2 $3 >/dev/null 2>&1; exit 0"
    if [[ -n "${5:-}" ]]; then
        cmd="'$5' $cmd"
    fi
    sh -c "$cmd" <"$4" 2>&1
}

block_of() {
    # block_of AGENT LABEL: the START line and the details of the last run.
    python3 - "$LOG" "$1" "$2" <<'EOF'
import re, sys
log, agent, label = sys.argv[1:4]
lines = open(log, encoding="utf-8", errors="replace").read().splitlines()
pid = None
for line in lines:
    m = re.match(r"^\S+ (\S+) (\S+) pid=(\d+) START$", line)
    if m and m.group(1) == agent and m.group(2) == label:
        pid = m.group(3)
if pid:
    for line in lines:
        if line.endswith("pid=%s START" % pid) or line.startswith("  [%s] " % pid):
            print(line)
EOF
}

test_probe_payloads() {
    local interp=${1:-} tag=${2:-bash5} f name agent label out st blk
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    local P=$PRE/awake-hook-probe.sh
    for f in "$PAY"/*.json; do
        name=$(basename "$f" .json)
        agent=${name%%-*}
        label=${name#*-}
        if [[ "$name" == cursor-as-claude-PreToolUse ]]; then
            agent=claude
            label=PreToolUse.cursor
        fi
        out=$(run_hook "$P" "$agent" "$label" "$f" "$interp")
        st=$?
        blk=$WORK/blk.$N.$name
        block_of "$agent" "$label" >"$blk"
        if [[ $st -ne 0 || -n "$out" ]]; then
            fail "probe[$tag] $name: exit 0, no output" "exit $st, output: $out"
            continue
        fi
        if ! has "$blk" " $agent $label pid=" || ! has "$blk" "] stdin eof after" ||
            ! has "$blk" "] json object" || ! has "$blk" "] done t0=" ||
            ! has "$blk" "] proc ppid=" || ! has "$blk" "] w2 cut="; then
            fail "probe[$tag] $name: a full block" "$(cat "$blk")"
            continue
        fi
        pass "probe[$tag] $name: a full block"
    done
    # Expected facts, from the plan's sections 2 and K.3.
    expect() {
        local agent=$1 label=$2 blk
        shift 2
        blk=$WORK/exp.$N.$agent.$label
        block_of "$agent" "$label" >"$blk"
        local s
        for s in "$@"; do
            if ! has "$blk" "$s"; then
                fail "probe[$tag] facts of $label" "missing: $s
$(cat "$blk")"
                return
            fi
        done
        pass "probe[$tag] facts of $label"
    }
    expect claude PreToolUse "values session_id=cc-sess-1 prompt_id=550e8400-e29b-41d4-a716-446655440000 permission_mode=default effort=level:high hook_event_name=PreToolUse agent_id=agent-abc123 agent_type=Explore tool_name=Bash tool_use_id=toolu_01ABC" \
        "content first=tool_input@" "ids before-content: session_id@1 prompt_id@26 effort@210 agent_id@267 | after-content: -" \
        "w2 cut=tool_input@" "session_id=cc-sess-1 agent_id=agent-abc123 conversation_id=- tool_name=Bash w25-key-sign=no bg-pattern=no"
    expect claude Stop "background_tasks=1[shell/running] session_crons=1" "content first=last_assistant_message@" "bg-pattern=yes" "stop_hook_active=true"
    expect claude StopFailure "error=rate_limit"
    expect claude UserPromptSubmit "w2 cut=prompt@" "agent_id=-" "hook_event_name=UserPromptSubmit"
    expect claude Notification.idle_prompt "notification_type=idle_prompt" "content first=message@"
    expect claude SessionStart.clear "source=clear" "content first=none"
    expect claude SubagentStop 'agent_type="" ' "background_tasks=0[] session_crons=0"
    expect cursor beforeSubmitPrompt "ids before-content: conversation_id@1 generation_id@" "| after-content: session_id@" \
        "w25-key-sign=yes(conversation_id@1)" "cursor_version=3.12.17" "content first=prompt@"
    expect cursor stop "status=aborted loop_count=0" "content first=none"
    expect cursor postToolUseFailure "failure_type=timeout" "is_interrupt=true"
    expect cursor subagentStop "child_conversation_id=child-conv-9" "subagent_type=generalPurpose status=completed"
    expect cursor sessionEnd "reason=window_close" "is_background_agent=false" "final_status=completed"
    expect claude PreToolUse.cursor "w25-key-sign=yes(conversation_id@1)"
    expect gemini BeforeAgent "ids before-content: session_id@1 timestamp@" "w25-key-sign=yes(timestamp@" "content first=prompt@"
    expect gemini Notification "notification_type=ToolPermission"
    expect gemini SessionEnd "reason=exit"
    expect codex SessionEnd "reason=other" "ids before-content: session_id@1 | after-content: -"
    expect codex Stop "content first=last_assistant_message@" "turn_id="
    expect codex PreToolUse.request_user_input "tool_name=request_user_input" "agent_id=agent-7" "turn_id=01a0090b-1d8e-7062-8c92-3e312d3150df"
    expect codex Interrupt "hook_event_name=Interrupt" "content first=none"
    expect codex SubagentStop "agent_id=agent-7 agent_type=worker" "content first=last_assistant_message@" \
        "ids before-content: session_id@1 turn_id@"
    expect codex PreToolUse "tool_name=Bash" "tool_use_id=call_2" "w2 cut=tool_input@"
    blk=$WORK/exp.$N.pf
    block_of claude PostToolUseFailure >"$blk"
    check "probe[$tag] an error message is not logged outside StopFailure" hasnt "$blk" "error="
    check "probe[$tag] no content reaches the log (SECRET)" hasnt "$LOG" SECRET
    check "probe[$tag] no e-mail reaches the log" hasnt "$LOG" "example.com"
    check "probe[$tag] every run logged its processes and idle time" \
        test "$(grep -c '] proc ppid=' "$LOG")" -eq "$(count_files "$PAY")" -a \
        "$(grep -c '] idle=[^ ]* idle_at=+[0-9]*ms$' "$LOG")" -eq "$(count_files "$PAY")"
    # The idle time is read first, and written with the facts in the first
    # write, right after START (a kill at an agent's time limit keeps them).
    blk=$WORK/exp.$N.order
    block_of claude Stop >"$blk"
    check "probe[$tag] the idle time and the facts come first, before the processes" \
        test "$(sed -n '2p' "$blk" | grep -c '] idle=')" -eq 1 -a \
        "$(sed -n '3p' "$blk" | grep -c '] stdin eof')" -eq 1 -a \
        "$(grep -n '] w2 cut=' "$blk" | cut -d: -f1)" -lt "$(grep -n '] done t0=' "$blk" | cut -d: -f1)"
}

test_probe_behaviour() {
    local interp=${1:-} tag=${2:-bash5} t0 t1 out pid
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    local P=$PRE/awake-hook-probe.sh S="$PRE/probe with space/awake-hook-probe.sh"
    local run=("$P")
    if [[ -n "$interp" ]]; then
        run=("$interp" "$P")
    fi

    out=$(run_hook "$S" claude UserPromptSubmit "$PAY/claude-UserPromptSubmit.json" "$interp")
    check "probe[$tag] the copy at a path with a space runs in K2's form" \
        grep -q "copy=space" "$LOG"

    out=$("${run[@]}" claude Stop <"$PAY/claude-Stop.json" 2>&1)
    check "probe[$tag] prints nothing even without redirections" test -z "$out"

    t0=$(ms_now)
    "${run[@]}" claude Stop < <(cat "$PAY/claude-Stop.json"; sleep 4) >/dev/null 2>&1 &
    pid=$!
    wait "$pid"
    t1=$(ms_now)
    if ((t1 - t0 < 2500)) && grep -q "stdin STILL OPEN after" "$LOG"; then
        pass "probe[$tag] stdin left open: done in $((t1 - t0)) ms, logged as still open"
    else
        fail "probe[$tag] stdin left open" "took $((t1 - t0)) ms; $(tail -n 5 "$LOG")"
    fi

    "${run[@]}" claude SessionEnd <&- >/dev/null 2>&1
    check "probe[$tag] stdin closed: exit 0" test $? -eq 0
    check "probe[$tag] stdin closed: logged" grep -Eq "stdin (none|read error|eof)" "$LOG"

    python3 -c 'import json; print(json.dumps({"session_id": "big-1", "hook_event_name": "PostToolUse", "tool_name": "Read", "tool_response": "SECRET" * 1500000, "tool_use_id": "t9"}))' >"$WORK/big.json"
    t0=$(ms_now)
    "${run[@]}" claude PostToolUse <"$WORK/big.json" >/dev/null 2>&1
    t1=$(ms_now)
    if ((t1 - t0 < 4000)) && grep -q "stdin eof after .* 9000[0-9]* bytes" "$LOG" && grep -q "tool_use_id=t9" "$LOG"; then
        pass "probe[$tag] a 9 MB payload: $((t1 - t0)) ms, facts complete"
    else
        fail "probe[$tag] a 9 MB payload" "took $((t1 - t0)) ms; $(tail -n 8 "$LOG")"
    fi

    printf 'not json {"session_id":"x1","prompt":"SECRET' >"$WORK/bad.json"
    "${run[@]}" claude UserPromptSubmit <"$WORK/bad.json" >/dev/null 2>&1
    check "probe[$tag] invalid JSON: raw scan" grep -q "json invalid; raw scan of known keys (any depth): session_id@10 prompt@" "$LOG"

    # shellcheck disable=SC2016 # the probe must not expand it either
    (cd "$WORK" && "${run[@]}" 'cla;ude' 'Pre$(touch owned)Tool' </dev/null >/dev/null 2>&1)
    check "probe[$tag] odd arguments are cleaned, never run" \
        test ! -e "$WORK/owned" -a -n "$(grep -F '?claude PretouchownedTool pid=' "$LOG")"

    # Twenty at once: each of a run's two writes (the idle time and the
    # facts first, then the rest) in one piece.
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
        "${run[@]}" codex PostToolUse <"$PAY/codex-PostToolUse.json" >/dev/null 2>&1 &
    done
    wait
    if out=$(python3 - "$LOG" <<'EOF'
import re, sys
lines = open(sys.argv[1]).read().splitlines()
pids = set(re.match(r"^\S+ codex PostToolUse pid=(\d+) START$", l).group(1)
           for l in lines if re.match(r"^\S+ codex PostToolUse pid=\d+ START$", l))
runs = {}
cur = None
for l in lines:
    m = re.match(r"^  \[(\d+)\] (\S+)", l)
    if not m or m.group(1) not in pids:
        cur = None
        continue
    if cur is None or cur[0] != m.group(1):
        cur = (m.group(1), [])
        runs.setdefault(m.group(1), []).append(cur[1])
    cur[1].append(m.group(2).split("=")[0])
want = [["idle", "stdin", "json", "content", "ids", "values", "w2"],
        ["done", "proc", "env", "envnames"]]
bad = [(p, r) for p, r in runs.items() if r != want]
print(len(pids), bad[:2])
sys.exit(0 if len(pids) == 20 and len(runs) == 20 and not bad else 1)
EOF
); then
        pass "probe[$tag] 20 parallel runs: 40 whole writes"
    else
        fail "probe[$tag] 20 parallel runs: 40 whole writes" "$out"
    fi

    # Killed by the agent's time limit: the watchdog says so.
    "${run[@]}" codex SessionEnd < <(sleep 6) >/dev/null 2>&1 &
    pid=$!
    sleep 0.3
    kill -KILL "$pid" 2>/dev/null
    sleep 3.5
    check "probe[$tag] killed before finishing: the watchdog logs it" \
        grep -q "watchdog: the probe ended before it finished" "$LOG"

    # Without Python: length and a raw scan; a stdin that never closes is
    # stopped by the watchdog after 3 s.
    sed -i.bak "s|^PROBE_PYTHON=.*|PROBE_PYTHON=''|" "$P"
    "${run[@]}" claude Stop <"$PAY/claude-Stop.json" >/dev/null 2>&1
    check "probe[$tag] without Python: the length and a raw scan" \
        grep -q "scan (any depth, no Python): session_id@1 effort@155 hook_event_name@181 last_assistant_message@" "$LOG"
    t0=$(ms_now)
    "${run[@]}" claude Stop < <(sleep 8) >/dev/null 2>&1
    t1=$(ms_now)
    if ((t1 - t0 < 5000)) && grep -q "watchdog: still running after 3 s" "$LOG"; then
        pass "probe[$tag] without Python, stdin open: the watchdog stops it ($((t1 - t0)) ms)"
    else
        fail "probe[$tag] without Python, stdin open" "took $((t1 - t0)) ms"
    fi
    mv -f "$P.bak" "$P"

    # The log cannot be written: the fallback file in $TMPDIR.
    mv "$PRE/logs" "$PRE/logs.away"
    : >"$PRE/logs"
    "${run[@]}" gemini BeforeAgent <"$PAY/gemini-BeforeAgent.json" >/dev/null 2>&1
    check "probe[$tag] an unwritable log: the fallback log in TMPDIR" \
        grep -q "log=fallback" "$TMPDIR/awake-hook-probe-fallback.log"
    rm -f "$PRE/logs"
    mv "$PRE/logs.away" "$PRE/logs"

    # Python fails (as under a sandbox): its own error line says why, the
    # payload never.
    printf '#!/bin/sh\necho "xcrun: error: cannot be used within an App Sandbox." >&2\nexit 1\n' >"$WORK/fakepy.$N"
    chmod 755 "$WORK/fakepy.$N"
    sed -i.bak "s|^PROBE_PYTHON=.*|PROBE_PYTHON='$WORK/fakepy.$N'|" "$P"
    "${run[@]}" claude UserPromptSubmit <"$PAY/claude-UserPromptSubmit.json" >/dev/null 2>&1
    check "probe[$tag] Python fails: the reason is logged" \
        grep -q "facts: the facts script failed (exit 1): xcrun: error: cannot be used within an App Sandbox." "$LOG"
    # ... and bash reads the payload instead: a writer that writes after the
    # facts script failed gets no EPIPE, and the read is measured.
    python3 -c 'import sys; sys.stdout.write("{\"session_id\": \"big-2\", \"x\": \"" + "y" * 200000 + "\"}")' >"$WORK/big2.json"
    local wst
    python3 -c 'import sys, time
data = open(sys.argv[1], "rb").read()
time.sleep(0.3)
sys.stdout.buffer.write(data)
sys.stdout.buffer.flush()' "$WORK/big2.json" | "${run[@]}" claude PostToolUse >/dev/null 2>&1
    wst=${PIPESTATUS[0]}
    check "probe[$tag] Python fails: bash reads stdin, so the writer gets no EPIPE" test "$wst" -eq 0
    check "probe[$tag] Python fails: the bash read of stdin is logged" grep -Eq \
        "stdin eof after [0-9]+ ms \(read by bash, as the facts script failed; [0-9]+ ms after the start\), 200032 bytes" "$LOG"
    check "probe[$tag] the probe leaves no files in its state folder" \
        test -z "$(find "$PRE/state" -mindepth 1 ! -name claude.json ! -name claude-installed.txt)"
    mv -f "$P.bak" "$P"

    # Neither the log nor $TMPDIR can be written: the fallback in /tmp.
    local fb2
    fb2="/tmp/awake-hook-probe-fallback-$(id -u).log"
    rm -f "$fb2"
    mv "$PRE/logs" "$PRE/logs.away"
    : >"$PRE/logs"
    : >"$WORK/notadir.$N"
    TMPDIR="$WORK/notadir.$N/x" "${run[@]}" gemini AfterAgent <"$PAY/gemini-AfterAgent.json" >/dev/null 2>&1
    check "probe[$tag] no log and no TMPDIR: the fallback log in /tmp" grep -q "log=fallback2" "$fb2"
    rm -f "$PRE/logs" "$fb2"
    mv "$PRE/logs.away" "$PRE/logs"

    # The in-hook last look (10.2), with a stand-in claude.
    kitsh last-look-hook on "$MOCK/claude" >/dev/null
    "${run[@]}" claude Stop <"$PAY/claude-Stop.json" >/dev/null 2>&1
    sleep 1.5
    check "probe[$tag] the in-hook last look: logged without cwd or name" \
        test -n "$(grep 'last look from the hook' "$LOG" | grep '2 sessions' | grep -v SECRET)"
    kitsh last-look-hook off >/dev/null
    check "probe[$tag] no content in the behaviour log (SECRET)" hasnt "$LOG" SECRET
}

test_probe_extras() {
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    PATH="$MOCK:$PATH" kitsh last-look "$MOCK/claude" >"$WORK/ll.out" 2>&1
    check "last-look: four variants and the timing, in the log" \
        test -n "$(grep -c 'agents --json' "$LOG" | grep -x 3)" -a -n "$(grep '10 calls:' "$LOG")"
    check "last-look: no cwd or name" hasnt "$LOG" SECRET
    # The extension's bundled claude, found without a path; and a path with ~.
    local ext="$HOME/.cursor/extensions/anthropic.claude-code-2.1.300-darwin-arm64"
    mkdir -p "$ext/resources/native-binary"
    cp "$MOCK/claude" "$ext/resources/native-binary/claude"
    printf '{"name": "claude-code", "version": "2.1.300"}\n' >"$ext/package.json"
    kitsh last-look >"$WORK/ll2.out" 2>&1
    check "last-look: finds the extension's bundled claude by itself" \
        grep -qF "last look (terminal), ~/.cursor/extensions/anthropic.claude-code-2.1.300-darwin-arm64/resources/native-binary/claude" "$WORK/ll2.out"
    # shellcheck disable=SC2088 # kit.py expands the ~
    kitsh last-look "~/.cursor/extensions/anthropic.claude-code-2.1.300-darwin-arm64/resources/native-binary/claude" \
        --no-agent-view >"$WORK/ll3.out" 2>&1
    check "last-look: a path with ~, and --no-agent-view" grep -q "last look (terminal) with disableAgentView" "$WORK/ll3.out"
    check "last-look --no-agent-view: --settings goes before the subcommand (claude accepts it there)" \
        test -n "$(grep -A2 'with disableAgentView' "$WORK/ll3.out" | grep 'agents --json (this shell): exit 0 after .* 2 sessions')"
    # The word terminal: the claude on the PATH, else ~/.claude/local/claude
    # (an old local install that zsh may know only as an alias).
    mkdir -p "$WORK/pathbin$N"
    ln -s "$MOCK/claude" "$WORK/pathbin$N/claude"
    PATH="$WORK/pathbin$N:$PATH" kitsh last-look terminal >"$WORK/ll4.out" 2>&1
    check "last-look terminal: the claude on the PATH" grep -qF "last look (terminal), $WORK/pathbin$N/claude" "$WORK/ll4.out"
    mkdir -p "$HOME/.claude/local"
    cp "$MOCK/claude" "$HOME/.claude/local/claude"
    PATH=/usr/bin:/bin kitsh last-look terminal >"$WORK/ll5.out" 2>&1
    check "last-look terminal: ~/.claude/local/claude when none is on the PATH" \
        grep -qF "last look (terminal), ~/.claude/local/claude" "$WORK/ll5.out"
    # A claude that rejects the call: the first line of its error output.
    printf '#!/bin/sh\necho "error: unknown option '"'"'--settings'"'"'" >&2\nexit 1\n' >"$WORK/badclaude$N"
    chmod 755 "$WORK/badclaude$N"
    kitsh last-look "$WORK/badclaude$N" --no-agent-view >"$WORK/ll6.out" 2>&1
    check "last-look: a rejected call logs the first line of the error output" \
        grep -qF "exit 1 after" "$WORK/ll6.out"
    check "last-look: ... which names what was rejected" grep -qF "error output: error: unknown option '--settings'" "$WORK/ll6.out"
    PATH="$MOCK:$PATH" kitsh assertions "during 10.2 a" >/dev/null 2>&1
    check "assertions: caffeinate and the editor kept, other apps dropped" \
        test -n "$(grep 'pid 4242(caffeinate)' "$LOG")" -a -z "$(grep -i safari "$LOG")"
    check "assertions: no assertion names (they can hold titles)" hasnt "$LOG" SECRET
    kitsh mark "10.2 a" "asked for two tool calls" >/dev/null
    check "mark: in the log" grep -q '^##### ..:..:.. mark: 10.2 a asked for two tool calls$' "$LOG"
    kitsh new-run "10.4 codex" >/dev/null
    check "new-run: current.log points to the new run" test "$(readlink "$LOG")" != "" -a -n "$(readlink "$LOG" | grep '10.4-codex')"
}

# ------------------------------------------------------- install, restore

# K.3, copied here from the plan so that the tests check kit.py against it.
k3_check() {
    # k3_check AGENT FILE [extra]
    python3 - "$1" "$2" "${3:-}" "$PRE" <<'EOF'
import json, re, sys
agent, path, extra, pre = sys.argv[1:5]
d = json.load(open(path))
K = {
 "claude": [("UserPromptSubmit", None, False, 10), ("SessionStart", "clear", False, 10),
            ("Stop", None, False, 10), ("StopFailure", None, False, 10),
            ("SessionEnd", None, False, None), ("Notification", "idle_prompt", False, 10),
            ("SubagentStart", None, False, 10), ("SubagentStop", None, False, 10),
            ("PermissionRequest", None, False, 10),
            ("PreToolUse", "AskUserQuestion|ExitPlanMode", False, 10),
            ("PreToolUse", None, True, None), ("PostToolUse", None, True, None),
            ("PostToolUseFailure", None, True, None)],
 "codex": [("UserPromptSubmit", None, False, 10), ("Stop", None, False, 10),
           ("Interrupt", None, False, None), ("SessionEnd", None, False, None),
           ("SubagentStart", None, False, 10), ("SubagentStop", None, False, 10),
           ("PermissionRequest", None, False, 10), ("PreToolUse", "request_user_input", False, 10),
           ("PreToolUse", None, True, None), ("PostToolUse", None, True, None)],
 "cursor": [(e, None, False, 10) for e in ("beforeSubmitPrompt", "afterAgentThought", "preToolUse",
            "postToolUse", "postToolUseFailure", "stop", "sessionEnd")],
}
if agent == "cursor" and extra:
    K["cursor"].append(("subagentStop", None, False, 10))
form = re.compile(r"^'(.+)' %s (\S+) >/dev/null 2>&1; exit 0$" % agent)
space_event = {"claude": "UserPromptSubmit", "codex": "UserPromptSubmit", "cursor": "beforeSubmitPrompt"}[agent]
found = []
errors = []
for event, groups in d.get("hooks", {}).items():
    if agent == "cursor":
        for e in groups:
            m = form.match(e.get("command", ""))
            if not m:
                continue
            if set(e) != {"command", "timeout"}:
                errors.append("cursor entry keys %s" % sorted(e))
            found.append((event, None, False, e.get("timeout"), m.group(1)))
        continue
    for gi, g in enumerate(groups):
        for h in g.get("hooks", []):
            m = form.match(h.get("command", ""))
            if not m:
                continue
            if h.get("type") != "command" or "args" in h:
                errors.append("type/args in %s" % event)
            if agent == "codex" and len(g["hooks"]) != 1:
                errors.append("codex handler not alone in its group: %s" % event)
            if agent == "codex" and gi != len(groups) - 1 and not all(
                    any(form.match(x.get("command", "")) for x in gg.get("hooks", []))
                    for gg in groups[gi:]):
                errors.append("codex group not at the end: %s" % event)
            found.append((event, g.get("matcher"), bool(h.get("async")), h.get("timeout"), m.group(1)))
            if h.get("async") and "timeout" in h:
                errors.append("async with timeout: %s" % event)
want = sorted(((e, m, a, t) for e, m, a, t in K[agent]), key=repr)
got = sorted(((e, m, a, t) for e, m, a, t, _ in found), key=repr)
if want != got:
    errors.append("handlers differ:\n want %s\n got  %s" % (want, got))
for e, m, a, t, p in found:
    space = " " in p
    if space != (e == space_event and not m):
        errors.append("%s path %s" % (e, p))
if errors:
    print("\n".join(errors))
    sys.exit(1)
EOF
}

test_install_shapes() {
    local f
    new_home
    mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor"
    kitsh install claude codex >/dev/null
    kitsh install cursor --extra >/dev/null
    check "K.3.1: Claude Code's 13 handlers exactly" k3_check claude "$HOME/.claude/settings.json"
    check "K.3.2: Codex's 10 handlers, each alone in a group at the end" k3_check codex "$HOME/.codex/hooks.json"
    check "K.3.3: Cursor's 7 handlers, and subagentStop with --extra" k3_check cursor "$HOME/.cursor/hooks.json" extra
    check "K.3.3: a new Cursor file gets version 1" pyq "$HOME/.cursor/hooks.json" 'list(d)[0] == "version" and d["version"] == 1'
    # Every installed command runs under sh, bash and (if given) bash 3.2.
    python3 - "$HOME/.claude/settings.json" "$HOME/.codex/hooks.json" "$HOME/.cursor/hooks.json" >"$WORK/cmds.$N" <<'EOF'
import json, sys
for p in sys.argv[1:]:
    d = json.load(open(p))
    for event, groups in d["hooks"].items():
        for g in groups:
            for h in (g.get("hooks", [g]) if isinstance(g, dict) else []):
                print(h["command"])
EOF
    local before after shell cmd
    for shell in sh "$BASH5" ${BASH32:+"$BASH32"}; do
        before=$(grep -c ' START$' "$LOG")
        while IFS= read -r cmd; do
            "$shell" -c "$cmd" <"$PAY/claude-SessionEnd.json"
        done <"$WORK/cmds.$N"
        after=$(grep -c ' START$' "$LOG")
        # shellcheck disable=SC2016 # expanded by $shell
        check "every installed command runs under $(basename "$shell") $("$shell" -c 'echo "${BASH_VERSION:-sh}"') ($((after - before)) of 31)" test $((after - before)) -eq 31
    done
    kitsh restore all >/dev/null
    check "restore all: the files the kit created are gone" \
        test ! -e "$HOME/.claude/settings.json" -a ! -e "$HOME/.codex/hooks.json" -a ! -e "$HOME/.cursor/hooks.json"
    check "restore all: the agents' folders stay" test -d "$HOME/.claude" -a -d "$HOME/.codex" -a -d "$HOME/.cursor"
}

test_install_cases() {
    local out st f
    # Missing folder.
    new_home
    out=$(kitsh install claude 2>&1)
    st=$?
    check "a missing ~/.claude: skipped, exit 1, nothing created" test $st -eq 1 -a ! -e "$HOME/.claude" -a -n "$(echo "$out" | grep 'not found')"
    out=$(kitsh install all 2>&1)
    check "install all with no agent: all skipped, exit 0" test $? -eq 0

    # Empty file, and {}.
    for f in empty brace; do
        new_home
        mkdir -p "$HOME/.claude"
        if [[ $f == empty ]]; then : >"$HOME/.claude/settings.json"; else echo '{}' >"$HOME/.claude/settings.json"; fi
        cp "$HOME/.claude/settings.json" "$WORK/orig.$N"
        kitsh install claude >/dev/null
        check "a $f settings.json: 13 handlers" k3_check claude "$HOME/.claude/settings.json"
        kitsh restore claude >"$WORK/out.$N"
        check "a $f settings.json: restore gives the same bytes" same "$WORK/orig.$N" "$HOME/.claude/settings.json"
    done

    # Claude Code with the user's hooks: kept in place and order; same-matcher groups shared.
    new_home
    mkdir -p "$HOME/.claude"
    cat >"$HOME/.claude/settings.json" <<'EOF'
{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]},{"matcher":"x","hooks":[{"type":"command","command":"echo x"}]}],"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"check-bash"}]}]},"permissions":{"allow":["Bash(ls:*)"]},"ünicode":"✓"}
EOF
    chmod 640 "$HOME/.claude/settings.json"
    cp -p "$HOME/.claude/settings.json" "$WORK/orig.$N"
    kitsh install claude >/dev/null
    local S=$HOME/.claude/settings.json
    check "Claude Code: the user's hooks stay first, in order" pyq "$S" \
        'd["hooks"]["Stop"][0]["hooks"][0]["command"] == "say done" and d["hooks"]["Stop"][1]["matcher"] == "x" and d["hooks"]["PreToolUse"][0]["hooks"][0]["command"] == "check-bash" and len(d["hooks"]["PreToolUse"][0]["hooks"]) == 1'
    check "Claude Code: the probe's Stop joins the group without a matcher (K5)" pyq "$S" \
        'len(d["hooks"]["Stop"]) == 2 and len(d["hooks"]["Stop"][0]["hooks"]) == 2'
    check "Claude Code: other keys and their order kept" pyq "$S" 'list(d) == ["model", "hooks", "permissions", "ünicode"]'
    check "Claude Code: the mode is kept (640)" test "$(mode_of "$S")" = 640
    check "K.3.1 with the user's hooks" k3_check claude "$S"
    cp "$S" "$WORK/after.$N"
    kitsh install claude >/dev/null
    check "a second install changes no byte" same "$WORK/after.$N" "$S"
    check "a second install makes no new backup" test "$(count_files "$PRE/backups")" -eq 1
    kitsh restore claude >"$WORK/out.$N"
    check "Claude Code: restore gives the same bytes" same "$WORK/orig.$N" "$S"
    check "Claude Code: restore says it matches the backup" grep -q "byte for byte" "$WORK/out.$N"
    out=$(kitsh restore claude)
    check "a second restore does nothing" test -n "$(echo "$out" | grep 'No probe handlers')"

    # Partial: one handler removed by hand is added back alone.
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    python3 - "$HOME/.claude/settings.json" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); del d["hooks"]["StopFailure"]
json.dump(d, open(p, "w"), indent=2)
EOF
    kitsh status claude >"$WORK/st.$N"
    check "status: partial (12 of 13), naming the missing one" grep -q "partial (12 of 13 probe handlers); missing StopFailure" "$WORK/st.$N"
    out=$(kitsh install claude)
    check "install adds back only the missing handler" test -n "$(echo "$out" | grep 'Added 1 of')"
    check "K.3.1 after the repair" k3_check claude "$HOME/.claude/settings.json"

    # A file the kit created, with other settings added since: kept.
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    python3 - "$HOME/.claude/settings.json" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["theme"] = "dark"
json.dump(d, open(p, "w"), indent=2)
EOF
    out=$(kitsh restore claude)
    check "restore of a file the kit created, with other settings added: kept, and said" \
        test -n "$(echo "$out" | grep 'The kit had created this file')" -a "$(cat "$HOME/.claude/settings.json")" = '{
  "theme": "dark"
}'

    # Restore keeps the user's other changes.
    new_home
    mkdir -p "$HOME/.claude"
    echo '{"model":"opus"}' >"$HOME/.claude/settings.json"
    kitsh install claude >/dev/null
    python3 - "$HOME/.claude/settings.json" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["theme"] = "dark"
d["hooks"]["Stop"][0]["hooks"].insert(0, {"type": "command", "command": "user-added"})
json.dump(d, open(p, "w"), indent=2)
EOF
    out=$(kitsh restore claude)
    check "restore after other changes: only the probe's removed, the rest kept" \
        pyq "$HOME/.claude/settings.json" 'd["model"] == "opus" and d["theme"] == "dark" and d["hooks"] == {"Stop": [{"hooks": [{"type": "command", "command": "user-added"}]}]}'
    check "restore after other changes: says so" test -n "$(echo "$out" | grep 'other changes')"

    # Codex: the user's groups keep their indices; a group added after the
    # probe's keeps its index at restore, through {"hooks": []}.
    new_home
    mkdir -p "$HOME/.codex"
    cat >"$HOME/.codex/hooks.json" <<'EOF'
{
  "description": "mine",
  "hooks": {
    "Stop": [
      {"hooks": [{"type": "command", "command": "user-stop-1"}]},
      {"matcher": "", "hooks": [{"type": "command", "command": "user-stop-2", "timeout": 5}]}
    ]
  }
}
EOF
    cp "$HOME/.codex/hooks.json" "$WORK/orig.$N"
    kitsh install codex >"$WORK/out.$N"
    local C=$HOME/.codex/hooks.json
    check "Codex: the user's groups keep indices 0 and 1" pyq "$C" \
        'd["hooks"]["Stop"][0]["hooks"][0]["command"] == "user-stop-1" and d["hooks"]["Stop"][1]["hooks"][0]["command"] == "user-stop-2" and len(d["hooks"]["Stop"]) == 3'
    check "K.3.2 with the user's groups" k3_check codex "$C"
    check "Codex: the trust step is left to the user" grep -q "Trust all and continue" "$WORK/out.$N"
    kitsh restore codex >/dev/null
    check "Codex: restore gives the same bytes" same "$WORK/orig.$N" "$C"
    kitsh install codex >/dev/null
    python3 - "$C" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p))
d["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": "user-later"}]})
json.dump(d, open(p, "w"), indent=2)
EOF
    out=$(kitsh restore codex)
    check "Codex: a later user group keeps its index (the probe's becomes {\"hooks\": []})" pyq "$C" \
        'd["hooks"]["Stop"][2] == {"hooks": []} and d["hooks"]["Stop"][3]["hooks"][0]["command"] == "user-later" and "PreToolUse" not in d["hooks"]'

    # Codex trust (K13): status counts trusted_hash lines; config.toml is never written.
    new_home
    mkdir -p "$HOME/.codex"
    kitsh install codex >/dev/null
    python3 - "$HOME/.codex/hooks.json" >"$HOME/.codex/config.toml" <<'EOF'
import json, re, sys
p = sys.argv[1]; d = json.load(open(p))
print('model = "gpt-5.6"\n')
for event, groups in d["hooks"].items():
    label = re.sub(r"(?<!^)(?=[A-Z])", "_", event).lower()
    for gi, g in enumerate(groups):
        for hi, h in enumerate(g["hooks"]):
            print('[hooks.state."%s:%s:%d:%d"]\ntrusted_hash = "sha256:abc"\n' % (p, label, gi, hi))
EOF
    cp "$HOME/.codex/config.toml" "$WORK/toml.$N"
    kitsh status codex >"$WORK/st.$N"
    check "Codex status: 10 of 10 trusted" grep -q "10 of 10 probe handlers have a trusted_hash" "$WORK/st.$N"
    kitsh codex-touch >"$WORK/out.$N"
    check "codex-touch: Stop now runs the copy at a path with a space" pyq "$HOME/.codex/hooks.json" \
        '"probe with space" in d["hooks"]["Stop"][0]["hooks"][0]["command"]'
    kitsh status codex >"$WORK/st.$N"
    check "codex-touch: still 10 of 10 handlers" grep -q "on (10 of 10 probe handlers)" "$WORK/st.$N"
    kitsh install codex >/dev/null
    check "install codex puts Stop back on the main copy" pyq "$HOME/.codex/hooks.json" \
        '"probe with space" not in d["hooks"]["Stop"][0]["hooks"][0]["command"]'
    kitsh restore codex >/dev/null
    check "Codex: config.toml is never written" same "$WORK/toml.$N" "$HOME/.codex/config.toml"
    printf '[hooks.state."x"]\ntrusted_hash = "1"\n\n[[hooks.Stop]]\nmatcher = ""\n' >"$HOME/.codex/config.toml"
    out=$(kitsh install codex 2>&1)
    check "Codex: inline [[hooks.Stop]] in config.toml is refused (K5)" test $? -eq 1 -a ! -e "$HOME/.codex/hooks.json" -a -n "$(echo "$out" | grep 'inline hook groups')"
    printf '[features]\nhooks = false\n' >"$HOME/.codex/config.toml"
    out=$(kitsh install codex 2>&1)
    check "Codex: [features] hooks = false is warned about" test -n "$(echo "$out" | grep 'turns hooks off')"

    # Cursor with another tool's entries.
    new_home
    mkdir -p "$HOME/.cursor"
    printf '{"version":1,"hooks":{"stop":[{"command":"./audit.sh","loop_limit":10}],"afterFileEdit":[{"command":"./format.sh"}]}}' >"$HOME/.cursor/hooks.json"
    cp "$HOME/.cursor/hooks.json" "$WORK/orig.$N"
    kitsh install cursor >/dev/null
    check "Cursor: the other tool's entries stay first" pyq "$HOME/.cursor/hooks.json" \
        'd["hooks"]["stop"][0]["command"] == "./audit.sh" and len(d["hooks"]["stop"]) == 2 and d["hooks"]["afterFileEdit"] == [{"command": "./format.sh"}]'
    check "K.3.3 with another tool's entries" k3_check cursor "$HOME/.cursor/hooks.json"
    kitsh restore cursor >/dev/null
    check "Cursor: restore gives the same bytes" same "$WORK/orig.$N" "$HOME/.cursor/hooks.json"

    # A symlinked file (a dotfiles folder), mode 600.
    new_home
    mkdir -p "$HOME/.claude" "$HOME/dotfiles"
    echo '{"model":"opus"}' >"$HOME/dotfiles/claude-settings.json"
    chmod 600 "$HOME/dotfiles/claude-settings.json"
    ln -s "$HOME/dotfiles/claude-settings.json" "$HOME/.claude/settings.json"
    cp -p "$HOME/dotfiles/claude-settings.json" "$WORK/orig.$N"
    kitsh install claude >/dev/null
    check "symlink: the link stays a link" test -L "$HOME/.claude/settings.json"
    check "symlink: the target got the handlers" k3_check claude "$HOME/dotfiles/claude-settings.json"
    check "symlink: mode 600 kept" test "$(mode_of "$HOME/dotfiles/claude-settings.json")" = 600
    kitsh restore claude >/dev/null
    check "symlink: restore gives the same bytes, and the link stays" \
        test -L "$HOME/.claude/settings.json" -a -z "$(cmp "$WORK/orig.$N" "$HOME/dotfiles/claude-settings.json")"

    # Refusals: the file stays as it was, exit 1.
    local bad
    for bad in comment trailing array hooks-string duplicate nan latin1 readonly dangling; do
        new_home
        mkdir -p "$HOME/.claude"
        f=$HOME/.claude/settings.json
        case $bad in
            comment) printf '{\n  // mine\n  "model": "opus"\n}\n' >"$f" ;;
            trailing) printf '{"model": "opus",}\n' >"$f" ;;
            array) printf '[]\n' >"$f" ;;
            hooks-string) printf '{"hooks": "none"}\n' >"$f" ;;
            duplicate) printf '{"model": "a", "model": "b"}\n' >"$f" ;;
            nan) printf '{"x": NaN}\n' >"$f" ;;
            latin1) printf '{"x": "\xe4"}\n' >"$f" ;;
            readonly) printf '{}\n' >"$f"; chmod 444 "$f" ;;
            dangling) ln -s "$HOME/nowhere.json" "$f" ;;
        esac
        cp -P "$f" "$WORK/orig.$N" 2>/dev/null || true
        out=$(kitsh install claude 2>&1)
        st=$?
        if [[ $st -eq 1 && "$out" == *REFUSED* ]] && { [[ $bad == dangling ]] || same "$WORK/orig.$N" "$f"; } &&
            [[ ! -e "$PRE/state/claude.json" ]]; then
            pass "refused, unchanged: $bad"
        else
            fail "refused, unchanged: $bad" "exit $st: $out"
        fi
    done
    new_home
    mkdir -p "$HOME/.codex"
    printf '{"hooks": {}, "version": 1}\n' >"$HOME/.codex/hooks.json"
    out=$(kitsh install codex 2>&1)
    check "refused, unchanged: a Codex file with an extra top-level key" test $? -eq 1 -a -n "$(echo "$out" | grep 'does not allow')"
    new_home
    mkdir -p "$HOME/.cursor"
    printf '{"hooks": {"stop": []}}\n' >"$HOME/.cursor/hooks.json"
    out=$(kitsh install cursor 2>&1)
    check "refused, unchanged: a Cursor file with hooks but no version" test $? -eq 1 -a -n "$(echo "$out" | grep 'no "version"')"

    # Changed between the read and the write (K5's compare).
    new_home
    mkdir -p "$HOME/.claude"
    echo '{"model":"opus"}' >"$HOME/.claude/settings.json"
    # shellcheck disable=SC2016 # expanded by kit.py's /bin/sh
    out=$(AWAKE_PREFLIGHT_TEST_BEFORE_COMPARE='echo "{\"model\":\"changed\"}" > "$TARGET"' kitsh install claude 2>&1)
    st=$?
    check "changed mid-edit: refused, the other writer's change kept" \
        test $st -eq 1 -a "$(cat "$HOME/.claude/settings.json")" = '{"model":"changed"}' -a -n "$(echo "$out" | grep 'changed while')"
    check "changed mid-edit: no temporary file left" test "$(count_files "$HOME/.claude")" -eq 1
    kitsh install claude >/dev/null
    # shellcheck disable=SC2016 # expanded by kit.py's /bin/sh
    out=$(AWAKE_PREFLIGHT_TEST_BEFORE_COMPARE='echo "{}" > "$TARGET"' kitsh restore claude 2>&1)
    check "changed mid-restore: refused" test $? -eq 1 -a "$(cat "$HOME/.claude/settings.json")" = '{}'

    # Backups are never overwritten, even within one second.
    new_home
    mkdir -p "$HOME/.claude"
    echo '{}' >"$HOME/.claude/settings.json"
    kitsh install claude >/dev/null
    kitsh restore claude >/dev/null
    kitsh install claude >/dev/null
    kitsh restore claude >/dev/null
    check "two installs: two backups, none overwritten" test "$(count_files "$PRE/backups")" -eq 2

    # CLAUDE_CONFIG_DIR, and restore through the recorded path.
    new_home
    mkdir -p "$HOME/alt"
    export CLAUDE_CONFIG_DIR=$HOME/alt
    kitsh install claude >"$WORK/out.$N"
    unset CLAUDE_CONFIG_DIR
    check "CLAUDE_CONFIG_DIR: used, with a warning" test -e "$HOME/alt/settings.json" -a -n "$(grep 'CLAUDE_CONFIG_DIR is set' "$WORK/out.$N")"
    kitsh restore claude >/dev/null
    check "CLAUDE_CONFIG_DIR: restore uses the recorded file" test ! -e "$HOME/alt/settings.json"

    # A home folder with a quote and a space: K2's quoting.
    new_home
    HOME="$WORK/it's home $N"
    mkdir -p "$HOME/.claude"
    PRE=$HOME/awake-preflight
    LOG=$PRE/logs/current.log
    kitsh install claude >/dev/null
    python3 -c 'import json, sys
d = json.load(open(sys.argv[1]))
for g in d["hooks"]["Stop"]:
    for h in g["hooks"]:
        print(h["command"])' "$HOME/.claude/settings.json" >"$WORK/cmd.$N"
    sh -c "$(cat "$WORK/cmd.$N")" <"$PAY/claude-Stop.json"
    check "a home folder with ' and a space: the handler runs" grep -q " claude Stop pid=" "$LOG"

    # print: valid JSON for each agent.
    for f in claude codex cursor gemini; do
        kitsh print "$f" | sed 1d >"$WORK/print.$N.$f"
        check "print $f: valid JSON" python3 -c 'import json, sys; json.load(open(sys.argv[1]))' "$WORK/print.$N.$f"
    done

    # Python missing.
    out=$(AWAKE_PREFLIGHT_PYTHON=/nonexistent/python3 kitsh install claude 2>&1)
    check "python3 missing: a clear error, exit 1" test $? -eq 1 -a -n "$(echo "$out" | grep 'python3 was not found')"

    # purge.
    new_home
    mkdir -p "$HOME/.claude"
    kitsh install claude >/dev/null
    out=$(echo yes | kitsh purge 2>&1)
    check "purge refuses while the probe is installed" test $? -eq 1 -a -d "$PRE"
    kitsh restore claude >/dev/null
    echo no | kitsh purge >/dev/null 2>&1
    check "purge without yes keeps the folder" test -d "$PRE"
    echo yes | kitsh purge >/dev/null 2>&1
    check "purge with yes deletes the folder" test ! -e "$PRE"
}

# Empty containers, Cursor's "version", a lone surrogate, probe handlers of
# another preflight folder, the editors' CLAUDE_CONFIG_DIR.
test_install_more() {
    local out st f orig
    # Cursor files that were {} or empty come back byte for byte, without
    # the "version": 1 that install added.
    for f in brace empty; do
        new_home
        mkdir -p "$HOME/.cursor"
        if [[ $f == empty ]]; then : >"$HOME/.cursor/hooks.json"; else echo '{}' >"$HOME/.cursor/hooks.json"; fi
        cp "$HOME/.cursor/hooks.json" "$WORK/orig.$N"
        kitsh install cursor >/dev/null
        check "a Cursor file that was $f: install adds version 1" pyq "$HOME/.cursor/hooks.json" 'd["version"] == 1'
        out=$(kitsh restore cursor)
        check "a Cursor file that was $f: restore gives the same bytes, and says so" \
            test -z "$(cmp "$WORK/orig.$N" "$HOME/.cursor/hooks.json" 2>&1)" -a -n "$(echo "$out" | grep 'byte for byte')"
    done
    # Empty containers the user had: kept, and never filled by install.
    for orig in '{"hooks":{"Stop":[]}}' \
        '{"hooks":{"PreToolUse":[{"matcher":"","hooks":[]}]}}' \
        '{"hooks":{"Stop":[{"matcher":""}],"PreToolUse":[{"hooks":[]}]}}' \
        '{"hooks":{}}'; do
        new_home
        mkdir -p "$HOME/.claude"
        printf '%s\n' "$orig" >"$HOME/.claude/settings.json"
        cp "$HOME/.claude/settings.json" "$WORK/orig.$N"
        kitsh install claude >/dev/null
        check "empty containers $orig: K.3.1" k3_check claude "$HOME/.claude/settings.json"
        check "empty containers $orig: the user's groups untouched, the probe's after them" python3 -c 'import json, sys
o = json.loads(sys.argv[1]).get("hooks", {}); d = json.load(open(sys.argv[2]))["hooks"]
sys.exit(0 if all(d[e][:len(g)] == g for e, g in o.items() if g) else 1)' "$orig" "$HOME/.claude/settings.json"
        out=$(kitsh restore claude)
        check "empty containers $orig: restore gives the same bytes" \
            test -z "$(cmp "$WORK/orig.$N" "$HOME/.claude/settings.json" 2>&1)" -a -n "$(echo "$out" | grep 'byte for byte')"
    done
    # A group without a hooks list survives a restore that keeps other
    # changes too.
    new_home
    mkdir -p "$HOME/.claude"
    echo '{"hooks":{"Stop":[{"matcher":""}]}}' >"$HOME/.claude/settings.json"
    kitsh install claude >/dev/null
    python3 - "$HOME/.claude/settings.json" <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); d["theme"] = "dark"
json.dump(d, open(p, "w"), indent=2)
EOF
    kitsh restore claude >/dev/null
    check "a user group without hooks survives install and restore with other changes" \
        pyq "$HOME/.claude/settings.json" 'd == {"hooks": {"Stop": [{"matcher": ""}]}, "theme": "dark"}'

    # A lone surrogate: refused, no traceback, unchanged.
    new_home
    mkdir -p "$HOME/.claude"
    printf '{"x": "\\ud800"}\n' >"$HOME/.claude/settings.json"
    cp "$HOME/.claude/settings.json" "$WORK/orig.$N"
    out=$(kitsh install claude 2>&1)
    st=$?
    check "a lone surrogate escape: refused, exit 1, no traceback, unchanged" \
        test $st -eq 1 -a -n "$(echo "$out" | grep 'REFUSED.*lone surrogate')" -a -z "$(echo "$out" | grep Traceback)" -a \
        -z "$(cmp "$WORK/orig.$N" "$HOME/.claude/settings.json" 2>&1)"

    # Probe handlers of another preflight folder.
    new_home
    mkdir -p "$HOME/.claude"
    echo '{"model":"opus"}' >"$HOME/.claude/settings.json"
    cp "$HOME/.claude/settings.json" "$WORK/orig.$N"
    AWAKE_PREFLIGHT_DIR="$HOME/other folder" kitsh install claude >/dev/null
    out=$(kitsh restore claude 2>&1)
    st=$?
    check "another folder's probe handlers: restore says so, exit 1, the file unchanged" \
        test $st -eq 1 -a -n "$(echo "$out" | grep "13 probe handler(s) from another preflight folder, ~/other folder")" -a \
        -n "$(echo "$out" | grep -F "AWAKE_PREFLIGHT_DIR=~/'other folder' probe.sh restore claude")" -a \
        -n "$(grep -c 'awake-hook-probe' "$HOME/.claude/settings.json")"
    out=$(kitsh status claude 2>&1)
    check "another folder's probe handlers: status names them" test -n "$(echo "$out" | grep 'Also: 13 probe handler(s) from another preflight folder')"
    check "another folder's probe handlers: its manifest stays" test -e "$HOME/other folder/state/claude.json"
    AWAKE_PREFLIGHT_DIR="$HOME/other folder" kitsh restore claude >/dev/null
    check "another folder's probe handlers: restored from that folder, the same bytes" same "$WORK/orig.$N" "$HOME/.claude/settings.json"

    # The editor's CLAUDE_CONFIG_DIR for the Claude Code extension (K1).
    new_home
    mkdir -p "$HOME/.claude" "$HOME/Library/Application Support/Cursor/User"
    printf '{\n  // mine\n  "claudeCode.environmentVariables": [{"name": "CLAUDE_CONFIG_DIR", "value": "~/.claude-work"}],\n}\n' \
        >"$HOME/Library/Application Support/Cursor/User/settings.json"
    out=$(kitsh install claude 2>&1)
    check "install claude warns about the editor's CLAUDE_CONFIG_DIR" \
        test -n "$(echo "$out" | grep "Warning: Cursor's Claude Code extension uses CLAUDE_CONFIG_DIR=~/.claude-work")" -a \
        -n "$(echo "$out" | grep -F "CLAUDE_CONFIG_DIR=~/.claude-work probe.sh install claude")"
    # shellcheck disable=SC2016 # the editor's own syntax, not the shell's
    printf '{"claudeCode.environmentVariables": [{"name": "CLAUDE_CONFIG_DIR", "value": "${env:HOME}/.claude"}]}\n' \
        >"$HOME/Library/Application Support/Cursor/User/settings.json"
    out=$(kitsh install claude 2>&1)
    check "no warning when the editor's CLAUDE_CONFIG_DIR is the folder used" test -z "$(echo "$out" | grep "extension uses CLAUDE_CONFIG_DIR")"

    # Gemini's settings.json with comments: the allowlist step says what to
    # do by hand.
    new_home
    mkdir -p "$HOME/.gemini"
    printf '{\n  // mine\n  "general": {}\n}\n' >"$HOME/.gemini/settings.json"
    out=$(kitsh gemini-allowlist on 2>&1)
    check "gemini-allowlist on a settings.json with comments: refused, with the setting to add by hand" \
        test $? -eq 1 -a -n "$(echo "$out" | grep 'add "security": {"allowedExtensions": \["^nomatch\$"\]} by hand')"
}

test_stop_block() {
    local out st S blk
    new_home
    mkdir -p "$HOME/.claude"
    out=$(kitsh stop-block on 2>&1)
    check "stop-block on before the probe: refused" test $? -eq 1 -a -n "$(echo "$out" | grep 'install claude')"
    printf '{"model":"opus","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}\n' >"$HOME/.claude/settings.json"
    S=$HOME/.claude/settings.json
    cp "$S" "$WORK/orig.$N"
    kitsh install claude >/dev/null
    kitsh stop-block on >"$WORK/out.$N"
    check "stop-block on: a Stop group of its own at the end, timeout 150" pyq "$S" \
        'd["hooks"]["Stop"][-1] == {"hooks": [{"type": "command", "command": "'"'"'%s/awake-stop-block.sh'"'"'" % "'"$PRE"'", "timeout": 150}]} and d["hooks"]["Stop"][0]["hooks"][0]["command"] == "say done"'
    check "stop-block on: the probe's 13 handlers stay" k3_check claude "$S"
    check "stop-block on: the script knows the preflight folder" grep -q "^PROBE_DIR='$PRE'$" "$PRE/awake-stop-block.sh"
    kitsh status claude >"$WORK/st.$N"
    check "stop-block on: status says so" grep -q "stop-block handler is ON" "$WORK/st.$N"
    kitsh install claude >/dev/null
    check "install claude again keeps the stop-block handler" pyq "$S" \
        'any("awake-stop-block.sh" in h["command"] for g in d["hooks"]["Stop"] for h in g["hooks"])'
    # Run it as Claude Code would: sh -c, the payload on stdin, with
    # CLAUDE_CODE_SESSION_ID set; and as the other programs that read
    # settings.json would. sb ENV... PAYLOAD: exit status in $st.
    sb() {
        local payload=${*: -1}
        env -u CURSOR_VERSION -u CLAUDE_CODE_SESSION_ID AWAKE_PREFLIGHT_TEST_STOP_BLOCK_SECONDS=1 \
            "${@:1:$#-1}" sh -c "'$PRE/awake-stop-block.sh'" <"$payload" >"$WORK/sb.out" 2>"$WORK/sb.err"
        st=$?
    }
    sed 's/"stop_hook_active":true/"stop_hook_active":false/' "$PAY/claude-Stop.json" >"$WORK/stop-false.json"
    sb CLAUDE_CODE_SESSION_ID=sess-A "$PAY/claude-Stop.json"
    check "stop-block: a Stop with stop_hook_active true goes through (exit 0)" test "$st" -eq 0 -a ! -s "$WORK/sb.err"
    sb CLAUDE_CODE_SESSION_ID=sess-A CURSOR_VERSION=3.12.17 "$WORK/stop-false.json"
    check "stop-block: with CURSOR_VERSION (Cursor's agent, the panel in Cursor) it goes through" \
        test "$st" -eq 0 -a -n "$(grep 'CURSOR_VERSION is set' "$LOG")"
    sb "$WORK/stop-false.json"
    check "stop-block: without CLAUDE_CODE_SESSION_ID it goes through" \
        test "$st" -eq 0 -a -n "$(grep 'CLAUDE_CODE_SESSION_ID is not set' "$LOG")"
    sb CLAUDE_CODE_SESSION_ID=sess-A "$PAY/cursor-stop.json"
    check "stop-block: Cursor's payload (conversation_id, no stop_hook_active) goes through" \
        test "$st" -eq 0 -a -n "$(grep 'has the key conversation_id' "$LOG")"
    sb CLAUDE_CODE_SESSION_ID=sess-A "$WORK/stop-false.json"
    check "stop-block: Claude Code's first Stop in a session is held, then exit 2 with a line for Claude on stderr" \
        test "$st" -eq 2 -a -n "$(grep '10.3 (c)' "$WORK/sb.err")" -a ! -s "$WORK/sb.out"
    sb CLAUDE_CODE_SESSION_ID=sess-A "$WORK/stop-false.json"
    check "stop-block: a second Stop in the same session goes through (once per session)" \
        test "$st" -eq 0 -a -n "$(grep 'already held once' "$LOG")"
    check "stop-block: its steps and reasons are noted in the run log" test "$(grep -c 'stop-block:' "$LOG")" -eq 7
    kitsh stop-block on >"$WORK/out.$N"
    sb CLAUDE_CODE_SESSION_ID=sess-A "$WORK/stop-false.json"
    check "stop-block on again: a new window, the session is held once more" \
        test "$st" -eq 2 -a -n "$(grep 'window starts again' "$WORK/out.$N")"
    echo 1000 >"$PRE/state/stop-block-on"
    sb CLAUDE_CODE_SESSION_ID=sess-B "$WORK/stop-false.json"
    check "stop-block: 20 minutes after on, every Stop goes through" \
        test "$st" -eq 0 -a -n "$(grep 'older than 20 minutes' "$LOG")"
    kitsh stop-block off >/dev/null
    check "stop-block off: the window and the once-per-session marks are gone" \
        test -z "$(find "$PRE/state" -name 'stop-block-*')"
    check "stop-block off: removed, and the probe's 13 handlers stay" k3_check claude "$S"
    check "stop-block off: no stop-block handler left" hasnt "$S" "awake-stop-block.sh"
    kitsh stop-block on >/dev/null
    kitsh restore claude >"$WORK/out.$N"
    check "restore claude with the stop-block on: the original bytes" same "$WORK/orig.$N" "$S"
    check "restore claude: the stop-block window is gone" test ! -e "$PRE/state/stop-block-on"
    blk=$(kitsh stop-block off 2>&1)
    check "stop-block off after restore: nothing to do" test -n "$(echo "$blk" | grep 'not in')"
}

test_gemini() {
    local out st
    new_home
    mkdir -p "$HOME/.gemini/extensions"
    export AWAKE_PREFLIGHT_GEMINI=$MOCK/gemini
    kitsh install gemini >"$WORK/out.$N"
    local X=$HOME/.gemini/extensions/awake-probe EXT=$PRE/gemini-extension
    check "Gemini: linked as awake-probe, pointing at the probe's folder outside ~/.gemini" \
        pyq "$X/.gemini-extension-install.json" "d == {'source': '$EXT', 'type': 'link'}"
    check "Gemini: the extension is named awake-probe, never awake" pyq "$EXT/gemini-extension.json" 'd["name"] == "awake-probe"'
    python3 - "$EXT/hooks/hooks.json" <<'EOF'
import json, re, sys
d = json.load(open(sys.argv[1]))
want = {"BeforeAgent": "awake-probe-turn-start", "BeforeTool": "awake-probe-tool-start",
        "AfterTool": "awake-probe-working", "Notification": "awake-probe-waiting",
        "AfterAgent": "awake-probe-turn-end", "SessionEnd": "awake-probe-session-end"}
ok = set(d["hooks"]) == set(want)
for e, groups in d["hooks"].items():
    ok = ok and len(groups) == 1 and groups[0].get("matcher") == "" and len(groups[0]["hooks"]) == 1
    h = groups[0]["hooks"][0]
    ok = ok and h["type"] == "command" and h["name"] == want[e] and h["timeout"] == 10000
    ok = ok and re.match(r"^'.+' gemini %s >/dev/null 2>&1; exit 0$" % e, h["command"]) is not None
    ok = ok and (("probe with space" in h["command"]) == (e == "BeforeAgent"))
sys.exit(0 if ok else 1)
EOF
    check "K.3.4: Gemini's 6 handlers, names, empty matchers, 10000 ms" test $? -eq 0
    kitsh status gemini >"$WORK/st.$N"
    check "Gemini status: linked" grep -q "linked by gemini" "$WORK/st.$N"
    kitsh gemini-record >"$WORK/out.$N"
    check "gemini-record: uninstalled, then a hand-written record (K14)" \
        test "$(cat "$X/.gemini-extension-install.json")" = "$(printf '{\n  "source": "%s",\n  "type": "link"\n}' "$EXT")"
    echo '{"general": {"vimMode": true}}' >"$HOME/.gemini/settings.json"
    cp "$HOME/.gemini/settings.json" "$WORK/gs.$N"
    kitsh gemini-allowlist on >/dev/null
    check "gemini-allowlist on: security.allowedExtensions = [\"^nomatch\$\"]" pyq "$HOME/.gemini/settings.json" \
        'd["security"] == {"allowedExtensions": ["^nomatch$"]} and d["general"] == {"vimMode": True}'
    kitsh restore gemini >"$WORK/out.$N"
    check "Gemini restore: link and folder gone, settings.json back byte for byte" \
        test ! -e "$X" -a ! -e "$EXT" -a -z "$(cmp "$WORK/gs.$N" "$HOME/.gemini/settings.json")"
    # An existing allowlist is left alone.
    echo '{"security": {"allowedExtensions": ["^mine$"]}}' >"$HOME/.gemini/settings.json"
    out=$(kitsh gemini-allowlist on 2>&1)
    check "gemini-allowlist on: an existing allowlist is refused" test $? -eq 1 -a -n "$(echo "$out" | grep 'leaves your allowlist alone')"
    # Another extension declaring the same name.
    mkdir -p "$HOME/.gemini/extensions/other"
    echo '{"name": "awake-probe", "version": "9"}' >"$HOME/.gemini/extensions/other/gemini-extension.json"
    out=$(kitsh install gemini 2>&1)
    check "Gemini: another folder declaring awake-probe is refused" test $? -eq 1 -a ! -e "$X"
    rm -rf "$HOME/.gemini/extensions/other"
    # A foreign awake-probe link folder is left alone at restore.
    kitsh install gemini >/dev/null
    echo "mine" >"$X/extra-file"
    printf '{"source": "/elsewhere", "type": "link"}' >"$X/.gemini-extension-install.json"
    out=$(kitsh restore gemini 2>&1)
    check "Gemini restore: a link folder that is not the probe's is left alone" test $? -eq 1 -a -e "$X/extra-file"
    # Not found.
    new_home
    export AWAKE_PREFLIGHT_GEMINI=""
    out=$(kitsh install gemini 2>&1)
    check "Gemini not found: skipped, exit 1" test $? -eq 1 -a -n "$(echo "$out" | grep 'not found')"
}

# ------------------------------------------------------------- the lease

lease_env() {
    export MOCK_AWAKE_STATE=$WORK/awake-state$N
    export MOCK_AWAKE=$MOCK/awake
    export AWAKE_BIN=$MOCK/awake
    export AWAKE_PREFLIGHT_TEST_HELPER=$MOCK/helper
    export AWAKE_PREFLIGHT_TEST_TIME=$MOCK/time
    export AWAKE_PREFLIGHT_TEST_BASH=${BASH32:-$BASH5}
    export AWAKE_PREFLIGHT_TEST_LEASE=6
    export AWAKE_PREFLIGHT_TEST_RENEW=1
    export AWAKE_PREFLIGHT_TEST_SAMPLE=2
    export AWAKE_PREFLIGHT_TEST_SAMPLES=3
    export AWAKE_PREFLIGHT_TEST_FLOOR_START=2
    export AWAKE_PREFLIGHT_TEST_FLOOR_SPAN=12
    mkdir -p "$MOCK_AWAKE_STATE"
}

lease_leftovers() {
    # Nothing the check started may outlive it.
    sleep 0.5
    ! pgrep -f "sleep 7200" >/dev/null && ! pgrep -f "$MOCK/helper" >/dev/null &&
        ! pgrep -f -- "$KIT/lease-check.sh" >/dev/null
}

# Starts a command as a terminal's foreground job would run: in a process
# group of its own, with SIGINT at its default (a script's background job
# would ignore it). kill -INT -- -PID then acts as Ctrl+C.
with_sigint() {
    exec python3 -c 'import os, signal, sys
signal.signal(signal.SIGINT, signal.SIG_DFL)
os.setpgrp()
os.execvp(sys.argv[1], sys.argv[1:])' "$@"
}

test_lease() {
    local sh=${1:-$BASH5} tag=${2:-bash5} out st res
    new_home
    lease_env
    # A session already running: refused, nothing started.
    "$MOCK/awake" --duration-seconds 60 >/dev/null
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto --yes 2>&1)
    st=$?
    check "lease[$tag] refuses while a session runs" test $st -eq 1 -a -n "$(echo "$out" | grep 'already running')"
    check "lease[$tag] the running session was left alone" test -f "$MOCK_AWAKE_STATE/session"
    rm -f "$MOCK_AWAKE_STATE/session"
    touch "$MOCK_AWAKE_STATE/passwordless-off"
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto --yes 2>&1)
    check "lease[$tag] refuses without password-free mode" test $? -eq 1 -a -n "$(echo "$out" | grep 'password-free mode is off')"
    rm -f "$MOCK_AWAKE_STATE/passwordless-off"
    out=$(echo n | PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto 2>&1)
    check "lease[$tag] asks before it starts a session" test -n "$(echo "$out" | grep 'Not started')" -a ! -f "$MOCK_AWAKE_STATE/session"
    # A session that starts lid-open (caffeinate) does not test the lease:
    # refused, and stopped again.
    echo caffeinate >"$MOCK_AWAKE_STATE/backend"
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto --yes 2>&1)
    st=$?
    check "lease[$tag] a lid-open session: refused" test $st -eq 1 -a -n "$(echo "$out" | grep "backend 'caffeinate'")"
    check "lease[$tag] a lid-open session: stopped again" \
        test -n "$(echo "$out" | grep 'Stopped the Awake session this check started')" -a ! -f "$MOCK_AWAKE_STATE/session"
    check "lease[$tag] awake was asked for --backend awake" grep -q -- '--backend awake -w' <<<"$out"
    rm -f "$MOCK_AWAKE_STATE/backend"

    # The automatic steps.
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto --yes 2>&1)
    st=$?
    res=$(newest "$PRE"/lease/lease-*.txt)
    for s in f a b d e; do
        check "lease[$tag] ($s) passes" grep -q "PASS ($s)" "$res"
    done
    check "lease[$tag] the decimal comma of /usr/bin/time is read" grep -q "renewals timed: min 80 ms, median 80 ms, max 80 ms" "$res"
    check "lease[$tag] the results file names the steps" grep -q "^Passed: f a b d e$" "$res"
    check "lease[$tag] exit 0" test $st -eq 0
    check "lease[$tag] no session, holder or renewer left" lease_leftovers
    check "lease[$tag] no session left running" test ! -f "$MOCK_AWAKE_STATE/session"
    check "lease[$tag] sudo's log lines: only the count is kept" hasnt "$res" SECRET
    check "lease[$tag] the results file records awake --status after each start" \
        test "$(grep -c '^awake --status: Awake is on.' "$res")" -eq 2

    # A start that exits 1 although the session starts, and shows up only
    # after the check read the status: cleanup still stops it.
    touch "$MOCK_AWAKE_STATE/start-fails"
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" auto --yes 2>&1)
    st=$?
    rm -f "$MOCK_AWAKE_STATE/start-fails"
    check "lease[$tag] a failed start whose session shows up late: exit 1, and cleanup stops it" \
        test $st -eq 1 -a -n "$(echo "$out" | grep 'no session runs as expected')" -a \
        ! -f "$MOCK_AWAKE_STATE/session" -a "$(tail -n 1 "$MOCK_AWAKE_STATE/ends" | cut -d' ' -f2)" = stopped
    check "lease[$tag] a failed start: nothing left running" lease_leftovers

    # The installed copy comes first; an awake from a repository checkout
    # on the PATH is used only after a question.
    local fake=$WORK/checkout$N
    mkdir -p "$fake/.git" "$fake/bin"
    cp "$MOCK/awake" "$fake/bin/awake"
    out=$(echo n | env -u AWAKE_BIN PATH="$fake/bin:$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" f 2>&1)
    st=$?
    check "lease[$tag] an awake from a repository checkout: asked, and refused on no" \
        test $st -eq 1 -a -n "$(echo "$out" | grep 'is in a repository checkout')"
    mkdir -p "$HOME/Library/Application Support/Awake/bin"
    cp "$MOCK/awake" "$HOME/Library/Application Support/Awake/bin/awake"
    out=$(env -u AWAKE_BIN PATH="$fake/bin:$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" f 2>&1)
    check "lease[$tag] the installed copy in ~/Library/Application Support/Awake/bin comes first" \
        test -n "$(echo "$out" | grep -F "awake: $HOME/Library/Application Support/Awake/bin/awake (awake 2.4.0")"
    rm -rf "$HOME/Library"

    # Ctrl+C in the middle of (a): the session it started is stopped and
    # its processes end.
    PATH="$MOCK:$PATH" with_sigint "$sh" "$KIT/lease-check.sh" auto --yes >"$WORK/int.$N" 2>&1 &
    local pid=$!
    sleep 4
    kill -INT -- "-$pid"
    wait "$pid"
    st=$?
    check "lease[$tag] Ctrl+C: exit 130" test $st -eq 130
    check "lease[$tag] Ctrl+C: the check's session was stopped" grep -q "Stopped the Awake session this check started" "$WORK/int.$N"
    check "lease[$tag] Ctrl+C: nothing left running" lease_leftovers
    check "lease[$tag] Ctrl+C: the stand-in recorded a stop" test "$(tail -n 1 "$MOCK_AWAKE_STATE/ends" | cut -d' ' -f2)" = stopped

    # Ctrl+C pressed again while the cleanup runs (each status read takes
    # 1 s here): the cleanup cannot be cut short.
    touch "$MOCK_AWAKE_STATE/slow"
    PATH="$MOCK:$PATH" with_sigint "$sh" "$KIT/lease-check.sh" auto --yes >"$WORK/int2.$N" 2>&1 &
    pid=$!
    local i
    for ((i = 0; i < 60; i++)); do
        [[ -f "$MOCK_AWAKE_STATE/session" ]] && break
        sleep 0.25
    done
    sleep 1
    kill -INT -- "-$pid"
    sleep 0.5
    kill -INT -- "-$pid" 2>/dev/null
    sleep 0.4
    kill -INT -- "-$pid" 2>/dev/null
    wait "$pid"
    st=$?
    rm -f "$MOCK_AWAKE_STATE/slow"
    check "lease[$tag] Ctrl+C three times: exit 130, and it says it is cleaning up" \
        test $st -eq 130 -a -n "$(grep 'Cleaning up' "$WORK/int2.$N")"
    check "lease[$tag] Ctrl+C three times: the session was stopped" \
        test ! -f "$MOCK_AWAKE_STATE/session" -a "$(tail -n 1 "$MOCK_AWAKE_STATE/ends" | cut -d' ' -f2)" = stopped
    check "lease[$tag] Ctrl+C three times: nothing left running" lease_leftovers

    # (c) and (g), the lid steps, with Enter pressed after the sleep.
    out=$( (echo y; sleep 12; echo) | PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" c 2>&1)
    res=$(newest "$PRE"/lease/lease-*.txt)
    check "lease[$tag] (c) guided: the exact prompt" test -n "$(echo "$out" | grep 'Close the lid NOW')"
    check "lease[$tag] (c) passes on the stand-in's pmset log" grep -q "PASS (c)" "$res"
    out=$( (echo y; sleep 24; echo) | PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" g 2>&1)
    res=$(newest "$PRE"/lease/lease-*.txt)
    check "lease[$tag] (g) passes on the stand-in's pmset log" grep -q "PASS (g)" "$res"
    check "lease[$tag] (c) and (g): nothing left running" lease_leftovers
    out=$(echo n | PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" c 2>&1)
    check "lease[$tag] (c) can be skipped" test -n "$(echo "$out" | grep '(c) skipped')"
}

# ----------------------------------------------------------- the collector

test_collect() {
    local sh=${1:-$BASH5} tag=${2:-bash5} out f
    new_home
    lease_env
    mkdir -p "$HOME/.claude" "$HOME/.codex" "$HOME/.cursor"
    printf '{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"my-own-SECRET-hook"}]}]}}' >"$HOME/.claude/settings.json"
    kitsh install claude codex cursor >/dev/null
    for f in "$PAY"/claude-*.json; do
        run_hook "$PRE/awake-hook-probe.sh" claude "$(basename "$f" .json | cut -d- -f2-)" "$f" >/dev/null
    done
    PATH="$MOCK:$PATH" "$sh" "$KIT/lease-check.sh" f >/dev/null 2>&1
    printf 'My note: the panel showed a SECRET-free card.\n' >"$PRE/notes.txt"
    local ext="$HOME/.cursor/extensions/anthropic.claude-code-2.1.300-darwin-arm64"
    mkdir -p "$ext/resources/native-binary"
    cp "$MOCK/claude" "$ext/resources/native-binary/claude"
    printf '{"name": "claude-code", "version": "2.1.300"}\n' >"$ext/package.json"
    # Gemini as 10.5 leaves it: installed, then restored before the collect.
    mkdir -p "$HOME/.gemini/extensions"
    AWAKE_PREFLIGHT_GEMINI=$MOCK/gemini kitsh install gemini >/dev/null
    AWAKE_PREFLIGHT_GEMINI=$MOCK/gemini kitsh restore gemini >/dev/null
    out=$(PATH="$MOCK:$PATH" "$sh" "$KIT/collect.sh" 2>&1)
    f=$(newest "$PRE"/results/preflight-*.txt)
    check "collect[$tag] says where the file is" test -n "$(echo "$out" | grep "Wrote ")" -a -s "$f"
    for s in "======== Versions" "======== Kit status" "======== The hook entries the kit installed" \
        "======== Probe log summary" "======== Probe logs" "======== Lease check (10.6)" \
        "2.1.300 (Claude Code)" "awake (" "Claude Code: ~/.claude/settings.json: on (13 of 13" \
        "PreToolUse [group" "UserPromptSubmit" "PASS (f)" "======== Your notes" "My note: the panel" \
        "extension anthropic.claude-code-2.1.300-darwin-arm64: version 2.1.300; bundled CLI at ~/.cursor/extensions/" \
        "======== The hook entries the kit installed (as installed" "# Gemini CLI, as installed" \
        "awake-probe-turn-start" "# Claude Code, as installed"; do
        check "collect[$tag] has: $s" has "$f" "$s"
    done
    check "collect[$tag] the home folder is written as ~" hasnt "$f" "$HOME"
    check "collect[$tag] no content, and not the user's own hooks" hasnt "$f" "my-own-SECRET-hook"
    check "collect[$tag] no probe content" test -z "$(grep SECRET "$f" | grep -v 'SECRET-free')"
    check "collect[$tag] the file is private (600)" test "$(mode_of "$f")" = 600
    # No claude on the PATH: the old local install is found.
    local nc=$WORK/noclaude$N t
    mkdir -p "$nc" "$HOME/.claude/local"
    for t in awake pmset log sudo time helper; do
        ln -s "$MOCK/$t" "$nc/$t"
    done
    cp "$MOCK/claude" "$HOME/.claude/local/claude"
    sleep 1
    PATH="$nc:/usr/bin:/bin" "$sh" "$KIT/collect.sh" >/dev/null 2>&1
    f=$(newest "$PRE"/results/preflight-*.txt)
    check "collect[$tag] finds claude in ~/.claude/local when it is not on the PATH" \
        has "$f" "claude (~/.claude/local/claude): 2.1.300 (Claude Code)"
}

# ------------------------------------------------------------------ lint

test_lint() {
    local sc f out
    sc=${SHELLCHECK:-$(command -v shellcheck || true)}
    if [[ -z "$sc" ]]; then
        printf 'skip  shellcheck not found (set SHELLCHECK=/path/to/shellcheck)\n'
    else
        for f in "$KIT"/*.sh "$HERE"/run-tests.sh "$MOCK"/*; do
            if out=$("$sc" -x "$f" 2>&1); then
                pass "shellcheck $(basename "$f")"
            else
                fail "shellcheck $(basename "$f")" "$out"
            fi
        done
    fi
    for f in "$KIT"/*.sh; do
        check "bash -n $(basename "$f")" "$BASH5" -n "$f"
        if [[ -n "$BASH32" ]]; then
            check "bash 3.2 -n $(basename "$f")" "$BASH32" -n "$f"
        fi
    done
    # compile() rather than py_compile, which would leave a __pycache__.
    check "python compiles kit.py and the facts script" python3 -c 'import sys
for p in sys.argv[1:]:
    compile(open(p, encoding="utf-8").read(), p, "exec")' "$KIT/kit.py" "$KIT/awake-hook-probe-facts.py"
    check "the kit holds no __pycache__" test -z "$(find "$KIT" -name __pycache__)"
    check "the kit's scripts are executable" test -x "$KIT/probe.sh" -a -x "$KIT/lease-check.sh" -a \
        -x "$KIT/collect.sh" -a -x "$KIT/awake-hook-probe.sh" -a -x "$KIT/awake-stop-block.sh"
}

main() {
    local sections=("$@")
    if [[ ${#sections[@]} -eq 0 ]]; then
        sections=(probe install lease collect lint)
    fi
    for s in "${sections[@]}"; do
        case $s in
            probe)
                test_probe_payloads "" bash5
                test_probe_behaviour "" bash5
                test_probe_extras
                if [[ -n "$BASH32" ]]; then
                    test_probe_payloads "$BASH32" bash3.2
                    test_probe_behaviour "$BASH32" bash3.2
                fi
                ;;
            install)
                SH=$BASH5 test_install_shapes
                SH=$BASH5 test_install_cases
                SH=$BASH5 test_install_more
                SH=$BASH5 test_gemini
                SH=$BASH5 test_stop_block
                if [[ -n "$BASH32" ]]; then
                    SH=$BASH32 test_install_shapes
                    SH=$BASH32 test_install_cases
                    SH=$BASH32 test_install_more
                    SH=$BASH32 test_gemini
                    SH=$BASH32 test_stop_block
                fi
                ;;
            lease)
                test_lease "$BASH5" bash5
                if [[ -n "$BASH32" ]]; then
                    test_lease "$BASH32" bash3.2
                fi
                ;;
            collect)
                test_collect "$BASH5" bash5
                if [[ -n "$BASH32" ]]; then
                    test_collect "$BASH32" bash3.2
                fi
                ;;
            lint) test_lint ;;
            *) printf 'unknown section %s\n' "$s" >&2 ;;
        esac
    done
    HOME=$REAL_HOME
    printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
    if [[ $FAIL -eq 0 ]]; then
        rm -rf "$WORK"
    else
        printf 'Work folder kept: %s\n' "$WORK"
    fi
    [[ $FAIL -eq 0 ]]
}

main "$@"
