#!/bin/sh
set -e

# Start background database proxy bridges for running services
getent hosts postgresql >/dev/null 2>&1 && socat TCP-LISTEN:5432,fork TCP-CONNECT:postgresql:5432 2>/dev/null &
getent hosts mysql      >/dev/null 2>&1 && socat TCP-LISTEN:3306,fork TCP-CONNECT:mysql:3306 2>/dev/null &
getent hosts mssql      >/dev/null 2>&1 && socat TCP-LISTEN:1433,fork TCP-CONNECT:mssql:1433 2>/dev/null &

mix deps.get
MIX_ENV=test mix deps.compile

exec mix test "$@"
