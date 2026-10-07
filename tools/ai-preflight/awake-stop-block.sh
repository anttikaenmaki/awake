#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# 10.3 (c) of docs/plans/agent-keep-awake.md: "a user Stop hook that sleeps
# 90 s and then exits 2: whether the continuation fires UserPromptSubmit".
#
# tools/ai-preflight/probe.sh stop-block on puts this in Claude Code's
# settings.json as a Stop handler with a 150 s timeout; stop-block off, or
# restore claude, takes it out again. On a Stop it waits 90 s, then exits 2,
# which makes Claude Code go on with the turn and show Claude the line it
# prints on stderr. It notes each step, and why it let a Stop through, in
# the probe's run log.
#
# Every program that reads ~/.claude/settings.json runs this handler: the
# Claude Code panel in Cursor or VS Code, Cursor's own agent through its
# third-party import (which has no stop_hook_active and no loop limit for
# these hooks, so an exit 2 there could loop), and Copilot with
# chat.useClaudeHooks. So it holds a Stop only:
#   - while stop-block on is less than 20 minutes old;
#   - for Claude Code itself (CLAUDE_CODE_SESSION_ID set, env-vars.md:371)
#     outside Cursor (no CURSOR_VERSION), as in Terminal;
#   - for a Claude Code payload (no conversation_id, loop_count or
#     timestamp key, which Cursor's and Copilot's payloads have);
#   - once per session, and never a Stop with "stop_hook_active": true.

# probe.sh fills in this value when it installs the hook.
PROBE_DIR='@@PROBE_DIR@@'

LC_ALL=C
export LC_ALL

payload=$(cat)
log="$PROBE_DIR/logs/current.log"
state="$PROBE_DIR/state"

note() {
    { printf '##### %s stop-block: %s\n' "$(date +%H:%M:%S)" "$1" >>"$log"; } 2>/dev/null
}

pass() {
    note "$1: this Stop goes through (exit 0)"
    exit 0
}

since=""
{ IFS= read -r since <"$state/stop-block-on"; } 2>/dev/null || true
now=$(date +%s)
if [[ ! "$since" =~ ^[0-9]+$ ]]; then
    pass "stop-block is not on (no $state/stop-block-on)"
fi
if ((now - since > 1200)); then
    pass "stop-block on is older than 20 minutes; run probe.sh stop-block on again to retry"
fi
if [[ -n "${CURSOR_VERSION:-}" ]]; then
    pass "CURSOR_VERSION is set (Cursor's agent, the Claude Code panel in Cursor, or claude in Cursor's terminal); 10.3 (c) runs in Terminal"
fi
if [[ -z "${CLAUDE_CODE_SESSION_ID:-}" ]]; then
    pass "CLAUDE_CODE_SESSION_ID is not set, so this is not Claude Code's own hook"
fi
# Every quote inside a JSON string is escaped, so an unescaped match is a
# key.
foreign_re='"(conversation_id|loop_count|timestamp)"[[:space:]]*:'
if [[ "$payload" =~ $foreign_re ]]; then
    pass "the payload has the key ${BASH_REMATCH[1]} (Cursor's agent or Copilot, not Claude Code)"
fi
active_re='"stop_hook_active"[[:space:]]*:[[:space:]]*true'
if [[ "$payload" =~ $active_re ]]; then
    pass "stop_hook_active is true"
fi
sid=${CLAUDE_CODE_SESSION_ID//[^A-Za-z0-9._-]/}
sid=${sid:0:128}
done_flag="$state/stop-block-done-$sid"
if [[ -e "$done_flag" ]]; then
    pass "this session ($sid) was already held once"
fi
if ! { : >"$done_flag"; } 2>/dev/null; then
    pass "cannot write $done_flag, which keeps the hold to once per session"
fi
hold=90
# The tests hold for less; this is read only when they run.
if [[ "${AWAKE_PREFLIGHT_TEST:-}" == 1 && "${AWAKE_PREFLIGHT_TEST_STOP_BLOCK_SECONDS:-}" =~ ^[0-9]+$ ]]; then
    hold=$AWAKE_PREFLIGHT_TEST_STOP_BLOCK_SECONDS
fi
note "holding this Stop of session $sid for $hold s, then exit 2"
sleep "$hold"
note "exit 2 now: Claude Code should go on with the turn"
printf '%s\n' "Awake preflight test 10.3 (c): please go on with one short step: run the shell command date, then stop." >&2
exit 2
