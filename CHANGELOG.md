# Changelog for v1.4

## Cowboy 2 support

TODO: Write about how to use Cowboy 2

## The Socket <-> Transport contract

We have used the opportunity of writing the new Cowboy 2 adapter to do an overhaul in how `Phoenix.Socket` interacts with transports. The result is a new API that makes it very easy to implement new transports and also allows developers to provide custom socket implementations without ceremony. For example, if you would like to have direct control of the socket and bypass the channel implementation completely, it is now very straight-forward to do so. See the `Phoenix.Socket.Transport` behaviour for more information.

This overhaul means that the `transport/3` macro in `Phoenix.Socket` is deprecated. Instead of defining transports in your socket.ex file:

    transport :websocket, Phoenix.Transport.Websocket,
      key1: value1, key2: value2, key3: value3

    transport :longpoll, Phoenix.Transport.LongPoll,
      key1: value1, key2: value2, key3: value3

Configurations must be applied directly in your endpoint file via the `Phoenix.Endpoint.socket/3` macro:

    socket "/socket", MyApp.UserSocket,
      websocket: [key1: value1, key2: value2, key3: value3],
      longpoll: [key1: value1, key2: value2, key3: value3]

Note the websocket/longpoll configuration given to socket/3 will only apply after you remove all `transport/3` calls from your socket definition. If you have explicitly upgraded to Cowboy 2, any transport defined with the `transport/3` macro will be ignored.

The old APIs for building transports are also deprecated. The good news is: adapting an existing transport to the new API is a less error prone process where you should mostly remove code.

## 1.4.0-dev

### Enhancements

  * [ChannelTest] Respect user's configured ExUnit `:assert_receive_timeout` for macro assertions
  * [Controller] Support partial file downloads with `:offset` and `:length` options to `send_download/3`
  * [Controller] Add additional security headers to `put_secure_browser_headers` (`x-content-type-options`, `x-download-options`, and `x-permitted-cross-domain-policies`)
  * [Controller] Add `put_router_url/2` to override the default URL generation pulled from endpoint configuration
  * [Endpoint] Add `Cowboy2Adapter` for HTTP2 support with cowboy2
  * [Endpoint] The `socket/3` macro now accepts direct configuration about websockets and longpoll
  * [Endpoint] Support MFA function in `:check_origin` config for custom origin checking
  * [Endpoint] Add new `:phoenix_error_render` instrumentation callback
  * [Logger] Add whitelist support to `filter_parameters` logger configuration, via new `:keep` tuple format
  * [Phoenix] Add `Phoenix.json_library/0` and replace `Poison` with `Jason` for JSON encoding in new projects
  * [Router] Display list of available routes on debugger 404 error page
  * [Router] Raise on duplicate plugs in `pipe_through` scopes
  * [Presence] Add `Presence.get_by_key` to fetch presences for specific user

### Bug Fixes

  * [Channel] Fix issue with WebSocket transport sending wrong ContentLength header with 403 response
  * [Router] Fix forward aliases failing to expand within scope block

### Deprecations

  * [Controller] Passing a view in `render/3` and `render/4` is deprecated in favor of `put_view/2`
  * [Endpoint] The `:handler` option in the endpoint is deprecated in favor of `:adapter`
  * [Socket] `transport/3` is deprecated. The transport is now specified in the endpoint
  * [Transport] The transport system has seen an overhaul and been drastically simplified. The previous mechanism for building transports is still supported but it is deprecated. Please see `Phoenix.Socket.Transport` for more information

### phx.new installer

  * Generate new Elixir 1.5+ child spec (therefore new apps require Elixir v1.5)
  * Use webpack for asset bundling

### JavaScript client

  * Add new instance-based Presence API with simplified synchronization callbacks
  * Accept a function for socket and channel `params` for dynamic parameter generation when connecting and joining
  * Fix race condition when presence diff arrives before state

## v1.3

The CHANGELOG for v1.3 releases can be found [in the v1.3 branch](https://github.com/phoenixframework/phoenix/blob/v1.3/CHANGELOG.md).
