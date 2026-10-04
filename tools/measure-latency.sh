#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# Times what Awake.app runs for a start and a stop, step by step, so that one
# version can be compared with the next on the same Mac. Not installed; run
# it from the checkout. Run with --help for details.
set -euo pipefail

readonly HELPER_INSTALL_PATH="/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper"

ROUNDS=5
LID_CLOSED=false
SOUND=false
DRY_RUN=false
CLI="${HOME}/Library/Application Support/Awake/bin/awake"

show_usage() {
    cat <<'EOF'
Usage: tools/measure-latency.sh [--rounds N] [--lid-closed] [--sound]
                                [--cli PATH] [--dry-run]

Times what Awake.app runs for a lid-open start and stop: the status read
before, the start or stop, and the status read after, each run the way the
app runs it. Prints the minimum, median and maximum of each step, then what
the app waits for. Run it before an update and after, with the same options,
and compare the two.

  --rounds N    How many starts and stops to time, 1 to 99 (default 5).
  --lid-closed  Also time a lid-closed start and stop. Only in the dry run,
                or when sudo runs Awake's helper without a password, as a
                password prompt would be timed too.
  --sound       Pass --sound, as the app did with Sound on before 2.4.0;
                since then it plays the sound itself. The dry run plays no
                sound, so there it changes nothing.
  --cli PATH    The awake to time (default: the installed one,
                ~/Library/Application Support/Awake/bin/awake).
  --dry-run     Time awake's dry run, which changes no settings.

Each round pauses 2 to 3 seconds before the stop, by a different fraction
of a second each round: the helper checks for a lid-closed stop only once a
second, so that stop takes anything up to a second longer, and the rounds
together sample all of it. Use 10 rounds or more to compare lid-closed
stops. Runs at different times can differ by a third, so compare versions
in the same sitting, one run straight after the other, with --cli.

It refuses to run while a session is on, checks that each start started and
each stop stopped, and stops a session it started when a step fails or it is
interrupted. The raw times go to ./awake-latency-YYYYMMDD-HHMMSS.tsv.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --rounds|--cli)
            if [[ $# -lt 2 ]]; then
                printf 'Option %s requires a value.\n' "$1" >&2
                exit 1
            fi
            if [[ "$1" == "--rounds" ]]; then
                ROUNDS=$2
            else
                CLI=$2
            fi
            shift 2
            ;;
        --lid-closed)
            LID_CLOSED=true
            shift
            ;;
        --sound)
            SOUND=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n\n' "$1" >&2
            show_usage >&2
            exit 1
            ;;
    esac
done
if [[ ! "$ROUNDS" =~ ^[1-9][0-9]?$ ]]; then
    printf '%s\n' "Option --rounds takes a number from 1 to 99." >&2
    exit 1
fi
if [[ ! -f "$CLI" || ! -x "$CLI" ]]; then
    printf 'No awake to run at %s. Install Awake, or pass --cli PATH.\n' "$CLI" >&2
    exit 1
fi

# The environment of the app's runs (AwakeCLI.swift, environment()): never
# the caller's notification choices, password settings, or app variables.
unset AWAKE_NOTIFICATIONS AWAKE_NO_NOTIFICATIONS AWAKE_APP_CUSTOM_PASSWORD_MODE AWAKE_GUI_CUSTOM_PASSWORD \
    AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY AWAKE_STATUS_JSON_FILE AWAKE_APP_THERMAL_STATE
if [[ "$DRY_RUN" == "true" ]]; then
    export AWAKE_DRY_RUN=true
else
    unset AWAKE_DRY_RUN
fi
# The app passes the thermal state it read from ProcessInfo to each start
# and stop; this reads it once, outside the timing. The dry run passes
# nominal, as no real state matters there. Without a state, none is passed,
# as the app would do.
APP_THERMAL_STATE=0
if [[ "$DRY_RUN" != "true" ]]; then
    APP_THERMAL_STATE=$(/usr/bin/osascript -l JavaScript \
        -e 'ObjC.import("Foundation"); $.NSProcessInfo.processInfo.thermalState' 2>/dev/null) || APP_THERMAL_STATE=""
    case "$APP_THERMAL_STATE" in
        0|1|2|3) ;;
        *) APP_THERMAL_STATE="" ;;
    esac
fi
if [[ "$DRY_RUN" == "true" && "$SOUND" == "true" ]]; then
    printf '%s\n' "The dry run plays no sound, so --sound times nothing here." >&2
fi

