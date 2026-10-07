#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# The Awake preflight probe (docs/plans/agent-keep-awake.md, 10.1).
#
# tools/ai-preflight/probe.sh installs a copy of this file and puts it in
# each agent's hook file, in K2's form:
#   '<path>' AGENT LABEL >/dev/null 2>&1; exit 0
# Each run appends to the current run's log in the preflight folder: when it
# ran (milliseconds), which handler, the processes above it, the input idle
# time, a few environment markers, how its read of stdin went, and only
# privacy-safe facts about the payload (key names, offsets, ids and types,
# from awake-hook-probe-facts.py). It never logs prompt text, tool input or
# output, file contents or assistant messages.
#
# It must never hold up or break an agent: it prints nothing, always exits
# 0, reads stdin with a time limit, and a watchdog stops it after 3 s.

# probe.sh fills in these three values when it installs the probe.
PROBE_DIR='@@PROBE_DIR@@'
PROBE_PYTHON='@@PROBE_PYTHON@@'
PROBE_MAIN='@@PROBE_MAIN@@'

exec >/dev/null 2>&1
umask 077
LC_ALL=C
export LC_ALL

probe_pid=$$
probe_agent=${1:-}
probe_label=${2:-}
case "$probe_agent" in
    claude|codex|cursor|gemini) ;;
    *) probe_agent="?${probe_agent//[^A-Za-z0-9._-]/}" ;;
esac
probe_label=${probe_label//[^A-Za-z0-9._-]/}
probe_label=${probe_label:0:64}
probe_agent=${probe_agent:0:16}

probe_log="$PROBE_DIR/logs/current.log"
if [[ ! -e "$probe_log" ]]; then
    probe_log="$PROBE_DIR/logs/no-run.log"
fi
probe_log_used=main
probe_fallback_log="${TMPDIR:-/tmp}"
probe_fallback_log="${probe_fallback_log%/}/awake-hook-probe-fallback.log"
probe_fallback2_log="/tmp/awake-hook-probe-fallback-${UID}.log"

# Appends $1 and a newline to file $2 in one write, so that the lines of
# hooks that run at the same time do not interleave: /bin/echo writes its
# arguments with one writev on macOS (and one buffered write with GNU's),
# where the printf of /bin/bash 3.2 writes each line on its own. The text
# never starts with - and holds no backslash, so echo prints it as it is.
probe_put() {
    if [[ -x /bin/echo ]]; then
        /bin/echo "$1" >>"$2"
    else
        printf '%s\n' "$1" >>"$2"
    fi
}

# Appends $1 to the log; falls back to a file in $TMPDIR, then to one in
# /tmp, when the log cannot be written (a sandbox, for example). collect.sh
# gathers all three.
probe_write() {
    if [[ "$probe_log_used" == main ]]; then
        if { probe_put "$1" "$probe_log"; } 2>/dev/null; then
            return 0
        fi
        probe_log_used=fallback
    fi
    if [[ "$probe_log_used" == fallback ]]; then
        if { probe_put "$1" "$probe_fallback_log"; } 2>/dev/null; then
            return 0
        fi
        probe_log_used=fallback2
    fi
    { probe_put "$1" "$probe_fallback2_log"; } 2>/dev/null
}

probe_clock_re='^([0-9][0-9]:[0-9][0-9]:[0-9][0-9]) ([0-9]+) ([0-9]+)$'
# Sets CLOCK_HMS (local HH:MM:SS.mmm), CLOCK_MS (epoch milliseconds) and
# CLOCK_KIND. macOS's /bin/bash 3.2 has no clock below a second, so this
# asks zsh's datetime module, else perl, else Python, else whole seconds.
probe_clock() {
    local out="" hms="" sec="" ns="" ms=""
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        sec=${EPOCHREALTIME%[.,]*}
        ns=${EPOCHREALTIME#*[.,]}000000000
        ms=${ns:0:3}
        printf -v hms '%(%H:%M:%S)T' "$sec"
        CLOCK_HMS="$hms.$ms"
        CLOCK_MS="$sec$ms"
        CLOCK_KIND=bash
        return 0
    fi
    if [[ -x /bin/zsh ]]; then
        out=$(/bin/zsh -fc 'zmodload zsh/datetime && strftime -s t %H:%M:%S $epochtime[1] && print -r -- $t $epochtime[1] $epochtime[2]' </dev/null 2>/dev/null) || out=""
        CLOCK_KIND=zsh
    fi
    if [[ -z "$out" && -x /usr/bin/perl ]]; then
        out=$(/usr/bin/perl -MPOSIX=strftime -MTime::HiRes=gettimeofday -e '($s, $u) = gettimeofday(); print strftime("%H:%M:%S", localtime($s)), " $s ", $u * 1000, "\n"' </dev/null 2>/dev/null) || out=""
        CLOCK_KIND=perl
    fi
    if [[ -z "$out" && -n "$PROBE_PYTHON" && -x "$PROBE_PYTHON" ]]; then
        out=$("$PROBE_PYTHON" -I -S -c 'import time; t = time.time(); s = int(t); print(time.strftime("%H:%M:%S", time.localtime(s)), s, int((t - s) * 1e9))' </dev/null 2>/dev/null) || out=""
        CLOCK_KIND=python
    fi
    if [[ "$out" =~ $probe_clock_re ]]; then
        hms=${BASH_REMATCH[1]}
        sec=${BASH_REMATCH[2]}
        ns=000000000${BASH_REMATCH[3]}
        ns=${ns:${#ns}-9}
        CLOCK_HMS="$hms.${ns:0:3}"
        CLOCK_MS="$sec${ns:0:3}"
        return 0
    fi
    CLOCK_HMS="$(date +%H:%M:%S </dev/null).000"
    sec=$(date +%s </dev/null)
    CLOCK_MS="${sec}000"
    CLOCK_KIND=seconds
}

# Sets the variable named $1 to $2 as it may be logged: the home folder as
# ~, and the value itself only when it looks like an id, a version or a
# path; anything else by its length.
probe_safe_re='^[A-Za-z0-9._:@+~/-]{0,160}$'
probe_safe_into() {
    local v=$2
    if [[ -n "${HOME:-}" && "$v" == "$HOME"* ]]; then
        v="~${v#"$HOME"}"
    fi
    if [[ "$v" =~ $probe_safe_re ]]; then
        case "$v" in
            *' '*) printf -v "$1" '"%s"' "$v" ;;
            *) printf -v "$1" '%s' "$v" ;;
        esac
    else
        printf -v "$1" '<len %d>' "${#v}"
    fi
}

# Like probe_safe_into, for a process name, which may hold spaces.
probe_name_re='^[A-Za-z0-9._:@+~/ ()-]{0,200}$'
probe_name_into() {
    local v=$2
    if [[ -n "${HOME:-}" && "$v" == "$HOME"* ]]; then
        v="~${v#"$HOME"}"
    fi
    if [[ "$v" =~ $probe_name_re ]]; then
        case "$v" in
            *' '*) printf -v "$1" '"%s"' "$v" ;;
            *) printf -v "$1" '%s' "$v" ;;
        esac
    else
        printf -v "$1" '<len %d>' "${#v}"
    fi
}

