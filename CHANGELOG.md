# Changelog for v1.7

See the [upgrade guide](https://gist.github.com/chrismccord/00a6ea2a96bc57df0cce526bd20af8a7) to upgrade from Phoenix 1.6.x.

Phoenix v1.7 requires Elixir v1.11+.

## Introduction of Verified Routes

Phoenix 1.7 includes a new `Phoenix.VerifiedRoutes` feature which provides `~p`
for route generation with compile-time verification.

Use of the `sigil_p` macro allows paths and URLs throughout your
application to be compile-time verified against your Phoenix router(s).
For example the following path and URL usages:

    <.link href={~p"/sessions/new"} method="post">Sign in</.link>

    redirect(to: url(~p"/posts/#{post}"))

Will be verified against your standard `Phoenix.Router` definitions:

    get "/posts/:post_id", PostController, :show
    post "/sessions/new", SessionController, :create

Unmatched routes will issue compiler warnings:

    warning: no route path for AppWeb.Router matches "/postz/#{post}"
      lib/app_web/controllers/post_controller.ex:100: AppWeb.PostController.show/2

*Note: Elixir v1.14+ is required for comprehensive warnings. Older versions
will work properly and warn on new compilations, but changes to the router file
will not issue new warnings.*

This feature replaces the `Helpers` module generated in your Phoenix router, but helpers
will continue to work and be generated. You can disable router helpers by passing the
`helpers: false` option to `use Phoenix.Router`.

## 1.7.0 (2023-02-24)

### Bug Fixes
  * Fix race conditions in the longpoll transport by batching messages

## 1.7.0-rc.3 (2023-02-15)

### Enhancements
  * Use stream based collections for `phx.gen.live` generators
  * Update `phx.gen.live` generators to use `Phoenix.Component.to_form`

## 1.7.0-rc.2 (2023-01-13)

### Bug Fixes
  * [Router] Fix routing bug causing incorrect matching order on similar routes
  * [phx.new] Fix installation hanging in some cases

## 1.7.0-rc.1 (2023-01-06)

### Enhancements
  * Raise if using verified routes outside of functions
  * Add tailwind.install/esbuild.install to mix setup

### Bug Fixes
  * [Presence] fix task shutdown match causing occasional presence errors
  * [VerifiedRoutes] Fix expansion causing more compile-time deps than necessary
  * [phx.gen.auth] Add password inputs to password reset edit form
  * [phx.gen.embedded] Fixes missing :references generation to phx.gen.embedded
  * Fix textarea rendering in core components
  * Halt all sockets on intercept to fix longpoll response already sent error

## 1.7.0-rc.0 (2022-11-07)

### Deprecations
  * `Phoenix.Controller.get_flash` has been deprecated in favor of the new `Phoenix.Flash` module, which provides unified flash access

### Enhancements
  * [Router] Add `Phoenix.VerifiedRoutes` for `~p`-based route generation with compile-time verification.
  * [Router] Support `helpers: false` to `use Phoenix.Router` to disable helper generation
  * [Router] Add `--info [url]` switch to `phx.routes` to get route information about a url/path
  * [Flash] Add `Phoenix.Flash` for unfied flash access

### JavaScript Client Bug Fixes
  * Fix heartbeat being sent after disconnect and causing abnormal disconnects

# Changelog for v1.6

See the [upgrade guide](https://gist.github.com/chrismccord/2ab350f154235ad4a4d0f4de6decba7b) to upgrade from Phoenix 1.5.x.

Phoenix v1.6 requires Elixir v1.9+.

## 1.6.15 (2022-10-26)

### Enhancements
  * Support for Phoenix.View 2.0

### JavaScript Client Bug Fixes
  * Fix heartbeat reconnect

## 1.6.14 (2022-10-10)
  * Fix security vulnerability in wildcard `check_origin` configurations

## 1.6.13 (2022-09-29)

### Enhancements
  * [phx.gen.release] Fetch compatible docker image from API when passing `--docker` flag

## 1.6.12 (2022-09-06)

### Bug Fixes
  * Fix `phx.gen.release` Dockerfile pointing to expired image

## 1.6.11 (2022-07-11)

### JavaScript Client Enhancements
 * Add convenience for getting longpoll reference with  `getLongPollTransport`

### JavaScript Client Bug Fixes
  * Cancel inflight longpoll requests on canceled longpoll session
  * Do not attempt to flush socket buffer when tearing down socket on `replaceTransport`

## 1.6.10 (2022-06-01)

### JavaScript Client Enhancements
  * Add `ping` function to socket

## 1.6.9 (2022-05-16)

### Bug Fixes
  * [phx.gen.release] Fix generated .dockerignore comment

## 1.6.8 (2022-05-06)

### Bug Fixes
  * [phx.gen.release] Fix Ecto check failing to find Ecto in certain cases

## 1.6.7 (2022-04-14)

### Enhancements
  * [Endpoint] Add Endpoint init telemetry event
  * [Endpoint] Prioritize user :http configuration for ranch  to fix inet_backend failing to be respected
  * [Logger] Support log_module in router metadata
  * [phx.gen.release] Don't handle assets in Docker when directory doesn't exist
  * [phx.gen.release] Skip generating migration files when ecto_sql is not installed

### JavaScript Client Enhancements
  * Switch to .mjs files for ESM for better compatibility across build tools

### JavaScript Client Bug Fixes
  * Fix LongPoll callbacks in JS client causing errors on connection close

## 1.6.6 (2022-01-04)

### Bug Fixes
  * [Endpoint] Fix `check_origin: :conn` failing to match scheme

## 1.6.5 (2021-12-16)

### Enhancements
  * [Endpoint] Support `check_origin: :conn` to enforce origin on the connection's host, port, and scheme

## 1.6.4 (2021-12-08)

### Bug Fixes
  * Fix incorrect `phx.gen.release` output

## 1.6.3 (2021-12-07)

### Enhancements
  * Add new `phx.gen.release` task for release and docker based deployments
  * Add `fullsweep_after` option to the websocket transport
  * Add `:force_watchers` option to `Phoenix.Endpoint` for running watchers even when web server is not started

### Bug Fixes
  * Fix Endpoint `log: false` failing to disable logging

### JavaScript Client Bug Fixes
  * Do not attempt to reconnect automatically if client gracefully closes connection

## 1.6.2 (2021-10-08)

### Bug Fixes
  * [phx.new] Fix external flag to esbuild using incorrect syntax

## 1.6.1 (2021-10-08)

### Enhancements
  * [phx.new] Add external flag to esbuild for fonts and image path loading
  * [phx.gen.auth] No longer set `argon2` as the default hash algorithm for `phx.gen.auth` in favor of bcrypt for performance reasons on smaller hardware

### Bug Fixes
  * Fix race conditions logging debug duplicate channel joins when no duplicate existed

### JavaScript Client Bug Fixes
  * Export commonjs modules for backwards compatibility

## 1.6.0 (2021-09-24) 🚀

### Enhancements
  * [ConnTest] Add `path_params/2` for retrieving router path parameters out of dynamically returned URLs.

### JavaScript Client Bug Fixes
  * Fix LongPoll transport undefined readyState check

## 1.6.0-rc.1 (2021-09-22)

### Enhancements
  * [mix phx.gen.auth] Validate bcrypt passwords are no longer than 72 bytes
  * re-enable `phx.routes` task to support back to back invocations, such as for aliased mix route tasks
  * [mix phx.gen.html] Remove comma after `for={@changeset}` on `form.html.heex`

### JavaScript Client Bug Fixes
  * Fix messages for duplicate topic being dispatched to old channels

## 1.6.0-rc.0 (2021-08-26)

### Enhancements
  * [CodeReloader] Code reloading can now pick up changes to .beam files if they were compiled in a separate OS process than the Phoenix server
  * [Controller] Do not create compile-time dependency for `action_fallback`
  * [Endpoint] Allow custom error response from socket handler
  * [Endpoint] Do not require a pubsub server in the socket (only inside channels)
  * [mix phx.digest.clean] Add `--all` flag to `mix phx.digest.clean`
  * [mix phx.gen.auth] Add `mix phx.gen.auth` generator
  * [mix phx.gen.context] Support `enum` types and the `redact` option when declaring fields
  * [mix phx.gen.notifier] A new generator to build notifiers that by default deliver emails
  * [mix phx.new] Update `mix phx.new` to require Elixir v1.12 and use the new `config/runtime.exs`
  * [mix phx.new] Set `plug_init_mode: :runtime` in generated `config/test.exs`
  * [mix phx.new] Add description to Ecto telemetry metrics
  * [mix phx.new] Use `Ecto.Adapters.SQL.Sandbox.start_owner!/2` in generators - this approach provides proper shutdown semantics for apps using LiveView and Presence
  * [mix phx.new] Add `--install` and `--no-install` options to `phx.new`
  * [mix phx.new] Add `--database sqlite3` option to `phx.new`
  * [mix phx.new] Remove usage of Sass
  * [mix phx.new] New applications now depend on Swoosh to deliver emails
  * [mix phx.new] No longer generate a socket file by default, instead one can run `mix phx.gen.socket`
  * [mix phx.new] No longer generates a home page using LiveView, instead one can run `mix phx.gen.live`
  * [mix phx.new] LiveView is now included by default. Passing `--no-live` will comment out lines in `app.js` and `Endpoint`
  * [mix phx.server] Add `--open` flag
  * [Router] Do not add compile time deps in `pipe_through`
  * [View] Extracted `Phoenix.View` into its own project to facilitate reuse

### JavaScript Client Enhancements
  * Add new `replaceTransport` function to socket with extended `onError` API to allow simplified LongPoll fallback
  * Fire each event in a separate task for the LongPoll transport to fix ordering
  * Optimize presence syncing

### Bug fixes
  * [Controller] Return normalized paths in `current_path/1` and `current_path/2`
  * [mix phx.gen.live] Fix a bug where tests with `utc_datetime` and `boolean` fields did not pass out of the box

### JavaScript Client Bug fixes
  * Bind to `beforeunload` instead of `unload` to solve Firefox connection issues
  * Fix presence onJoin including current metadata in new presence

### Deprecations
  * [mix compile.phoenix] Adding the `:phoenix` compiler to your `mix.exs` (`compilers: [:phoenix] ++ Mix.compilers()`) is no longer required from Phoenix v1.6 forward if you are running on Elixir v1.11. Remove it from your `mix.exs` and you should gain faster compilation times too
  * [Endpoint] Phoenix now requires Cowboy v2.7+

### Breaking changes
  * [View] `@view_module` and `@view_template` are no longer set. Use `Phoenix.Controller.view_module/1` and `Phoenix.Controller.view_template/1` respectively, or pass explicit assigns from `Phoenix.View.render`.

## v1.5

The CHANGELOG for v1.5 releases can be found in the [v1.5 branch](https://github.com/phoenixframework/phoenix/blob/v1.5/CHANGELOG.md).
