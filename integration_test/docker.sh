#!/bin/sh
set -e

cd "$(dirname "$0")"

# Handle "down" sub-command to easily stop backing services
if [ "$1" = "down" ]; then
  exec docker compose --profile "*" down
fi

# Derive compilation parallelism from available cores (half of CPU cores, min 2)
CORES=$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || echo 4)
HALF_CORES=$(( CORES > 2 ? CORES / 2 : 2 ))

export MIX_OS_DEPS_COMPILE_PARTITION_COUNT="${MIX_OS_DEPS_COMPILE_PARTITION_COUNT:-$HALF_CORES}"
export MAKEFLAGS="${MAKEFLAGS:--j$MIX_OS_DEPS_COMPILE_PARTITION_COUNT}"

exec docker compose run --build --rm runner "$@"
