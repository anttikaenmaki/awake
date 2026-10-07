#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# 10.6 of docs/plans/agent-keep-awake.md: the lease, with today's Awake.
#
#   lease-check.sh            (f), then (a), (b), (d), (e); then offers (c) and (g)
#   lease-check.sh auto       only the automatic steps (f), (a), (b), (d), (e)
#   lease-check.sh c | g | f  one step
#   --yes                     answer yes to "start a session?" (not to the lid steps)
#
# Run it in Terminal, with the lid open, the Mac plugged in, password-free
# mode on and no Awake session running. It asks before it starts a session.
# It runs the installed awake, ~/Library/Application Support/Awake/bin/awake
# (what the awake command runs), and records awake --status after each start.
# (c) and (g) need the lid closed: it says exactly when to close and open
# it. Everything goes to a results file in ~/awake-preflight/lease/. On exit,
# Ctrl+C included, it ends the renewal loops and the stand-in process it
# started, and stops an Awake session only if it is one this script started.
#
# It runs under /bin/bash (Apple's bash 3.2), as 10.6 asks, uses sudo only
# as 10.6 does (sudo -n with the installed helper's extend), and no network.

set -euo pipefail

KIT_SRC=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
PREFLIGHT_DIR=${AWAKE_PREFLIGHT_DIR:-$HOME/awake-preflight}
PY=${AWAKE_PREFLIGHT_PYTHON:-/usr/bin/python3}
TEST_MODE=${AWAKE_PREFLIGHT_TEST:-0}

HELPER=/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper
TIME_BIN=/usr/bin/time
F_BASH=/bin/bash
LEASE=120
RENEW=30
SAMPLE=60
SAMPLES=5
FLOOR_START=90
FLOOR_SPAN=180
# The tests run this on Linux with stand-ins and shorter times; these
# variables are read only then.
if [[ "$TEST_MODE" == 1 ]]; then
    HELPER=${AWAKE_PREFLIGHT_TEST_HELPER:-$HELPER}
    TIME_BIN=${AWAKE_PREFLIGHT_TEST_TIME:-$TIME_BIN}
    F_BASH=${AWAKE_PREFLIGHT_TEST_BASH:-$F_BASH}
    LEASE=${AWAKE_PREFLIGHT_TEST_LEASE:-$LEASE}
    RENEW=${AWAKE_PREFLIGHT_TEST_RENEW:-$RENEW}
    SAMPLE=${AWAKE_PREFLIGHT_TEST_SAMPLE:-$SAMPLE}
    SAMPLES=${AWAKE_PREFLIGHT_TEST_SAMPLES:-$SAMPLES}
    FLOOR_START=${AWAKE_PREFLIGHT_TEST_FLOOR_START:-$FLOOR_START}
    FLOOR_SPAN=${AWAKE_PREFLIGHT_TEST_FLOOR_SPAN:-$FLOOR_SPAN}
fi

MODE=all
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        all | auto | a | b | c | d | e | f | g) MODE=$arg ;;
        --yes) ASSUME_YES=true ;;
        -h | --help)
            sed -n '4,21p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf 'lease-check.sh: unknown argument %s (see --help)\n' "$arg" >&2
            exit 2
            ;;
    esac
done
case "$MODE" in
    a | b | d | e) MODE=auto ;;
esac

AWAKE=""
RESULTS=""
RENEW_LOG=""
FLOOR_LOG=""
STOP_FILE=""
HOLDER=""
RENEWER=""
STOPPER=""
FLOOR=""
OUR_TOKENS=""
PENDING_START=false
STATUS_JSON=""
REPLY=""
PASSES=""
FAILS=""
T_RENEW_START=""

say() {
    printf '%s\n' "$*"
    if [[ -n "$RESULTS" ]]; then
        printf '%s\n' "$*" >>"$RESULTS"
    fi
}

record() {
    if [[ -n "$RESULTS" ]]; then
        printf '%s\n' "$*" >>"$RESULTS"
    fi
}

die() {
    say "lease-check.sh: $*"
    exit 1
}

verdict() {
    # verdict STEP PASS|FAIL|NOTE TEXT
    say "  $2 ($1): $3"
    case "$2" in
        PASS) PASSES="$PASSES $1" ;;
        FAIL) FAILS="$FAILS $1" ;;
    esac
}