# Stops the probe if it is still running after 3 s, and says why; also says
# when the probe was killed before it finished (by the agent's time limit).
probe_watchdog() {
    local s=""
    trap 'kill "$s" 2>/dev/null; exit 0' TERM
    sleep 3 &
    s=$!
    wait "$s"
    if kill -0 "$probe_pid" 2>/dev/null &&
        ps -o args= -p "$probe_pid" 2>/dev/null | grep -q 'awake-hook-probe'; then
        probe_write "  [$probe_pid] watchdog: still running after 3 s; stopped it (stdin or a command hung)"
        kill -KILL "$probe_pid" 2>/dev/null
    else
        probe_write "  [$probe_pid] watchdog: the probe ended before it finished (killed, perhaps at the agent's time limit)"
    fi
    exit 0
}

probe_clock
probe_t0=$CLOCK_MS
probe_write "$CLOCK_HMS $probe_agent $probe_label pid=$probe_pid START"

probe_watchdog </dev/null >/dev/null 2>&1 &
probe_watchdog_pid=$!

# HIDIdleTime, the input idle time W26 and W31 read, in seconds: first, so
# that the probe's own work does not add to it; idle_at says how long after
# the start it was read.
probe_idle=""
if [[ -x /usr/sbin/ioreg ]]; then
    probe_idle=$(/usr/sbin/ioreg -c IOHIDSystem </dev/null 2>/dev/null |
        awk '/HIDIdleTime/ { printf "%.3fs", $NF / 1000000000; exit }' 2>/dev/null)
fi
probe_idle=${probe_idle:-NA}
probe_clock
probe_idle_at=$((CLOCK_MS - probe_t0))

