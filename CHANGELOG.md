# Changelog for v1.6

Phoenix v1.6 requires Elixir v1.9+.

## 1.6.0-dev

### Enhancements

  * [Endpoint] Allow custom error response from socket handler
  * [Endpoint] Do not require a pubsub server in the socket (only inside channels)
  * [mix phx.new] Add description to Ecto telemetry metrics
  * [mix phx.new] Use `Ecto.Adapters.SQL.Sandbox.start_owner!/2` in generators - this approach provides proper shutdown semantics for apps using LiveView and Presence

### Bug fixes

  * [mix phx.gen.live] Fix a bug where tests with `utc_datetime` fields did not pass out of the box

### Deprecations

  * [Endpoint] Phoenix now requires Cowboy v2.7+
  * [View] `@view_module` is deprecated in favor of `Phoenix.Controller.view_module/1` and `@view_template` is deprecated in favor of `Phoenix.Controller.view_template/1`

## v1.5

The CHANGELOG for v1.5 releases can be found [in the v1.5 branch](https://github.com/phoenixframework/phoenix/blob/v1.5/CHANGELOG.md).
