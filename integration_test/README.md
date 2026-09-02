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
`MIX_ENV=test` and then copied to `_build/dev` to improve test speed.
Therefore, dependencies should not be listed in `mix.exs` with an `only: <env>`
option.

### Test module concurrency and granularity

Integration test cases are organized into focused, granular test modules (e.g.,
`AppWithPostgresAdapterHtmlTest`, `AppWithPostgresAdapterLiveTest`,
`AppWithScopesLiveTest`, etc.) marked with `async: true`.

Because ExUnit parallelizes execution across *modules* while running tests
*serially within each module*, keeping modules fine-grained prevents individual
slow modules from bottlenecking overall test runs and ensures test runner
schedulers/vCPUs remain continuously saturated throughout the suite.

### App naming convention

Each test module generates an application using a systematic, concise
`<prefix>_<feature>` naming pattern:

| Prefix | Adapter / Scope | App Names |
| :--- | :--- | :--- |
| `pg_` | PostgreSQL | `pg_app`, `pg_html`, `pg_json`, `pg_live`, `pg_auth_html`, `pg_auth_live` |
| `my_` | MySQL | `my_html`, `my_json`, `my_live`, `my_scope`, `my_auth_html`, `my_auth_live` |
| `ms_` | MSSQL | `ms_html`, `ms_json`, `ms_live`, `ms_auth_html`, `ms_auth_live` |
| `lt_` | SQLite3 | `lt_html`, `lt_json`, `lt_live`, `lt_auth_html`, `lt_auth_live` |
| `um_` | Umbrella (Postgres) | `um_app`, `um_html`, `um_json`, `um_live`, `um_auth_html`, `um_auth_live` |
| `sc_` | Scopes | `sc_html`, `sc_json`, `sc_live`, `sc_routes` |
| — | Minimal | `minimal` |

This naming convention satisfies two strict requirements:
1. **Database isolation**: Ensures unique database names (`<app_name>_test`)
   across concurrent tests.
2. **Formatter line-length limit**: App names are converted to module names
   during code generation. Keeping `app_name` short (as of writing, max 10
   characters excluding underscores) ensures generated template lines never
   exceed Elixir's default formatter line limit.
