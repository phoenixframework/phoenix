## Phoenix Integration Tests

This project contains integration tests for Phoenix's generated projects.

## Running Tests

### Option A: Using Docker & Docker Compose (Recommended)

Run the integration test suite in an isolated container without needing local database or Elixir setup:

    $ ./docker.sh

Pass specific test files or tag filters to target individual tests:

    $ ./docker.sh test/code_generation/app_with_defaults_test.exs --include database
    $ ./docker.sh --include database:postgresql

To test against different Elixir or Erlang/OTP versions:

    $ ELIXIR_IMAGE_TAG=1.18.5-erlang-27.3.4.17-ubuntu-noble-20260810 ./docker.sh

Find valid image tags (Ubuntu-based, `hexpm/elixir` repo) on [bob.hex.pm](https://bob.hex.pm/docker?repo=hexpm/elixir&os=ubuntu&os_version=noble-&sort=elixir_version,erlang_version,os_version).

All databases (PostgreSQL, MySQL, and MSSQL) are started by default. Because the official MSSQL image supports only `amd64`, the MSSQL service and tests are automatically skipped on other platforms (e.g., `arm64`).

When running tests repeatedly, backing database containers remain warm in the background for instant re-runs. To tear down the database services when finished:

    $ ./docker.sh down

### Option B: Running Natively on the Host

Install dependencies and run the tests on your machine:

    $ mix deps.get

Run the basic test suite (without databases):

    $ mix test

To run tests against a specific database:

    $ mix test --include database:postgresql
    $ mix test --include database:mysql
    $ mix test --include database:mssql
    $ mix test --include database:sqlite3

To run all tests including databases:

    $ mix test --include database

> [!NOTE]
> **Running databases for host-native tests:**
> `docker-compose.yml` does not publish database ports to the host by default. This avoids port collisions with local databases already running on your machine (e.g. PostgreSQL on 5432 or MySQL on 3306) and prevents exposing test databases with default credentials to the local network.
>
> When running tests directly on the host (`mix test`) rather than inside Docker (`./docker.sh`), include `docker-compose.ports.yml` to publish ports strictly to loopback (`127.0.0.1`):
>
> ```bash
> # Start all databases with host ports published on 127.0.0.1
> $ docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d
>
> # Or start only a specific database (e.g. Postgres)
> $ docker compose -f docker-compose.yml -f docker-compose.ports.yml up -d postgres
> ```

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
