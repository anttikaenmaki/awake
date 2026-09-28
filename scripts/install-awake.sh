#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly SOURCE_AWAKE="${REPO_ROOT}/bin/awake"
readonly SOURCE_HELPER="${REPO_ROOT}/bin/awake-helper"
readonly GUI_PICKER_SOURCE="${REPO_ROOT}/tools/awake-gui-picker.swift"
readonly GUI_PICKER_ICON_SOURCE="${REPO_ROOT}/app/AwakeStatusApp/Assets/awake-off.png"
readonly BUILD_SCRIPT="${REPO_ROOT}/tools/build-awake-app.sh"
readonly APP_SUPPORT_DIR="${HOME}/Library/Application Support/Awake"
readonly MANAGED_BIN_DIR="${APP_SUPPORT_DIR}/bin"
readonly MANAGED_AWAKE="${MANAGED_BIN_DIR}/awake"
readonly MANAGED_HELPER_SOURCE="${MANAGED_BIN_DIR}/awake-helper"
readonly MANAGED_GUI_PICKER="${MANAGED_BIN_DIR}/awake-gui-picker"
readonly MANAGED_GUI_PICKER_ICON="${MANAGED_BIN_DIR}/awake-off.png"
readonly INSTALL_INFO="${APP_SUPPORT_DIR}/install-info.sh"
readonly DEFAULT_USER_BIN="${HOME}/.local/bin"
readonly APP_BUNDLE_ID="net.kaenmaki.awake.statusbar"
readonly APP_EXECUTABLE_NAME="AwakeStatusBar"
readonly INSTALLED_HELPER="/Library/PrivilegedHelperTools/net.kaenmaki.awake.helper"
PASSWORDLESS_RULE="/private/etc/sudoers.d/awake-$(/usr/bin/id -u)"
readonly PASSWORDLESS_RULE

APP_DESTINATION="${HOME}/Applications/Awake.app"
NO_LAUNCH=false
PASSWORDLESS=false
PATH_CONFIG_FILE=""
PATH_LINE=""
PATH_LINE_ADDED=false
PATH_CONFIG_CREATED=false
APP_WAS_RUNNING=false
CLI_WRAPPER_PATH=""
WRAPPER_DIR=""
WRAPPER_NEEDS_PATH_LINE=false
AWAKE_UI_OPTION="--gui"
# The PATH line that an earlier install recorded, from install-info.sh.
PREVIOUS_PATH_CONFIG_FILE=""
PREVIOUS_PATH_LINE=""
PREVIOUS_PATH_LINE_ADDED=false
PREVIOUS_PATH_CONFIG_CREATED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-launch)
            NO_LAUNCH=true
            ;;
        --passwordless)
            PASSWORDLESS=true
            ;;
        --app-destination)
            shift
            if [[ $# -eq 0 ]]; then
                printf '%s\n' "Option --app-destination requires a path." >&2
                exit 1
            fi
            APP_DESTINATION=$1
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

APP_DESTINATION=${APP_DESTINATION%/}
if [[ "${APP_DESTINATION##*/}" != ?*.app ]]; then
    printf '%s\n' "Option --app-destination takes the path of the app, such as ~/Applications/Awake.app." >&2
    exit 1
fi
readonly APP_DESTINATION
readonly APP_PARENT_DIR="$(dirname -- "${APP_DESTINATION}")"
readonly TEMP_BUILD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/awake-install.XXXXXX")"
readonly TEMP_APP="${TEMP_BUILD_DIR}/Awake.app"
readonly TEMP_WRAPPER="${TEMP_BUILD_DIR}/awake-wrapper"
readonly TEMP_GUI_PICKER="${TEMP_BUILD_DIR}/awake-gui-picker"

cleanup() {
    rm -rf -- "${TEMP_BUILD_DIR}"
}
trap cleanup EXIT

login_shell_path() {
    local shell_path=""

    if shell_path=$("${SHELL:-/bin/zsh}" -lc 'printf "%s" "$PATH"' 2>/dev/null); then
        printf '%s' "$shell_path"
    else
        printf '%s' "$PATH"
    fi
}

# Succeeds when $1 is a folder, or can be made one, that the wrapper can be
# installed into.
wrapper_dir_is_usable() {
    local dir=$1

    if [[ -d "$dir" ]]; then
        [[ -w "$dir" ]]
        return
    fi
    [[ ! -e "$dir" && ! -L "$dir" ]] && mkdir -p -- "$dir" 2>/dev/null
}

# Installs the wrapper into WRAPPER_DIR, then adds the PATH line for it when
# one is needed, so that no PATH line is left without a wrapper.
install_wrapper() {
    cat > "${TEMP_WRAPPER}" <<EOF
#!/bin/bash
exec "${MANAGED_AWAKE}" "\$@"
EOF
    chmod 755 "${TEMP_WRAPPER}"
    install -m 755 "${TEMP_WRAPPER}" "${WRAPPER_DIR}/awake"
    CLI_WRAPPER_PATH="${WRAPPER_DIR}/awake"
    if [[ "${WRAPPER_NEEDS_PATH_LINE}" == "true" ]]; then
        append_path_to_shell_config "${WRAPPER_DIR}"
    fi
}

# A Bash login shell reads only the first of these files that exists, so the
# line goes into that one: a new ~/.bash_profile would hide ~/.profile.
path_config_file_for_shell() {
    local shell_name
    local file

    shell_name="$(basename -- "${SHELL:-/bin/zsh}")"
    case "$shell_name" in
        bash)
            for file in "${HOME}/.bash_profile" "${HOME}/.bash_login" "${HOME}/.profile"; do
                if [[ -e "$file" ]]; then
                    printf '%s' "$file"
                    return 0
                fi
            done
            printf '%s' "${HOME}/.bash_profile"
            ;;
        *)
            printf '%s' "${HOME}/.zprofile"
            ;;
    esac
}