# The payload: read and summarized by the facts script, which never prints
# content. Without Python, only the length and a raw scan of key names.
probe_here=${0%/*}
probe_facts=""
probe_status=0
probe_read=0
if [[ -n "$PROBE_PYTHON" && -x "$PROBE_PYTHON" && -f "$probe_here/awake-hook-probe-facts.py" ]]; then
    # Python's error text comes with its output, so that when it fails
    # (under a sandbox, for example) its last line can say why: that text
    # never holds the payload, and only letters, digits and a little
    # punctuation of it are kept. On success only the facts' own lines are.
    probe_out=$("$PROBE_PYTHON" -I -S "$probe_here/awake-hook-probe-facts.py" 2>&1) || probe_status=$?
    probe_facts=""
    probe_err=""
    while IFS= read -r probe_line; do
        [[ -n "$probe_line" ]] && probe_err=$probe_line
        case "$probe_line" in
            "stdin "* | "note: "* | "json "* | "content "* | "ids "* | "values "* | "w2 "* | "facts error: "*)
                case "$probe_line" in
                    "stdin "*) probe_read=1 ;;
                esac
                probe_facts="$probe_facts$probe_line
" ;;
        esac
    done <<EOF
$probe_out
EOF
    if [[ "$probe_status" -ne 0 || -z "$probe_facts" ]]; then
        probe_err=${probe_err//[^A-Za-z0-9 ._:\/()=-]/?}
        probe_facts="${probe_facts}facts: the facts script failed (exit $probe_status)${probe_err:+: ${probe_err:0:160}}"
    fi
    unset probe_out
else
    probe_payload=$(cat)
    probe_read=1
    probe_facts="stdin eof (no Python: time not measured), ${#probe_payload} bytes"
    probe_scan=$(printf '%s' "$probe_payload" |
        grep -a -o -b -E '"(session_id|agent_id|conversation_id|generation_id|child_conversation_id|effort|timestamp|hook_event_name|tool_name|prompt|tool_input|tool_response|tool_output|last_assistant_message|text|attachments|prompt_response|message|details|llm_request)"[[:space:]]*:' 2>/dev/null |
        head -n 40 | sed -n 's/^\([0-9][0-9]*\):"\([a-z_]*\)".*/\2@\1/p' | tr '\n' ' ')
    probe_facts="$probe_facts
scan (any depth, no Python): ${probe_scan:-none}"
    unset probe_payload
fi

# The first write: the idle time and the payload's facts, as soon as they
# are known, so that a kill at an agent's time limit (Codex's 1 s for
# Interrupt and SessionEnd, Claude Code's 1.5 s at exit) does not lose them.
probe_first="  [$probe_pid] idle=$probe_idle idle_at=+${probe_idle_at}ms"
while IFS= read -r probe_line; do
    [[ -n "$probe_line" ]] && probe_first="$probe_first
  [$probe_pid] $probe_line"
done <<EOF
$probe_facts
EOF
probe_write "$probe_first"

# The processes above the probe: the shell that ran the handler (comm), the
# process Awake would watch (gcomm), and four more levels.
probe_ppid=$PPID
probe_chain=$(ps -A -o pid= -o ppid= -o comm= 2>/dev/null |
    awk -v start="$probe_ppid" '
        { line = $0; sub(/^ *[0-9]+ +[0-9]+ /, "", line); parent[$1] = $2; name[$1] = line }
        END { p = start; for (i = 0; i < 6 && p != "" && p > 0; i++) { printf "%s\t%s\n", p, name[p]; p = parent[p] } }' 2>/dev/null)
probe_comm=""
probe_gp=""
probe_gcomm=""
probe_more=""
probe_level=0
while IFS=$'\t' read -r probe_p probe_name; do
    [[ -n "$probe_p" ]] || continue
    probe_name_into probe_name "$probe_name"
    case $probe_level in
        0) probe_comm=$probe_name ;;
        1) probe_gp=$probe_p; probe_gcomm=$probe_name ;;
        *) probe_more="$probe_more < $probe_p:$probe_name" ;;
    esac
    probe_level=$((probe_level + 1))
done <<EOF
$probe_chain
EOF
probe_pflag=""
probe_pargs=$(ps -o args= -p "$probe_ppid" 2>/dev/null) || probe_pargs=""
# The flag after the shell's name: -c, or -lc for a login shell (Codex's
# fallback, 2.3). Nothing else of the command line is kept.
read -r _ probe_a1 _ <<EOF
$probe_pargs
EOF
case "${probe_a1:-}" in
    -*) probe_pflag=${probe_a1:0:8} ;;
esac
unset probe_pargs

probe_tmpw=fail
if { : >>"/tmp/awake-preflight-${UID}.tmpw"; } 2>/dev/null; then
    probe_tmpw=ok
fi

probe_copy=other
if [[ "$0" == "$PROBE_MAIN" ]]; then
    probe_copy=main
elif [[ "$0" == *" "* ]]; then
    probe_copy=space
fi

