#!/usr/bin/env bash
#
# Verify that all package versions match a release tag
#
# Usage: ./verify-release-versions.sh <tag>
# Example: ./verify-release-versions.sh v1.8.9

set -euo pipefail

TAG="${1:-}"

if [[ -z "$TAG" ]]; then
    echo "Usage: $0 <tag>" >&2
    echo "Example: $0 v1.8.9" >&2
    exit 1
fi

cd "$(dirname "$0")/.."

TAG_VERSION="${TAG#v}"
FAILED=0

check_version() {
    if [[ "$2" != "$TAG_VERSION" ]]; then
        echo "::error file=$1::$1 has version '$2', but tag $TAG requires '$TAG_VERSION'."
        FAILED=1
    fi
}

mix_version() {
    sed -n 's/^ *@version "\(.*\)"$/\1/p' "$1"
}

check_version mix.exs "$(mix_version mix.exs)"
check_version installer/mix.exs "$(mix_version installer/mix.exs)"
check_version package.json "$(jq -r .version package.json)"

exit "$FAILED"
