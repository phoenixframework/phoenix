# Changelog for v1.7

See the [upgrade guide](https://gist.github.com/chrismccord/00a6ea2a96bc57df0cce526bd20af8a7) to upgrade from Phoenix 1.6.x.

Phoenix v1.7 requires Elixir v1.11+ & Erlang v22.1+.

## Introduction of Verified Routes

Phoenix 1.7 includes a new `Phoenix.VerifiedRoutes` feature which provides `~p`
for route generation with compile-time verification.

Use of the `sigil_p` macro allows paths and URLs throughout your
application to be compile-time verified against your Phoenix router(s).
For example the following path and URL usages:

    <.link href={~p"/sessions/new"} method="post">Log in</.link>

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

## phx.new revamp

The `phx.new` application generator has been improved to rely on function components for
both Controller and LiveView rendering, ultimately simplifying the rendering stack of
Phoenix applications and providing better reuse.

New applications come with a collection of well-documented and accessible core components,
styled with Tailwind CSS by default. You can opt-out of Tailwind CSS with the `--no-tailwind`
flag (the Tailwind CSS classes are kept in the generated components as reference for
future styling).

## 1.7.21 (2025-03-27)

### Bug fixes
  * Fix socket sometimes not reconnecting after pagehide/pageshow ([#6103](https://github.com/phoenixframework/phoenix/issues/6103))
  * Check if priv folder exists before re-linking in CodeReloader ([#6124](https://github.com/phoenixframework/phoenix/pull/6124))

### Enhancements
  * Relax LiveView dependency for new projects

## 1.7.20 (2025-02-20)

### Enhancements
  * Add `[:phoenix, :socket_drain]` telemetry event to track socket draining and use it for logging
  * Address Elixir 1.18 warnings in phx.new
  * Add `PHX_NEW_CACHE_DIR` env var for cached `phx.new` builds

### Bug fixes
  * Fix code reloader error when `mix.lock` is touched without its content changing

## 1.7.19 (2025-01-31)

### Enhancements
  * [phx.new] - bind to `0.0.0.0` in `dev.exs` if phx.new is being run inside a docker container.
    This exposes the container's phoenix server to the host so that it is accessible over port forwarding.

## 1.7.18 (2024-12-10)

### Enhancements
  * Use new interpolation syntax in generators
  * Update gettext in generators to 0.26

## 1.7.17 (2024-12-03)

### Enhancements
  * Use LiveView 1.0.0 for newly generated applications

## 1.7.16 (2024-12-03)

### Bug fixes
  * Fix required Elixir version in mix.exs

## 1.7.15 (2024-12-02)

### Enhancements
  * Support phoenixframework.org installer

## 1.7.14 (2024-06-18)

### Bug fixes
  * Revert "Add `follow_redirect/2` to Phoenix.ConnTest" (#5797) as this conflicts with `follow_redirect/2` in LiveView, which is imported with ConnTest by default

## 1.7.13 (2024-06-18)

### Bug fixes
  * Fix Elixir 1.17 warning in Cowboy2Adapter
  * Fix verified routes emitting diagnostics without file and position

### JavaScript Client Bug Fixes
  * Fix error when `sessionStorage` is not available on global namespace

### Enhancements
  * Add `follow_redirect/2` to Phoenix.ConnTest
  * Use LiveView 1.0.0-rc for newly generated applications
  * Use new `Phoenix.Component.used_input?` for form errors in generated `core_components.ex`
  * Allow `mix ecto.setup` from the umbrella root
  * Bump Endpoint static cache manifest on `config_change` callback

## 1.7.12 (2024-04-11)

### JavaScript Client Bug Fixes
  * Fix all unjoined channels from being removed from the socket when channel leave is called on any single unjoined channel instance

### Enhancements
  * [phx.gen.auth] Add enhanced session fixation protection.
    For applications whichs previously used `phx.gen.auth`, the following line can be added to the `renew_session` function in the auth module:

    ```diff
      defp renew_session(conn) do
    +   delete_csrf_token()

        conn
        |> configure_session(renew: true)
        |> clear_session()
    ```

    *Note*: because the session id is in a http-only cookie by default, the only way to perform this attack prior to this change is if your application was already vulnerable to an XSS attack, which itself grants more escalated "privileges” than the CSRF fixation.

### JavaScript Client Enhancements
  * Only memorize longpoll fallback for browser session if WebSocket never had a successful connection

## 1.7.11 (2024-02-01)

### Enhancements
  * [phx.new] Default to the [Bandit webserver](https://github.com/mtrudel/bandit) for newly generated applications
  * [phx.new] Enable longpoll transport by default and auto fallback when websocket fails for newly generated applications

### JavaScript Client Enhancements
  * Support new `longPollFallbackMs` option to auto fallback when websocket fails to connect
  * Support new `debug` option to enable verbose logging

### Deprecations
  * Deprecate the `c:init/2` callback in endpoints in favor of `config/runtime.exs` or in favor of `{Phoenix.Endpoint, options}`

## 1.7.10 (2023-11-03)

### Bug fixes
  * [phx.new] Fix `CoreComponents.flash` generating incorrect id's causing flash messages to fail to be closed when clicked

### Enhancements
  * [Phoenix.Endpoint] Support dynamic port for `Endpoint.url/0`

## 1.7.9 (2023-10-11)

### Bug fixes
  * [Phoenix.CodeReloader] - Fix error in code reloader causing compilation errors
  * [phx.new] – fix LiveView debug heex configuration being generated when `--no-html` pas passed

## 1.7.8 (2023-10-09)

### Bug fixes
  * [Phoenix.ChannelTest] Stringify lists when pushing data
  * [Phoenix.Controller] Fix filename when sending downloads with non-ascii names
  * [Phoenix.CodeReloader] Remove duplicate warnings on recent Elixir versions
  * [Phoenix.CodeReloader] Do not crash code reloader if file information is missing from diagnostic
  * [Phoenix.Logger] Do not crash when status is atom
  * [phx.gen.release] Fix `mix phx.gen.release --docker` failing with `:http_util` error on Elixir v1.15
  * [phx.gen.*] Skip map inputs in generated forms as there is no trivial matching input
  * [phx.new] Fix tailwind/esbuild config and paths in umbrella projects
  * [phx.new] Do not render `th` for actions if actions are empty

### Enhancements
  * [Phoenix] Allow latest `plug_crypto`
  * [Phoenix.Endpoint] Support dynamic socket drainer configuration
  * [Phoenix.Logger] Change socket serializer/version logs to warning
  * [Phoenix.VerifiedRoutes] Add support for static resources with fragments in `~p`
  * [phx.gen.schema] Support `--repo` and `--migration-dir` flags
  * [phx.new] Allow `<.input type="checkbox">` without `value` attr in core components
  * [phx.new] Allow UTC datetimes in the generators
  * [phx.new] Automatically migrate when release starts when using sqlite 3
  * [phx.new] Allow ID to be assigned in flash component
  * [phx.new] Add `--adapter` flag for generating application with bandit
  * [phx.new] Include DNSCluster for simple clustering
  * [phx.routes] Support `--method` option

## 1.7.7 (2023-07-10)

### Enhancements
  * Support incoming binary payloads to channels over longpoll transport

## 1.7.6 (2023-06-16)

### Bug Fixes
  * Support websock_adapter 0.5.3

### Enhancements
  *  Allow using Phoenix.ChannelTest socket/connect in another process

## 1.7.5 (2023-06-15)

### Bug Fixes
  * Fix LongPoll error when draining connections

## 1.7.4 (2023-06-15)

### Bug Fixes
  * Fix the WebSocket draining sending incorrect close code when draining causing LiveViews to reload the page instead of reconnecting

## 1.7.3 (2023-05-30)

### Enhancements
  * Use LiveView 0.19 for new apps

### Bug Fixes
  * Fix compilation error page on plug debugger showing obscure error when app fails to compile
  * Fix warnings being printed twice in route verification

## 1.7.2 (2023-03-20)

### Enhancements
  * [Endpoint] Add socket draining for batched and orchestrated Channel/LiveView socket shutdown
  * [code reloader] Improve the compilation error page to remove horizontal scrolling and include all warnings and errors from compilation
  * [phx.new] Support the `--no-tailwind` and `--no-esbuild` flags
  * [phx.new] Move heroicons to assets/vendor
  * [phx.new] Simplify core modal to use the new JS.exec instruction to reduce footprint
  * [sockets] Allow custom csrf_token_keys in WebSockets

## 1.7.1 (2023-03-02)

### Enhancements
  * [phx.new] Embed heroicons in app.css bundle to optimize usage

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

## v1.6

The CHANGELOG for v1.6 releases can be found in the [v1.6 branch](https://github.com/phoenixframework/phoenix/blob/v1.6/CHANGELOG.md).
