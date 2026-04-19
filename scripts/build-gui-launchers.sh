#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly SOURCE_FILE="${SCRIPT_DIR}/gui-app-launcher.swift"

build_launcher() {
    local output_path=$1

    /usr/bin/swiftc -O \
        -framework AppKit \
        "${SOURCE_FILE}" \
        -o "${output_path}"
}

build_launcher "${REPO_ROOT}/Install Awake.app/Contents/MacOS/Install Awake"
build_launcher "${REPO_ROOT}/Uninstall Awake.app/Contents/MacOS/Uninstall Awake"

chmod 755 \
    "${REPO_ROOT}/Install Awake.app/Contents/MacOS/Install Awake" \
    "${REPO_ROOT}/Uninstall Awake.app/Contents/MacOS/Uninstall Awake"

touch \
    "${REPO_ROOT}/Install Awake.app" \
    "${REPO_ROOT}/Uninstall Awake.app"
