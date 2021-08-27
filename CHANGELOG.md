# Changelog for v1.6

Phoenix v1.6 requires Elixir v1.9+.

## 1.6.0-rc.0 (2021-08-26)

### Enhancements

  * [Controller] Do not create compile-time dependency for `action_fallback`
  * [Endpoint] Allow custom error response from socket handler
  * [Endpoint] Do not require a pubsub server in the socket (only inside channels)
  * [mix phx.gen.auth] Add `mix phx.gen.auth` generator
  * [mix phx.gen.context] Support `enum` types and the `redact` option when declaring fields
  * [mix phx.new] Update `mix phx.new` to require Elixir v1.11 and use the new `config/runtime.exs`
  * [mix phx.new] Add description to Ecto telemetry metrics
  * [mix phx.new] Use `Ecto.Adapters.SQL.Sandbox.start_owner!/2` in generators - this approach provides proper shutdown semantics for apps using LiveView and Presence
  * [mix phx.new] Add `--install` and `--no-install` options to `phx.new`
  * [mix phx.new] Add `--database sqlite3` option to `phx.new`
  * [View] Extracted `Phoenix.View` into its own project to facilitate reuse
  * [mix phx.new] Remove usage of Sass

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

  * [Endpoint] Phoenix now requires Cowboy v2.7+
  * [View] `@view_module` is deprecated in favor of `Phoenix.Controller.view_module/1` and `@view_template` is deprecated in favor of `Phoenix.Controller.view_template/1`

## v1.5

The CHANGELOG for v1.5 releases can be found in the [v1.5 branch](https://github.com/phoenixframework/phoenix/blob/v1.5/CHANGELOG.md).
