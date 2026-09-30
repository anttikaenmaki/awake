#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
set -euo pipefail

# Prints the Homebrew cask for an Awake release: TEMPLATE (by default
# tools/homebrew/awake.rb) with its version and the SHA-256 checksum of the
# release's source archive filled in. The Homebrew tap workflow writes the
# tap's Casks/awake.rb with it, and CI checks the template with it.

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"

if (( $# < 2 || $# > 3 )); then
    printf '%s\n' "Usage: tools/homebrew/render-cask.sh VERSION SHA256 [TEMPLATE]" >&2
    exit 2
fi
readonly VERSION=$1
readonly SHA256=$2
readonly TEMPLATE=${3:-"${SCRIPT_DIR}/awake.rb"}

if [[ ! "${VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Not a version of the form X.Y.Z: %s\n' "${VERSION}" >&2
    exit 1
fi
if [[ ! "${SHA256}" =~ ^[0-9a-f]{64}$ ]]; then
    printf 'Not a SHA-256 checksum in lowercase hex: %s\n' "${SHA256}" >&2
    exit 1
fi

cask=$(sed -e "s/@VERSION@/${VERSION}/g" -e "s/@SHA256@/${SHA256}/g" "${TEMPLATE}")
if [[ "${cask}" == *@VERSION@* || "${cask}" == *@SHA256@* ]]; then
    printf '%s\n' "The template still has a placeholder after filling it in." >&2
    exit 1
fi
if [[ "${cask}" != *"version \"${VERSION}\""* || "${cask}" != *"sha256 \"${SHA256}\""* ]]; then
    printf '%s\n' "The template has no version or sha256 line to fill in." >&2
    exit 1
fi
printf '%s\n' "${cask}"