probe_rc=""
if [[ -n "${CLAUDE_CODE_BRIDGE_SESSION_ID:-}" ]]; then
    probe_rc=rc
fi
# The names, never the values, of the agents' environment variables.
probe_names=""
probe_count=0
if probe_all=$(compgen -e 2>/dev/null); then
    for probe_n in $probe_all; do
        case "$probe_n" in
            CLAUDE*|CURSOR*|CODEX*|GEMINI*|VSCODE*|TERM_PROGRAM|ANTHROPIC*|OPENAI*)
                probe_count=$((probe_count + 1))
                if ((probe_count <= 60)); then
                    probe_names="$probe_names $probe_n"
                fi ;;
        esac
    done
    if ((probe_count > 60)); then
        probe_names="$probe_names (+$((probe_count - 60)) more)"
    fi
fi

probe_clock
probe_took=$((CLOCK_MS - probe_t0))

probe_v_ccsid="" probe_v_child="" probe_v_entry="" probe_v_cursor="" probe_v_layout=""
probe_v_gsid="" probe_v_cfg="" probe_v_role="" probe_v_term="" probe_v_shell=""
probe_safe_into probe_v_ccsid "${CLAUDE_CODE_SESSION_ID:-}"
probe_safe_into probe_v_child "${CLAUDE_CODE_CHILD_SESSION:-}"
probe_safe_into probe_v_entry "${CLAUDE_CODE_ENTRYPOINT:-}"
probe_safe_into probe_v_cursor "${CURSOR_VERSION:-}"
probe_safe_into probe_v_layout "${CURSOR_LAYOUT:-}"
probe_safe_into probe_v_gsid "${GEMINI_SESSION_ID:-}"
probe_safe_into probe_v_cfg "${CLAUDE_CONFIG_DIR:-}"
probe_safe_into probe_v_role "${CURSOR_EXTENSION_HOST_ROLE:-}"
probe_safe_into probe_v_term "${TERM_PROGRAM:-}"
probe_safe_into probe_v_shell "${SHELL:-}"

# The second write: how the run went, the processes and the environment.
probe_write "  [$probe_pid] done t0=$probe_t0 took=${probe_took}ms copy=$probe_copy log=$probe_log_used tmpw=$probe_tmpw clock=$CLOCK_KIND
  [$probe_pid] proc ppid=$probe_ppid comm=$probe_comm pflag=$probe_pflag gp=$probe_gp gcomm=$probe_gcomm${probe_more:+ chain$probe_more}
  [$probe_pid] env ccsid=$probe_v_ccsid child=$probe_v_child entry=$probe_v_entry rc=$probe_rc cursor=$probe_v_cursor layout=$probe_v_layout gsid=$probe_v_gsid cfg=$probe_v_cfg role=$probe_v_role term=$probe_v_term shell=$probe_v_shell
  [$probe_pid] envnames${probe_names:- none}"

# When the facts script failed before it read stdin (a Python that cannot
# run under a sandbox, say), or said nothing about it, nothing has read the
# payload: read it here, so that the agent's write does not fail (EPIPE)
# and 10.1's gate is still measured. The watchdog bounds this read too.
if [[ "$probe_read" -eq 0 ]]; then
    probe_clock
    probe_d0=$CLOCK_MS
    probe_n=$(cat | wc -c | tr -d ' ')
    probe_clock
    probe_write "  [$probe_pid] stdin eof after $((CLOCK_MS - probe_d0)) ms (read by bash, as the facts script failed; $((CLOCK_MS - probe_t0)) ms after the start), ${probe_n:-0} bytes"
fi

kill "$probe_watchdog_pid" 2>/dev/null

# 10.2's last look from inside a hook (W21), only while probe.sh
# last-look-hook is on: Claude Code's Stop runs claude agents --json in the
# background, with the hook's environment, detached like Awake's watcher.
if [[ "$probe_agent" == claude && "$probe_label" == Stop && -f "$PROBE_DIR/last-look-hook" &&
    -n "$PROBE_PYTHON" && -x "$PROBE_PYTHON" ]]; then
    IFS= read -r probe_claude <"$PROBE_DIR/last-look-hook" || probe_claude=""
    if [[ -x "$probe_claude" ]]; then
        (
            probe_out=$("$PROBE_PYTHON" -I -S "$probe_here/awake-hook-probe-facts.py" --last-look "$probe_claude" 2>/dev/null) ||
                probe_out="the facts script failed"
            probe_write "  [$probe_pid] last look from the hook (child=${CLAUDE_CODE_CHILD_SESSION:-}): $probe_out"
        ) </dev/null >/dev/null 2>&1 &
    fi
fi
exit 0
