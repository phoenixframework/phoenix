defmodule Phoenix.Endpoint do
  @moduledoc ~S"""
  Defines a Phoenix endpoint.

  The endpoint is the boundary where all requests to your
  web application start. It is also the interface your
  application provides to the underlying web servers.

  Overall, an endpoint has three responsibilities:

    * to provide a wrapper for starting and stopping the
      endpoint as part of a supervision tree;

    * to define an initial plug pipeline for requests
      to pass through;

    * to host web specific configuration for your
      application.

  ## Endpoints

  An endpoint is simply a module defined with the help
  of `Phoenix.Endpoint`. If you have used the `mix phx.new`
  generator, an endpoint was automatically generated as
  part of your application:

      defmodule YourApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :your_app

        # plug ...
        # plug ...

        plug YourApp.Router
      end

  Endpoints must be explicitly started as part of your application
  supervision tree. Endpoints are added by default
  to the supervision tree in generated applications. Endpoints can be
  added to the supervision tree as follows:

      supervisor(YourApp.Endpoint, [])

  ### Endpoint configuration

  All endpoints are configured in your application environment.
  For example:

      config :your_app, YourApp.Endpoint,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Endpoint configuration is split into two categories. Compile-time
  configuration means the configuration is read during compilation
  and changing it at runtime has no effect. The compile-time
  configuration is mostly related to error handling and instrumentation.

  Runtime configuration, instead, is accessed during or
  after your application is started and can be read through the
  `c:config/2` function:

      YourApp.Endpoint.config(:port)
      YourApp.Endpoint.config(:some_config, :default_value)

  ### Dynamic configuration

  For dynamically configuring the endpoint, such as loading data
  from environment variables or configuration files, Phoenix invokes
  the `init/2` callback on the endpoint, passing a `:supervivsor`
  atom as first argument and the endpoint configuration as second.

  All of Phoenix configuration, except the Compile-time configuration
  below can be set dynamically from the `c:init/2` callback.

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

          [view: MyApp.ErrorView, accepts: ~w(html), layout: false]

      The default format is used when none is set in the connection.

    * `:instrumenters` - a list of instrumenter modules whose callbacks will
      be fired on instrumentation events. Read more on instrumentation in the
      "Instrumentation" section below.

  ### Runtime configuration

    * `:cache_static_manifest` - a path to a json manifest file that contains
      static files and their digested version. This is typically set to
      "priv/static/cache_manifest.json" which is the file automatically generated
      by `mix phx.digest`.

    * `:check_origin` - configure transports to check origins or not. May
      be false, true or a list of hosts that are allowed. Hosts also support
      wildcards. For example:

          check_origin: ["//phoenixframework.org", "//*.example.com"]

    * `:http` - the configuration for the HTTP server. Currently uses
      Cowboy and accepts all options as defined by
      [`Plug.Adapters.Cowboy`](https://hexdocs.pm/plug/Plug.Adapters.Cowboy.html).
      Defaults to `false`.

    * `:https` - the configuration for the HTTPS server. Currently uses
      Cowboy and accepts all options as defined by
      [`Plug.Adapters.Cowboy`](https://hexdocs.pm/plug/Plug.Adapters.Cowboy.html).
      Defaults to `false`.

    * `:force_ssl` - ensures no data is ever sent via http, always redirecting
      to https. It expects a list of options which are forwarded to `Plug.SSL`.
      By defalts it sets the "strict-transport-security" header in https requests,
      forcing browsers to always use https. If an unsafe request (http) is sent,
      it redirects to the https version using the `:host` specified in the `:url`
      configuration. To dynamically redirect to the `host` of the current request,
      `:host` must be set `nil`.

    * `:secret_key_base` - a secret key used as a base to generate secrets
      for encrypting and signing data. For example, cookies and tokens
      are signed by default, but they may also be encrypted if desired.
      Defaults to `nil` as it must be set per application.

    * `:server` - when `true`, starts the web server when the endpoint
      supervision tree starts. Defaults to `false`. The `mix phx.server`
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

      The `:host` option requires a string or `{:system, "ENV_VAR"}`. Similar
      to `:port`, when given a tuple like `{:system, "HOST"}`, the host
      will be referenced from `System.get_env("HOST")` at runtime.

    * `:static_url` - configuration for generating URLs for static files.
      It will fallback to `url` if no option is provided. Accepts the same
      options as `url`.

    * `:watchers` - a set of watchers to run alongside your server. It
      expects a list of tuples containing the executable and its arguments.
      Watchers are guaranteed to run in the application directory, but only
      when the server is enabled. For example, the watcher below will run
      the "watch" mode of the brunch build tool when the server starts.
      You can configure it to whatever build tool or command you want:

          [node: ["node_modules/brunch/bin/brunch", "watch"]]

      The `:cd` option can be used on a watcher to override the folder from 
      which the watcher will run. By default this will be the project's root:
      `File.cwd!()`

          [node: ["node_Modules/brunch/bin/brunch", "watch", cd: "my_frontend"]]

    * `:live_reload` - configuration for the live reload option.
      Configuration requires a `:patterns` option which should be a list of
      file patterns to watch. When these files change, it will trigger a reload.
      If you are using a tool like [pow](http://pow.cx) in development,
      you may need to set the `:url` option appropriately.

          live_reload: [
            url: "ws://localhost:4000",
            patterns: [
              ~r{priv/static/.*(js|css|png|jpeg|jpg|gif)$},
              ~r{web/views/.*(ex)$},
              ~r{web/templates/.*(eex)$}
            ]
          ]

    * `:pubsub` - configuration for this endpoint's pubsub adapter.
      Configuration either requires a `:name` of the registered pubsub
      server or a `:name` and `:adapter` pair. The pubsub name and adapter
      are compile time configuration, while the remaining options are runtime.
      The given adapter and name pair will be started as part of the supervision
      tree. If no adapter is specified, the pubsub system will work by sending
      events and subscribing to the given name. Defaults to:

          [adapter: Phoenix.PubSub.PG2, name: MyApp.PubSub]

      It also supports custom adapter configuration:

          [name: :my_pubsub, adapter: Phoenix.PubSub.Redis,
           host: "192.168.100.1"]

  ## Endpoint API

  In the previous section, we have used the `c:config/2` function that is
  automatically generated in your endpoint. Here's a list of all the functions
  that are automatically defined in your endpoint:

    * for handling paths and URLs: `c:struct_url/0`, `c:url/0`, `c:path/1`,
      `c:static_url/0`, and `c:static_path/1`;
    * for handling channel subscriptions: `c:subscribe/2` and `c:unsubscribe/1`;
    * for broadcasting to channels: `c:broadcast/3`, `c:broadcast!/3`,
      `c:broadcast_from/4`, and `c:broadcast_from!/4`
    * for configuration: `c:start_link/0`, `c:config/2`, and `c:config_change/2`;
    * for instrumentation: `c:instrument/3`;
    * as required by the `Plug` behaviour: `c:Plug.init/1` and `c:Plug.call/2`.

  ## Instrumentation

  Phoenix supports instrumentation through an extensible API. Each endpoint
  defines an `c:instrument/3` macro that both users and Phoenix internals can call
  to instrument generic events. This macro is responsible for measuring the time
  it takes for the event to be processed and for notifying a list of interested
  instrumenter modules of this measurement.

  You can configure this list of instrumenter modules in the compile-time
  configuration of your endpoint. (see the `:instrumenters` option above). The
  way these modules express their interest in events is by exporting public
  functions where the name of each function is the name of an event. For
  example, if someone instruments the `:render_view` event, then each
  instrumenter module interested in that event will have to export
  `render_view/3`.

  ### Callbacks cycle

  The event callback sequence is:

    1. The event callback is called *before* the event happens (in this case,
       before the view is rendered) with the atom `:start` as the first
       argument; see the "Before clause" section below.
    2. The event occurs (in this case, the view is rendered).
    3. The same event callback is called again, this time with the atom `:stop`
       as the first argument; see the "After clause" section below.

  The second and third argument that each event callback takes depends on the
  callback being an "after" or a "before" callback i.e. it depends on the
  value of the first argument, `:start` or `:stop`. For this reason, most of
  the time you will want to define (at least) two separate clauses for each
  event callback, one for the "before" and one for the "after" callbacks.

  All event callbacks are run in the same process that calls the `c:instrument/3`
  macro; hence, instrumenters should be careful to avoid performing blocking actions.
  If an event callback fails in any way (exits, throws, or raises), it won't
  affect anything as the error is caught, but the failure will be logged. Note
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
      is happening (under `:function`). This information can be used arbitrarily
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
      instrumented function **in native units**.

    * `result_of_before_callback` is the return value of the "before" clause of
      the same `event_callback`. This is a means of passing data from the
      "before" clause to the "after" clause when instrumenting.

  The return value of each "before" event callback will be stored and passed to
  the corresponding "after" callback.

  ### Using instrumentation

  Each Phoenix endpoint defines its own `instrument/3` macro. This macro is
  called like this:

      require MyApp.Endpoint
      MyApp.Endpoint.instrument(:render_view, %{view: "index.html"}, fn ->
        # actual view rendering
      end)

  All the instrumenter modules that export a `render_view/3` function will be
  notified of the event so that they can perform their respective actions.

  ### Phoenix default events

  By default, Phoenix instruments the following events:

    * `:phoenix_controller_call` - it's the whole controller pipeline.
      The `%Plug.Conn{}` is passed as runtime metadata.
    * `:phoenix_controller_render` - the rendering of a view from a
      controller. The map of runtime metadata passed to instrumentation
      callbacks has the `:view` key - for the name of the view, e.g. `HexWeb.ErrorView`,
      the `:template` key - for the name of the template, e.g.,
      `"index.html"`, the `:format` key - for the format of the template, and
      the `:conn` key - containing the `%Plug.Conn{}`.
    * `:phoenix_channel_join` - the joining of a channel. The `%Phoenix.Socket{}`
      and join params are passed as runtime metadata via `:socket` and `:params`.
    * `:phoenix_channel_receive` - the receipt of an incoming message over a
      channel. The `%Phoenix.Socket{}`, payload, event, and ref are passed as
      runtime metadata via `:socket`, `:params`, `:event`, and `:ref`.

  ### Dynamic instrumentation

  If you want to instrument a piece of code, but the endpoint that should
  instrument it (the one that contains the `c:instrument/3` macro you want to use)
  is not known at compile time, only at runtime, you can use the
  `Phoenix.Endpoint.instrument/4` macro. Refer to its documentation for more
  information.

  """

  @type topic :: String.t
  @type event :: String.t
  @type msg :: map

  # Configuration

  @doc """
  Starts the Endpoint supervision tree.

  Starts endpoint's configuration cache and possibly the servers for
  handling requests.
  """
  @callback start_link() :: Supervisor.on_start

  @doc """
  Access the endpoint configuration given by key.
  """
  @callback config(key :: atom, default :: term) :: term

  @doc """
  Reload the endpoint configuration on application upgrades.
  """
  @callback config_change(changed :: term, removed :: term) :: term

  @doc """
  Initialize the endpoint configuration.

  Invoked when the endpoint supervisor starts, allows dynamically
  configuring the endpoint from system environment or other runtime sources.
  """
  @callback init(:supervisor, config :: Keyword.t) :: {:ok, Keyword.t}

  # Paths and URLs

  @doc """
  Generates the endpoint base URL, but as a `URI` struct.
  """
  @callback struct_url() :: URI.t

  @doc """
  Generates the endpoint base URL without any path information.
  """
  @callback url() :: String.t

  @doc """
  Generates the path information when routing to this endpoint.
  """
  @callback path(path :: String.t) :: String.t

  @doc """
  Geerates the static URL without any path information.
  """
  @callback static_url() :: String.t

  @doc """
  Generates a route to a static file in `priv/static`
  """
  @callback static_path(path :: String.t) :: String.t

  # Channels

  @doc """
  Subscribes the caller to the given topic.

  See `Phoenix.PubSub.subscribe/3` for options.
  """
  @callback subscribe(topic, opts :: Keyword.t) :: :ok | {:error, term}

  @doc """
  Unsubscribes the caller from the given topic.
  """
  @callback unsubscribe(topic) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic`.
  """
  @callback broadcast(topic, event, msg) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic`.

  Raises in case of failures.
  """
  @callback broadcast!(topic, event, msg) :: :ok | no_return

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic`.
  """
  @callback broadcast_from(from :: pid, topic, event, msg) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic`.

  Raises in case of failures.
  """
  @callback broadcast_from!(from :: pid, topic, event, msg) :: :ok | no_return

  # Instrumentation

  @doc """
  Allows instrumenting operation defined by `function`.

  `runtime_metadata` may be omitted and defaults to `nil`.

  Read more about instrumentation in the "Instrumentation" section.
  """
  @macrocallback instrument(instrument_event :: Macro.t, runtime_metadata :: Macro.t, funcion :: Macro.t) :: Macro.t

  @doc false
  defmacro __using__(opts) do
    quote do
      @behaviour Phoenix.Endpoint

      unquote(config(opts))
      unquote(pubsub())
      unquote(plug())
      unquote(server())
    end
  end

  defp config(opts) do
    quote do
      @otp_app unquote(opts)[:otp_app] || raise "endpoint expects :otp_app to be given"
      var!(config) = Phoenix.Endpoint.Supervisor.config(@otp_app, __MODULE__)
      var!(code_reloading?) = var!(config)[:code_reloader]

      # Avoid unused variable warnings
      _ = var!(code_reloading?)

      @doc false
      def init(_key, config) do
        {:ok, config}
      end

      defoverridable init: 2
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

      # TODO v2: Remove pid version
      @doc false
      def subscribe(pid, topic) when is_pid(pid) and is_binary(topic) do
        IO.warn "#{__MODULE__}.subscribe/2 is deprecated, please use subscribe/1"
        Phoenix.PubSub.subscribe(@pubsub_server, pid, topic, [])
      end
      def subscribe(pid, topic, opts) when is_pid(pid) and is_binary(topic) and is_list(opts) do
        Phoenix.PubSub.subscribe(@pubsub_server, pid, topic, opts)
      end
      def subscribe(topic) when is_binary(topic) do
        Phoenix.PubSub.subscribe(@pubsub_server, topic, [])
      end
      def subscribe(topic, opts) when is_binary(topic) and is_list(opts) do
        Phoenix.PubSub.subscribe(@pubsub_server, topic, opts)
      end

      # TODO v2: Remove pid version
      @doc false
      def unsubscribe(pid, topic) do
        IO.warn "#{__MODULE__}.unsubscribe/2 is deprecated, please use unsubscribe/1"
        Phoenix.PubSub.unsubscribe(@pubsub_server, topic)
      end
      def unsubscribe(topic) do
        Phoenix.PubSub.unsubscribe(@pubsub_server, topic)
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
      use Plug.Builder
      import Phoenix.Endpoint

      Module.register_attribute(__MODULE__, :phoenix_sockets, accumulate: true)

      if force_ssl = Phoenix.Endpoint.__force_ssl__(__MODULE__, var!(config)) do
        plug Plug.SSL, force_ssl
      end

      if var!(config)[:debug_errors] do
        use Plug.Debugger, otp_app: @otp_app, style: [
          primary: "#EB532D",
          logo: "data:image/png;base64,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"
        ]
      end

      # Compile after the debugger so we properly wrap it.
      @before_compile Phoenix.Endpoint
      @phoenix_render_errors var!(config)[:render_errors]
    end
  end

  defp server() do
    quote location: :keep, unquote: false do
      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      defoverridable child_spec: 1

      @doc """
      Starts the endpoint supervision tree.
      """
      def start_link(_opts \\ []) do
        Phoenix.Endpoint.Supervisor.start_link(@otp_app, __MODULE__)
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
        Phoenix.Endpoint.Supervisor.config_change(__MODULE__, changed, removed)
      end

      @doc """
      Generates the endpoint base URL without any path information.

      It uses the configuration under `:url` to generate such.
      """
      def url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_url__,
          &Phoenix.Endpoint.Supervisor.url/1)
      end

      @doc """
      Generates the static URL without any path information.

      It uses the configuration under `:static_url` to generate
      such. It falls back to `:url` if `:static_url` is not set.
      """
      def static_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_static_url__,
          &Phoenix.Endpoint.Supervisor.static_url/1)
      end

      @doc """
      Generates the endpoint base URL but as a `URI` struct.

      It uses the configuration under `:url` to generate such.
      Useful for manipulating the URL data and passing it to
      URL helpers.
      """
      def struct_url do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_struct_url__,
          &Phoenix.Endpoint.Supervisor.struct_url/1)
      end

      @doc """
      Returns the host for the given endpoint.
      """
      def host do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_host__,
          &Phoenix.Endpoint.Supervisor.host/1)
      end

      @doc """
      Generates the path information when routing to this endpoint.
      """
      def path(path) do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_path__,
          &Phoenix.Endpoint.Supervisor.path/1) <> path
      end

      @doc """
      Generates the script name.
      """
      def script_name do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_script_name__,
          &Phoenix.Endpoint.Supervisor.script_name/1)
      end

      @doc """
      Generates a route to a static file in `priv/static`.
      """
      def static_path(path) do
        Phoenix.Config.cache(__MODULE__, :__phoenix_static__,
                             &Phoenix.Endpoint.Supervisor.static_path/1) <>
        Phoenix.Config.cache(__MODULE__, {:__phoenix_static__, path},
                             &Phoenix.Endpoint.Supervisor.static_path(&1, path))
      end
    end
  end

  @doc false
  def __force_ssl__(module, config) do
    if force_ssl = config[:force_ssl] do
      host = force_ssl[:host] || config[:url][:host] || "localhost"

      if host == "localhost" do
        IO.puts :stderr, """
        warning: you have enabled :force_ssl but your host is currently set to localhost.
        Please configure your endpoint url host properly:

            config #{inspect module}, url: [host: "YOURHOST.com"]
        """
      end

      Keyword.put_new(force_ssl, :host, {module, :host, []})
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    sockets = Module.get_attribute(env.module, :phoenix_sockets)
    otp_app = Module.get_attribute(env.module, :otp_app)
    instrumentation = Phoenix.Endpoint.Instrument.definstrument(otp_app, env.module)

    quote do
      defoverridable [call: 2]

      # Inline render errors so we set the endpoint before calling it.
      def call(conn, opts) do
        conn = put_in conn.secret_key_base, config(:secret_key_base)
        conn = put_in conn.script_name, script_name()
        conn = Plug.Conn.put_private(conn, :phoenix_endpoint, __MODULE__)

        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e
          Phoenix.Endpoint.RenderErrors.__catch__(conn, kind, reason, stack, @phoenix_render_errors)
        catch
          kind, reason ->
            stack = System.stacktrace()
            Phoenix.Endpoint.RenderErrors.__catch__(conn, kind, reason, stack, @phoenix_render_errors)
        end
      end

      @doc """
      Returns all sockets configured in this endpoint.
      """
      def __sockets__, do: unquote(sockets)

      unquote(instrumentation)
    end
  end

  ## API

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

    * a module name - the endpoint itself
    * a `Plug.Conn` struct - this macro will look for the endpoint module in the
      `:private` field of the connection; if it's not there, `fun` will be
      executed with no instrumentation
    * a `Phoenix.Socket` struct - this macro will look for the endpoint module in the
      `:endpoint` field of the socket; if it's not there, `fun` will be
      executed with no instrumentation

  Usually, users should prefer to instrument events using the `c:instrument/3`
  macro defined in every Phoenix endpoint. This macro should only be used for
  cases when the endpoint is dynamic and not known at compile time.

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

  ## Examples

      iex> Phoenix.Endpoint.server?(:my_app, MyApp.Endpoint)
      true
  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    Phoenix.Endpoint.Supervisor.server?(otp_app, endpoint)
  end

  defp tear_alias({:__aliases__, meta, [h|t]}) do
    alias = {:__aliases__, meta, [h]}
    quote do
      Module.concat([unquote(alias)|unquote(t)])
    end
  end
  defp tear_alias(other), do: other
end

