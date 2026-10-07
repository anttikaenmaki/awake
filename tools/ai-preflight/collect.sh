#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# Bundles the Awake preflight results (docs/plans/agent-keep-awake.md,
# section 10) into one text file to read and then send: the versions, the
# hook entries the kit installed (not your other settings), the probe's run
# logs and a summary of them, your notes in ~/awake-preflight/notes.txt, and
# the lease check's results. Your home folder is written as ~. The probe
# logs hold no prompt text, tool input or output, file contents or assistant
# messages.
#
#   collect.sh        writes ~/awake-preflight/results/preflight-<time>.txt
#
# Run it before probe.sh restore, so that the entries are also listed as
# they are now; the entries as each install wrote them are kept in any case
# (Gemini's are restored before the final collect, as 10.5 asks). It uses
# no network and no sudo.

set -euo pipefail

KIT_SRC=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
PREFLIGHT_DIR=${AWAKE_PREFLIGHT_DIR:-$HOME/awake-preflight}
PY=${AWAKE_PREFLIGHT_PYTHON:-/usr/bin/python3}

die() {
    printf 'collect.sh: %s\n' "$1" >&2
    exit 1
}

if [[ -z "${AWAKE_PREFLIGHT_PYTHON:-}" && "$(uname -s)" == Darwin ]] &&
    ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
    die "the Command Line Tools are not installed, so /usr/bin/python3 cannot run (xcode-select --install)."
fi
[[ -x "$PY" ]] || die "python3 was not found at $PY."
[[ -d "$PREFLIGHT_DIR" ]] || die "$PREFLIGHT_DIR does not exist; nothing to collect (run probe.sh install first)."

kit() {
    "$PY" -I "$KIT_SRC/kit.py" --dir "$PREFLIGHT_DIR" --kit-src "$KIT_SRC" --python "$PY" "$@"
}

# Runs a command for at most $1 seconds, with no input (macOS has no
# timeout command); prints its output, or why there is none.
run_limited() {
    local secs=$1 pid w status=0
    shift
    "$@" </dev/null 2>&1 &
    pid=$!
    (sleep "$secs" && kill -TERM "$pid" 2>/dev/null) </dev/null >/dev/null 2>&1 &
    w=$!
    wait "$pid" || status=$?
    pkill -P "$w" 2>/dev/null || true
    kill "$w" 2>/dev/null || true
    wait "$w" 2>/dev/null || true
    return "$status"
}

section() {
    printf '\n======== %s ========\n' "$1"
}

# Prints "LABEL: output" for a command that may be missing or slow.
version_of() {
    local label=$1 out=""
    shift
    if ! command -v "$1" >/dev/null 2>&1 && [[ ! -x "$1" ]]; then
        printf '%s: not found\n' "$label"
        return 0
    fi
    out=$(run_limited 20 "$@" | head -n 5) || true
    printf '%s: %s\n' "$label" "$(printf '%s' "$out" | tr '\n' ' ')"
}

# The installed copy first, as lease-check.sh runs it.
MANAGED_AWAKE="$HOME/Library/Application Support/Awake/bin/awake"
find_awake() {
    if [[ -x "$MANAGED_AWAKE" ]]; then
        printf '%s' "$MANAGED_AWAKE"
    elif command -v awake >/dev/null 2>&1; then
        command -v awake
    fi
}

# The claude a Terminal runs: on the PATH, else the native install, else
# the old local install (which zsh may know only as an alias).
find_claude() {
    local f
    if command -v claude >/dev/null 2>&1; then
        command -v claude
        return 0
    fi
    for f in "$HOME/.local/bin/claude" "$HOME/.claude/local/claude"; do
        if [[ -x "$f" && -f "$f" ]]; then
            printf '%s' "$f"
            return 0
        fi
    done
}

# The logs besides the run logs: hook runs before any run log existed, and
# the probe's fallbacks when it could not write its folder (a sandbox).
tmp_dir=${TMPDIR:-/tmp}
EXTRA_LOGS=("$PREFLIGHT_DIR/logs/no-run.log" "${tmp_dir%/}/awake-hook-probe-fallback.log"
    "/tmp/awake-hook-probe-fallback-${UID}.log")

