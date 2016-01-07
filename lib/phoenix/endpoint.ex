defmodule Phoenix.Endpoint do
  @moduledoc """
  Defines a Phoenix endpoint.

  The endpoint is the boundary where all requests to your
  web application start. It is also the interface your
  application provides to the underlying web servers.

  Overall, an endpoint has three responsibilities:

    * to provide a wrapper for starting and stopping the
      endpoint as part of a supervision tree;

    * to define an initial plug pipeline where requests
      are sent through;

    * to host web specific configuration for your
      application.

  ## Endpoints

  An endpoint is simply a module defined with the help
  of `Phoenix.Endpoint`. If you have used the `mix phoenix.new`
  generator, an endpoint was automatically generated as
  part of your application:

      defmodule YourApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :your_app

        # plug ...
        # plug ...

        plug YourApp.Router
      end

  Before being used, an endpoint must be explicitly started as part
  of your application supervision tree too (which is again done by
  default in generated applications):

      supervisor(YourApp.Endpoint, [])

  ## Endpoint configuration

  All endpoints are configured in your application environment.
  For example:

      config :your_app, YourApp.Endpoint,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Endpoint configuration is split into two categories. Compile-time
  configuration means the configuration is read during compilation
  and changing it at runtime has no effect. The compile-time
  configuration is mostly related to error handling and instrumentation.

  Runtime configuration, instead, is accessed during or
  after your application is started and can be read and written through the
  `config/2` function:

      YourApp.Endpoint.config(:port)
      YourApp.Endpoint.config(:some_config, :default_value)

  ### Compile-time configuration

    * `:code_reloader` - when `true`, enables code reloading functionality

    * `:debug_errors` - when `true`, uses `Plug.Debugger` functionality for
      debugging failures in the application. Recommended to be set to `true`
      only in development as it allows listing of the application source
      code during debugging. Defaults to `false`.

    * `:render_errors` - responsible for rendering templates whenever there
      is a failure in the application. For example, if the application crashes
      with a 500 error during a HTML request, `render("500.html", assigns)`
      will be called in the view given to `:render_errors`. Defaults to:

          [view: MyApp.ErrorView, accepts: ~w(html)]

      The default format is used when none is set in the connection.

    * `:instrumenters` - a list of instrumenters modules whose callbacks will
      be fired on instrumentation events. Read more on instrumentation in the
      "Instrumentation" section below.

  ### Runtime configuration

    * `:root` - the root of your application for running external commands.
      This is only required if the watchers or code reloading functionality
      are enabled.

    * `:cache_static_manifest` - a path to a json manifest file that contains
      static files and their digested version. This is typically set to
      "priv/static/manifest.json" which is the file automatically generated
      by `mix phoenix.digest`.

    * `:check_origin` - configure transports to check origins or not. May
      be false, true or a list of hosts that are allowed.

    * `:http` - the configuration for the HTTP server. Currently uses
      cowboy and accepts all options as defined by
      [`Plug.Adapters.Cowboy`](http://hexdocs.pm/plug/Plug.Adapters.Cowboy.html).
      Defaults to `false`.

    * `:https` - the configuration for the HTTPS server. Currently uses
      cowboy and accepts all options as defined by
      [`Plug.Adapters.Cowboy`](http://hexdocs.pm/plug/Plug.Adapters.Cowboy.html).
      Defaults to `false`.

    * `:force_ssl` - ensures no data is ever sent via http, always redirecting
      to https. It expects a list of options which are forwarded to `Plug.SSL`.
      By default, it redirects http requests and sets the
      "strict-transport-security" header for https ones.

    * `:secret_key_base` - a secret key used as a base to generate secrets
      to encode cookies, session and friends. Defaults to `nil` as it must
      be set per application.

    * `:server` - when `true`, starts the web server when the endpoint
      supervision tree starts. Defaults to `false`. The `mix phoenix.server`
      task automatically sets this to `true`.

    * `:url` - configuration for generating URLs throughout the app.
      Accepts the `:host`, `:scheme`, `:path` and `:port` options. All
      keys except `:path` can be changed at runtime. Defaults to:

          [host: "localhost", path: "/"]

      The `:port` option requires either an integer, string, or
      `{:system, "ENV_VAR"}`. When given a tuple like `{:system, "PORT"}`,
      the port will be referenced from `System.get_env("PORT")` at runtime
      as a workaround for releases where environment specific information
      is loaded only at compile-time.

    * `:static_url` - configuration for generating URLs for static files.
      It will fallback to `url` if no option is provided. Accepts the same
      options as `url`.

    * `:watchers` - a set of watchers to run alongside your server. It
      expects a list of tuples containing the executable and its arguments.
      Watchers are guaranteed to run in the application directory but only
      when the server is enabled. For example, the watcher below will run
      the "watch" mode of the brunch build tool when the server starts.
      You can configure it to whatever build tool or command you want:

          [node: ["node_modules/brunch/bin/brunch", "watch"]]

    * `:live_reload` - configuration for the live reload option.
      Configuration requires a `:paths` option which should be a list of
      files to watch. When these files change, it will trigger a reload.
      If you are using a tool like [pow](http://pow.cx) in development,
      you may need to set the `:url` option appropriately.

          [url: "ws://localhost:4000",
           paths: [Path.expand("priv/static/js/phoenix.js")]]

    * `:pubsub` - configuration for this endpoint's pubsub adapter.
      Configuration either requires a `:name` of the registered pubsub
      server or a `:name` and `:adapter` pair. The given adapter and
      name pair will be started as part of the supervision tree. if
      no adapter is specified, the pubsub system will work by sending
      events and subscribing to the given name. Defaults to:

          [adapter: Phoenix.PubSub.PG2, name: MyApp.PubSub]

      It also supports custom adpater configuration:

          [name: :my_pubsub, adapter: Phoenix.PubSub.Redis,
           host: "192.168.100.1"]

  ## Endpoint API

  In the previous section, we have used the `config/2` function which is
  automatically generated in your endpoint. Here is a summary of all the
  functions that are automatically defined in your endpoint.

  #### Paths and URLs

    * `url()` - generates the endpoint base URL without any path information
    * `static_url()` - generates the static URL without any path information

    * `struct_url()` - generates the endpoint base URL but as a `URI` struct

    * `path(path)` - generates the path information when routing to this
      endpoint
    * `static_path(path)` - generates a route to a static file in `priv/static`

  #### Channels

    * `subscribe(pid, topic, opts)` - subscribes the pid to the given topic.
      See `Phoenix.PubSub.subscribe/4` for options.

    * `unsubscribe(pid, topic)` - unsubscribes the pid from the given topic.

    * `broadcast(topic, event, msg)` - broadcasts a `msg` with as `event`
      in the given `topic`.

    * `broadcast!(topic, event, msg)` - broadcasts a `msg` with as `event`
      in the given `topic`. Raises in case of failures.

    * `broadcast_from(from, topic, event, msg)` - broadcasts a `msg` from
      the given `from` as `event` in the given `topic`.

    * `broadcast_from!(from, topic, event, msg)` - broadcasts a `msg` from
      the given `from` as `event` in the given `topic`. Raises in case of failures.

  #### Endpoint configuration

    * `start_link()` - starts the Endpoint supervision tree, including its
      configuration cache and possibly the servers for handling requests
    * `config(key, default)` - access the endpoint configuration given by key
    * `config_change(changed, removed)` - reload the endpoint configuration
      on application upgrades

  #### Plug API

    * `init(opts)` - invoked when starting the endpoint server
    * `call(conn, opts)` - invoked on every request (simply dispatches to
      the defined plug pipeline)

  #### Instrumentation API

    * `instrument(event, runtime_metadata \\ nil, function)` - read more about
      instrumentation in the "Instrumentation" section

  ## Instrumentation

  Phoenix supports instrumentation through an extensible API. Each endpoint
  defines an `instrument/3` macro that both users and Phoenix internals can call
  to instrument generic events. This macro is responsible for measuring the time
  it takes for the event to happen and for notifying a list of interested
  instrumenter modules of this measurement.

  You can configure this list of instrumenter modules in the compile-time
  configuration of your endpoint. (see the `:instrumenters` option above). The
  way these modules express their interest in events is by exporting public
  functions where the name of each function is the name of an event. For
  example, if someone instruments the `:render_view` event, then each
  instrumenter module interested in that event will have to export
  `render_view/3`.

  **Note**: since the configuration for the list of instrumenters is specified
  at compile time but it's used inside Phoenix itself, if you change this
  configuration you'll have to recompile Phoenix manually:

      $ mix deps.compile phoenix
      $ mix compile

  ### Callbacks cycle

  The way event callbacks are called is the following.

    1. The event callback is called *before* the event happens (in this case,
       before the view is rendered) with the atom `:start` as the first
       argument; see the "Before clause" section below.
    2. The event happens (in this case, the view is rendered).
    3. The same event callback is called again, this time with the atom `:stop`
       as the first argument; see the "After clause" section below.

  The second and third argument that each event callback takes depend on the
  callback being an "after" or a "before" callback (i.e., they depend on the
  value of the first argument, `:start` or `:stop`). For this reason, most of
  the time you will want to define (at least) two separate clauses for each
  event callback, one for the "before" and one for the "after" callbacks.

  All event callbacks are run in the same process that calls the `instrument/3`
  macro; hence, instrumenters should be careful in performing blocking actions.
  If an event callback fails in any way (exits, throws, or raises), it won't
  affect anything (the error is caught) but the failure will be logged. Note
  that "after" callbacks are not guaranteed to be called as, for example, a link
  may break before they've been called.

  #### "Before" clause

  When the first argument to an event callback is `:start`, the signature of
  that callback is:

      event_callback(:start, compile_metadata, runtime_metadata)

  where:

    * `compile_metadata` is a map of compile-time metadata about the environment
      where `instrument/3` has been called. It contains the module where the
      instrumentation is happening (under the `:module` key), the file and line
      (`:file` and `:line`), and the function inside which the instrumentation
      is happening (under `:function`). This information can be used arbitrarely
      by the callback.
    * `runtime_metadata` is a map of runtime data that the instrumentation
      passes to the callbacks. This can be used for any purposes: for example,
      when instrumenting the rendering of a view, the name of the view could be
      passed in these runtime data so that instrumenters know which view is
      being rendered (`instrument(:view_render, %{view: "index.html"}, fn
      ...)`).

  #### "After" clause

  When the first argument to an event callback is `:stop`, the signature of that
  callback is:

      event_callback(:stop, time_diff, result_of_before_callback)

  where:

    * `time_diff` is an integer representing the time it took to execute the
      instrumented function **in microseconds**.
    * `result_of_before_callback` is the return value of the "before" clause of
      the same `event_callback`. This is a means of passing data from the
      "before" clause to the "after" clause when instrumenting. For example, an
      instrumenter can implement custom time measuring with this:

          defmodule MyInstrumenter do
            def event_callback(:start, _compile, _runtime) do
              :erlang.monotonic_time(:micro_seconds)
            end

            def event_callback(:stop, _time_diff, start_time) do
              stop_time = :erlang.monotonic_time(:micro_seconds)
              do_something_with_diff(stop_time - start_time)
            end
          end

  The return value of each "before" event callback will be stored and passed to
  the corresponding "after" callback.

  ### Using instrumentation

  Each Phoenix endpoint defines its own `instrument/3` macro. This macro is
  called like this:

      require MyApp.Endpoint
      MyApp.Endpoint.instrument :render_view, %{view: "index.html"}, fn ->
        # actual view rendering
      end

  All the instrumenter modules that export a `render_view/3` function will be
  notified of the event so that they can perform their respective actions.

  ### Phoenix default events

  By default, Phoenix instruments the following events:

    * `:phoenix_controller_call` - it's the whole controller pipeline. No
      runtime metadata is passed to the instrumentation here.
    * `:phoenix_controller_render` - the rendering of a view from a
      controller. The map of runtime metadata passed to instrumentation
      callbacks has the `:template` key - for the name of the template, e.g.,
      `"index.html"` - and the `:format` key - for the format of the template.

  ### Dynamic instrumentation

  If you want to instrument a piece of code but the endpoint that should
  instrument it (the one that contains the `instrument/3` macro you want to use)
  is not known at compile time, but only at runtime, then you can use the
  `Phoenix.Endpoint.instrument/4` macro. Refer to its documentation for more
  information.

  """

  alias Phoenix.Endpoint.Adapter

  @doc false
  defmacro __using__(opts) do
    quote do
      unquote(config(opts))
      unquote(pubsub())
      unquote(plug())
      unquote(server())
    end
  end

  defp config(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] || raise "endpoint expects :otp_app to be given"
      var!(config) = Adapter.config(@otp_app, __MODULE__)
      var!(code_reloading?) = var!(config)[:code_reloader]

      # Avoid unused variable warnings
      _ = var!(code_reloading?)
    end
  end

  defp pubsub() do
    quote do
      @pubsub_server var!(config)[:pubsub][:name] ||
        (if var!(config)[:pubsub][:adapter] do
          raise ArgumentError, "an adapter was given to :pubsub but no :name was defined, " <>
                               "please pass the :name option accordingly"
        end)

      def __pubsub_server__, do: @pubsub_server

      def subscribe(pid, topic, opts \\ []) do
        Phoenix.PubSub.subscribe(@pubsub_server, pid, topic, opts)
      end

      def unsubscribe(pid, topic) do
        Phoenix.PubSub.unsubscribe(@pubsub_server, pid, topic)
      end

      def broadcast_from(from, topic, event, msg) do
        Phoenix.Channel.Server.broadcast_from(@pubsub_server, from, topic, event, msg)
      end

      def broadcast_from!(from, topic, event, msg) do
        Phoenix.Channel.Server.broadcast_from!(@pubsub_server, from, topic, event, msg)
      end

      def broadcast(topic, event, msg) do
        Phoenix.Channel.Server.broadcast(@pubsub_server, topic, event, msg)
      end

      def broadcast!(topic, event, msg) do
        Phoenix.Channel.Server.broadcast!(@pubsub_server, topic, event, msg)
      end
    end
  end

  defp plug() do
    quote location: :keep do
      @behaviour Plug
      import Phoenix.Endpoint

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      Module.register_attribute(__MODULE__, :phoenix_sockets, accumulate: true)
      @before_compile Phoenix.Endpoint

      def init(opts) do
        opts
      end

      def call(conn, _opts) do
        conn = put_in conn.secret_key_base, config(:secret_key_base)
        conn
        |> Plug.Conn.put_private(:phoenix_endpoint, __MODULE__)
        |> put_script_name()
        |> phoenix_pipeline()
      end

      defoverridable [init: 1, call: 2]

      if force_ssl = var!(config)[:force_ssl] do
        plug Plug.SSL,
          Keyword.put_new(force_ssl, :host, var!(config)[:url][:host] || "localhost")
      end

      if var!(config)[:debug_errors] do
        use Plug.Debugger, otp_app: @otp_app
      end

      use Phoenix.Endpoint.RenderErrors, var!(config)[:render_errors]
    end
  end

  defp server() do
    quote location: :keep, unquote: false do
      @doc """
      Starts the endpoint supervision tree.
      """
      def start_link do
        Adapter.start_link(@otp_app, __MODULE__)
      end

      @doc """
      Returns the endpoint configuration for `key`

      Returns `default` if the key does not exist.
      """
      def config(key, default \\ nil) do
        case :ets.lookup(__MODULE__, key) do
          [{^key, val}] -> val
          [] -> default
        end
      end

      @doc """
      Reloads the configuration given the application environment changes.
      """
      def config_change(changed, removed) do
        Phoenix.Endpoint.Adapter.config_change(__MODULE__, changed, removed)
      end

      @doc """
      Generates the endpoint base URL without any path information.

      It uses the configuration under `:url` to generate such.
      """
      def url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_url__,
          &Phoenix.Endpoint.Adapter.url/1)
      end

      @doc """
      Generates the static URL without any path information.

      It uses the configuration under `:static_url` to generate
      such. It fallsback to `:url` if `:static_url` is not set.
      """
      def static_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_static_url__,
          &Phoenix.Endpoint.Adapter.static_url/1)
      end

      @doc """
      Generates the endpoint base URL but as a `URI` struct.

      It uses the configuration under `:url` to generate such.
      Useful for manipulating the url data and passing to
      URL helpers.
      """
      def struct_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_struct_url__,
          &Phoenix.Endpoint.Adapter.struct_url/1)
      end

      @doc """
      Generates the path information when routing to this endpoint.
      """
      script_name = var!(config)[:url][:path]

      if script_name == "/" do
        def path(path), do: path

        defp put_script_name(conn) do
          conn
        end
      else
        def path(path), do: unquote(script_name) <> path

        defp put_script_name(conn) do
          put_in conn.script_name, unquote(Plug.Router.Utils.split(script_name))
        end
      end

      # The static path should be properly scoped according to
      # the static_url configuration. If one is not available,
      # we fallback to the url configuration as in the adapter.
      static_script_name = (var!(config)[:static_url] || var!(config)[:url])[:path] || "/"
      static_script_name = if static_script_name == "/", do: "", else: static_script_name

      @doc """
      Generates a route to a static file in `priv/static`.
      """
      def static_path(path) do
        # This should be in sync with the endpoint warmup.
        unquote(static_script_name) <>
          Phoenix.Config.cache(__MODULE__, {:__phoenix_static__, path},
                               &Phoenix.Endpoint.Adapter.static_path(&1, path))
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    sockets = Module.get_attribute(env.module, :phoenix_sockets)
    plugs = Module.get_attribute(env.module, :plugs)
    {conn, body} = Plug.Builder.compile(env, plugs, [])
    otp_app = Module.get_attribute(env.module, :otp_app)
    instrumentation = Phoenix.Endpoint.Instrument.definstrument(otp_app, env.module)

    quote do
      defp phoenix_pipeline(unquote(conn)), do: unquote(body)

      @doc """
      Returns all sockets configured in this endpoint.
      """
      def __sockets__, do: unquote(sockets)

      unquote(instrumentation)
    end
  end

  ## API

  @doc """
  Stores a plug to be executed as part of the pipeline.
  """
  defmacro plug(plug, opts \\ []) do
    quote do
      @plugs {unquote(plug), unquote(opts), true}
    end
  end

  @doc """
  Defines a mount-point for a Socket module to handle channel definitions.

  ## Examples

      socket "/ws", MyApp.UserSocket
      socket "/ws/admin", MyApp.AdminUserSocket

  By default, the given path is a websocket upgrade endpoint,
  with long-polling fallback. The transports can be configured
  within the Socket handler. See `Phoenix.Socket` for more information
  on defining socket handlers.
  """
  defmacro socket(path, module) do
    # Tear the alias to simply store the root in the AST.
    # This will make Elixir unable to track the dependency
    # between endpoint <-> socket and avoid recompiling the
    # endpoint (alongside the whole project ) whenever the
    # socket changes.
    module = tear_alias(module)

    quote do
      @phoenix_sockets {unquote(path), unquote(module)}
    end
  end

  @doc """
  Instruments the given function using the instrumentation provided by
  the given endpoint.

  To specify the endpoint that will provide instrumentation, the first argument
  can be:

    * a module name -  the endpoint itself
    * a `Plug.Conn` struct - this macro will look for the endpoint module in the
      `:private` field of the connection; if it's not there, `fun` will be
      executed with no instrumentation
    * a `Phoenix.Socket` struct - this macro will look for the endpoint module in the
      `:endpoint` field of the socket; if it's not there, `fun` will be
      executed with no instrumentation

  Usually, users should prefer to instrument events using the `instrument/3`
  macro defined in every Phoenix endpoint. This macro should only be used for
  cases when the endpoint is dynamic and not known at compile time instead.

  ## Examples

      endpoint = MyApp.Endpoint
      Phoenix.Endpoint.instrument endpoint, :render_view, fn -> ... end

  """
  defmacro instrument(endpoint_or_conn_or_socket, event, runtime \\ Macro.escape(%{}), fun) do
    compile = Phoenix.Endpoint.Instrument.strip_caller(__CALLER__) |> Macro.escape()

    quote do
      case Phoenix.Endpoint.Instrument.extract_endpoint(unquote(endpoint_or_conn_or_socket)) do
        nil -> unquote(fun).()
        endpoint -> endpoint.instrument(unquote(event), unquote(compile), unquote(runtime), unquote(fun))
      end
    end
  end

  @doc """
  Checks if Endpoint's web server has been configured to start.

    * `otp_app` - The otp app running the endpoint, for example `:my_app`
    * `endpoint` - The endpoint module, for example `MyApp.Endpoint`

  ## Exampes

      iex> Phoenix.Endpoint.server?(:my_app, MyApp.Endpoint)
      true
  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    Adapter.server?(otp_app, endpoint)
  end

  defp tear_alias({:__aliases__, meta, [h|t]}) do
    alias = {:__aliases__, meta, [h]}
    quote do
      Module.concat([unquote(alias)|unquote(t)])
    end
  end
  defp tear_alias(other), do: other
end
