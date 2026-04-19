#!/bin/bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly SOURCE_DIR="${REPO_ROOT}/AwakeStatusApp/Sources"
readonly INFO_PLIST="${REPO_ROOT}/AwakeStatusApp/Resources/Info.plist"
readonly ASSET_SOURCE_DIR="${REPO_ROOT}/AwakeStatusApp/Assets"
readonly CUSTOM_OFF_LOGO="${ASSET_SOURCE_DIR}/awake-off.png"
readonly CUSTOM_ON_LOGO="${ASSET_SOURCE_DIR}/awake-on.png"

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

# Use the bundled Swift renderer so GUI installs do not depend on Pillow.
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
cp "${CUSTOM_OFF_LOGO}" "${RESOURCES_DIR}/AppIcon.png"
cp "${CUSTOM_OFF_LOGO}" "${RESOURCES_DIR}/NotificationOff.png"
cp "${CUSTOM_ON_LOGO}" "${RESOURCES_DIR}/NotificationOn.png"
cp "${TEMP_ASSET_DIR}/StatusOffTemplate.png" "${RESOURCES_DIR}/StatusOffTemplate.png"
cp "${TEMP_ASSET_DIR}/StatusOnTemplate.png" "${RESOURCES_DIR}/StatusOnTemplate.png"

printf '%s\n' "${OUTPUT_APP}"
