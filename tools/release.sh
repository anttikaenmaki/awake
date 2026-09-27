#!/bin/bash
# Copyright (C) 2026 Antti Käenmäki
#
# Prepares a release: sets the new version everywhere it appears, dates the
# changelog, and commits the result. Also checks that the version is
# consistent (used by CI) and prints release notes (used by the Release
# workflow). Run with --help for details.
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly REPO_URL="https://github.com/anttikaenmaki/awake"
readonly CLI="bin/awake"
readonly README="README.md"
readonly CHANGELOG="CHANGELOG.md"
# Each has the version as both CFBundleShortVersionString and CFBundleVersion.
PLISTS=(
    "app/AwakeStatusApp/Resources/Info.plist"
    "Install Awake.app/Contents/Info.plist"
    "Uninstall Awake.app/Contents/Info.plist"
)
readonly SEMVER_RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

problems=0

usage() {
    cat <<'EOF'
Usage: tools/release.sh [patch|minor|major|X.Y.Z]
       tools/release.sh --check | --version | --notes [X.Y.Z]

Without an option, prepare a release on the current branch (normally dev):
set the new version in bin/awake, README.md and the three Info.plist files,
turn the Unreleased section of CHANGELOG.md into a dated section for it, and
commit the result as "Version X.Y.Z". Without an argument, the level comes
from the Unreleased section (Breaking or Removed: major; Added, Changed or
Deprecated: minor; otherwise patch), and you confirm it. Merging the commit
into main tags vX.Y.Z and publishes the GitHub release
(.github/workflows/release.yml).

  --check          exit with an error unless all version strings and the
                   newest dated section of CHANGELOG.md agree
  --version        print the current version
  --notes [X.Y.Z]  print the changelog section of a version (default: the
                   current one), without its heading
  -h, --help       show this help
EOF
}

die() {
    printf 'release.sh: %s\n' "$1" >&2
    exit 1
}

usage_error() {
    usage >&2
    exit 2
}

# The version in bin/awake is the reference that everything else must match.
current_version() {
    awk -F'"' '/^readonly VERSION="/ { print $2; exit }' "$CLI"
}

# Print the <string> value that follows <key>KEY</key> in a plist.
plist_value() {
    awk -v key="<key>$2</key>" '
        found {
            if (match($0, /<string>[^<]*<\/string>/)) print substr($0, RSTART + 8, RLENGTH - 17)
            exit
        }
        index($0, key) { found = 1 }
    ' "$1"
}

# Run a filter over a file and write the result back. Writing through the
# existing file keeps its mode, so bin/awake stays executable.
rewrite() {
    local file=$1 tmp
    shift
    tmp="$(mktemp)"
    if ! "$@" "$file" > "$tmp"; then
        rm -f -- "$tmp"
        die "could not update ${file}"
    fi
    cat -- "$tmp" > "$file"
    rm -f -- "$tmp"
}

set_version() {
    local version=$1 plist
    rewrite "$CLI" awk -v version="$version" '
        /^# Version: / { $0 = "# Version: " version }
        /^readonly VERSION="/ { $0 = "readonly VERSION=\"" version "\"" }
        { print }
    '
    rewrite "$README" awk -v version="$version" '
        /^Current version: `/ { sub(/`[^`]*`/, "`" version "`") }
        { print }
    '
    for plist in "${PLISTS[@]}"; do
        rewrite "$plist" awk -v version="$version" '
            pending { sub(/<string>[^<]*<\/string>/, "<string>" version "</string>"); pending = 0 }
            /<key>CFBundle(ShortVersionString|Version)<\/key>/ { pending = 1 }
            { print }
        '
    done
}

# Print a section of the changelog (a version, or "Unreleased") without its
# heading and without surrounding blank lines.
changelog_section() {
    awk -v heading="## [$1]" '
        /^## \[/ { if (inside) exit; inside = (index($0, heading) == 1); next }
        /^\[[A-Za-z0-9.]+\]: / { if (inside) exit }
        inside { line[++n] = $0 }
        END {
            first = 1
            while (first <= n && line[first] ~ /^[[:space:]]*$/) first++
            last = n
            while (last >= first && line[last] ~ /^[[:space:]]*$/) last--
            for (i = first; i <= last; i++) print line[i]
        }
    ' "$CHANGELOG"
}

# Print the version of the newest dated changelog section.
latest_release() {
    local heading re='^## \[([^]]+)\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$'
    heading="$(awk '/^## \[[0-9]/ { print; exit }' "$CHANGELOG")"
    [[ "$heading" =~ $re ]] || return 1
    printf '%s\n' "${BASH_REMATCH[1]}"
}

# Move the Unreleased notes under a heading for the new version, leaving an
# empty Unreleased section above it, and add the new comparison link.
date_changelog() {
    rewrite "$CHANGELOG" awk -v previous="$1" -v version="$2" -v day="$3" -v url="$REPO_URL" '
        $0 == "## [Unreleased]" { print; print ""; print "## [" version "] - " day; next }
        index($0, "[Unreleased]: ") == 1 {
            print "[Unreleased]: " url "/compare/v" version "...HEAD"
            print "[" version "]: " url "/compare/v" previous "...v" version
            next
        }
        { print }
    '
}

report() {
    printf 'release.sh: %s\n' "$1" >&2
    problems=$((problems + 1))
}

