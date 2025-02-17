## Phoenix Integration Tests

This project contains integration tests for phoenix's generated projects.

## Running tests

To install dependencies, run:

    $ mix deps.get

Then run the basic test suite (no dependencies on the database) with:

    $ mix test

To run the test suite with tests that test a specific database, run:

    $ mix test --include database:postgresql
    $ mix test --include database:mysql
    $ mix test --include database:mssql
    $ mix test --include database:sqlite3

For convenience, there is also a `docker-compose.yml` file that allows for starting up all of the supported databases locally.

    $ docker-compose up

This allows all tests to be run with the following command

    $ mix test --include database

Or alternatively, with docker and docker compose installed, you can just run `./docker.sh`.

## How tests are written

In order to have consistent, repeatable builds, all dependencies for all phoenix
project variations are listed in `mix.exs` and locked via `mix.lock`. If a
dependency version needs to be updated, it can be updated with `mix.exs` or
using `mix deps.update <dep name>`.

It is also important to note that dependencies are initially compiled with
`MIX_ENV=test` and then copied to `_build/dev_` to improve test speed.
Therefore, dependencies should not be listed in `mix.exs` with an `only: <env>`
option.
