#!/bin/sh
set -e

# Start background database proxy bridges for running services
getent hosts postgresql >/dev/null 2>&1 && socat -d0 TCP-LISTEN:5432,fork TCP-CONNECT:postgresql:5432 &
getent hosts mysql      >/dev/null 2>&1 && socat -d0 TCP-LISTEN:3306,fork TCP-CONNECT:mysql:3306 &
getent hosts mssql      >/dev/null 2>&1 && socat -d0 TCP-LISTEN:1433,fork TCP-CONNECT:mssql:1433 &

mix deps.get
MIX_ENV=test mix deps.compile

exec mix test "$@"