expect() {
    local place=$1 found=$2 expected=$3
    [[ "$found" == "$expected" ]] || report "${place} says \"${found}\", but ${CLI} says \"${expected}\""
}

check() {
    local expected plist latest
    expected="$(current_version)"
    [[ "$expected" =~ $SEMVER_RE ]] || die "found no version of the form X.Y.Z in ${CLI}"
    problems=0
    expect "the header of ${CLI}" "$(awk '/^# Version: / { print $3; exit }' "$CLI")" "$expected"
    expect "$README" "$(awk -F'`' '/^Current version: `/ { print $2; exit }' "$README")" "$expected"
    for plist in "${PLISTS[@]}"; do
        expect "CFBundleShortVersionString in ${plist}" "$(plist_value "$plist" CFBundleShortVersionString)" "$expected"
        expect "CFBundleVersion in ${plist}" "$(plist_value "$plist" CFBundleVersion)" "$expected"
    done
    if latest="$(latest_release)"; then
        expect "the newest section of ${CHANGELOG}" "$latest" "$expected"
    else
        report "${CHANGELOG} has no section headed \"## [X.Y.Z] - YYYY-MM-DD\""
    fi
    grep -qx '## \[Unreleased\]' "$CHANGELOG" || report "${CHANGELOG} has no \"## [Unreleased]\" section"
    awk -v link="[${expected}]: " 'index($0, link) == 1 { found = 1 } END { exit !found }' "$CHANGELOG" ||
        report "${CHANGELOG} has no link definition for [${expected}]"
    ((problems == 0)) || die "found ${problems} version problem(s)"
    printf 'Version %s is consistent in %s, %s, the %d Info.plist files and %s.\n' \
        "$expected" "$CLI" "$README" "${#PLISTS[@]}" "$CHANGELOG"
}

# Suggest a release level from the kinds of change in the Unreleased notes.
suggest_level() {
    if grep -qiE '\*\*breaking|^### removed' <<< "$1"; then
        echo major
    elif grep -qiE '^### (added|changed|deprecated)' <<< "$1"; then
        echo minor
    else
        echo patch
    fi
}

bump() {
    local major minor patch
    IFS=. read -r major minor patch <<< "$1"
    case "$2" in
        major) echo "$((major + 1)).0.0" ;;
        minor) echo "${major}.$((minor + 1)).0" ;;
        patch) echo "${major}.${minor}.$((patch + 1))" ;;
    esac
}

# Succeed if version $1 is newer than version $2.
newer() {
    local a1 a2 a3 b1 b2 b3
    IFS=. read -r a1 a2 a3 <<< "$1"
    IFS=. read -r b1 b2 b3 <<< "$2"
    ((a1 != b1 ? a1 > b1 : a2 != b2 ? a2 > b2 : a3 > b3))
}

release() {
    local request=$1 current notes suggested new answer
    check > /dev/null
    current="$(current_version)"
    [[ -z "$(git status --porcelain)" ]] ||
        die "the working tree has uncommitted changes; commit or stash them first, so that the release commit holds only the version change"
    notes="$(changelog_section Unreleased)"
    grep -q '^- ' <<< "$notes" ||
        die "the Unreleased section of ${CHANGELOG} lists no changes; describe them there first"
    suggested="$(suggest_level "$notes")"

    case "$request" in
        "")
            [[ -t 0 ]] || die "cannot ask for confirmation without a terminal; pass patch, minor, major, or a version"
            new="$(bump "$current" "$suggested")"
            printf 'The Unreleased section suggests a %s release: %s -> %s.\n' "$suggested" "$current" "$new"
            read -r -p "Release ${new}? [y/N] " answer
            [[ "$answer" == [yY]* ]] || die "cancelled"
            ;;
        patch|minor|major)
            new="$(bump "$current" "$request")"
            [[ "$request" == "$suggested" ]] ||
                printf 'Note: the Unreleased section suggests a %s release; making a %s release as requested.\n' "$suggested" "$request"
            ;;
        *)
            [[ "$request" =~ $SEMVER_RE ]] || usage_error
            newer "$request" "$current" || die "${request} is not newer than the current version ${current}"
            new=$request
            ;;
    esac
    if git rev-parse -q --verify "refs/tags/v${new}" > /dev/null; then
        die "the tag v${new} already exists"
    fi

    set_version "$new"
    date_changelog "$current" "$new" "$(date +%Y-%m-%d)"
    check > /dev/null
    git add -- "$CLI" "$README" "$CHANGELOG" "${PLISTS[@]}"
    git commit -q -m "Version ${new}"
    printf 'Committed "Version %s" on %s.\n' "$new" "$(git branch --show-current)"
    printf 'Push it and merge it into main; the Release workflow then tags v%s and publishes the GitHub release.\n' "$new"
}

notes() {
    local version=${1:-$(current_version)} text
    text="$(changelog_section "$version")"
    [[ -n "$text" ]] || die "${CHANGELOG} has no section for ${version}"
    printf '%s\n' "$text"
}

cd -- "$REPO_ROOT"

case "${1:-}" in
    -h|--help)
        usage
        ;;
    --check)
        (($# == 1)) || usage_error
        check
        ;;
    --version)
        (($# == 1)) || usage_error
        current_version
        ;;
    --notes)
        (($# <= 2)) || usage_error
        notes "${2:-}"
        ;;
    -*)
        usage_error
        ;;
    *)
        (($# <= 1)) || usage_error
        release "${1:-}"
        ;;
esac
