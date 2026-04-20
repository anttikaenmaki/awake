#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly SOURCE_FILE="${SCRIPT_DIR}/gui-app-launcher.swift"
readonly OFF_ICON="${REPO_ROOT}/app/AwakeStatusApp/Assets/awake-off.png"

build_launcher() {
    local output_path=$1

    /usr/bin/swiftc -O \
        -framework AppKit \
        "${SOURCE_FILE}" \
        -o "${output_path}"
}

mkdir -p \
    "${REPO_ROOT}/Install Awake.app/Contents/MacOS" \
    "${REPO_ROOT}/Install Awake.app/Contents/Resources" \
    "${REPO_ROOT}/Uninstall Awake.app/Contents/MacOS" \
    "${REPO_ROOT}/Uninstall Awake.app/Contents/Resources"

build_launcher "${REPO_ROOT}/Install Awake.app/Contents/MacOS/Install Awake"
build_launcher "${REPO_ROOT}/Uninstall Awake.app/Contents/MacOS/Uninstall Awake"

chmod 755 \
    "${REPO_ROOT}/Install Awake.app/Contents/MacOS/Install Awake" \
    "${REPO_ROOT}/Uninstall Awake.app/Contents/MacOS/Uninstall Awake"

cp "${OFF_ICON}" "${REPO_ROOT}/Install Awake.app/Contents/Resources/AppIcon.png"
cp "${OFF_ICON}" "${REPO_ROOT}/Uninstall Awake.app/Contents/Resources/AppIcon.png"

touch \
    "${REPO_ROOT}/Install Awake.app" \
    "${REPO_ROOT}/Uninstall Awake.app"
