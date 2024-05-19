#!/usr/bin/env sh -e

ELIXIR="1.16.2"
ERLANG="26.2.5"
SUFFIX="alpine-3.19.1"

# Get the directory of the script
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")

# Get the parent directory
PARENT_DIR=$(dirname "$SCRIPT_DIR")

# Check if docker-compose is available
if command -v docker-compose &> /dev/null
then
    COMPOSE_CMD="docker-compose"
elif docker compose version &> /dev/null
then
    COMPOSE_CMD="docker compose"
else
    echo "Error: Neither docker-compose nor the docker compose plugin is available."
    exit 1
fi

# Start databases
$COMPOSE_CMD up -d

# Run test commands (adapt from .github/workflows/ci.yml if necessary)
docker run --rm --network=integration_test_default \
    -w $PARENT_DIR -v $PARENT_DIR:$PARENT_DIR \
    -it hexpm/elixir:$ELIXIR-erlang-$ERLANG-$SUFFIX sh -c '
mix local.rebar --force
mix local.hex --force
apk add --no-progress --update git socat make gcc libc-dev
socat TCP-LISTEN:5432,fork TCP-CONNECT:postgres:5432&
socat TCP-LISTEN:3306,fork TCP-CONNECT:mysql:3306&
socat TCP-LISTEN:1433,fork TCP-CONNECT:mssql:1433&
echo "Running installer tests"
cd installer
mix test
echo "Running integration tests"
cd ../integration_test
mix deps.get
mix test --include database
'

$COMPOSE_CMD down
