#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
exec /bin/bash "${SCRIPT_DIR}/scripts/uninstall-awake.sh" "$@"
