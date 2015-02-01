# Changelog

## v0.9.0-dev

See these [`0.8.x` to `0.9.0` upgrade instructions](https://gist.github.com/chrismccord/def6f4dc444b6a8f8d8b) to bring your existing apps up to speed.

* Enhancements
  * [PubSub/Channels] The PubSub layer now supports Redis, and is opened up to other third party adapters. It still defaults to PG2, but other adapters are convenient for non-distributed deployments or durable messaging.

* Bug fixes
  * [Plug] Ensure session and flash are serializable to JSON

* Backwards incompatible changes
  * [PubSub] The new PubSub system requires the adapter's superviser to be added to your supervisione tree. Add `supervisor(Phoenix.PubSub.PG2, [MyApp.PubSub])` to your app supervistor.
  * [PubSub] The `Phoenix.PubSub` API now requires a registered server name, ie `Phoenix.PubSub.broadcast(MyApp.PubSub, "foo:bar", %{baz: :bang})`
  * [Channel] Channel broadcasts from outside a socket connection now must be called off the Channel module directly, ie: `MyApp.MyChannel.broadcast("topic", "event", %{...})`
  * [Channel] The error return signature has been changed from `{:error, socket, reason}` to {:error, reason, socket}`
  * [Plug] `Plug.CSRFProtection` now uses a cookie instead of session and expects a `"_csrf_token"` parameter instead of `"csrf_token"`
  * [Router] The `destroy` action has been renamed to `delete`, update your controller actions and url builders accordingly


## v0.8.0 (2015-01-11)

See these [`0.7.x` to `0.8.0` upgrade instructions](https://gist.github.com/chrismccord/9434b8fa208b3aae22b6) to bring your existing apps up to speed.

* Enhancements
  * [Router] `protect_from_forgery` has been added to the Router for CSRF protection. This is automatically plugged in new projects. See [this example](https://github.com/phoenixframework/phoenix/blob/ce5ebf3d9de4412a18e6325cd0d34e1b9699fb5a/priv/template/web/router.ex#L7) for plugging in your existing router pipeline(s)
  * [Router] New `socket` macro allows scoping channels to different transports and mounting multiple socket endpoints
  * [Channels] The "topic" abstraction has been refined to be a simple string identifier to provide more direct integration with the `Phoenix.PubSub` layer
  * [Channels] Channels can now intercept outgoing messages and customize the broadcast for a socket-by-socket customization, message dropping, etc
  * [Channels] A channel can be left by returning `{:leave, socket}` from a channel callback to unsubscribe from the channel
  * [Channels] Channel Serializer can now use binary protocol over websockets instead of just text
  * [Endpoint] Allow the reloadable paths to be configured in the endpoint
  * [Mix] Allow the code generation namespace to be configured with the `:app_namespace` option
  * [Mix] Allow `:reloadable_paths` in Endpoint configuration to reload directories other than `"web"` in development

* Bug Fixes
  * [Channel] Fix WebSocket heartbeat causing unnecessary `%Phoenix.Socket{}`'s to be tracked and leave errors on disconnect
  * [Mix] Ensure Phoenix can serve and code reload inside umbrella apps

* Backwards incompatible changes
  * [Endpoint] Endpoints should now be explicitly started in your application supervision tree. Just add `worker(YourApp.Endpoint, [])` to your supervision tree in `lib/your_app.ex`
  * `mix phoenix.start` was renamed to `mix phoenix.server`
  * [Endpoint] The `YourApp.Endpoint.start/0` function was removed. You can simply remove it from your `test/test_helper.ex` file
  * [Router] Generated named paths now expect a conn arg. For example, `MyApp.Router.Helpers.page_path(conn, :show, "hello")` instead of `MyApp.Router.Helpers.page_path(:show, "hello")`
  * [Controller] `Phoenix.Controller.Flash` has been removed in favor of `fetch_flash/2`, `get_flash/2`, and `put_flash/2` functions on `Phoenix.Controller`
  * [Router] `Phoenix.Router.Socket` has been removed in favor of new `Phoenix.Router.socket/2` macro.
  * [Router] The `channel` macro now requires a topic pattern to be used to match incoming channel messages to a channel handler. See `Phoenix.Router.channel/2` for details.
  * [Channel] The `event/3` callback has been renamed to `handle_in/3` and the argument order has changed to `def handle_in("some:event", msg, socket)`
  * [Channel] Channel callback return signatures have changed and now require `{:ok, socket} | {:leave, socket| | {:error, socket, reason}`. `terminate/2` and `hibernate/2` have also been removed.

## v0.7.2 (2014-12-11)

* Enhancements
  * [Mix] Update Plug to `0.9.0`. You can now remove the Plug git dep from your `mix.exs`.

* Bug fixes
  * [Endpoint] Ensure CodeReloader is removed fron Endpoint when disabled

## v0.7.1 (2014-12-09)

* Bug fixes
  * [Phoenix] Include Plug dep in new project generation since it's a github dep until next Plug release.

## v0.7.0 (2014-12-09)
See these [`0.6.x` to `0.7.0` upgrade instructions](https://gist.github.com/chrismccord/c24b2b516066d987f4fe) to bring your existing apps up to speed.

* Enhancements
  * [Endpoint] Introduce the concept of endpoints which removes some of the responsibilities from the router
  * [Endpoint] Move configuration from the :phoenix application to the user own OTP app

* Bug fixes
  * [Router] Fix a bug where the error rendering layer was not picking JSON changes
  * [CodeReloader] Fix a bug where the code reloader was unable to recompile when the router could not compile

* Backwards incompatible changes
  * [I18n] `Linguist` has been removed as a dependency, and an `I18n` module is no longer generated in your project
  * [View] `ErrorsView` has been renamed to `ErrorView`, update your `MyApp.ErrorsView` accordingly
  * [Controller] `html/2`, `json/2`, `text/2`, `redirect/2` and
`render/3` no longer halt automatically
  * [Router] Configuration is no longer stored in the router but in the application endpoint. The before pipeline was also removed and move to the endpoint itself

## v0.6.2 (2014-12-07)

* Bug fixes
  * [Mix] Fix phoenix dep reference in new project generator

## v0.6.1 (2014-11-30)

* Enhancements
  * [Controller] Allow sensitive parameters to be filtered from logs
  * [Router] Add ability for routes to be scoped by hostname via the :host option
  * [Router] Add `Plug.Debugger` that shows helpful error pages in case of failures
  * [Router] Add `Phoenix.Router.RenderErrors` which dispatches to a view for rendering in case of crashes
  * [Router] Log which pipelines were triggered during a request
  * [Channel] Allows custom serializers to be configured for WebSocket Transport

## v0.6.0 (2014-11-22)

See the [`0.5.x` to `0.6.0` upgrade instructions](https://gist.github.com/chrismccord/e774e6ab5220e6505a03) for upgrading your
existing applications.

* Enhancements
  * [Controller] Support `put_view/2` to configure which view to use
when rendering in the controller
  * [Controller] Support templates as an atom in
`Phoenix.Controller.render/3` as a way to explicitly render templates
based on the request format
  * [Controller] Split paths from external urls in `redirect/2`
  * [Controller] `json/2` automatically encodes the data to JSON by
using the registered `:format_encoders`
  * [Controller] `html/2`, `json/2`, `text/2`, `redirect/2` and
`render/3` now halt automatically
  * [Controller] Add `accepts/2` for content negotiation
  * [Controller] Add `put_layout_formats/2` and `layout_formats/1` to
configure and read which formats have a layout when rendering
  * [View] Assigns are always guaranteed to be maps
  * [View] Add support to `format_encoders` that automatically encodes
rendered templates. This means a "user.json" template only needs to
return a map (or any structure encodable to JSON) and it will be
automatically encoded to JSON by Phoenix
  * [View] Add a .exs template engine
  * [Channel] Add a `Transport` contract for custom Channel backends
  * [Channel] Add a `LongPoller` transport with automatic LP fallback
in `phoenix.js`
  * [phoenix.js] Add long-polling support with automatic LP fallback
for older browsers

* Deprecations
  * [Controller] `html/3`, `json/3`, `text/3` and `redirect/3` were
deprecated in favor of using `put_status/2`
  * [Controller] `redirect(conn, url)` was deprecated in favor of
`redirect(conn, to: url)`

* Backwards incompatible changes
  * [Controller] Passing a string to render without format in the
controller, as in `render(conn, "show")` no longer works. You should
either make the format explicit `render(conn, "show.html")` or use an
atom `render(conn, :show)` to dynamically render based on the format
  * [View] Using `:within` was renamed in favor of `:layout` for
rendering with layouts
  * [View] Your application should now directly use Phoenix.View in
its main view and specify further configuration in the `using(...)`
section
  * [View] Template engines now should implement compile and simply
return the quoted expression of the function body instead of the
quoted expression of the render function
  * [Router] `PUT` route generation for the `:update` action has been
dropped in favor of `PATCH`, but `PUT` still matches requests to maintain compatibility with proxies.
  * [Router] Router no longer defines default :browser and :api
pipelines

* Bug fixes
  * [Router] Generate correct route for helper path on root

## v0.5.0

* Enhancements
  * [Router] Named helpers are now automatically generated for every
route based on the controller name
  * [Router] Named helpers have been optimized to do as little work as
possible at runtime
  * [Router] Support multiple pipelines at the router level
  * [Channels] The `phoenix.js` channel client now sends a
configurable heartbeat every 30s to maintain connections

* Deprecations
  * [Controller] `assign_private` is deprecated in favor of
`put_private`
  * [Controller] `assign_status` is deprecated in favor of
`put_status`

* Backwards incompatible changes
  * [Controller] Remove default, injected aliases: `Flash`, `JSON`
  * [Controller] Controllers now require `plug :action` to be
explicitly invoked
  * [Router] `*path` identifiers in routers are now returned as a list
  * [Router] Named helpers are now defined in a explicit module nested
to your router. For example, if your router is named `MyApp.Router`,
the named helpers will be available at `MyApp.Router.Helpers`
  * [Router] `session_secret` configuration is deprecated in favor of
`secret_key_base`
  * [Router] Plugs can now only be defined inside pipelines. All
routers now need to explicitly declare which pipeline they want to use
  * [Router] Router configuration was revamped, static configuration
has been moved into `:static`, session configuration into `:session`,
parsers configuration into `:parsers`, the http server configuration
has been moved into `:http`, the https configuration into `:https` and
the URI information for generating URIs into `:uri`
  * [CodeReloaer] Code reloading now requires the `:phoenix` compiler
to be added to the list of compilers in your `mix.exs` project config,
ie: `compilers: [:phoenix] ++ Mix.compilers`. Additionally, the
`Phoenix.CodeReloader.reload!` invocation should be removed from your
`test_helper.exs` for applications generated on `0.4.x`.
  * [Topic] `Phoenix.Topic` has been renamed to `Phoenix.PubSub`. If you were calling into the topic layer directly, update your module references.


## v0.4.1 (2014-09-08)

* Bug fixes
  * [Project Generation] Fix project template dependencies pointing to
incorrect phoenix and elixir versions


## v0.4.0 (2014-08-30)

* Enhancements
  * [Controller] Controllers are now Plugs and can be plugged as a
"second layer" plug stack from the Router plug stack
  * [Controller] Elixir Logger Integration - Improved request logger,
durations, params, etc
  * [Controller] Custom 404/500 page handling,
[details](https://github.com/phoenixframework/phoenix/blob/0b6bdffab45fc46bc1455860f2d3971d0224eeb5/README.md#custom-not-found-and-error-pages)
  * [Controller] Ability to halt Plug stacks with Plug 0.7.0 `halt/1`
  * [Controller] Add `assign_layout/2` and `assign_status/2`
  * [Controller] Flash messages for one-time message support across
redirects
  * [View] Internationalization support
  * [View] New `Template.Engine` behaviour for third-party template
engines. See
[PhoenixHaml](https://github.com/chrismccord/phoenix_haml) for haml
support via Calliope.
  * `render/2` can be explicitly plugged for automatic rendering of
actions based on action name
  * [Channel] Assign API for Sockets allows ephemeral state to be
stored on the multiplexed socket, similar to conn assigns
  * [Config] Add `proxy_port` Router config option for deployments
where public facing port differs from local port
  * [Router] Add nested generated `Helpers` module to Routers for easy
imports of named route helpers, ie `import MyApp.Router.Helpers`


* Bug fixes
  * Various bug fixes and improvements

* Backwards incompatible changes
  * [Config] ExConf Configuration has been replaced by Mix Config
  * Directory and naming conventions have changed. A `web/` directory
now lives at root of the project and holds routers, controllers,
channels, views & templates, where all `web/` files are recompiled by
the code reloader during development. Modules that cannot be simply
recompiled in process are placed in lib as normal and require a server
restart to take effect. Follow
[this guide](https://gist.github.com/dgoldie/2fdc90fe09ecdddb78f4) for
upgrade steps from 0.3.x.
  * Naming conventions now use singular form for module names,
directory names, and named route helpers
  * [Router] Named route helpers have been reworked to use single
function name with pattern matched arguments. See the
[readme  examples](https://github.com/phoenixframework/phoenix/blob/0b6bdffab45fc46bc1455860f2d3971d0224eeb5/README.md#resources)
  * [Controller] `layout: nil` render option has been replaced by
`assign_layout(conn, :none)`
  * [Plugs] `Plugs.JSON` now adds parsed params under "_json" key when
the JSON object is an array


## v0.3.1 (2014-07-04)
* Enhancements
  * Various performance improvements

## v0.3.0 (2014-06-30)

* Enhancements
  * Add Precompiled EEx Templating Engine and View layer
  * Add JSON Plug parser
  * Update Plug to 0.5.2 with Cookie Session support
  * URL helpers ie, `Router.page_path`, now properly encode nested
query string params

* Bug fixes
  * Auto template compilation has been fixed for Elixir 0.14.2
`@external_resource` changes

* Backwards incompatible changes
  * Controller action arity has changed. All actions now receive the
Plug conn and params as arguments, ie `def show(conn, %{"id" => id})`
  * Channel and Topic `reply` and `broadcast` functions now require a
map instead of an arbitrary dict
