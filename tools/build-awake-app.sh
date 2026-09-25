#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly APP_SOURCE_DIR="${REPO_ROOT}/app/AwakeStatusApp"
readonly APP_ASSET_DIR="${APP_SOURCE_DIR}/Assets"
readonly SOURCE_DIR="${APP_SOURCE_DIR}/Sources"
readonly INFO_PLIST="${APP_SOURCE_DIR}/Resources/Info.plist"
readonly OFF_ICON="${APP_ASSET_DIR}/awake-off.png"
# Menu bar template icons; regenerate with tools/render-status-icons.py.
STATUS_ICONS=(
    StatusOffTemplate.png
    StatusOffTemplate@2x.png
    StatusOnTemplate.png
    StatusOnTemplate@2x.png
)

OUTPUT_APP="${REPO_ROOT}/build/Awake.app"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --output-app)
            shift
            if [[ $# -eq 0 ]]; then
                printf '%s\n' "Option --output-app requires a path." >&2
                exit 1
            fi
            OUTPUT_APP=$1
            ;;
        *)
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
    esac
    shift
done

readonly OUTPUT_APP
readonly EXECUTABLE_PATH="${OUTPUT_APP}/Contents/MacOS/AwakeStatusBar"
readonly RESOURCES_DIR="${OUTPUT_APP}/Contents/Resources"
readonly TEMP_ASSET_DIR="$(mktemp -d "${TMPDIR:-/tmp}/awake-assets.XXXXXX")"

cleanup() {
    rm -rf -- "${TEMP_ASSET_DIR}"
}
trap cleanup EXIT

mkdir -p -- "$(dirname -- "${OUTPUT_APP}")"
rm -rf -- "${OUTPUT_APP}"
mkdir -p -- "${OUTPUT_APP}/Contents/MacOS" "${RESOURCES_DIR}"

# The checked-in app assets provide the app icon and the menu bar icons.
# The Swift renderer still generates the notification images.
/usr/bin/swift "${SCRIPT_DIR}/render-awake-assets.swift" "${TEMP_ASSET_DIR}"

/usr/bin/swiftc -O \
    -framework AppKit \
    -framework WebKit \
    -framework UserNotifications \
    "${SOURCE_DIR}"/*.swift \
    -o "${EXECUTABLE_PATH}"

chmod 755 "${EXECUTABLE_PATH}"
cp "${INFO_PLIST}" "${OUTPUT_APP}/Contents/Info.plist"
cp "${REPO_ROOT}/README.md" "${RESOURCES_DIR}/README.md"
cp "${OFF_ICON}" "${RESOURCES_DIR}/AppIcon.png"
cp "${TEMP_ASSET_DIR}/NotificationOff.png" "${RESOURCES_DIR}/NotificationOff.png"
cp "${TEMP_ASSET_DIR}/NotificationOn.png" "${RESOURCES_DIR}/NotificationOn.png"
for status_icon in "${STATUS_ICONS[@]}"; do
    cp "${APP_ASSET_DIR}/${status_icon}" "${RESOURCES_DIR}/${status_icon}"
done

printf '%s\n' "${OUTPUT_APP}"
