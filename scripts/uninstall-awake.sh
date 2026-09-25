#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly APP_SUPPORT_DIR="${HOME}/Library/Application Support/Awake"
readonly INSTALL_INFO="${APP_SUPPORT_DIR}/install-info.sh"
readonly DEFAULT_APP_PATH="${HOME}/Applications/Awake.app"
readonly DEFAULT_MANAGED_AWAKE="${APP_SUPPORT_DIR}/bin/awake"
readonly DEFAULT_LAUNCH_AGENT="${HOME}/Library/LaunchAgents/net.kaenmaki.awake.statusbar.plist"

CLI_WRAPPER_PATH=""
MANAGED_AWAKE_PATH="${DEFAULT_MANAGED_AWAKE}"
APP_PATH="${DEFAULT_APP_PATH}"
PATH_CONFIG_FILE=""
PATH_LINE_ADDED="false"

if [[ -f "${INSTALL_INFO}" ]]; then
    # shellcheck source=/dev/null
    source "${INSTALL_INFO}"
    CLI_WRAPPER_PATH=${cli_wrapper_path:-}
    MANAGED_AWAKE_PATH=${managed_awake_path:-$DEFAULT_MANAGED_AWAKE}
    APP_PATH=${app_path:-$DEFAULT_APP_PATH}
    PATH_CONFIG_FILE=${path_config_file:-}
    PATH_LINE_ADDED=${path_line_added:-false}
fi

bootout_launch_agent() {
    if [[ -f "${DEFAULT_LAUNCH_AGENT}" ]]; then
        /bin/launchctl bootout "gui/$(id -u)" "${DEFAULT_LAUNCH_AGENT}" >/dev/null 2>&1 || true
        rm -f -- "${DEFAULT_LAUNCH_AGENT}"
    fi
}

stop_command_path() {
    if [[ -x "${MANAGED_AWAKE_PATH}" ]]; then
        printf '%s' "${MANAGED_AWAKE_PATH}"
        return 0
    fi

    if [[ -x "${REPO_ROOT}/bin/awake" ]]; then
        printf '%s' "${REPO_ROOT}/bin/awake"
        return 0
    fi

    return 1
}

stop_active_session_if_needed() {
    local stop_command=""
    local stop_args=("--stop")

    if ! stop_command=$(stop_command_path); then
        return 0
    fi

    if [[ ! -t 1 ]]; then
        # During uninstall, prefer the managed no-reauth stop path but still
        # allow the normal native GUI prompt if the managed helper is gone.
        stop_args=("--gui" "--stop")
    fi

    printf '%s\n' "Stopping the current Awake session if needed ..."
    if ! AWAKE_NO_NOTIFICATIONS=true /bin/bash "${stop_command}" "${stop_args[@]}"; then
        printf '%s\n' "Failed to stop the current Awake session. Aborting uninstall." >&2
        return 1
    fi
}

remove_wrapper() {
    local path=$1

    if [[ -z "$path" || ! -e "$path" ]]; then
        return 0
    fi

    if [[ -w "$path" ]]; then
        rm -f -- "$path"
    else
        sudo rm -f -- "$path"
    fi
}

remove_path_line_if_needed() {
    local config_file=$1
    local export_line='export PATH="$HOME/.local/bin:$PATH"'

    if [[ "$PATH_LINE_ADDED" != "true" || -z "$config_file" || ! -f "$config_file" ]]; then
        return 0
    fi

    python3 - "$config_file" "$export_line" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
line_to_remove = sys.argv[2]
lines = config_path.read_text().splitlines()
filtered = [line for line in lines if line != line_to_remove]
config_path.write_text("\n".join(filtered) + ("\n" if filtered else ""))
PY
}

printf '%s\n' "Removing Awake launch-at-login configuration ..."
bootout_launch_agent

stop_active_session_if_needed

printf '%s\n' "Stopping the running Awake app if needed ..."
/usr/bin/osascript -e 'tell application id "net.kaenmaki.awake.statusbar" to quit' >/dev/null 2>&1 || true

printf '%s\n' "Removing Awake app preferences ..."
# Address the preferences by path so a test run with a temporary HOME leaves
# the real user's preferences alone.
/usr/bin/defaults delete "${HOME}/Library/Preferences/net.kaenmaki.awake.statusbar" >/dev/null 2>&1 || true

printf '%s\n' "Removing the PATH wrapper ..."
remove_wrapper "${CLI_WRAPPER_PATH}"
remove_path_line_if_needed "${PATH_CONFIG_FILE}"

printf '%s\n' "Removing Awake.app ..."
rm -rf -- "${APP_PATH}"

printf '%s\n' "Removing the managed awake command ..."
rm -rf -- "${APP_SUPPORT_DIR}"

printf '\n%s\n' "Awake has been uninstalled."
