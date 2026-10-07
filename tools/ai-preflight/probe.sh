#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# The Awake preflight kit's main command (docs/plans/agent-keep-awake.md,
# section 10). See tools/ai-preflight/README.md for the steps.
#
#   probe.sh install claude|cursor|codex|gemini|all ... [--extra]
#   probe.sh restore claude|cursor|codex|gemini|all ...
#   probe.sh status [AGENT ...]
#   probe.sh mark TEXT...          note a step in the current run log
#   probe.sh new-run [NAME]        start a new run log
#   probe.sh log | tail            show the current run log's path, or follow it
#   probe.sh print AGENT [--extra] the probe's handlers, to add by hand
#   probe.sh stop-block on|off     10.3 (c): a Claude Code Stop hook that waits 90 s, then exits 2
#   probe.sh codex-touch           10.4: change one Codex handler's path
#   probe.sh gemini-record         10.5: link the Gemini probe by a hand-written record
#   probe.sh gemini-allowlist on|off   10.5: the allowlist check
#   probe.sh last-look [CLAUDE|terminal] [--no-agent-view]
#                                  10.2, 10.3 (f): claude agents --json, as the watcher would
#                                  run it (no CLAUDE: the panel's bundled claude)
#   probe.sh last-look-hook on [CLAUDE|terminal] | off   10.2: the same from inside a Stop hook
#   probe.sh idle-watch [SECONDS] [EVERY]       10.2, B-18: log HIDIdleTime
#   probe.sh assertions [LABEL]    10.2: what the agents hold (pmset -g assertions)
#   probe.sh purge                 delete the preflight folder at the very end
#
# Everything lives in ~/awake-preflight (AWAKE_PREFLIGHT_DIR): the probe,
# its copy in "probe with space", the run logs, the backups and the lease
# results. JSON is edited by kit.py under /usr/bin/python3; nothing here
# uses the network or sudo.

set -euo pipefail

KIT_SRC=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
PREFLIGHT_DIR=${AWAKE_PREFLIGHT_DIR:-$HOME/awake-preflight}
PY=${AWAKE_PREFLIGHT_PYTHON:-/usr/bin/python3}

die() {
    printf 'probe.sh: %s\n' "$1" >&2
    exit 1
}

usage() {
    sed -n '4,29p' "$0" | sed 's/^# \{0,1\}//'
}

check_python() {
    if [[ -z "${AWAKE_PREFLIGHT_PYTHON:-}" && "$(uname -s)" == Darwin ]] &&
        ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
        die "the Command Line Tools are not installed, so /usr/bin/python3 cannot run. Install them with xcode-select --install, then try again."
    fi
    if [[ ! -x "$PY" ]]; then
        die "python3 was not found at $PY. On a Mac, install the Command Line Tools (xcode-select --install)."
    fi
    if ! "$PY" -I -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' \
        </dev/null >/dev/null 2>&1; then
        die "$PY did not run, or is older than Python 3.8."
    fi
}

kit() {
    "$PY" -I "$KIT_SRC/kit.py" --dir "$PREFLIGHT_DIR" --kit-src "$KIT_SRC" --python "$PY" "$@"
}

current_log() {
    printf '%s' "$PREFLIGHT_DIR/logs/current.log"
}

cmd_mark() {
    local log text
    log=$(current_log)
    if [[ ! -e "$log" ]]; then
        die "no run log yet; run probe.sh install first."
    fi
    text="$*"
    text=${text//$'\n'/ }
    printf '##### %s mark: %s\n' "$(date '+%H:%M:%S')" "$text" >>"$log"
    printf 'Marked in %s: %s\n' "$log" "$text"
}

cmd_purge() {
    local answer=""
    if [[ ! -d "$PREFLIGHT_DIR" ]]; then
        printf 'Nothing to delete: %s does not exist.\n' "$PREFLIGHT_DIR"
        return 0
    fi
    if [[ ! -f "$PREFLIGHT_DIR/.awake-preflight" ]]; then
        die "$PREFLIGHT_DIR has no .awake-preflight marker; not deleting it."
    fi
    local f
    for f in "$PREFLIGHT_DIR"/state/*.json; do
        [[ -e "$f" ]] || continue
        case "$f" in
            *.restored-*) ;;
            *) die "some agents still have the probe installed (see probe.sh status). Run probe.sh restore all first." ;;
        esac
    done
    printf 'This deletes %s: the probe, the run logs, the backups and the results.\n' "$PREFLIGHT_DIR"
    printf 'Send the collected results first. Type yes to delete: '
    read -r answer || answer=""
    if [[ "$answer" != yes ]]; then
        printf 'Not deleted.\n'
        return 1
    fi
    rm -rf -- "$PREFLIGHT_DIR"
    rm -f -- "/tmp/awake-preflight-${UID}.tmpw" "/tmp/awake-hook-probe-fallback-${UID}.log"
    if [[ -n "${TMPDIR:-}" ]]; then
        rm -f -- "${TMPDIR%/}/awake-hook-probe-fallback.log"
    fi
    printf 'Deleted %s.\n' "$PREFLIGHT_DIR"
}

main() {
    local cmd=${1:-help}
    if [[ $# -gt 0 ]]; then
        shift
    fi
    case "$cmd" in
        install | restore | status | print | new-run | codex-touch | stop-block | gemini-record | \
            gemini-allowlist | last-look | last-look-hook | idle-watch | assertions)
            check_python
            kit "$cmd" "$@"
            ;;
        mark)
            [[ $# -gt 0 ]] || die "say what to mark, for example: probe.sh mark 10.2 a"
            cmd_mark "$@"
            ;;
        log)
            printf '%s\n' "$(current_log)"
            ;;
        tail)
            [[ -e "$(current_log)" ]] || die "no run log yet; run probe.sh install first."
            tail -n 40 -F "$(current_log)"
            ;;
        purge)
            cmd_purge
            ;;
        help | -h | --help)
            usage
            ;;
        *)
            usage >&2
            exit 2
            ;;
    esac
}

main "$@"
