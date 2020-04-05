# Changelog for v1.5

## Phoenix.PubSub 2.0 released

Phoenix.PubSub 2.0 has been released with a more flexible and powerful fastlane mechanism. We use this opportunity to also move Phoenix.PubSub out of the endpoint and explicitly into your supervision tree. To update, you will need to remove or update the `{:phoenix_pubsub, "~> 1.x"}` entry in your `mix.exs` to at least "2.0".

Then once you start an application, you will get a warning about the `:pubsub` key in your endpoint being deprecated. Follow the steps in the warning and you are good to go!

## Guides revamped

Phoenix built-in guides have been restructured and revamped, providing a better navigation structure and more content.

## 1.5.0-dev

### Enhancements

  * [Channel] Do not block the channel supervisor on join
  * [ConnTest] Add `init_test_session` to Phoenix.ConnTest
  * [Controller] Support `:disposition` option in `send_download/3`
  * [Endpoint] Allow named params to be used when defining socket paths
  * [Endpoint] Raise if `force_ssl` has changed from compile time to runtime
  * [Generator] Add `mix phx.gen.live`
  * [PubSub] Migrate to PubSub 2.0 with a more flexible fastlaning mechanism
  * [View] Add `render_layout` which makes it easy to work with nested layouts

### Deprecations

  * [ChannelTest] `use Phoenix.ChannelTest` is deprecated in favor of `import Phoenix.ChannelTest`
  * [ConnTest] `use Phoenix.ConnTest` is deprecated in favor of `import Plug.Conn; import Phoenix.ConnTest`
  * [Endpoint] The outdated `Phoenix.Endpoint.CowboyAdapter` for Cowboy 1 is deprecated. Please make sure `{:plug_cowboy, "~> 2.1"}` or later is listed in your `mix.exs`
  * [Endpoint] `subscribe` and `unsubscribe` via the endpoint is deprecated, please use `Phoenix.PubSub` directly instead
  * [Layout] Use `<%= @inner_content %>` instead of `<%= render @view_module, @view_template, assigns %>` for rendering the child layout

### phx.new installer

  * Built-in support for MSSQL databases via the `tds` adapter
  * `Phoenix.PubSub` is now started directly in your application supervision tree
  * `Phoenix.Ecto.CheckRepoStatus` is now added to new applications that use Ecto
  * Automatically use `System.get_env("MIX_TEST_PARTITION")` in the database name in the test environemnt for built-in CI test partitioning
  * Generate a `MyApp.Telemetry` module with examples of Telemetry Metrics you may want to track in your app
  * Support the `--live` flag for generating apps with out-of-the-box LiveView support

### JavaScript client

  * Ensure all channel event listeners are called

## v1.4

The CHANGELOG for v1.4 releases can be found [in the v1.4 branch](https://github.com/phoenixframework/phoenix/blob/v1.4/CHANGELOG.md).