WORK=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/awake-latency.XXXXXX")
RESULTS="${WORK}/results.tsv"
REPORT_FILE="${WORK}/status-report"
STARTED_SESSION=false
INTERRUPTED=false
printf 'round\taction\tstep\tseconds\texit_status\n' > "$RESULTS"

# A status read, as the app's fetchStatus runs it.
status_run() {
    "$CLI" --status-json </dev/null
}

# A start or a stop, as the app's runManagedCommand runs it: with the file
# that newer versions write the status they leave into, and the app's
# thermal state. Older versions ignore both, so the same script times them.
action_run() {
    : > "$REPORT_FILE"
    if [[ -n "$APP_THERMAL_STATE" ]]; then
        AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true AWAKE_STATUS_JSON_FILE="$REPORT_FILE" \
            AWAKE_APP_THERMAL_STATE="$APP_THERMAL_STATE" "$CLI" "$@" </dev/null
    else
        AWAKE_SUPPRESS_GUI_NOTIFICATIONS_ONLY=true AWAKE_STATUS_JSON_FILE="$REPORT_FILE" "$CLI" "$@" </dev/null
    fi
}

session_is_active() {
    local output=""

    output=$(status_run 2>/dev/null) || true
    [[ "$output" == *'"active":true'* ]]
}

# Times one step with the shell's own time keyword, which starts no process
# of its own. $1 is the round, $2 the action, $3 the step, the rest the
# command. Output goes to files, never pipes: a start leaves processes
# running that hold its output open, as the app's runs do.
time_step() {
    local round=$1
    local action=$2
    local step=$3
    local seconds=""
    local rc=0
    shift 3

    TIMEFORMAT='%3R'
    { time "$@" >"${WORK}/out" 2>"${WORK}/err"; } 2>"${WORK}/time" || rc=$?
    exit_if_interrupted
    seconds=$(/usr/bin/tail -n 1 "${WORK}/time")
    # A decimal comma, in some languages.
    seconds=${seconds/,/.}
    printf '%s\t%s\t%s\t%s\t%s\n' "$round" "$action" "$step" "$seconds" "$rc" >> "$RESULTS"
    if [[ "$rc" != "0" ]]; then
        printf '%s, %s: exited with status %s.\n' "$action" "$step" "$rc" >&2
        /bin/cat -- "${WORK}/out" "${WORK}/err" >&2
        return 1
    fi
}

# Ctrl-C or TERM only sets a flag, checked after each step and pause: a
# trap that ran during a step would write to that step's files instead.
exit_if_interrupted() {
    if [[ "$INTERRUPTED" == "true" ]]; then
        exit 130
    fi
}

finish() {
    if [[ "$STARTED_SESSION" == "true" ]] && session_is_active; then
        printf '%s\n' "Stopping the session this script started." >&2
        action_run --gui --stop >/dev/null 2>&1 || true
    fi
    rm -rf -- "$WORK"
}
trap finish EXIT
trap 'INTERRUPTED=true' INT TERM

if session_is_active; then
    printf '%s\n' "A session is on. Stop it first, so that this script does not change it." >&2
    exit 1
fi

BACKENDS="caffeinate"
if [[ "$LID_CLOSED" == "true" ]]; then
    if [[ "$DRY_RUN" == "true" ]] || /usr/bin/sudo -n "$HELPER_INSTALL_PATH" check >/dev/null 2>&1; then
        BACKENDS="caffeinate awake"
    else
        printf '%s\n' "Skipping lid-closed: sudo would ask for a password, and the prompt would be timed too." >&2
    fi
fi
SOUND_ARGUMENTS=()
if [[ "$SOUND" == "true" ]]; then
    SOUND_ARGUMENTS=(--sound)
fi