# Adds `export PATH="$HOME/<dir>:$PATH"` for a directory under $HOME.
append_path_to_shell_config() {
    local dir=$1
    local config_file
    local export_line

    export_line="export PATH=\"\$HOME/${dir#"${HOME}/"}:\$PATH\""
    config_file="$(path_config_file_for_shell)"
    PATH_CONFIG_FILE="${config_file}"
    PATH_LINE="${export_line}"
    if [[ ! -e "${config_file}" ]]; then
        PATH_CONFIG_CREATED=true
    fi
    touch "${config_file}"
    if ! grep -Fqx -- "${export_line}" "${config_file}"; then
        printf '\n%s\n' "${export_line}" >> "${config_file}"
        PATH_LINE_ADDED=true
    fi
}

path_contains_dir() {
    local path_value=$1
    local dir=$2

    # Compare whole entries so that, for example, ~/bin2 does not count as ~/bin.
    [[ ":${path_value}:" == *":${dir}:"* || ":${path_value}:" == *":${dir}/:"* ]]
}

# Sets WRAPPER_DIR, and WRAPPER_NEEDS_PATH_LINE when the folder is not on the
# login-shell PATH yet. Folders the user cannot write to are skipped. It runs
# before anything is changed, and in the installer's own shell, so that the
# values stay set.
choose_wrapper_dir() {
    local path_value
    local dir

    path_value="$(login_shell_path)"
    for dir in "${HOME}/bin" "${DEFAULT_USER_BIN}"; do
        if path_contains_dir "${path_value}" "${dir}" && wrapper_dir_is_usable "${dir}"; then
            WRAPPER_DIR=${dir}
            return 0
        fi
    done

    WRAPPER_NEEDS_PATH_LINE=true
    if [[ -d "${HOME}/bin" && -w "${HOME}/bin" ]]; then
        WRAPPER_DIR="${HOME}/bin"
        return 0
    fi
    if wrapper_dir_is_usable "${DEFAULT_USER_BIN}"; then
        WRAPPER_DIR=${DEFAULT_USER_BIN}
        return 0
    fi
    printf '%s\n' "Could not install the awake command: neither ~/bin nor ~/.local/bin can be written to." >&2
    exit 1
}