now_s() {
    date +%s
}

# Milliseconds since the epoch: /bin/bash 3.2 has no clock below a second.
now_ms() {
    local out=""
    if [[ -n "${EPOCHREALTIME:-}" ]]; then
        out=${EPOCHREALTIME//[.,]/}
        printf '%s' "${out:0:${#out}-3}"
        return 0
    fi
    if [[ -x /bin/zsh ]]; then
        out=$(/bin/zsh -fc 'zmodload zsh/datetime && print -r -- $(( epochtime[1] * 1000 + epochtime[2] / 1000000 ))' 2>/dev/null) || out=""
    fi
    if [[ -z "$out" && -x /usr/bin/perl ]]; then
        out=$(/usr/bin/perl -MTime::HiRes=time -e 'printf "%d", time() * 1000' 2>/dev/null) || out=""
    fi
    if [[ -z "$out" ]]; then
        out="$(date +%s)000"
    fi
    printf '%s' "$out"
}

# confirm QUESTION [ask]: --yes answers it, unless a second word (lid, ask)
# says that only the owner may.
confirm() {
    local answer=""
    if [[ "$ASSUME_YES" == true && -z "${2:-}" ]]; then
        say "$1 [y/N] y (--yes)"
        return 0
    fi
    printf '%s [y/N] ' "$1"
    read -r answer || answer=""
    record "$1 [y/N] $answer"
    [[ "$answer" == y || "$answer" == Y || "$answer" == yes ]]
}

wait_enter() {
    local answer=""
    printf '%s ' "$1"
    read -r answer || true
    record "$1 (Enter at $(date '+%H:%M:%S'))"
}

read_status() {
    STATUS_JSON=$("$AWAKE" --status-json 2>/dev/null) || STATUS_JSON=""
}

# Sets REPLY to the value of the top-level field $1 of STATUS_JSON (a
# string without quotes, or true, false, null or a number); empty when the
# field is missing. Always returns 0.
json_field() {
    local re_str="\"$1\":\"([^\"]*)\""
    local re_lit="\"$1\":(true|false|null|-?[0-9]+)"
    REPLY=""
    if [[ "$STATUS_JSON" =~ $re_str ]]; then
        REPLY=${BASH_REMATCH[1]}
    elif [[ "$STATUS_JSON" =~ $re_lit ]]; then
        REPLY=${BASH_REMATCH[1]}
    fi
    return 0
}

# Runs a command for at most $1 seconds (macOS has no timeout command).
run_limited() {
    local secs=$1 pid w status=0
    shift
    "$@" &
    pid=$!
    (sleep "$secs" && kill -TERM "$pid" 2>/dev/null) </dev/null >/dev/null 2>&1 &
    w=$!
    wait "$pid" || status=$?
    pkill -P "$w" 2>/dev/null || true
    kill "$w" 2>/dev/null || true
    wait "$w" 2>/dev/null || true
    return "$status"
}

# True when STATUS_JSON shows a session; leaves REPLY alone.
session_active() {
    local re='"active":true[,}]'
    [[ "$STATUS_JSON" =~ $re ]]
}

# Sleeps $1 seconds in a way a signal can cut short (the trap then runs at
# once, not after the sleep).
NAP=""
nap() {
    sleep "$1" &
    NAP=$!
    wait "$NAP" || true
    NAP=""
}

is_our_token() {
    [[ -n "$1" && " $OUR_TOKENS " == *" $1 "* ]]
}

# Ends a background loop, then the command it runs at the moment (the loop
# first, so that it records no renewal cut short).
stop_loop() {
    local pid=$1 kids=""
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kids=$(pgrep -P "$pid" 2>/dev/null || true)
        kill "$pid" 2>/dev/null || true
        kill -CONT "$pid" 2>/dev/null || true
        if [[ -n "$kids" ]]; then
            # shellcheck disable=SC2086 # one PID per word
            kill $kids 2>/dev/null || true
        fi
        wait "$pid" 2>/dev/null || true
    fi
}

cleanup() {
    local status=$?
    set +e
    # Nothing may cut the cleanup short: a second Ctrl+C would otherwise
    # leave this check's session and its stand-in process behind. The
    # commands it runs (awake --stop) inherit the ignore.
    trap '' INT TERM HUP
    trap - EXIT
    if [[ -n "$HOLDER$RENEWER$STOPPER$FLOOR" || "$PENDING_START" == true ]] ||
        [[ "$status" -ne 0 && -n "$OUR_TOKENS" ]]; then
        say ""
        say "Cleaning up (stopping this check's session and helper processes) ..."
    fi
    if [[ -n "$NAP" ]]; then
        kill "$NAP" 2>/dev/null
    fi
    stop_loop "$STOPPER"
    stop_loop "$RENEWER"
    stop_loop "$FLOOR"
    if [[ -n "$AWAKE" && ( -n "$OUR_TOKENS" || "$PENDING_START" == true ) ]]; then
        read_status
        json_field session_token
        # PENDING_START: interrupted between awake's start and reading the
        # new token; no session ran just before (ensure_no_session), so a
        # running one is this check's.
        if session_active && { is_our_token "$REPLY" || [[ "$PENDING_START" == true ]]; }; then
            "$AWAKE" --stop >>"${RESULTS:-/dev/null}" 2>&1
            say "Stopped the Awake session this check started."
        fi
    fi
    if [[ -n "$HOLDER" ]] && kill -0 "$HOLDER" 2>/dev/null; then
        kill "$HOLDER" 2>/dev/null
        wait "$HOLDER" 2>/dev/null
    fi
    if [[ -n "$STOP_FILE" ]]; then
        rm -f "$STOP_FILE"
    fi
    if [[ -n "$RESULTS" ]]; then
        say ""
        say "Passed:${PASSES:- none}"
        say "Failed:${FAILS:- none}"
        say "Results: $RESULTS"
    fi
    exit "$status"
}

new_holder() {
    if [[ -n "$HOLDER" ]] && kill -0 "$HOLDER" 2>/dev/null; then
        return 0
    fi
    # Stands in for the watcher's PID (10.6).
    sleep 7200 >/dev/null 2>&1 &
    HOLDER=$!
    record "holder: sleep 7200, PID $HOLDER"
}

ensure_no_session() {
    read_status
    if [[ -z "$STATUS_JSON" ]]; then
        die "awake --status-json gave no answer."
    fi
    if session_active; then
        json_field session_token
        if is_our_token "$REPLY"; then
            "$AWAKE" --stop >>"$RESULTS" 2>&1 || true
            say "  (stopped this check's earlier session first)"
        else
            die "an Awake session is running that this check did not start. Stop it (awake --stop) and run this again."
        fi
    fi
}

# Starts a lid-closed session with the given awake arguments and records
# its token. awake runs with this script's own terminal, as when 10.6's
# commands are typed in Terminal: it picks its terminal mode only when its
# input and output are both a terminal, so its output is not captured here.
start_session() {
    local token="" status=0 backend=""
    ensure_no_session
    say "  \$ awake --backend awake $*"
    PENDING_START=true
    "$AWAKE" --backend awake "$@" || status=$?
    read_status
    json_field session_token
    token=$REPLY
    if [[ "$status" -ne 0 ]] || ! session_active || [[ -z "$token" ]]; then
        # PENDING_START stays true: should the session still start, or show
        # up just after this read, cleanup stops it (no other session ran
        # before the start, ensure_no_session made sure of that).
        if session_active && [[ -n "$token" ]]; then
            OUR_TOKENS="$OUR_TOKENS $token"
        fi
        die "awake --backend awake $* exited $status, and no session runs as expected (awake --status-json: $STATUS_JSON)"
    fi
    OUR_TOKENS="$OUR_TOKENS $token"
    PENDING_START=false
    json_field session_backend
    backend=$REPLY
    SESSION_TOKEN=$token
    SESSION_START=$(now_s)
    record "session started: token $token, backend $backend, at $SESSION_START"
    # awake's own start messages went to the terminal only; its status
    # goes to the results file.
    record "awake --status: $("$AWAKE" --status 2>&1 | tr '\n' ' ')"
    if [[ "$backend" != awake ]]; then
        die "the session runs with the backend '$backend', not 'awake' (lid closed), which 10.6 needs."
    fi
}

# 10.6's renewal loop, with each renewal's exit status and time added.
start_renewer() {
    (
        while sleep "$RENEW"; do
            s=0
            "$TIME_BIN" -p sudo -n "$HELPER" extend "$(id -u)" "@$(($(date +%s) + LEASE))" || s=$?
            printf 'renewal exit=%s at=%s\n' "$s" "$(date +%s)"
        done
    ) </dev/null >>"$RENEW_LOG" 2>&1 &
    RENEWER=$!
    if [[ -z "$T_RENEW_START" ]]; then
        T_RENEW_START=$(now_s)
    fi
    record "renewer: PID $RENEWER, every $RENEW s, log $RENEW_LOG"
}

# Waits until the session with token $1 is no longer running, at most $2
# seconds, looking every $3 seconds; sets WAITED_MS.
wait_end() {
    local token=$1 limit=$2 every=$3 t0 now
    t0=$(now_ms)
    while :; do
        read_status
        json_field session_token
        if ! session_active || [[ "$REPLY" != "$token" ]]; then
            now=$(now_ms)
            WAITED_MS=$((now - t0))
            return 0
        fi
        now=$(now_ms)
        if (((now - t0) / 1000 >= limit)); then
            WAITED_MS=$((now - t0))
            return 1
        fi
        nap "$every"
    done
}

last_reason() {
    read_status
    json_field last_completion_reason
    printf '%s' "$REPLY"
}

kit_py() {
    "$PY" -I "$KIT_SRC/kit.py" --dir "$PREFLIGHT_DIR" --kit-src "$KIT_SRC" --python "$PY" "$@"
}

pmset_events_since() {
    pmset -g log 2>/dev/null | kit_py pmset-events "$1" || true
}

# ------------------------------------------------------------------ steps

step_f() {
    local f out inode_note=""
    say ""
    # shellcheck disable=SC2016 # expanded by $F_BASH, not here
    say "(f) The log gate's test under $F_BASH ($("$F_BASH" -c 'echo "$BASH_VERSION"'))"
    f=$(mktemp "${TMPDIR:-/tmp}/awake-lease-f.XXXXXX")
    # 10.6's commands, on a private file instead of /tmp/f.
    # shellcheck disable=SC2016 # expanded by $F_BASH, not here
    out=$("$F_BASH" -c 'f=$1; echo x > "$f"; exec 4<"$f"; [[ "$f" -ef /dev/fd/4 ]] && echo same; rm "$f"; echo y > "$f"; [[ "$f" -ef /dev/fd/4 ]] || echo replaced; exec 4<&-' _ "$f" 2>&1) || true
    record "output: $(printf '%s' "$out" | tr '\n' ' ')"
    # shellcheck disable=SC2016 # expanded by $F_BASH, not here
    if stat -f %i "$f" >/dev/null 2>&1; then
        inode_note=$("$F_BASH" -c 'f=$1; exec 4<"$f"; a=$(stat -f %i "$f"); b=$(stat -L -f %i /dev/fd/4); echo "stat inode of the file $a, of /dev/fd/4 $b"' _ "$f" 2>&1) || true
    else
        inode_note=$("$F_BASH" -c 'f=$1; exec 4<"$f"; a=$(stat -c %i "$f"); b=$(stat -L -c %i /dev/fd/4); echo "stat inode of the file $a, of /dev/fd/4 $b"' _ "$f" 2>&1) || true
    fi
    record "$inode_note"
    rm -f "$f"
    if [[ "$out" == "same"$'\n'"replaced" ]]; then
        verdict f PASS "-ef sees through /dev/fd/4: 'same', then 'replaced'"
    else
        verdict f FAIL "expected 'same' then 'replaced', got: $(printf '%s' "$out" | tr '\n' ' ') (W29's log gate then compares inodes from stat)"
    fi
}

step_a() {
    local i target now token end_mode deadline ahead ok=true first=""
    say ""
    say "(a) A lid-closed session tied to a stand-in process, renewed every $RENEW s; awake --status-json every $SAMPLE s, $SAMPLES times ($((SAMPLE * SAMPLES / 60)) min)"
    new_holder
    start_session -w "$HOLDER" --duration-seconds "$LEASE"
    first=$SESSION_TOKEN
    start_renewer
    for ((i = 1; i <= SAMPLES; i++)); do
        target=$((SESSION_START + SAMPLE * i))
        now=$(now_s)
        if ((target > now)); then
            nap $((target - now))
        fi
        read_status
        now=$(now_s)
        record "status at +$((now - SESSION_START)) s: $STATUS_JSON"
        if ! session_active; then
            verdict a FAIL "at +$((now - SESSION_START)) s the session was no longer running (reason $(last_reason)); see the renewals in $RENEW_LOG"
            return 1
        fi
        json_field session_token
        token=$REPLY
        json_field end_mode
        end_mode=$REPLY
        json_field deadline_at
        deadline=$REPLY
        if [[ ! "$deadline" =~ ^[0-9]+$ ]]; then
            deadline=0
        fi
        ahead=$((deadline - now))
        say "  +$((now - SESSION_START)) s: token $token, end_mode $end_mode, deadline_at $deadline ($ahead s ahead)"
        if [[ "$token" != "$first" || "$end_mode" != until ]] || ((ahead > LEASE + 1 || ahead <= 0)); then
            ok=false
        fi
    done
    if [[ "$ok" == true ]]; then
        verdict a PASS "the same session_token throughout, end_mode until, deadline_at never more than $LEASE s ahead"
    else
        verdict a FAIL "see the samples above (expected the same token, until, and at most $LEASE s ahead)"
    fi
}

step_b() {
    local reason
    say ""
    say "(b) Renewals stopped (kill -STOP): the session should end within $LEASE s, as timeout"
    if ! session_active; then
        verdict b FAIL "no session was running after (a)"
        return 1
    fi
    kill -STOP "$RENEWER"
    record "renewer stopped at $(now_s)"
    if wait_end "$SESSION_TOKEN" $((LEASE + 60)) 2; then
        reason=$(last_reason)
        record "awake --status: $("$AWAKE" --status 2>&1 | tr '\n' ' ')"
        if ((WAITED_MS <= (LEASE + 5) * 1000)) && [[ "$reason" == timeout ]]; then
            verdict b PASS "ended $((WAITED_MS / 1000)) s after the renewals stopped, reason $reason"
        else
            verdict b FAIL "ended $((WAITED_MS / 1000)) s after the renewals stopped, reason ${reason:-unknown} (expected at most $LEASE s, timeout)"
        fi
    else
        verdict b FAIL "still running $((WAITED_MS / 1000)) s after the renewals stopped"
    fi
    stop_loop "$RENEWER"
    RENEWER=""
}

step_d() {
    local reason
    say ""
    say "(d) The stand-in process killed: the session should end within about 3 s, as process_exited"
    new_holder
    start_session -w "$HOLDER" --duration-seconds "$LEASE"
    start_renewer
    nap 5
    kill "$HOLDER" 2>/dev/null || true
    wait "$HOLDER" 2>/dev/null || true
    HOLDER=""
    if wait_end "$SESSION_TOKEN" 30 0.2; then
        reason=$(last_reason)
        if ((WAITED_MS <= 5000)) && [[ "$reason" == process_exited ]]; then
            verdict d PASS "ended $WAITED_MS ms after the kill, reason $reason"
        else
            verdict d FAIL "ended $WAITED_MS ms after the kill, reason ${reason:-unknown} (expected about 3 s, process_exited)"
        fi
    else
        verdict d FAIL "still running $((WAITED_MS / 1000)) s after the kill"
    fi
    stop_loop "$RENEWER"
    RENEWER=""
}

step_e() {
    local times count stats renewals failed minutes logged now
    say ""
    say "(e) The cost of a renewal, and whether sudo logs each one"
    times=$(sed -n 's/^real[[:space:]]*\([0-9][0-9]*[.,][0-9]*\).*/\1/p' "$RENEW_LOG" 2>/dev/null | tr ',' '.')
    count=$(printf '%s\n' "$times" | grep -c '[0-9]' || true)
    renewals=$(grep -c '^renewal exit=' "$RENEW_LOG" 2>/dev/null || true)
    failed=$(grep '^renewal exit=' "$RENEW_LOG" 2>/dev/null | grep -vc '^renewal exit=0 ' || true)
    record "real times (s): $(printf '%s' "$times" | tr '\n' ' ')"
    if ((count > 0)); then
        stats=$(printf '%s\n' "$times" | grep '[0-9]' | sort -n | awk '
            { v[NR] = $1 * 1000 }
            END { printf "min %d ms, median %d ms, max %d ms", v[1], v[int((NR + 1) / 2)], v[NR] }')
        say "  $count renewals timed: $stats (the plan's estimate: 75 to 155 ms each)"
    else
        say "  no renewal times found in $RENEW_LOG"
    fi
    if ((renewals > 0 && failed == 0)); then
        verdict e PASS "all $renewals renewals exited 0"
    else
        verdict e FAIL "$failed of $renewals renewals exited non-zero (see $RENEW_LOG)"
    fi
    now=$(now_s)
    minutes=$(((now - ${T_RENEW_START:-$now}) / 60 + 2))
    logged=$(run_limited 180 log show --last "${minutes}m" --predicate 'process == "sudo"' 2>/dev/null | grep -c extend || true)
    logged=${logged:-0}
    say "  sudo log lines naming extend in the last $minutes min: $logged, for $renewals renewals (only the count is kept)"
    if ((renewals > 0 && logged >= renewals)); then
        verdict e NOTE "sudo logs each renewal"
    else
        verdict e NOTE "sudo logged fewer lines than renewals (or hides them as <private>)"
    fi
}

lid_preflight() {
    ensure_no_session
    say "  The Mac must be plugged in, with no external display connected (with one, closing"
    say "  the lid does not sleep the Mac), and the lid open until the script says to close it."
}

step_c() {
    local t_stop events sleep_at delta reason
    say ""
    say "(c) The same as (b) with the lid closed: the Mac should sleep about 2.5 min after the renewals stop"
    if ! confirm "Run (c) now? It needs the lid closed for at least 4 minutes." lid; then
        say "  (c) skipped."
        return 0
    fi
    lid_preflight
    new_holder
    start_session -w "$HOLDER" --duration-seconds "$LEASE"
    start_renewer
    STOP_FILE=$(mktemp "${TMPDIR:-/tmp}/awake-lease-stop.XXXXXX")
    (
        sleep "$RENEW"
        kill -STOP "$RENEWER"
        date +%s >"$STOP_FILE"
    ) </dev/null >/dev/null 2>&1 &
    STOPPER=$!
    say ""
    say "  >>> Close the lid NOW. Keep it closed for at least 4 minutes."
    say "      (The renewals stop in $RENEW s; the Mac should sleep within about 2.5 minutes after that.)"
    say "      Then open the lid, log in if asked, and press Enter here."
    wait_enter "  Press Enter after you have opened the lid again:"
    wait "$STOPPER" 2>/dev/null || true
    STOPPER=""
    t_stop=$(cat "$STOP_FILE" 2>/dev/null || true)
    events=$(pmset_events_since "$SESSION_START")
    record "pmset -g log since the start:"
    record "$events"
    reason=$(last_reason)
    if [[ -z "$t_stop" ]]; then
        verdict c FAIL "the renewals were never stopped (was Enter pressed too early?)"
    else
        sleep_at=$(printf '%s\n' "$events" | awk -v t="$t_stop" '$2 == "Sleep" && $1 >= t { print $1; exit }')
        if [[ -z "$sleep_at" ]]; then
            verdict c FAIL "no Sleep in pmset -g log after the renewals stopped (lid closed long enough?); reason ${reason:-unknown}"
        else
            delta=$((sleep_at - t_stop))
            if ((delta <= LEASE + 40)); then
                verdict c PASS "slept $delta s after the renewals stopped (about 2.5 min expected); reason ${reason:-unknown}"
            else
                verdict c FAIL "slept $delta s after the renewals stopped (expected about 2.5 min); reason ${reason:-unknown}"
            fi
        fi
    fi
    stop_loop "$RENEWER"
    RENEWER=""
    rm -f "$STOP_FILE"
    STOP_FILE=""
}

step_g() {
    local events sleep_at last t0 reason
    say ""
    say "(g) The floor by hand: a $LEASE s session of your own, renewed from $FLOOR_START s for $FLOOR_SPAN s; the Mac should stay awake past $LEASE s and sleep about $LEASE s after the last renewal"
    if ! confirm "Run (g) now? It needs the lid closed for at least 8 minutes." lid; then
        say "  (g) skipped."
        return 0
    fi
    lid_preflight
    start_session --duration-seconds "$LEASE"
    t0=$SESSION_START
    : >"$FLOOR_LOG"
    (
        sleep "$FLOOR_START"
        end=$((SECONDS + FLOOR_SPAN))
        while ((SECONDS < end)); do
            s=0
            sudo -n "$HELPER" extend "$(id -u)" "@$(($(date +%s) + LEASE))" || s=$?
            printf 'floor renewal exit=%s at=%s\n' "$s" "$(date +%s)"
            sleep "$RENEW"
        done
    ) </dev/null >>"$FLOOR_LOG" 2>&1 &
    FLOOR=$!
    say ""
    say "  >>> Close the lid NOW. Keep it closed for at least 8 minutes."
    say "      (The Mac should stay awake past $LEASE s and sleep about $(((FLOOR_START + FLOOR_SPAN + LEASE) / 60)) minutes after the start.)"
    say "      Then open the lid, log in if asked, and press Enter here."
    wait_enter "  Press Enter after you have opened the lid again:"
    record "floor renewals:"
    record "$(cat "$FLOOR_LOG" 2>/dev/null)"
    last=$(sed -n 's/^floor renewal exit=0 at=\([0-9]*\)$/\1/p' "$FLOOR_LOG" | tail -n 1)
    events=$(pmset_events_since "$t0")
    record "pmset -g log since the start:"
    record "$events"
    reason=$(last_reason)
    sleep_at=$(printf '%s\n' "$events" | awk '$2 == "Sleep" { print $1; exit }')
    if [[ -z "$last" ]]; then
        verdict g FAIL "no floor renewal succeeded (see $FLOOR_LOG)"
    elif [[ -z "$sleep_at" ]]; then
        verdict g FAIL "no Sleep in pmset -g log after the start (lid closed long enough?); reason ${reason:-unknown}"
    elif ((sleep_at - t0 > LEASE + 10)) && ((sleep_at - last <= LEASE + 40)); then
        verdict g PASS "slept $((sleep_at - t0)) s after the start and $((sleep_at - last)) s after the last renewal; reason ${reason:-unknown}"
    else
        verdict g FAIL "slept $((sleep_at - t0)) s after the start and $((sleep_at - last)) s after the last renewal (expected past $LEASE s, and about $LEASE s after the last); reason ${reason:-unknown}"
    fi
    stop_loop "$FLOOR"
    FLOOR=""
}

# ------------------------------------------------------------------- main

# Succeeds when folder $1 or one above it holds .git.
dir_in_work_tree() {
    local d=$1
    while [[ -n "$d" && "$d" != / ]]; do
        if [[ -e "$d/.git" ]]; then
            return 0
        fi
        d=${d%/*}
    done
    return 1
}

# Succeeds when the file $1, or the file a symlink $1 points to, is inside
# a git work tree (a repository checkout rather than the installed copy).
in_work_tree() {
    local d target
    d=$(cd -P -- "$(dirname -- "$1")" 2>/dev/null && pwd -P) || return 1
    if dir_in_work_tree "$d"; then
        return 0
    fi
    target=$(readlink "$1" 2>/dev/null || true)
    if [[ -n "$target" ]]; then
        case "$target" in
            /*) ;;
            *) target="$d/$target" ;;
        esac
        d=$(cd -P -- "$(dirname -- "$target")" 2>/dev/null && pwd -P) || return 1
        dir_in_work_tree "$d" && return 0
    fi
    return 1
}

# 10.6 tests today's installed Awake: the copy the installer keeps in
# ~/Library/Application Support/Awake/bin, which the awake command on the
# PATH runs (scripts/install-awake.sh). Another awake on the PATH is used
# only when that copy is missing, and one from a repository checkout only
# after a question.
MANAGED_AWAKE="$HOME/Library/Application Support/Awake/bin/awake"
find_awake() {
    if [[ -n "${AWAKE_BIN:-}" ]]; then
        AWAKE=$AWAKE_BIN
        return 0
    fi
    if [[ -x "$MANAGED_AWAKE" ]]; then
        AWAKE=$MANAGED_AWAKE
        return 0
    fi
    if ! command -v awake >/dev/null 2>&1; then
        die "awake was not found in ~/Library/Application Support/Awake/bin or on the PATH."
    fi
    AWAKE=$(command -v awake)
    say "Note: the installed copy $MANAGED_AWAKE is missing; using $AWAKE from the PATH."
    if in_work_tree "$AWAKE"; then
        say "Warning: $AWAKE is in a repository checkout, not the installed Awake that 10.6 tests."
        confirm "Use it anyway?" ask || exit 1
    fi
}

main() {
    local batt=""
    if [[ "$TEST_MODE" != 1 && "$(uname -s)" != Darwin ]]; then
        printf 'lease-check.sh: this runs on the Mac (10.6).\n' >&2
        exit 1
    fi
    umask 077
    mkdir -p "$PREFLIGHT_DIR/lease"
    RESULTS="$PREFLIGHT_DIR/lease/lease-$(date +%Y%m%d-%H%M%S).txt"
    RENEW_LOG="${RESULTS%.txt}-renewals.log"
    FLOOR_LOG="${RESULTS%.txt}-floor.log"
    : >"$RESULTS"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    trap 'exit 129' HUP

    say "Awake preflight 10.6, the lease: $(date '+%Y-%m-%d %H:%M:%S %z'), steps: $MODE"
    say "bash $BASH_VERSION ($BASH)"
    if [[ "$BASH" != /bin/bash ]]; then
        say "Note: 10.6 asks for /bin/bash; this runs under $BASH. Run it as /bin/bash $0."
    fi
    if [[ -x /usr/bin/sw_vers ]]; then
        say "macOS $(/usr/bin/sw_vers -productVersion) ($(/usr/bin/sw_vers -buildVersion)), $(uname -m)"
    fi
    find_awake
    say "awake: $AWAKE ($("$AWAKE" --version 2>&1 | head -n 1))"
    if [[ "$MODE" == f ]]; then
        step_f
        return 0
    fi
    [[ -x "$HELPER" ]] || die "the helper $HELPER is not installed."
    read_status
    [[ -n "$STATUS_JSON" ]] || die "awake --status-json gave no answer."
    record "status before: $STATUS_JSON"
    if session_active; then
        die "an Awake session is already running. Stop it first (awake --stop), then run this again."
    fi
    json_field other_user_session
    if [[ "$REPLY" == true ]]; then
        die "another account's lid-closed session is running."
    fi
    json_field passwordless
    if [[ "$REPLY" != true ]]; then
        die "password-free mode is off; 10.6 needs it (awake --passwordless on)."
    fi
    batt=$(pmset -g batt 2>/dev/null | head -n 1 || true)
    record "power: $batt"
    if [[ "$batt" != *"AC Power"* ]]; then
        say "The Mac does not seem to be plugged in ($batt); 10.6 asks for it."
        confirm "Go on anyway?" || exit 1
    fi

    case "$MODE" in
        all | auto)
            step_f
            say ""
            say "Steps (a), (b) and (d) start lid-closed Awake sessions of $LEASE s tied to a stand-in process"
            say "and renew them every $RENEW s with sudo -n and the installed helper, about $(((SAMPLE * SAMPLES + LEASE + 60) / 60 + 1)) minutes in all."
            say "Keep the lid open and the Mac plugged in meanwhile."
            if ! confirm "Start?"; then
                say "Not started."
                return 0
            fi
            step_a || true
            step_b || true
            step_d || true
            step_e || true
            if [[ "$MODE" == all ]]; then
                step_c || true
                step_g || true
            fi
            ;;
        c)
            step_c
            ;;
        g)
            step_g
            ;;
    esac
}

SESSION_TOKEN=""
SESSION_START=""
WAITED_MS=0
main
