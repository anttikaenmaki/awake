#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly SOURCE_AWAKE="${REPO_ROOT}/bin/awake"
readonly GUI_PICKER_SOURCE="${REPO_ROOT}/tools/awake-gui-picker.swift"
readonly GUI_PICKER_ICON_SOURCE="${REPO_ROOT}/app/AwakeStatusApp/Assets/awake-off.png"
readonly BUILD_SCRIPT="${REPO_ROOT}/tools/build-awake-app.sh"
readonly APP_SUPPORT_DIR="${HOME}/Library/Application Support/Awake"
readonly MANAGED_BIN_DIR="${APP_SUPPORT_DIR}/bin"
readonly MANAGED_AWAKE="${MANAGED_BIN_DIR}/awake"
readonly MANAGED_GUI_PICKER="${MANAGED_BIN_DIR}/awake-gui-picker"
readonly MANAGED_GUI_PICKER_ICON="${MANAGED_BIN_DIR}/awake-off.png"
readonly INSTALL_INFO="${APP_SUPPORT_DIR}/install-info.sh"
readonly DEFAULT_USER_BIN="${HOME}/.local/bin"

APP_DESTINATION="${HOME}/Applications/Awake.app"
NO_LAUNCH=false
PATH_CONFIG_FILE=""
PATH_LINE_ADDED=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-launch)
            NO_LAUNCH=true
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

install_wrapper_into_writable_dir() {
    local wrapper_dir=$1

    mkdir -p -- "$wrapper_dir"
    cat > "${TEMP_WRAPPER}" <<EOF
#!/bin/bash
exec "${MANAGED_AWAKE}" "\$@"
EOF
    chmod 755 "${TEMP_WRAPPER}"
    install -m 755 "${TEMP_WRAPPER}" "${wrapper_dir}/awake"
    printf '%s' "${wrapper_dir}/awake"
}

path_config_file_for_shell() {
    local shell_name

    shell_name="$(basename -- "${SHELL:-/bin/zsh}")"
    case "$shell_name" in
        bash)
            printf '%s' "${HOME}/.bash_profile"
            ;;
        *)
            printf '%s' "${HOME}/.zprofile"
            ;;
    esac
}

append_path_to_shell_config() {
    local config_file
    local export_line='export PATH="$HOME/.local/bin:$PATH"'

    config_file="$(path_config_file_for_shell)"
    PATH_CONFIG_FILE="${config_file}"
    touch "${config_file}"
    if ! grep -Fq "${export_line}" "${config_file}"; then
        printf '\n%s\n' "${export_line}" >> "${config_file}"
        PATH_LINE_ADDED=true
    fi
}

choose_wrapper_path() {
    local path_value

    path_value="$(login_shell_path)"

    if [[ "${path_value}" == *"${HOME}/bin"* ]]; then
        install_wrapper_into_writable_dir "${HOME}/bin"
        return 0
    fi

    if [[ "${path_value}" == *"${DEFAULT_USER_BIN}"* ]]; then
        install_wrapper_into_writable_dir "${DEFAULT_USER_BIN}"
        return 0
    fi

    if [[ -d "${HOME}/bin" && -w "${HOME}/bin" ]]; then
        install_wrapper_into_writable_dir "${HOME}/bin"
        return 0
    fi

    if [[ -d "${DEFAULT_USER_BIN}" && -w "${DEFAULT_USER_BIN}" ]]; then
        append_path_to_shell_config
        install_wrapper_into_writable_dir "${DEFAULT_USER_BIN}"
        return 0
    fi

    append_path_to_shell_config
    install_wrapper_into_writable_dir "${DEFAULT_USER_BIN}"
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

    cat > "${INSTALL_INFO}" <<EOF
#!/bin/bash
cli_wrapper_path=$(shell_quote_literal "${wrapper_path}")
managed_awake_path=$(shell_quote_literal "${MANAGED_AWAKE}")
app_path=$(shell_quote_literal "${APP_DESTINATION}")
path_config_file=$(shell_quote_literal "${PATH_CONFIG_FILE}")
path_line_added=$(shell_quote_literal "${PATH_LINE_ADDED}")
EOF
    chmod 600 "${INSTALL_INFO}"
}

report_path_setup() {
    local wrapper_path=$1

    if [[ "${PATH_LINE_ADDED}" == "true" ]]; then
        printf '%s\n' "Added ${DEFAULT_USER_BIN} to your shell PATH in ${PATH_CONFIG_FILE}."
        printf '%s\n' "Open a new Terminal window to use the updated PATH wrapper."
    else
        printf '%s\n' "The PATH wrapper is ready at ${wrapper_path}."
    fi
}

printf '%s\n' "Building Awake.app ..."
"${BUILD_SCRIPT}" --output-app "${TEMP_APP}" >/dev/null

printf '%s\n' "Building Awake GUI picker ..."
/usr/bin/swiftc -O \
    -framework AppKit \
    "${GUI_PICKER_SOURCE}" \
    -o "${TEMP_GUI_PICKER}"

printf '%s\n' "Installing Awake.app ..."
mkdir -p -- "${APP_PARENT_DIR}"
rm -rf -- "${APP_DESTINATION}"
/usr/bin/ditto "${TEMP_APP}" "${APP_DESTINATION}"

printf '%s\n' "Installing the managed awake command ..."
mkdir -p -- "${MANAGED_BIN_DIR}"
install -m 755 "${SOURCE_AWAKE}" "${MANAGED_AWAKE}"
install -m 755 "${TEMP_GUI_PICKER}" "${MANAGED_GUI_PICKER}"
install -m 644 "${GUI_PICKER_ICON_SOURCE}" "${MANAGED_GUI_PICKER_ICON}"

printf '%s\n' "Installing the PATH wrapper ..."
CLI_WRAPPER_PATH="$(choose_wrapper_path)"
write_install_info "${CLI_WRAPPER_PATH}"

if [[ "${NO_LAUNCH}" != "true" ]]; then
    printf '%s\n' "Launching Awake.app ..."
    /usr/bin/open -gj "${APP_DESTINATION}"
fi

printf '\n%s\n' "Awake installation complete."
printf 'App: %s\n' "${APP_DESTINATION}"
printf 'Managed CLI: %s\n' "${MANAGED_AWAKE}"
printf 'PATH wrapper: %s\n' "${CLI_WRAPPER_PATH}"
report_path_setup "${CLI_WRAPPER_PATH}"
