# Changelog for v1.6

See the [upgrade guide](https://gist.github.com/chrismccord/2ab350f154235ad4a4d0f4de6decba7b) to upgrade from Phoenix 1.5.x.

Phoenix v1.6 requires Elixir v1.9+.

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

### Bug Fixes
  * Fix LiveView upload testing errors caused by `Phoenix.ChannelTest`

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
