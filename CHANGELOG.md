# Changelog for v1.6

Phoenix v1.6 requires Elixir v1.9+.

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
  * [View] `@view_module` is deprecated in favor of `Phoenix.Controller.view_module/1` and `@view_template` is deprecated in favor of `Phoenix.Controller.view_template/1`

## v1.5

The CHANGELOG for v1.5 releases can be found in the [v1.5 branch](https://github.com/phoenixframework/phoenix/blob/v1.5/CHANGELOG.md).
