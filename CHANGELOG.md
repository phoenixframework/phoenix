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

## phx.new revamp

The `phx.new` application generator has been improved to rely on function components for
both Controller and LiveView rendering, ultimately simplifying the rendering stack of
Phoenix applications and providing better reuse.

New applications come with a collection of well-documented and accessible core components,
styled with Tailwind CSS by default. You can opt-out of Tailwind CSS with the `--no-tailwind`
flag (the Tailwind CSS classes are kept in the generated components as reference for
future styling).

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
