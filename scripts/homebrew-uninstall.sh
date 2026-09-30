#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

# The uninstall step of the Homebrew cask (tools/homebrew/awake.rb).
# Homebrew runs a cask's uninstall step also before an upgrade or a
# reinstall, which must keep Awake and its settings: the new version's
# installer then updates it in place. So this runs the uninstaller only when
# the brew command that runs it is an uninstall. For any other command, or
# when the command cannot be told, Awake stays installed, and
# uninstall-awake.sh in this folder removes it.

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

# The brew command, such as uninstall or upgrade, from the command line of
# the brew process that runs this script: the first word after brew.rb that
# is not an option. Fails when no ancestor within a few levels is brew.
brew_command() {
    local pid=$PPID
    local depth=0
    local command_line=""
    local words=()
    local word=""

    while (( depth < 8 )) && [[ "${pid}" =~ ^[0-9]+$ ]] && (( pid > 1 )); do
        command_line=$(/bin/ps -ww -o args= -p "${pid}" 2>/dev/null || true)
        if [[ "${command_line}" == *"/brew.rb "* ]]; then
            read -r -a words <<< "${command_line#*/brew.rb }"
            for word in "${words[@]}"; do
                if [[ "${word}" != -* ]]; then
                    printf '%s' "${word}"
                    return 0
                fi
            done
            return 1
        fi
        pid=$(/bin/ps -o ppid= -p "${pid}" 2>/dev/null | tr -d '[:space:]' || true)
        depth=$((depth + 1))
    done
    return 1
}

command=$(brew_command || true)
case "${command}" in
    uninstall | remove | rm)
        exec /bin/bash "${SCRIPT_DIR}/uninstall-awake.sh"
        ;;
    upgrade | reinstall)
        printf '%s\n' "Keeping Awake installed for brew ${command}: the new version's installer updates it in place, with its settings."
        ;;
    *)
        printf '%s\n' "Awake stays installed, as this was not run by brew uninstall. To remove it, run brew uninstall awake, or uninstall-awake.sh from a copy of Awake."
        ;;
esac
