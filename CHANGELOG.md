# Changelog for v1.5

See the [upgrade guides](https://gist.github.com/chrismccord/e53e79ef8b34adf5d8122a47db44d22f) to bring your Phoenix 1.4.x apps up to speed

## Phoenix.PubSub 2.0 released

Phoenix.PubSub 2.0 has been released with a more flexible and powerful fastlane mechanism. We use this opportunity to also move Phoenix.PubSub out of the endpoint and explicitly into your supervision tree. To update, you will need to remove or update the `{:phoenix_pubsub, "~> 1.x"}` entry in your `mix.exs` to at least `2.0`.

Then once you start an application, you will get a warning about the `:pubsub` key in your endpoint being deprecated. Follow the steps in the warning and you are good to go!

## Guides revamped

Phoenix built-in guides have been restructured and revamped, providing a better navigation structure and more content.

### 1.5.9 (2021-05-10)

### JavaScript client
  * Bind to `beforeunload` instead of `unload` to solve Firefox connection issues

### 1.5.8 (2021-02-23)

### Enhancements
  * [Endpoint] - Add `:log_access_url` config to endpoint start
  * [Router] - Include route information in router_dispatch exception for telemetry events
  * [Router] - Optimize router code generation to reduce compilation dependencies
  * [phx.new] - Use topbar in new apps with the --live flag

### JavaScript client
  * Default channel `push` payload to empty object for backwards compatibility

### 1.5.7 (2020-11-20)

### Enhancements
  * [Channel] - Add binary serialization support to default serializers

### JavaScript client
  * Add binary serialization support to default serializers for ability to push `ArrayBuffer` objects as binary WebSocket frames

### 1.5.6 (2020-10-12)

### Enhancements
  * [phx.new] Add --install and --no-install options to phx.new

### Bug fixes
  * [phx.new] Update `phoenix_live_dashboard` requirement to fix version conflicts

### 1.5.5 (2020-09-21)

### Enhancements
  * [Phoenix.Logger] Add :conn to `[:phoenix, :router_dispatch, :exception]` events
  * [Phoenix.Endpoint] Use regex to detect invalid hosts for IPv6 configurations
  * [Phoenix.Controller] Don't create compile-time references when using `action_fallback` to speed up compilation
  * [Phoenix.Endpoint] Expose `:connect_info` `:trace_context_headers` in websockets and long polling

### 1.5.4 (2020-07-21)

### Enhancements
  * [Phoenix.Endpoint] Include `:conn` in `[:phoenix, :error_rendered]` event
  * [Phoenix.Endpoint] Warn if the `url.host` provided for the endpoint is invalid
  * [Phoenix.Router] Log when router plugs halt
  * Fix warnings on Elixir v1.11

### Bug fixes
  * [Phoenix.Router] Rename the `[:phoenix, :router_dispatch, :exception]` metadata from `:error` to `:reason` to match the documentation and the telemetry specification (`:error` is still emitted for compatibility but it will be fully removed on v1.6)

## 1.5.3 (2020-05-21)

### Bug fixes
  * [phx.new] - Fix incompatible LiveView version for newly generated projects

## 1.5.2 (2020-05-21)

### Enhancements
  * [Channel] Import `assigns: 2` on channels
  * [Endpoint] Track latest static in `config(:cache_static_manifest_latest)`
  * [Endpoint] Allow `:user_agent` on `connect_info`

### Bug fixes
  * [Endpoint] Undeprecate `subscribe` and `unsubscribe` in the endpoint

## 1.5.1 (2020-04-23)

### Bug Fixes
  * [Endpoint] Ignore the root layout on error pages unless explicitly set

## 1.5.0 (2020-04-22)

### Enhancements

  * [Channel] Do not block the channel supervisor on join
  * [ConnTest] Add `init_test_session` to Phoenix.ConnTest
  * [Controller] Support `:disposition` option in `send_download/3`
  * [Endpoint] Automatically perform connection draining when shutting down the VM
  * [Endpoint] Allow named params to be used when defining socket paths
  * [Endpoint] Raise if `force_ssl` has changed from compile time to runtime
  * [Generator] Add `mix phx.gen.live` for LiveView CRUD generation
  * [PubSub] Migrate to PubSub 2.0 with a more flexible fastlaning mechanism
  * [View] Add `render_layout` which makes it easy to work with nested layouts
  * [View] Raise if `assigns` argument to functions `render/3`, `render_existing/3`, `render_many/4`, `render_one/4`, `render_layout/4`, `render_to_iodata/3`, `render_to_string/4` is a struct
  * [Transport] Transports can now optionally implement `handle_control/2` for handling control frames such as `:ping` and `:pong`

### Deprecations

  * [ChannelTest] `use Phoenix.ChannelTest` is deprecated in favor of `import Phoenix.ChannelTest`
  * [ConnTest] `use Phoenix.ConnTest` is deprecated in favor of `import Plug.Conn; import Phoenix.ConnTest`
  * [Endpoint] The outdated `Phoenix.Endpoint.CowboyAdapter` for Cowboy 1 is deprecated. Please make sure `{:plug_cowboy, "~> 2.1"}` or later is listed in your `mix.exs`.
  * [Endpoint] `Phoenix.Endpoint.instrument/4` is deprecated and has no effect. Use `:telemetry` instead. See `Phoenix.Logger` for more information.
  * [Endpoint] The `:pubsub` key for endpoint is deprecated. Once you start your app, you will see step-by-step instructions on how to use the new PubSub config.
  * [Layout] Use `<%= @inner_content %>` instead of `<%= render @view_module, @view_template, assigns %>` for rendering the child layout

### phx.new installer

  * Built-in support for MSSQL databases via [`Ecto.Adapters.Tds`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.Tds.html)
  * `Phoenix.PubSub` is now started directly in your application supervision tree
  * `Phoenix.Ecto.CheckRepoStatus` is now added to new applications that use Ecto
  * Automatically use `System.get_env("MIX_TEST_PARTITION")` in the database name in the test environment for built-in CI test partitioning
  * Generate a `MyApp.Telemetry` module with examples of Telemetry Metrics you may want to track in your app
  * Support the `--live` flag for generating apps with out-of-the-box LiveView support
  * Include SCSS support by default when using webpack

### JavaScript client

  * Ensure all channel event listeners are called
  * Fix rejoining channels after explicit disconnect following be immediate reconnect
  * Prevent duplicate join race conditions by immediately leaving duplicate channel on client

## v1.4

The CHANGELOG for v1.4 releases can be found [in the v1.4 branch](https://github.com/phoenixframework/phoenix/blob/v1.4/CHANGELOG.md).
