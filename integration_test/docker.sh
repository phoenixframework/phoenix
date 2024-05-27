#!/usr/bin/env sh -e

# adapt with versions from .github/versions/ci.yml if necessary;
# you can also override these with environment variables
ELIXIR="${ELIXIR:-1.16.2}"
ERLANG="${ERLANG:-26.2.5}"
SUFFIX="${SUFFIX:-alpine-3.19.1}"

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

# Run test script in container
docker run --rm --network=integration_test_default \
    -w $PARENT_DIR -v $PARENT_DIR:$PARENT_DIR \
    -it hexpm/elixir:$ELIXIR-erlang-$ERLANG-$SUFFIX sh integration_test/test.sh

$COMPOSE_CMD down
