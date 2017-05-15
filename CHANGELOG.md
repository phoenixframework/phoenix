# Changelog

## 1.2.4 (2017-5-15)

* Enhancements
  * [phoenix.new] Support Erlang 20 in `phoenix.new` archive

## 1.2.3 (2017-3-14)

* Enhancements
  * [Plug] Use latest plug crypto to harden Phoenix.Token

## 1.2.2 (2017-3-14)

* Big Fixes
  * [Controller] Harden local redirect against arbitrary URL redirection

## 1.2.1 (2016-8-11)

* Enhancements
  * [Router] Improve errors for invalid route paths
  * [Plug] Include new development error pages

* Bug Fixes
  * [Endpoint] Fixed issue where endpoint would fail to code reload on next request after an endpoint compilation error


## 1.2.0 (2016-6-23)

See these [`1.1.x` to `1.2.x` upgrade instructions](https://gist.github.com/chrismccord/29100e16d3990469c47f851e3142f766) to bring your existing apps up to speed.

* Enhancements
  * [CodeReloader] The `lib/` directory is now code reloaded by default along with `web/` in development
  * [Channel] Add `subscribe/2` and `unsubscribe/2` to handle external topic subscriptions for a socket
  * [Channel] Add `:phoenix_channel_join` instrumentation hook
  * [View] Generate private `render_template/2` clauses for views to allow overriding `render/2` clauses before rendering templates
  * [View] Add `:path` and `:pattern` options to allow wildcard template inclusion as well as customized template directory locations

* Deprecations
  * [Endpoint] Generated `subscribe/3` and `unsubscribe/2` clauses have been deprecated in favor of `subscribe/2` and `unsubscribe/1` which uses the caller's pid
  * [PubSub] `Phoenix.PubSub.subscribe/3` and `Phoenix.PubSub.unsubscribe/2` have been deprecated in favor of `subscribe/2` and `unsubscribe/1` which uses the caller's pid
  * [Watcher] Using the `:root` endpoint configuration for watchers is deprecated. Pass the :cd option at the end of your watcher argument list in config/dev.exs. For example:

      ```elixir
      watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin",
                 cd: Path.expand("../", __DIR__)]]
      ```

* Bug Fixes
  * [Template] Prevent infinite call stack when rendering a non-existent template from `template_not_found`

* Backward incompatible changes
  * [Channel] `subscribe/1` and `unsubscribe/1` have been removed in favor of calling subscribe and unsubscribe off the endpoint directly

* JavaScript client enhancements
  * Add Presence object for syncing presence state between client and server
  * Use return value of channel onMessage callback for specialized message transformations before dispatching to the channel

* JavaScript client backward incompatible changes
  * `Presence.syncState` and `Presence.syncDiff` now return a copy of the state instead of mutating it


## 1.1.6 (2016-6-03)

* Enhancements
  * Add Erlang 19 compatibility

## 1.1.5 (2016-6-01)

* Enhancements
  * Fix warnings for Elixir 1.3

## 1.1.4 (2016-1-25)

* Enhancements
  * [phoenix.new] Update dependencies and solve problem where Mix may take too long to resolve deps
  * [phoenix.new] Be more conservative regarding brunch dependencies
  * [phoenix.new] Provide `local.phoenix` task
  * [phoenix.digest] Add `?vsn=d` to digested assets

## 1.1.3 (2016-1-20)

* Enhancements
  * [phoenix.gen] Support `--binary-id` option when generating scaffold
  * [phoenix.new] Don't include Ecto gettext translations if `--no-ecto` is passed

* JavaScript client bug fixes
  * Ensure exports variable does not leak
  * Fix `setTimeout` scoping issue for Babel

## 1.1.2 (2016-1-8)

See these *optional* [`1.1.1` to `1.1.2` upgrade instructions](https://gist.github.com/chrismccord/d5bc5f8e38c8f76cad33) to bring your existing apps up to speed.

* Enhancements
  * [Cowboy] Improve log report for errors from the UserSocket
  * [ChannelTest] Add `refute_push` and `refute_reply`
  * [Router] Improve error messages when calling Router helpers without matching clauses
  * [phoenix.new] Use brunch 2.1.1 npm integration to load `phoenix` and `phoenix_html` js deps

## 1.1.1 (2015-12-26)

* Bug fixes
  * Fix `--no-html` flag on `phoenix.new` task failing to generate ErrorHelpers module

## 1.1.0 (2015-12-16)

See these [`1.0.x` to `1.1.0` upgrade instructions](https://gist.github.com/chrismccord/557ef22e2a03a7992624) to bring your existing apps up to speed.

* Enhancements
  * [Router] Enable defining routes for custom http methods with a new `match` macro
  * [CodeReloader] The socket transports now trigger the code reloader when enabled for external clients that only connect to channels without trigger a recompile through the normal page request.
  * [phoenix.digest] The `phoenix.digest` task now digests asset urls in stylesheets automatically
  * [Channel] Add `Phoenix.Channel.reply/3` to reply asynchronously to a channel push
  * [Channel] `code_change/3` is now supported to upgrade channel servers
  * [Endpoint] `check_origin` now supports wildcard hosts, ie `check_origin: ["//*.example.com"]`
  * [Endpoint] `check_origin` treats invalid origin hosts as missing for misbehaving clients
  * [Endpoint] Add `Phoenix.Endpoint.server?/2` to check if webserver has been configured to start
  * [ConnTest] Add `assert_error_sent` to assert an error was wrapped and sent with a given status

* Backward incompatible changes
  * [View] The `@inner` assign has been removed in favor of explicit rendering with `render/3` and the new `@view_module` and `view_template` assigns, for example: `<%= @inner %>` is replaced by `<%= render @view_module, @view_template, assigns %>`

## 1.0.4 (2015-11-30)

* Enhancements
  * [ConnTest] Add `bypass_through` to pass a connection through a Router and pipelines while bypassing route dispatch.

* Bug fixes
  * [LongPoll] force application/json content-type to fix blank JSON bodies on older IE clients using xdomain


## 1.0.3 (2015-9-28)

* Enhancements
  * [Controller] Transform FunctionClauseError's from controller actions into ActionClauseError, and send 400 response
  * [Router] Allow plugs to be passed to `pipe_through`
  * [Channel] WebSocket transport now sends server heartbeats and shutdowns if client heartbeats stop. Fixes timeout issues when clients keep connection open, but hang with suspended js runtimes

* JavaScript client deprecations
  * Passing params to socket.connect() has been deprecated in favor of the `:params` option of the Socket constructor

## 1.0.2 (2015-9-6)

* Enhancements
  * [Installer] Support `--database mongodb` when generating new apps
  * [Installer] Support `binary_id` and `migration` configuration for models

* Bug fixes
  * [Digest] Ensure Phoenix app is loaded before digesting
  * [Generator] Ensure proper keys are generated in JSON views and tests
  * [Generator] Ensure proper titles are generated in HTML views and tests
  * [Mix] Ensure app is compiled before showing routes with `mix phoenix.routes`
  * [Token] Ensure max age is counted in seconds and not in milliseconds

## 1.0.1 (2015-9-3)

* Enhancements
  * [Controller] `phoenix.gen.json` generator now excludes `:new` and `:edit` actions
  * [Endpoint] Set hostname to "localhost" by default for dev and test
  * [ConnTest] Support multiple json mime types in `json_response/2`

## 1.0.0 (2015-8-28) 🚀

## v0.17.1 (2015-8-26)

* Enhancements
  * [ChannelTest] Add `connect/2` helper for test UserSocket handlers
  * [Endpoint] Expose `struct_url/0` in the endpoint that returns the URL as struct for further manipulation
  * [Router] Allow `URI` structs to be given to generated `url/1` and `path/2` helpers

* Bug fixes
  * [Endpoint] Pass port configuration when configuring force_ssl
  * [Mix] By default include all attributes in generated JSON views
  * [Router] Fix `pipe_through` not respecting halting when piping through multiple pipelines

## v0.17.0 (2015-8-19)

See these [`0.16.x` to `0.17.0` upgrade instructions](https://gist.github.com/chrismccord/ee5ae90b949a9768b871) to bring your existing apps up to speed.

* Enhancements
  * [Endpoint] Allow `check_origin` and `force_ssl` to be config in transports and fallback to endpoint config
  * [Transport] Log when `check_origin` fails

* Bug fixes
  * [Mix] Properly humanize names in the generator

* Deprecations
  * [Endpoint] `render_errors: [default_format: "html"]` is deprecated in favor of `render_errors: [accepts: ["html"]]`

* Backward incompatible changes
  * [Controller] The "format" param for overriding the accept header has been renamed to "_format" and is no longer injected into the params when parsing the Accept headers. Use `get_format/1` to access the negotiated format.
  * [ChannelTest] In order to test channels, one must now explicitly create a socket and pass it to `subscribe_and_join`. For example, `subscribe_and_join(MyChannel, "my_topic")` should now become `socket() |> subscribe_and_join(MyChannel, "my_topic")` or `socket("user:id", %{user_id: 13}) |> subscribe_and_join(MyChannel, "my_topic")`.

## v0.16.1 (2015-8-6)

* JavaScript client bug fixes
  * Pass socket params on reconnect

## v0.16.0 (2015-8-5)

See these [`0.15.x` to `0.16.0` upgrade instructions](https://gist.github.com/chrismccord/969d75d1562979a3ae37) to bring your existing apps up to speed.

* Enhancements
  * [Brunch] No longer ship with `sass-brunch` dependency
  * [Endpoint] Add `force_ssl` support
  * [Mix] Allow `phoenix.gen.*` tasks templates to be customized by the target application by placing copies at `priv/template/phoenix.gen.*`
  * [Mix] Support `mix phoenix.gen.model Comment comment post_id:references:posts`
  * [Mix] Add `mix phoenix.gen.secret`
  * [Router] Provide `put_secure_browser_headers/2` and use it by default in the browser pipeline
  * [Socket] Automatically check origins on socket transports
  * [Token] Add `Phoenix.Token` for easy signing and verification of tokens

* Bug fixes
  * [Cowboy] Ensure we print proper URL when starting the server with both http and https
  * [Digest] Do not gzip binary files like png and jpg. Default only to known text files and make them configurable via `config :phoenix, :gzippable_exts, ~w(.txt .html .js .css)` and so on

* Backward incompatible changes
  * [Controller] `jsonp/3` function has been removed in favor of the `plug :allow_jsonp`
  * [Controller] `controller_template/1` has been renamed to `view_template/1`
  * [HTML] Use `phoenix_html ~> 2.0` which includes its own `phoenix_html.js` version
  * [Socket] `:origins` transport option has been renamed to `:check_origin`
  * [View] `render_one` and `render_many` no longer inflect the view module from the model in favor of explicitly passing the view

* JavaScript client backwards incompatible changes
  * Socket params are now passed to `socket.connect()` instead of an option on the constructor.
  * Socket params are no longer merged as default params for channel params. Use `connect/2` on the server to wire up default channel assigns.
  * Socket `chan` has been renamed to `channel`, for example `socket.channel("some:topic")`

## v0.15.0 (2015-7-27)

See these [`0.14.x` to `0.15.0` upgrade instructions](https://gist.github.com/chrismccord/931373940f320bf41a50) to bring your existing apps up to speed.

* Enhancements
  * [Socket] Introduce `Phoenix.Socket` behaviour that allows socket authentication, termination, and default channel socket assigns
  * [PubSub] Use ETS dispatch table for increased broadcast performance
  * [Channel] Use event intercept for increased broadcast performance

* Backward incompatible changes
  * [Router] channel routes are now defined on a socket handler module instead of the Router
  * [Router] `socket` mounts have been moved from the Router to the Endpoint
  * [Channel] `handle_out` callbacks now require explicit event intercept for callback to be invoked, with `Phoenix.Channel.intercept/1`
  * [Transports] WebSocket and LongPoll transport configuration has been moved from mix config to the UserSocket

* JavaScript client backwards incompatible changes
  * `Phoenix.LongPoller` has been renamed to `Phoenix.LongPoll`
  * A new client version is required to   accommodate server changes

## v0.14.0 (2015-06-29)

See these [`0.13.x` to `0.14.0` upgrade instructions](https://gist.github.com/chrismccord/57805158f463d3369103) to bring your existing apps up to speed.

* Enhancements
  * [Phoenix.HTML] Update to phoenix_html 1.1.0 which raises on missing assigns
  * [Controller] Add `jsonp/2` for handling JSONP responses
  * [Channel] Enhance logging with join information
  * [Router] Add `forward` macro to forward a requests to a Plug, invoking the pipeline

* Javascript client enhancements
  * Add socket params to apply default, overridable params to all channel params.
  * Enchance logging

* Bug fixes
  * [Channel] Fix xdomain content type not being treated as JSON requests

* Javascript client backwards incompatible changes
  * `logger` option to `Phoenix.Socket`, now uses three arguments, ie: `logger: (kind, msg, data) => { console.log(`${kind}: ${msg}`, data) }`

* Backward incompatible changes
  * [Controller] `plug :action` is now called automatically
  * [Endpoint] The `:format` option in `:render_errors` has been renamed to `:default_format`
  * [PubSub.Redis] The Redis PubSub adapter has been extracted into its own project. If using redis, see the [project's readme](https://github.com/phoenixframework/phoenix_pubsub_redis) for instructions
  * [View] The default template `web/templates/layout/application.html.eex` has been renamed to `app.html.eex`

## v0.13.1 (2015-05-16)

See these [`0.13.0` to `0.13.1` upgrade instructions](https://gist.github.com/chrismccord/4a62780056b08c60542d) to bring your existing apps up to speed.

* Enhancements
  * [Channel] Add `phoenix.new.channel Channel topic`
  * [Channel] Add `Phoenix.ChannelCase`
  * [Controller] Assert changes in the repository on generated controller tests
  * [Endpoint] Add `static_url` to endpoint to configure host, port and more for static urls
  * [phoenix.new] Generate a channel case for new apps
  * [phoenix.new] Improve installation workflow by asking to install and fetch dependencies once
  * [phoenix.new] Add `errors_on/1` to generated model case

## v0.13.0 (2015-05-11)

See these [`0.12.x` to `0.13.0` upgrade instructions](https://gist.github.com/chrismccord/0a3bf5229801d61f219b) to bring your existing apps up to speed.

* Enhancements
  * [Channel] Allow router helpers to work in channels by passing a socket (instead of connection), for example: `user_path(socket, :index)`
  * [Channel] Support replies in `join/3`
  * [HTML] `Phoenix.HTML` has been extracted to its own project. You need to explicitly depend on it by adding `{:phoenix_html, "~> 1.0"}` to `deps` in your `mix.exs` file
  * [HTML] `safe/1` in views is deprecated in favor of `raw/1`
  * [Generators] Allow `belongs_to` in model generator which supports associations and indexes

* Bug fixes
  * [HTML] `select` no longer inverses the key and values in the given options
  * [phoenix.new] Do not run `deps.get` if there is no Hex

* Backward incompatible changes
  * [Channel] To refuse joining a channel, `join/3` now requires `{:error, reason}`

* Javascript client backward incompatible changes
  * channel instances are now created from the `socket`
  * channel joins are now called explicitly off channel instances
  * channel onClose now only triggered on explicit client `leave` or server `:stop`
  * Examples:

      ```javascript
      let socket = new Phoenix.Socket("/ws")
      let chan = socket.chan("rooms:123", {})
      chan.join().receive("ok", ({resp} => ...).receive("error", ({reason}) => ...)
      ```


## v0.12.0 (2015-04-30)

See these [`0.11.x` to `0.12.0` upgrade instructions](https://gist.github.com/chrismccord/b3975ba356dba902ec88) to bring your existing apps up to speed.

* Enhancements
  * [Channel] Leaving the channel or closing the client will now trigger terminate on the channel, regardless of traping exits, with reasons `{:shutdown, :left}` and `{:shutdown, :closed}` respectively
  * [Controller] Support `:namespace` option in controllers in order to use proper layout in namespaced applications
  * [Controller] Add `controller_template/1` to lookup the template rendered from the controller
  * [Generators] Add `phoenix.gen.json`
  * [Generators] Allow models to be skipped on `phoenix.gen.json` and `phoenix.gen.html` generators
  * [Generators] Generate test files in `phoenix.gen.html`, `phoenix.gen.json` and `phoenix.gen.model`
  * [HTML] Add `search_input/3`, `telephone_input/3`, `url_input/3` and `range_input/3` to `Phoenix.HTML.Form`
  * [Installer] Add the generated `config/prod.secret.exs` file to `.gitignore` by default
  * [Static] Add a `mix phoenix.digest` task to run during deploys to generate digest filenames and gzip static files. A new configuration called `cache_static_manifest` was added which should be set to "priv/static/manifest.json" in production which will preload the manifest file generated by the mix task in order to point to the digested files when generating static paths
  * [Test] Add `html_response/2`, `json_response/2`, `text_response/2` and `response/2` to aid connection-based testing
  * [View] Add `render_existing/3` to render a template only if it exists without raising an error
  * [View] Add `render_many/4` and `render_one/4` to make it easier to render collection and optional data respctivelly

* Bug fixes
  * [Channel] Ensure channels are terminated when WebSocket and LongPoller transports exit normally
  * [Installer] Declare missing applications in generated phoenix.new app
  * [Installer] No longer generate encryption salt in generated phoenix.new app
  * [Installer] Generate proper credentials in phoenix.new for different databases
  * [Mix] Ensure the serve endpoints configuration is persistent
  * [Router] Ensure URL helpers know how to call `to_param` on query parameters

## v0.11.0 (2015-04-07)

See these [`0.10.x` to `0.11.0` upgrade instructions](https://gist.github.com/chrismccord/3603fd2735019f86c74b) to bring your existing apps up to speed.

* Javascript client enhancements
  * Joins are now synchronous, removing the prior issues of client race conditions
  * Events can now be replied to from the server, for request/response style messaging
  * Clients can now detect and react to individual channel errors and terminations

* Javascript client backward incompatible changes
  * The `Socket` instance no long connects automatically. You must explicitly call `connect()`
  * `close()` has been renamed to `disconnect()`
  * `send` has been renamed to `push` to unify client and server messaging commands
  * The `join` API has changed to use synchronous messaging. Check the upgrade guide for details

* Backwards incompatible changes
  * [Generator] `mix phoenix.gen.resource` renamed to `mix phoenix.gen.html`
  * [Channel] `reply` has been renamed to `push` to better signify we are only push a message down the socket, not replying to a specific request
  * [Channel] The return signatures for `handle_in/3` and `handle_out/3` have changed, ie:

        handle_in(event :: String.t, msg :: map, Socket.t) ::
          {:noreply, Socket.t} |
          {:reply, {status :: atom, response :: map}, Socket.t} |
          {:reply, status :: atom, Socket.t} |
          {:stop, reason :: term, Socket.t} |
          {:stop, reason :: term, reply :: {status :: atom, response :: map}, Socket.t} |
          {:stop, reason :: term, reply :: status :: atom, Socket.t}

        handle_out(event :: String.t, msg :: map, Socket.t) ::
          {:ok, Socket.t} |
          {:noreply, Socket.t} |
          {:error, reason :: term, Socket.t} |
          {:stop, reason :: term, Socket.t}


  * [Channel] The `leave/2` callback has been removed. If you need to cleanup/teardown when a client disconnects, trap exits and handle in `terminate/2`, ie:

        def join(topic, auth_msg, socket) do
          Process.flag(:trap_exit, true)
          {:ok, socket}
        end

        def terminate({:shutdown, :client_left}, socket) do
          # client left intentionally
        end
        def terminate(reason, socket) do
          # terminating for another reason (connection drop, crash, etc)
        end

  * [HTML] `use Phoenix.HTML` no longer imports controller functions. You must add `import Phoenix.Controller, only: [get_flash: 2]` manually to your views or your `web.ex`
  * [Endpoint] Code reloader must now be configured in your endpoint instead of Phoenix. Therefore, upgrade your `config/dev.exs` replacing

          config :phoenix, :code_reloader, true

    by

          config :your_app, Your.Endpoint, code_reloader: true

  * [Endpoint] Live reloader is now a dependency instead of being shipped with Phoenix. Please add `{:phoenix_live_reload, "~> 0.3"}` to your dependencies
  * [Endpoint] The `live_reload` configuration has changed to allow a `:url` option and work with `:patterns` instead of paths:

        config :your_app, Your.Endpoint,
          code_reloader: true,
          live_reload: [
            url: "ws://localhost:4000",
            patterns: [~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
                       ~r{web/views/.*(ex)$},
                       ~r{web/templates/.*(eex)$}]]

  * [Endpoint] Code and live reloader must now be explicitly plugged in your endpoint. Wrap them inside `lib/your_app/endpoint.ex` in a `code_reloading?` block:

          if code_reloading? do
            plug Phoenix.LiveReloader
            plug Phoenix.CodeReloader
          end

* Enhancements
  * [Endpoint] Allow the default format used when rendering errors to be customized in the `render_views` configuration
  * [HTML] Add `button/2` function to `Phoenix.HTML`
  * [HTML] Add `textarea/3` function to `Phoenix.HTML.Form`
  * [Controller] `render/3` and `render/4` allows a view to be specified
    directly.

* Bug fixes
  * [HTML] Fix out of order hours, minutes and days in date/time select

## v0.10.0 (2015-03-08)

See these [`0.9.x` to `0.10.0` upgrade instructions](https://gist.github.com/chrismccord/cf51346c6636b5052885) to bring your existing apps up to speed.

* Enhancements
  * [CLI] Make `phoenix.new` in sync with `mix new` by making the project directory optional
  * [Controller] Add `scrub_params/2` which makes it easy to remove and prune blank string values from parameters (usually sent by forms)
  * [Endpoint] Runtime evaluation of `:port` configuration is now supported. When given a tuple like `{:system, "PORT"}`, the port will be referenced from `System.get_env("PORT")` at runtime as a workaround for releases where environment specific information is loaded only at compile-time
  * [HTML] Provide `tag/2`, `content_tag/2` and `content_tag/3` helpers to make tag generation easier and safer
  * [Router] Speed up router compilation

* Backwards incompatible changes
  * [Plug] Update to Plug 0.10.0 which moves CSRF tokens from cookies back to sessions. To avoid future bumps on the road, a `get_csrf_token/0` function has been added to controllers
  * [PubSub] Remove the option `:options` from `:pubsub`. Just define the options alongside the pubsub configuration
  * [Pubsub] Require the `:name` option when configuring a pubsub adapter

## v0.9.0 (2015-02-12)

See these [`0.8.x` to `0.9.0` upgrade instructions](https://gist.github.com/chrismccord/def6f4dc444b6a8f8d8b) to bring your existing apps up to speed.

* Enhancements
  * [PubSub/Channels] The PubSub layer now supports Redis, and is opened up to other third party adapters. It still defaults to PG2, but other adapters are convenient for non-distributed deployments or durable messaging.

* Bug fixes
  * [Plug] Ensure session and flash are serializable to JSON

* Backwards incompatible changes
  * [PubSub] The new PubSub system requires the adapter's configuration to be added to your Endpoint's mix config.
  * [PubSub] The `Phoenix.PubSub` API now requires a registered server name, ie `Phoenix.PubSub.broadcast(MyApp.PubSub, "foo:bar", %{baz: :bang})`
  * [Channel] Channel broadcasts from outside a socket connection now must be called from an Endpoint module directly, ie: `MyApp.Endpoint.broadcast("topic", "event", %{...})`
  * [Channel] The error return signature has been changed from `{:error, socket, reason}` to `{:error, reason, socket}`
  * [Plug] `Plug.CSRFProtection` now uses a cookie instead of session and expects a `"_csrf_token"` parameter instead of `"csrf_token"`
  * [Router/Controller] The `destroy` action has been renamed to `delete`, update your controller actions and url builders accordingly


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
  * [Mix] Allow the code generation namespace to be configured with the `:namespace` option
  * [Mix] Allow `:reloadable_paths` in Endpoint configuration to reload directories other than `"web"` in development

* Bug Fixes
  * [Channel] Fix WebSocket heartbeat causing unnecessary `%Phoenix.Socket{}`'s to be tracked and leave errors on disconnect
  * [Mix] Ensure Phoenix can serve and code reload inside umbrella apps

* Backwards incompatible changes
  * [Endpoint] Endpoints should now be explicitly started in your application supervision tree. Just add `supervisor(YourApp.Endpoint, [])` to your supervision tree in `lib/your_app.ex`
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
  * [Router] Configuration is no longer stored in the router but in the application endpoint. The before pipeline was also removed and moved to the endpoint itself

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