# Reads the PATH line that an earlier install recorded. The record is read in
# a separate shell, so a damaged one cannot stop the install.
read_previous_install_info() {
    local fields=()
    local value=""

    if [[ ! -f "${INSTALL_INFO}" ]]; then
        return 0
    fi
    while IFS= read -r -d '' value; do
        fields+=("${value}")
    done < <(/bin/bash -c 'source "$1" >/dev/null 2>&1 </dev/null; printf "%s\0" "${path_config_file-}" "${path_line-}" "${path_line_added-}" "${path_config_created-}"' _ "${INSTALL_INFO}" 2>/dev/null)
    if (( ${#fields[@]} == 4 )); then
        PREVIOUS_PATH_CONFIG_FILE=${fields[0]}
        PREVIOUS_PATH_LINE=${fields[1]}
        PREVIOUS_PATH_LINE_ADDED=${fields[2]}
        PREVIOUS_PATH_CONFIG_CREATED=${fields[3]}
    fi
}

# A reinstall finds the wrapper folder on PATH through the line that the first
# install added, and so adds none. The record of that line is kept while the
# line is there, so that the uninstaller still removes it.
keep_previous_path_line_record() {
    if [[ "${PATH_LINE_ADDED}" == "true" || "${PREVIOUS_PATH_LINE_ADDED}" != "true" ||
        -z "${PREVIOUS_PATH_CONFIG_FILE}" || -z "${PREVIOUS_PATH_LINE}" || ! -f "${PREVIOUS_PATH_CONFIG_FILE}" ]]; then
        return 0
    fi
    if grep -Fqx -- "${PREVIOUS_PATH_LINE}" "${PREVIOUS_PATH_CONFIG_FILE}"; then
        RECORD_PATH_CONFIG_FILE=${PREVIOUS_PATH_CONFIG_FILE}
        RECORD_PATH_LINE=${PREVIOUS_PATH_LINE}
        RECORD_PATH_LINE_ADDED=true
        RECORD_PATH_CONFIG_CREATED=${PREVIOUS_PATH_CONFIG_CREATED}
    fi
}

shell_quote_literal() {
    if [[ $# -eq 0 ]]; then
        printf '%q' ""
    else
        printf '%q' "$1"
    fi
}

write_install_info() {
    local wrapper_path=$1

    RECORD_PATH_CONFIG_FILE=${PATH_CONFIG_FILE}
    RECORD_PATH_LINE=${PATH_LINE}
    RECORD_PATH_LINE_ADDED=${PATH_LINE_ADDED}
    RECORD_PATH_CONFIG_CREATED=${PATH_CONFIG_CREATED}
    keep_previous_path_line_record
    cat > "${INSTALL_INFO}" <<EOF
#!/bin/bash
cli_wrapper_path=$(shell_quote_literal "${wrapper_path}")
managed_awake_path=$(shell_quote_literal "${MANAGED_AWAKE}")
app_path=$(shell_quote_literal "${APP_DESTINATION}")
path_config_file=$(shell_quote_literal "${RECORD_PATH_CONFIG_FILE}")
path_line=$(shell_quote_literal "${RECORD_PATH_LINE}")
path_line_added=$(shell_quote_literal "${RECORD_PATH_LINE_ADDED}")
path_config_created=$(shell_quote_literal "${RECORD_PATH_CONFIG_CREATED}")
EOF
    chmod 600 "${INSTALL_INFO}"
}

# Sets AWAKE_UI_OPTION: awake asks for the administrator password in the
# terminal when there is one, and with the macOS password dialog otherwise
# (Install Awake.app). It must run in the installer's own shell: inside
# $(...), standard output is a pipe, never a terminal.
choose_awake_ui_option() {
    if [[ -t 0 && -t 1 ]]; then
        AWAKE_UI_OPTION="--terminal"
    else
        AWAKE_UI_OPTION="--gui"
    fi
}

# The app and the picker are built from source, which needs Apple's Command
# Line Tools with Swift 5.7 or later.
check_build_tools() {
    local version_text=""
    local major=""
    local minor=""

    if ! /usr/bin/xcode-select -p >/dev/null 2>&1; then
        printf '%s\n' "Awake's installer needs Apple's Command Line Tools to build the menu bar app." \
            "Install them with: xcode-select --install" \
            "When that has finished, run the installer again." >&2
        exit 1
    fi
    if ! version_text=$(/usr/bin/swiftc --version 2>&1); then
        printf '%s\n' "The Swift compiler, which the installer needs to build the menu bar app, did not run:" "${version_text}" >&2
        exit 1
    fi
    if [[ "${version_text}" =~ Swift\ version\ ([0-9]+)\.([0-9]+) ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        if (( 10#${major} < 5 || ( 10#${major} == 5 && 10#${minor} < 7 ) )); then
            printf 'Awake needs Swift 5.7 or later to build the menu bar app, and this Mac has Swift %s.%s. Update the Command Line Tools in Software Update, then run the installer again.\n' "${major}" "${minor}" >&2
            exit 1
        fi
    fi
}

# Replacing the app deletes what is at its path, so only an Awake.app is
# replaced there.
is_awake_app() {
    [[ -d "$1" ]] || return 1
    grep -Fq -- "<string>${APP_BUNDLE_ID}</string>" "$1/Contents/Info.plist" 2>/dev/null ||
        [[ -f "$1/Contents/MacOS/${APP_EXECUTABLE_NAME}" ]]
}

check_app_destination() {
    if [[ ( -e "${APP_DESTINATION}" || -L "${APP_DESTINATION}" ) ]] && ! is_awake_app "${APP_DESTINATION}"; then
        printf '%s\n' "${APP_DESTINATION} is not Awake.app, so the installer does not replace it. Move it away, or choose another path with --app-destination." >&2
        exit 1
    fi
}

# Prints the status of the installed version's running session, such as
# "Awake is on and has 1 hour left.", or nothing when none runs. Every
# version since 2.0.0 starts that line of --status with "Awake is on".
running_session_status() {
    local output=""
    local first_line=""

    output=$(AWAKE_NO_NOTIFICATIONS=true "${MANAGED_AWAKE}" --status 2>/dev/null) || true
    first_line=${output%%$'\n'*}
    if [[ "${first_line}" == "Awake is on"* ]]; then
        printf '%s' "${first_line}"
    fi
}

stop_previous_session() {
    local status_text=""

    if [[ ! -x "${MANAGED_AWAKE}" ]]; then
        return 0
    fi
    status_text=$(running_session_status)
    if [[ -n "${status_text}" ]]; then
        printf 'Installing stops the running session: %s\n' "${status_text}"
    fi
    # Let the installed version end its own session before it is replaced.
    AWAKE_NO_NOTIFICATIONS=true "${MANAGED_AWAKE}" "${AWAKE_UI_OPTION}" --stop >/dev/null 2>&1 || true
    if [[ -n "${status_text}" && -n "$(running_session_status)" ]]; then
        printf '%s\n' "The session could not be stopped and keeps running. Stop it later with 'awake --stop'." >&2
    fi
}

# A running menu bar app keeps running its old code, so quit it before the
# update and start the new version afterwards. Only the app at
# APP_DESTINATION is quit: its AwakeStatusBar processes get TERM, and KILL if
# they are still there after 5 seconds. Other copies of the app, such as a
# build run from the repository, are left alone.
quit_running_app() {
    local executable="${APP_DESTINATION}/Contents/MacOS/${APP_EXECUTABLE_NAME}"
    local resolved_executable=""
    local pid=""
    local command_line=""
    local pids=()
    local waited=0
    local alive=false

    if [[ -d "${APP_DESTINATION}" ]]; then
        resolved_executable="$(cd -- "${APP_DESTINATION}" && pwd -P)/Contents/MacOS/${APP_EXECUTABLE_NAME}"
    fi
    for pid in $(/usr/bin/pgrep -u "$(/usr/bin/id -u)" -x "${APP_EXECUTABLE_NAME}" || true); do
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
    APP_WAS_RUNNING=true
    printf '%s\n' "Quitting the running Awake.app ..."
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
        waited=$((waited + 1))
    done
    /bin/kill -KILL "${pids[@]}" >/dev/null 2>&1 || true
}

# The helper is there when the installed copy matches the one just installed
# into the managed folder. awake --install-helper ends without an error when
# the password prompt is cancelled, so its exit status does not tell.
helper_is_installed() {
    [[ -x "${INSTALLED_HELPER}" ]] && /usr/bin/cmp -s "${MANAGED_HELPER_SOURCE}" "${INSTALLED_HELPER}"
}

report_path_setup() {
    local wrapper_path=$1

    if [[ "${PATH_LINE_ADDED}" == "true" ]]; then
        printf '%s\n' "Added $(dirname -- "${wrapper_path}") to your shell PATH in ${PATH_CONFIG_FILE}."
        printf '%s\n' "Open a new Terminal window to use the updated PATH wrapper."
    else
        printf '%s\n' "The PATH wrapper is ready at ${wrapper_path}."
    fi
}

choose_awake_ui_option
check_app_destination
check_build_tools
read_previous_install_info
choose_wrapper_dir

printf '%s\n' "Building Awake.app ..."
"${BUILD_SCRIPT}" --output-app "${TEMP_APP}" >/dev/null

printf '%s\n' "Building Awake GUI picker ..."
/usr/bin/swiftc -O \
    -framework AppKit \
    "${GUI_PICKER_SOURCE}" \
    -o "${TEMP_GUI_PICKER}"

stop_previous_session
quit_running_app

printf '%s\n' "Installing Awake.app ..."
mkdir -p -- "${APP_PARENT_DIR}"
check_app_destination
rm -rf -- "${APP_DESTINATION}"
/usr/bin/ditto "${TEMP_APP}" "${APP_DESTINATION}"

printf '%s\n' "Installing the managed awake command ..."
mkdir -p -- "${MANAGED_BIN_DIR}"
install -m 755 "${SOURCE_AWAKE}" "${MANAGED_AWAKE}"
install -m 755 "${SOURCE_HELPER}" "${MANAGED_HELPER_SOURCE}"
install -m 755 "${TEMP_GUI_PICKER}" "${MANAGED_GUI_PICKER}"
install -m 644 "${GUI_PICKER_ICON_SOURCE}" "${MANAGED_GUI_PICKER_ICON}"

printf '%s\n' "Installing the PATH wrapper ..."
install_wrapper
write_install_info "${CLI_WRAPPER_PATH}"

# Lid-closed sessions need the root-owned helper; installing it asks for the
# administrator password once. Turning on password-free mode installs or
# updates the helper in the same step, under the same prompt.
if [[ "${PASSWORDLESS}" == "true" ]]; then
    printf '%s\n' "Installing the privileged helper and turning on password-free mode ..."
    "${MANAGED_AWAKE}" "${AWAKE_UI_OPTION}" --passwordless on || true
else
    printf '%s\n' "Installing the privileged helper ..."
    "${MANAGED_AWAKE}" "${AWAKE_UI_OPTION}" --install-helper || true
fi
if ! helper_is_installed; then
    printf '%s\n' "The helper was not installed. Lid-closed mode needs it; run 'awake --install-helper' later." >&2
elif [[ "${PASSWORDLESS}" == "true" && ! -e "${PASSWORDLESS_RULE}" ]]; then
    printf '%s\n' "Password-free mode was not turned on. You can turn it on later in the menu bar app's Settings." >&2
fi

# --no-launch still restarts an app that was running before the update.
if [[ "${NO_LAUNCH}" != "true" || "${APP_WAS_RUNNING}" == "true" ]]; then
    printf '%s\n' "Launching Awake.app ..."
    /usr/bin/open -gj "${APP_DESTINATION}"
fi

printf '\n%s\n' "Awake installation complete."
printf 'App: %s\n' "${APP_DESTINATION}"
printf 'Managed CLI: %s\n' "${MANAGED_AWAKE}"
printf 'PATH wrapper: %s\n' "${CLI_WRAPPER_PATH}"
report_path_setup "${CLI_WRAPPER_PATH}"
