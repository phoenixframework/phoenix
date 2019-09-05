# Changelog for v1.4

See the [upgrade guides](https://gist.github.com/chrismccord/bb1f8b136f5a9e4abc0bfc07b832257e) to bring your Phoenix 1.3.x apps up to speed, including instructions on upgrading to Cowboy 2 for HTTP support.

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

## 1.4.10 (2019-09-05)

### Enhancements
  * [Socket] support assigning multiple key/value pairs with keyword list or map with `assign/2`.

### Bug Fixes
  * [Endpoint] Fix match error in failed websocket handshake


## JavaScript client enhancements
  * support `vsn` option for customizing serializer protocol version


## 1.4.9 (2019-07-03)

### Enhancements
  * [local.phx] Use hex for fetching the latest `phx_new` package
  * [phx.new] Use Ecto v3.1 and MyXQL for new apps

### Bug Fixes
  * [Endpoint] Fix bug causing headers to be dropped for cowboy adapters on WebSocket upgrade
  * [ConnTest] Fix issue causing loss of connection information when using `bypass_through`

## 1.4.8 (2019-06-12)

### JavaScript client bug fixes
  * Fix npm package build

## 1.4.7 (2019-06-11)

### Enhancements
  * [Router] Add `route_info` for compile and runtime metadata for a given request verb, path, and host
  * [Endpoint|Router|Controller|Channel] Add `:telemetry` integration with dispatched telemetry events

### Bug Fixes
  * [Router] Fix compile error for scope's with named parameters when using `forward` route definitions

## 1.4.6 (2019-05-13)

### Bug Fixes
  * [phx.new] Fix `errors_on` lookup in generated `DataCase` module using `Map.get` instead of `Keyword.get`

## 1.4.5 (2019-05-08)

### Bug Fixes
  * [Controller] Fix `current_url` error caused by bad function dispatch
  * [phx.new] Use proper path for watcher in umbrella
  * [Digester] Fix invalid SRI hash generation

### Enhancements
  * [phx.new] Generate new `errors_on` function in `DataCase` module capable of handling array types

## 1.4.4 (2019-04-30)

### Enhancements
  * [Channel] Support `handle_call` and `handle_cast` proxying for channel servers
  * [Router] Raise error when route name uses `static` in the prefix
  * [Router] Add `Routes.static_integrity/1` for subresource integrity validation

### Bug Fixes
  * [phx.gen.*] prohibit context creation with the same name as the application

### JavaScript client bug fixes
  * Fix bug causing error on window unload when no connection is established
  * Fix reconnect retry after explicit disconnect
  * Fix `globalWindow` conflict with React Native applications

## 1.4.3 (2019-03-29)

### JavaScript client enhancements
  * add `binaryType` option to socket constructor, with `arraybuffer` default for binary messages
  * use more aggressive socket reconnect for faster connection recovery
  * rejoin channels as soon as socket reconnects for faster rejoins
  * decouple channel rejoin backoffs with new `rejoinAfterMs` option
  * optimize reconnects when browser restores from back/forward cache
    by listening for window beforeunload
  * Expose default `Serializer` for public use

### JavaScript client bug fixes
  * fix bug causing socket to never reconnect when hearbeats timeouts
    are encountered on the client, often experienced with backgrounded
    browser tabs

## 1.4.2 (2019-03-13)

### Enhancements
  * [Router] add `scoped_alias` to return the full alias with the current scope's aliased prefix
  * [Router] add `alias: false` option to router definitions to to disable scope prefix on case by case basis
  * [Router] Support any struct with :endpoint key in path/url helpers
  * [Channel] Optimize channel join through non-blocking callback init
  * [Endpoint] Log Web access URLs for HTTP and HTTPS configurations
  * [phx.routes] Show socket paths for websocket and longpoll transports
  * [phx.new] Add `--verbose` flag for verbose installer output
  * [phx.gen.schema] Allow the app configuration to specify a custom migration module for the generated migration code

### Bug Fixes
  * [phx.gen.json] Fix invalid map fields for generated json tests
  * [phx.gen.html|json|context|schema] prohibit context or schema creation with the same name as the application causing incorrect aliases to be generated

## 1.4.1 (2019-02-12)

### Enhancements
  * Optimize router helper generation for faster compilation
  * Drop special convention for context locations

### Bug Fixes
  * Add missing `:jason` to generated umbrella application

### JavaScript client bug fixes
  * Fix reconnect regression experienced with spotty connections

## 1.4.0 (2018-11-07)

### Enhancements
  * [phx.new] Update Ecto deps with the release of Ecto 3.0 including `phoenix_ecto` 4.0
  * [phx.new] Import Ecto's `.formatter.exs` in new projects 
  * [phx.new] Use Ecto 3.0RC, with `ecto_sql` in new project deps
  * [phx.new] Use Plug 1.7 with new `:plug_cowboy` dependency for cowboy adapter
  * [phx.gen.html|json|schema|context] Support new Ecto 3.0 usec datetime types
  * [Phoenix] Add `Phoenix.json_library/0` and replace `Poison` with `Jason` for JSON encoding in new projects
  * [Endpoint] Add `Cowboy2Adapter` for HTTP2 support with cowboy2
  * [Endpoint] The `socket/3` macro now accepts direct configuration about websockets and longpoll
  * [Endpoint] Support MFA function in `:check_origin` config for custom origin checking
  * [Endpoint] Add new `:phoenix_error_render` instrumentation callback
  * [Endpoint] Log the configured url instead of raw IP when booting endpoint webserver
  * [Endpoint] Allow custom keyword pairs to be passed to the socket `:connect_info` options.
  * [Router] Display list of available routes on debugger 404 error page
  * [Router] Raise on duplicate plugs in `pipe_through` scopes
  * [Controller] Support partial file downloads with `:offset` and `:length` options to `send_download/3`
  * [Controller] Add additional security headers to `put_secure_browser_headers` (`x-content-type-options`, `x-download-options`, and `x-permitted-cross-domain-policies`)
  * [Controller] Add `put_router_url/2` to override the default URL generation pulled from endpoint configuration
  * [Logger] Add whitelist support to `filter_parameters` logger configuration, via new `:keep` tuple format
  * [Socket] Add new `phoenix_socket_connect` instrumentation
  * [Socket] Improve error message when missing socket mount in endpoint
  * [Logger] Log calls to user socket connect
  * [Presence] Add `Presence.get_by_key` to fetch presences for specific user
  * [CodeReloader] Add `:reloadable_apps` endpoint configuration option to allow recompiling local dependencies
  * [ChannelTest] Respect user's configured ExUnit `:assert_receive_timeout` for macro assertions


### Bug Fixes
  * Add missing `.formatter.exs` to Hex package for proper elixir formatter integration
  * [phx.gen.cert] Fix usage inside umbrella applications
  * [phx.new] Revert `Routes.static_url` in app layout in favor of original `Routes.static_path`
  * [phx.new] Use `phoenix_live_reload` 1.2 to fix Hex version errors
  * [phx.gen.json|html] Fix generator tests incorrectly encoding datetimes
  * [phx.gen.cert] Fix generation of cert inside umbrella projects
  * [Channel] Fix issue with WebSocket transport sending wrong ContentLength header with 403 response
  * [Router] Fix forward aliases failing to expand within scope block
  * [Router] Fix regression in router compilation failing to escape plug options

### phx.new installer
  * Generate new Elixir 1.5+ child spec (therefore new apps require Elixir v1.5)
  * Use webpack for asset bundling

### Deprecations
  * Elixir 1.3 is no longer supported, Elixir 1.4+ is required
  * [Controller] Passing a view in `render/3` and `render/4` is deprecated in favor of `put_view/2`
  * [Endpoint] The `:handler` option in the endpoint is deprecated in favor of `:adapter`
  * [Socket] `transport/3` is deprecated. The transport is now specified in the endpoint
  * [Transport] The transport system has seen an overhaul and been drastically simplified. The previous mechanism for building transports is still supported but it is deprecated. Please see `Phoenix.Socket.Transport` for more information

### JavaScript client
  * Add new instance-based Presence API with simplified synchronization callbacks
  * Accept a function for socket and channel `params` for dynamic parameter generation when connecting and joining
  * Fix race condition when presence diff arrives before state
  * Immediately rejoin channels on socket reconnect for faster recovery after reconnection
  * Fix reconnect caused by pending heartbeat

## v1.3

The CHANGELOG for v1.3 releases can be found [in the v1.3 branch](https://github.com/phoenixframework/phoenix/blob/v1.3/CHANGELOG.md).