collect() {
    local awake_bin="" f agent_cli="" gemini_bin="" claude_bin="" path_awake=""
    printf 'Awake preflight results (docs/plans/agent-keep-awake.md, section 10)\n'
    printf 'Collected: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf 'This file has no prompt text, tool input or output, file contents or\n'
    printf 'assistant messages: the probe never logs them. Read it before sending.\n'
    if command -v git >/dev/null 2>&1 &&
        { [[ "$(uname -s)" != Darwin ]] || /usr/bin/xcode-select -p >/dev/null 2>&1; }; then
        printf 'Kit: %s %s\n' "$(git -C "$KIT_SRC" rev-parse --short HEAD 2>/dev/null || echo '?')" \
            "$(git -C "$KIT_SRC" status --porcelain -- . 2>/dev/null | grep -q . && echo '(changed locally)' || true)"
    fi

    section "System"
    if [[ -x /usr/bin/sw_vers ]]; then
        printf 'macOS %s (%s)\n' "$(/usr/bin/sw_vers -productVersion)" "$(/usr/bin/sw_vers -buildVersion)"
    fi
    printf 'uname: %s\n' "$(uname -srm)"
    printf '/bin/bash: %s\n' "$(/bin/bash --version 2>/dev/null | head -n 1)"
    printf 'python: %s\n' "$("$PY" --version 2>&1)"
    printf 'LANG=%s LC_ALL=%s LC_NUMERIC=%s SHELL=%s\n' "${LANG:-}" "${LC_ALL:-}" "${LC_NUMERIC:-}" "${SHELL:-}"

    section "Versions"
    awake_bin=$(find_awake)
    if [[ -n "$awake_bin" ]]; then
        version_of "awake ($awake_bin)" "$awake_bin" --version
    else
        printf 'awake: not found\n'
    fi
    path_awake=$(command -v awake || true)
    if [[ -n "$path_awake" && "$path_awake" != "$awake_bin" ]]; then
        printf 'awake on the PATH: %s\n' "$path_awake"
    fi
    claude_bin=$(find_claude || true)
    if [[ -n "$claude_bin" ]]; then
        version_of "claude ($claude_bin)" "$claude_bin" --version
    else
        printf 'claude: not found (not on the PATH, in ~/.local/bin or in ~/.claude/local)\n'
    fi
    version_of "codex ($(command -v codex || echo 'not on PATH'))" codex --version
    if command -v codex >/dev/null 2>&1; then
        printf 'codex features list, hook lines: %s\n' \
            "$(run_limited 20 codex features list | grep -i hook | tr -s ' ' | tr '\n' ';' || true)"
    fi
    gemini_bin=$(command -v gemini || true)
    for f in /opt/homebrew/bin/gemini /usr/local/bin/gemini; do
        if [[ -z "$gemini_bin" && -x "$f" ]]; then
            gemini_bin=$f
        fi
    done
    if [[ -n "$gemini_bin" ]]; then
        version_of "gemini ($gemini_bin)" "$gemini_bin" --version
        printf 'gemini extensions list, the awake-probe part:\n'
        run_limited 30 "$gemini_bin" extensions list | grep -i -A6 'awake-probe' | sed 's/^/  /' || printf '  (awake-probe not listed)\n'
    else
        printf 'gemini: not found\n'
    fi
    agent_cli=$(command -v cursor-agent || true)
    if [[ -z "$agent_cli" ]] && command -v agent >/dev/null 2>&1; then
        case "$(cd -P -- "$(dirname -- "$(command -v agent)")" 2>/dev/null && pwd -P)/$(readlink "$(command -v agent)" 2>/dev/null || true)" in
            *cursor*) agent_cli=$(command -v agent) ;;
        esac
    fi
    if [[ -n "$agent_cli" ]]; then
        version_of "Cursor's agent CLI ($agent_cli)" "$agent_cli" --version
    else
        printf "Cursor's agent CLI: not found\n"
    fi
    kit editor-info || true

    section "Kit status"
    kit status all || true

    section "The hook entries the kit installed (only the probe's own, now)"
    kit extract || true

    section "The hook entries the kit installed (as installed, also for agents restored since)"
    set -- "$PREFLIGHT_DIR"/state/*-installed.txt
    if [[ -e "$1" ]]; then
        for f in "$@"; do
            cat "$f"
        done
    else
        printf '(none recorded)\n'
    fi

    section "Probe log summary"
    set -- "$PREFLIGHT_DIR"/logs/run-*.log
    if [[ -e "$1" ]]; then
        kit summarize-logs "$@" || true
    else
        printf '(no run logs)\n'
    fi
    for f in "${EXTRA_LOGS[@]}"; do
        if [[ -s "$f" ]]; then
            kit summarize-logs "$f" || true
        fi
    done
    if [[ -e "/tmp/awake-preflight-${UID}.tmpw" ]]; then
        printf '/tmp write test file: present (at least one hook could write to /tmp)\n'
    else
        printf '/tmp write test file: absent\n'
    fi

    section "Probe logs"
    for f in "$PREFLIGHT_DIR"/logs/run-*.log "${EXTRA_LOGS[@]}"; do
        if [[ -s "$f" ]]; then
            printf -- '---- %s (%s bytes)\n' "$f" "$(wc -c <"$f" | tr -d ' ')"
            cat "$f"
        fi
    done

    section "Your notes ($PREFLIGHT_DIR/notes.txt)"
    if [[ -s "$PREFLIGHT_DIR/notes.txt" ]]; then
        cat "$PREFLIGHT_DIR/notes.txt"
    else
        printf '(none; the marks you made with probe.sh mark are in the probe logs)\n'
    fi

    section "Lease check (10.6)"
    set -- "$PREFLIGHT_DIR"/lease/lease-*.txt
    if [[ -e "$1" ]]; then
        for f in "$PREFLIGHT_DIR"/lease/lease-*; do
            printf -- '---- %s\n' "$f"
            cat "$f"
        done
    else
        printf '(lease-check.sh has not run)\n'
    fi
}

main() {
    local out tmp
    umask 077
    mkdir -p "$PREFLIGHT_DIR/results"
    out="$PREFLIGHT_DIR/results/preflight-$(date +%Y%m%d-%H%M%S).txt"
    tmp="$out.part"
    collect >"$tmp" 2>&1
    "$PY" -I -c '
import sys
home, src, dst = sys.argv[1:4]
with open(src, encoding="utf-8", errors="replace") as f:
    text = f.read()
if home and home != "/":
    text = text.replace(home, "~")
with open(dst, "w", encoding="utf-8") as f:
    f.write(text)
' "$HOME" "$tmp" "$out"
    rm -f "$tmp"
    printf 'Wrote %s (%s bytes).\n' "$out" "$(wc -c <"$out" | tr -d ' ')"
    printf 'Read it before sending: it holds versions, the probe entries the kit installed,\n'
    printf 'the probe logs (no prompt text) and the lease results. Your home folder is shown as ~.\n'
}

main
