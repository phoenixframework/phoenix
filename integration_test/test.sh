#!/bin/sh -e

mix local.rebar --force
mix local.hex --force

# Install Dependencies
apk add --no-progress --update git socat make gcc libc-dev cmake g++

# Set up local proxies
socat TCP-LISTEN:5432,fork TCP-CONNECT:postgres:5432&
socat TCP-LISTEN:3306,fork TCP-CONNECT:mysql:3306&
socat TCP-LISTEN:1433,fork TCP-CONNECT:mssql:1433&

# Navigate to the integration_test directory relative to the script location
cd "$(dirname "$0")"

echo "Running integration tests"
mix deps.get
mix test --include database
