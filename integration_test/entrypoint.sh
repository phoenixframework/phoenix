#!/bin/sh
set -e

# Start background database proxy bridges
socat TCP-LISTEN:5432,fork TCP-CONNECT:postgresql:5432 &
socat TCP-LISTEN:3306,fork TCP-CONNECT:mysql:3306 &
socat TCP-LISTEN:1433,fork TCP-CONNECT:mssql:1433 &

mix deps.get
MIX_ENV=test mix deps.compile

exec mix test "$@"
