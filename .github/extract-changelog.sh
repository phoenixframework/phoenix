#!/usr/bin/env bash
#
# Extract changelog for a specific version from CHANGELOG.md
#
# Usage: ./extract-changelog.sh <version>
# Example: ./extract-changelog.sh v1.8.9

set -euo pipefail

VERSION="${1:-}"

if [[ -z "$VERSION" ]]; then
    echo "Usage: $0 <version>" >&2
    echo "Example: $0 v1.8.9" >&2
    exit 1
fi

# Normalize version to include 'v' prefix
VERSION="${VERSION#v}"  # Remove 'v' if present
VERSION="v${VERSION}"   # Add 'v' prefix

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANGELOG_PATH="${SCRIPT_DIR}/../CHANGELOG.md"

if [[ ! -f "$CHANGELOG_PATH" ]]; then
    echo "Error: CHANGELOG.md not found at $CHANGELOG_PATH" >&2
    exit 1
fi

# Extract the section for the specified version
# Match from "## vX.Y.Z" until the next "## v" header
awk -v version="$VERSION" '
    BEGIN { found = 0; printing = 0 }

    # Match the start of our target version section
    /^## v[0-9]/ {
        if (printing) {
            # We hit the next version, stop printing
            exit
        }
        # Check if this line contains our version
        if (index($0, "## " version " ") > 0) {
            found = 1
            printing = 1
            next  # Skip the version header line
        }
    }

    printing { print }

    END {
        if (!found) {
            print "Error: Version " version " not found in changelog" > "/dev/stderr"
            exit 1
        }
    }
' "$CHANGELOG_PATH"