round=1
while (( round <= ROUNDS )); do
    for backend in $BACKENDS; do
        mode="lid-open"
        if [[ "$backend" == "awake" ]]; then
            mode="lid-closed"
        fi
        time_step "$round" "${mode} start" "status before" status_run
        STARTED_SESSION=true
        # The arguments of the keyboard shortcut's start (AwakeCLI.swift,
        # startArguments), with the default settings.
        time_step "$round" "${mode} start" "action" action_run --gui --start --duration-seconds 1200 \
            --backend "$backend" --min-battery 5 --thermal-guard on --unplug-guard off --keep-display on \
            ${SOUND_ARGUMENTS[@]+"${SOUND_ARGUMENTS[@]}"}
        time_step "$round" "${mode} start" "status after" status_run
        if ! /usr/bin/grep -q '"active":true' "${WORK}/out"; then
            printf '%s\n' "The ${mode} start did not start a session." >&2
            exit 1
        fi
        # As a person would: not stopped in the same second. The helper's
        # timer looks for a lid-closed stop's stop-request once a second, so
        # a fixed pause would meet that check at the same point every round
        # and time the same fraction of its second. Round i of N adds
        # (i - 1 + a random fraction) / N of a second, so the rounds spread
        # over the whole second.
        pause_ms=$(( ((round - 1) * 1000 + RANDOM % 1000) / ROUNDS ))
        /bin/sleep "2.$(printf '%03d' "$pause_ms")"
        exit_if_interrupted
        time_step "$round" "${mode} stop" "status before" status_run
        time_step "$round" "${mode} stop" "action" action_run --gui --stop ${SOUND_ARGUMENTS[@]+"${SOUND_ARGUMENTS[@]}"}
        time_step "$round" "${mode} stop" "status after" status_run
        if ! /usr/bin/grep -q '"active":false' "${WORK}/out"; then
            printf '%s\n' "The ${mode} stop did not stop the session." >&2
            exit 1
        fi
        STARTED_SESSION=false
        /bin/sleep 1
        exit_if_interrupted
    done
    round=$((round + 1))
done

version=$("$CLI" --version 2>/dev/null </dev/null) || version="awake, unknown version"
# The path tells builds apart that report the same version, as a dev build
# does until its release.
cli_label=$CLI
if [[ "$CLI" == "$HOME"/* ]]; then
    cli_label="~${CLI#"$HOME"}"
fi
model=$(/usr/sbin/sysctl -n hw.model 2>/dev/null) || model=$(/usr/bin/uname -m 2>/dev/null) || model="unknown Mac"
macos=$(/usr/bin/sw_vers -productVersion 2>/dev/null) || macos="unknown"
options=""
if [[ "$DRY_RUN" == "true" ]]; then
    options="${options}, dry run"
fi
if [[ "$SOUND" == "true" ]]; then
    options="${options}, --sound"
fi
rounds="${ROUNDS} rounds"
if [[ "$ROUNDS" == "1" ]]; then
    rounds="1 round"
fi
printf '%s (%s), %s, macOS %s, %s%s\n\n' "$version" "$cli_label" "$model" "$macos" "$rounds" "$options"
# The minimum, median and maximum of each step in ms, in the order run; then,
# for each action, what the app waits for, as sums of the medians: "today"
# the three runs, "with C" the status before and the action (the action
# writes the status it leaves), "with C and H" the action alone.
LC_ALL=C /usr/bin/awk -F'\t' '
    NR == 1 { next }
    {
        key = $2 ": " $3
        if (!(key in count)) {
            order[++steps] = key
        }
        value[key, ++count[key]] = $4 * 1000
        if (!($2 in seen)) {
            seen[$2] = 1
            actions[++action_count] = $2
        }
        if ($3 == "status before") before[$2] = key
        if ($3 == "action") run[$2] = key
        if ($3 == "status after") after[$2] = key
    }
    function nth(key, i,    sorted, j, k, t, c) {
        c = count[key]
        for (j = 1; j <= c; j++) sorted[j] = value[key, j]
        for (j = 2; j <= c; j++) {
            t = sorted[j]
            for (k = j - 1; k >= 1 && sorted[k] > t; k--) sorted[k + 1] = sorted[k]
            sorted[k + 1] = t
        }
        return sorted[i]
    }
    function median(key,    c) {
        c = count[key]
        if (c % 2) return nth(key, (c + 1) / 2)
        return (nth(key, c / 2) + nth(key, c / 2 + 1)) / 2
    }
    END {
        printf "%-32s %7s %7s %7s\n", "Step (ms)", "min", "median", "max"
        for (s = 1; s <= steps; s++) {
            key = order[s]
            printf "%-32s %7.0f %7.0f %7.0f\n", key, nth(key, 1), median(key), nth(key, count[key])
        }
        printf "\n%-32s %7s %9s %14s\n", "The app waits (ms)", "today", "with C", "with C and H"
        for (a = 1; a <= action_count; a++) {
            name = actions[a]
            printf "%-32s %7.0f %9.0f %14.0f\n", name, \
                median(before[name]) + median(run[name]) + median(after[name]), \
                median(before[name]) + median(run[name]), median(run[name])
        }
    }' "$RESULTS"
tsv="./awake-latency-$(/bin/date +%Y%m%d-%H%M%S).tsv"
if /bin/cp -- "$RESULTS" "$tsv" 2>/dev/null; then
    printf '\nThe raw times are in %s.\n' "$tsv"
else
    printf '\nCould not save the raw times in %s.\n' "$tsv" >&2
fi
