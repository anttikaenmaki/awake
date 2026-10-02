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
readonly APP_BUNDLE_ID="net.kaenmaki.awake.statusbar"

CLI_WRAPPER_PATH=""
MANAGED_AWAKE_PATH="${DEFAULT_MANAGED_AWAKE}"
APP_PATH="${DEFAULT_APP_PATH}"
PATH_CONFIG_FILE=""
PATH_LINE='export PATH="$HOME/.local/bin:$PATH"'
PATH_LINE_ADDED="false"
PATH_CONFIG_CREATED="false"
INSTALL_INFO_READ=false
WRAPPER_FOUND_WITHOUT_RECORD=false

# Reads the paths that the installer recorded. The record is read in a
# separate shell, so a damaged one cannot stop the uninstall; values it lacks
# keep their defaults.
read_install_info() {
    local fields=()
    local value=""

    while IFS= read -r -d '' value; do
        fields+=("${value}")
    done < <(/bin/bash -c 'source "$1" >/dev/null 2>&1 </dev/null; printf "%s\0" "${cli_wrapper_path-}" "${managed_awake_path-}" "${app_path-}" "${path_config_file-}" "${path_line-}" "${path_line_added-}" "${path_config_created-}"' _ "${INSTALL_INFO}" 2>/dev/null)
    if (( ${#fields[@]} != 7 )); then
        return 1
    fi
    CLI_WRAPPER_PATH=${fields[0]}
    MANAGED_AWAKE_PATH=${fields[1]:-$DEFAULT_MANAGED_AWAKE}
    APP_PATH=${fields[2]:-$DEFAULT_APP_PATH}
    PATH_CONFIG_FILE=${fields[3]}
    PATH_LINE=${fields[4]:-$PATH_LINE}
    PATH_LINE_ADDED=${fields[5]:-false}
    PATH_CONFIG_CREATED=${fields[6]:-false}
}

if [[ -f "${INSTALL_INFO}" ]]; then
    if read_install_info; then
        INSTALL_INFO_READ=true
    else
        printf 'Could not read %s, so Awake is removed from its default places.\n' "${INSTALL_INFO}" >&2
    fi
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
    # The installed version may be older than 2.4.0, which posts
    # notifications unless told not to.
    if ! AWAKE_NO_NOTIFICATIONS=true /bin/bash "${stop_command}" "${stop_args[@]}"; then
        printf '%s\n' "Failed to stop the current Awake session. Aborting uninstall." >&2
        return 1
    fi
}

# Succeeds when $1 is the wrapper that the installer writes: it runs the
# managed awake and does nothing else.
is_awake_wrapper() {
    local expected=""

    expected=$(printf '#!/bin/bash\nexec "%s" "$@"' "${MANAGED_AWAKE_PATH}")
    [[ -f "$1" && "$(cat -- "$1" 2>/dev/null)" == "${expected}" ]]
}

remove_wrapper() {
    local path=$1

    if [[ -z "$path" || ( ! -e "$path" && ! -L "$path" ) ]]; then
        return 0
    fi
    if ! is_awake_wrapper "$path"; then
        printf 'Not removing %s: it is not the awake command that the installer added.\n' "$path" >&2
        return 0
    fi
    # Removing a file needs write access to its folder, not to the file.
    if ! rm -f -- "$path" 2>/dev/null || [[ -e "$path" ]]; then
        printf 'Could not remove %s; remove it yourself.\n' "$path" >&2
    fi
}

# Without a record, the wrapper is looked for where the installer puts it.
remove_wrappers_from_default_places() {
    local path=""

    for path in "${HOME}/bin/awake" "${HOME}/.local/bin/awake"; do
        if is_awake_wrapper "$path"; then
            WRAPPER_FOUND_WITHOUT_RECORD=true
            remove_wrapper "$path"
        fi
    done
}

# Removes the PATH line that the installer added, with the blank line that
# the installer wrote before it, and the whole file when the installer
# created it and nothing else is left in it.
remove_path_line_if_needed() {
    local config_file=$1
    local export_line=$PATH_LINE
    local line=""
    local kept=()
    local found=false
    local only_blank=true

    if [[ "$PATH_LINE_ADDED" != "true" || -z "$config_file" || -z "$export_line" || ! -f "$config_file" ]]; then
        return 0
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == "$export_line" ]]; then
            found=true
            if (( ${#kept[@]} > 0 )) && [[ -z "${kept[${#kept[@]} - 1]}" ]]; then
                unset "kept[${#kept[@]} - 1]"
            fi
            continue
        fi
        kept+=("$line")
    done < "$config_file"
    if [[ "$found" != "true" ]]; then
        return 0
    fi

    for line in ${kept[@]+"${kept[@]}"}; do
        if [[ "$line" == *[![:space:]]* ]]; then
            only_blank=false
            break
        fi
    done
    # Never a symlink: the link is the user's, whatever it points to.
    if [[ "$PATH_CONFIG_CREATED" == "true" && "$only_blank" == "true" && ! -L "$config_file" ]]; then
        rm -f -- "$config_file"
        return
    fi
    # Written in place, so the file keeps its permissions, and a link stays a
    # link.
    if (( ${#kept[@]} > 0 )); then
        printf '%s\n' "${kept[@]}" > "$config_file"
    else
        : > "$config_file"
    fi
}

# Succeeds when $1 is an Awake.app, the only thing the uninstaller deletes at
# the recorded app path.
is_awake_app() {
    [[ -d "$1" ]] || return 1
    grep -Fq -- "<string>${APP_BUNDLE_ID}</string>" "$1/Contents/Info.plist" 2>/dev/null ||
        [[ -f "$1/Contents/MacOS/AwakeStatusBar" ]]
}

printf '%s\n' "Removing Awake launch-at-login configuration ..."
bootout_launch_agent

stop_active_session_if_needed

remove_helper() {
    local command=""
    local ui_option="--gui"

    if ! command=$(stop_command_path); then
        return 0
    fi
    if [[ -t 0 && -t 1 ]]; then
        ui_option="--terminal"
    fi
    printf '%s\n' "Removing the privileged helper and password-free rules ..."
    # The installed version may be older than 2.4.0, which posts
    # notifications unless told not to.
    if ! AWAKE_NO_NOTIFICATIONS=true /bin/bash "${command}" "${ui_option}" --uninstall-helper; then
        printf '%s\n' "The helper was not removed. Remove /Library/PrivilegedHelperTools/net.kaenmaki.awake.helper, /Library/LaunchDaemons/net.kaenmaki.awake.boot-restore.plist, and /private/etc/sudoers.d/awake-* with administrator rights." >&2
    fi
}

remove_helper

# Quits the Awake app of this installation: AwakeStatusBar processes that run
# from APP_PATH get TERM, and KILL if they are still there after 5 seconds.
# Other copies of the app, such as a build run from the repository, are left
# alone.
quit_installed_app() {
    local app_path=${APP_PATH%/}
    local executable="${app_path}/Contents/MacOS/AwakeStatusBar"
    local resolved_executable=""
    local pid=""
    local command_line=""
    local pids=()
    local waited=0
    local alive=false

    if [[ -d "${app_path}" ]]; then
        resolved_executable="$(cd -- "${app_path}" && pwd -P)/Contents/MacOS/AwakeStatusBar"
    fi
    for pid in $(/usr/bin/pgrep -u "$(id -u)" -x AwakeStatusBar || true); do
        # A UTF-8 locale, so that ps prints a path with other than ASCII
        # letters as it is.
        command_line=$(LC_ALL=en_US.UTF-8 /bin/ps -ww -o command= -p "${pid}" 2>/dev/null || true)
        if [[ "${command_line}" == "${executable}" || "${command_line}" == "${executable} "* ]] ||
            [[ -n "${resolved_executable}" && ( "${command_line}" == "${resolved_executable}" || "${command_line}" == "${resolved_executable} "* ) ]]; then
            pids+=("${pid}")
        fi
    done
    if (( ${#pids[@]} == 0 )); then
        return 0
    fi
    /bin/kill -TERM "${pids[@]}" >/dev/null 2>&1 || true
    while (( waited < 50 )); do
        alive=false
        for pid in "${pids[@]}"; do
            if /bin/kill -0 "${pid}" >/dev/null 2>&1; then
                alive=true
            fi
        done
        if [[ "${alive}" != "true" ]]; then
            return 0
        fi
        /bin/sleep 0.1
        ((waited += 1))
    done
    /bin/kill -KILL "${pids[@]}" >/dev/null 2>&1 || true
}

printf '%s\n' "Stopping the running Awake app if needed ..."
quit_installed_app

printf '%s\n' "Removing Awake app preferences ..."
# Address the preferences by path so a test run with a temporary HOME leaves
# the real user's preferences alone.
/usr/bin/defaults delete "${HOME}/Library/Preferences/net.kaenmaki.awake.statusbar" >/dev/null 2>&1 || true

printf '%s\n' "Removing the PATH wrapper ..."
if [[ -n "${CLI_WRAPPER_PATH}" ]]; then
    remove_wrapper "${CLI_WRAPPER_PATH}"
else
    remove_wrappers_from_default_places
fi
if [[ "${WRAPPER_FOUND_WITHOUT_RECORD}" == "true" || ( -f "${INSTALL_INFO}" && "${INSTALL_INFO_READ}" != "true" ) ]]; then
    printf '%s\n' "With no record of the installation, any PATH line that the installer added for awake stays in your shell's startup file (such as ~/.zprofile); remove it yourself."
fi
if ! remove_path_line_if_needed "${PATH_CONFIG_FILE}"; then
    printf 'Could not remove the PATH line from %s; remove it yourself.\n' "${PATH_CONFIG_FILE}" >&2
fi

printf '%s\n' "Removing Awake.app ..."
if is_awake_app "${APP_PATH}"; then
    rm -rf -- "${APP_PATH}"
elif [[ -e "${APP_PATH}" || -L "${APP_PATH}" ]]; then
    printf 'Not removing %s: it is not Awake.app.\n' "${APP_PATH}" >&2
fi

printf '%s\n' "Removing the managed awake command ..."
rm -rf -- "${APP_SUPPORT_DIR}"

printf '\n%s\n' "Awake has been uninstalled."
