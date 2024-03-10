defmodule Phoenix.Endpoint do
  @moduledoc ~S"""
  Defines a Phoenix endpoint.

  The endpoint is the boundary where all requests to your
  web application start. It is also the interface your
  application provides to the underlying web servers.

  Overall, an endpoint has three responsibilities:

    * to provide a wrapper for starting and stopping the
      endpoint as part of a supervision tree

    * to define an initial plug pipeline for requests
      to pass through

    * to host web specific configuration for your
      application

  ## Endpoints

  An endpoint is simply a module defined with the help
  of `Phoenix.Endpoint`. If you have used the `mix phx.new`
  generator, an endpoint was automatically generated as
  part of your application:

      defmodule YourAppWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :your_app

        # plug ...
        # plug ...

        plug YourApp.Router
      end

  Endpoints must be explicitly started as part of your application
  supervision tree. Endpoints are added by default
  to the supervision tree in generated applications. Endpoints can be
  added to the supervision tree as follows:

      children = [
        YourAppWeb.Endpoint
      ]

  ## Endpoint configuration

  All endpoints are configured in your application environment.
  For example:

      config :your_app, YourAppWeb.Endpoint,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Endpoint configuration is split into two categories. Compile-time
  configuration means the configuration is read during compilation
  and changing it at runtime has no effect. The compile-time
  configuration is mostly related to error handling.

  Runtime configuration, instead, is accessed during or
  after your application is started and can be read through the
  `c:config/2` function:

      YourAppWeb.Endpoint.config(:port)
      YourAppWeb.Endpoint.config(:some_config, :default_value)

  ### Compile-time configuration

  Compile-time configuration may be set on `config/dev.exs`, `config/prod.exs`
  and so on, but has no effect on `config/runtime.exs`:

    * `:code_reloader` - when `true`, enables code reloading functionality.
      For the list of code reloader configuration options see
      `Phoenix.CodeReloader.reload/1`. Keep in mind code reloading is
      based on the file-system, therefore it is not possible to run two
      instances of the same app at the same time with code reloading in
      development, as they will race each other and only one will effectively
      recompile the files. In such cases, tweak your config files so code
      reloading is enabled in only one of the apps or set the MIX_BUILD
      environment variable to give them distinct build directories

    * `:debug_errors` - when `true`, uses `Plug.Debugger` functionality for
      debugging failures in the application. Recommended to be set to `true`
      only in development as it allows listing of the application source
      code during debugging. Defaults to `false`

    * `:force_ssl` - ensures no data is ever sent via HTTP, always redirecting
      to HTTPS. It expects a list of options which are forwarded to `Plug.SSL`.
      By default it sets the "strict-transport-security" header in HTTPS requests,
      forcing browsers to always use HTTPS. If an unsafe request (HTTP) is sent,
      it redirects to the HTTPS version using the `:host` specified in the `:url`
      configuration. To dynamically redirect to the `host` of the current request,
      set `:host` in the `:force_ssl` configuration to `nil`

  ### Runtime configuration

  The configuration below may be set on `config/dev.exs`, `config/prod.exs`
  and so on, as well as on `config/runtime.exs`. Typically, if you need to
  configure them with system environment variables, you set them in
  `config/runtime.exs`. These options may also be set when starting the
  endpoint in your supervision tree, such as `{MyApp.Endpoint, options}`.

    * `:adapter` - which webserver adapter to use for serving web requests.
      See the "Adapter configuration" section below

    * `:cache_static_manifest` - a path to a json manifest file that contains
      static files and their digested version. This is typically set to
      "priv/static/cache_manifest.json" which is the file automatically generated
      by `mix phx.digest`. It can be either: a string containing a file system path
      or a tuple containing the application name and the path within that application.

    * `:cache_static_manifest_latest` - a map of the static files pointing to their
      digest version. This is automatically loaded from `cache_static_manifest` on
      boot. However, if you have your own static handling mechanism, you may want to
      set this value explicitly. This is used by projects such as `LiveView` to
      detect if the client is running on the latest version of all assets.

    * `:cache_manifest_skip_vsn` - when true, skips the appended query string
      "?vsn=d" when generating paths to static assets. This query string is used
      by `Plug.Static` to set long expiry dates, therefore, you should set this
      option to true only if you are not using `Plug.Static` to serve assets,
      for example, if you are using a CDN. If you are setting this option, you
      should also consider passing `--no-vsn` to `mix phx.digest`. Defaults to
      `false`.

    * `:check_origin` - configure the default `:check_origin` setting for
      transports. See `socket/3` for options. Defaults to `true`.

    * `:secret_key_base` - a secret key used as a base to generate secrets
      for encrypting and signing data. For example, cookies and tokens
      are signed by default, but they may also be encrypted if desired.
      Defaults to `nil` as it must be set per application

    * `:server` - when `true`, starts the web server when the endpoint
      supervision tree starts. Defaults to `false`. The `mix phx.server`
      task automatically sets this to `true`

    * `:url` - configuration for generating URLs throughout the app.
      Accepts the `:host`, `:scheme`, `:path` and `:port` options. All
      keys except `:path` can be changed at runtime. Defaults to:

          [host: "localhost", path: "/"]

      The `:port` option requires either an integer or string. The `:host`
      option requires a string.

      The `:scheme` option accepts `"http"` and `"https"` values. Default value
      is inferred from top level `:http` or `:https` option. It is useful
      when hosting Phoenix behind a load balancer or reverse proxy and
      terminating SSL there.

      The `:path` option can be used to override root path. Useful when hosting
      Phoenix behind a reverse proxy with URL rewrite rules

    * `:static_url` - configuration for generating URLs for static files.
      It will fallback to `url` if no option is provided. Accepts the same
      options as `url`

    * `:watchers` - a set of watchers to run alongside your server. It
      expects a list of tuples containing the executable and its arguments.
      Watchers are guaranteed to run in the application directory, but only
      when the server is enabled (unless `:force_watchers` configuration is
      set to `true`). For example, the watcher below will run the "watch" mode
      of the webpack build tool when the server starts. You can configure it
      to whatever build tool or command you want:

          [
            node: [
              "node_modules/webpack/bin/webpack.js",
              "--mode",
              "development",
              "--watch",
              "--watch-options-stdin"
            ]
          ]

      The `:cd` and `:env` options can be given at the end of the list to customize
      the watcher:

          [node: [..., cd: "assets", env: [{"TAILWIND_MODE", "watch"}]]]

      A watcher can also be a module-function-args tuple that will be invoked accordingly:

          [another: {Mod, :fun, [arg1, arg2]}]

    * `:force_watchers` - when `true`, forces your watchers to start
      even when the `:server` option is set to `false`.

    * `:live_reload` - configuration for the live reload option.
      Configuration requires a `:patterns` option which should be a list of
      file patterns to watch. When these files change, it will trigger a reload.

          live_reload: [
            url: "ws://localhost:4000",
            patterns: [
              ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
              ~r"lib/app_web/(live|views)/.*(ex)$",
              ~r"lib/app_web/templates/.*(eex)$"
            ]
          ]

    * `:pubsub_server` - the name of the pubsub server to use in channels
      and via the Endpoint broadcast functions. The PubSub server is typically
      started in your supervision tree.

    * `:render_errors` - responsible for rendering templates whenever there
      is a failure in the application. For example, if the application crashes
      with a 500 error during a HTML request, `render("500.html", assigns)`
      will be called in the view given to `:render_errors`.
      A `:formats` list can be provided to specify a module per format to handle
      error rendering. Example:

          [formats: [html: MyApp.ErrorHTML], layout: false, log: :debug]

    * `:log_access_url` - log the access url once the server boots

  Note that you can also store your own configurations in the Phoenix.Endpoint.
  For example, [Phoenix LiveView](https://hexdocs.pm/phoenix_live_view) expects
  its own configuration under the `:live_view` key. In such cases, you should
  consult the documentation of the respective projects.

  ### Adapter configuration

  Phoenix allows you to choose which webserver adapter to use. Newly generated
  applications created via the `phx.new` Mix task use the
  [`Bandit`](https://github.com/mtrudel/bandit) webserver via the
  `Bandit.PhoenixAdapter` adapter. If not otherwise specified via the `adapter`
  option Phoenix will fall back to the `Phoenix.Endpoint.Cowboy2Adapter` for
  backwards compatibility with applications generated prior to Phoenix 1.7.8.

  Both adapters can be configured in a similar manner using the following two
  top-level options:

    * `:http` - the configuration for the HTTP server. It accepts all options
      as defined by either [`Bandit`](https://hexdocs.pm/bandit/Bandit.html#t:options/0)
      or [`Plug.Cowboy`](https://hexdocs.pm/plug_cowboy/) depending on your
      choice of adapter. Defaults to `false`

    * `:https` - the configuration for the HTTPS server. It accepts all options
      as defined by either [`Bandit`](https://hexdocs.pm/bandit/Bandit.html#t:options/0)
      or [`Plug.Cowboy`](https://hexdocs.pm/plug_cowboy/) depending on your
      choice of adapter. Defaults to `false`

  In addition, the connection draining can be configured for the Cowboy webserver via the following
  top-level option (this is not required for Bandit as it has connection draining built-in):

    * `:drainer` - a drainer process waits for any on-going request to finish
      during application shutdown. It accepts the `:shutdown` and
      `:check_interval` options as defined by `Plug.Cowboy.Drainer`.
      Note the draining does not terminate any existing connection, it simply
      waits for them to finish. Socket connections run their own drainer
      before this one is invoked. That's because sockets are stateful and
      can be gracefully notified, which allows us to stagger them over a
      longer period of time. See the documentation for `socket/3` for more
      information

  ## Endpoint API

  In the previous section, we have used the `c:config/2` function that is
  automatically generated in your endpoint. Here's a list of all the functions
  that are automatically defined in your endpoint:

    * for handling paths and URLs: `c:struct_url/0`, `c:url/0`, `c:path/1`,
      `c:static_url/0`,`c:static_path/1`, and `c:static_integrity/1`

    * for gathering runtime information about the address and port the
      endpoint is running on: `c:server_info/1`

    * for broadcasting to channels: `c:broadcast/3`, `c:broadcast!/3`,
      `c:broadcast_from/4`, `c:broadcast_from!/4`, `c:local_broadcast/3`,
      and `c:local_broadcast_from/4`

    * for configuration: `c:start_link/1`, `c:config/2`, and `c:config_change/2`

    * as required by the `Plug` behaviour: `c:Plug.init/1` and `c:Plug.call/2`

  """

  @type topic :: String.t()
  @type event :: String.t()
  @type msg :: map | {:binary, binary}

  require Logger

  # Configuration

  @doc """
  Starts the endpoint supervision tree.

  Starts endpoint's configuration cache and possibly the servers for
  handling requests.
  """
  @callback start_link(keyword) :: Supervisor.on_start()

  @doc """
  Access the endpoint configuration given by key.
  """
  @callback config(key :: atom, default :: term) :: term

  @doc """
  Reload the endpoint configuration on application upgrades.
  """
  @callback config_change(changed :: term, removed :: term) :: term

  # Paths and URLs

  @doc """
  Generates the endpoint base URL, but as a `URI` struct.
  """
  @callback struct_url() :: URI.t()

  @doc """
  Generates the endpoint base URL without any path information.
  """
  @callback url() :: String.t()

  @doc """
  Generates the path information when routing to this endpoint.
  """
  @callback path(path :: String.t()) :: String.t()

  @doc """
  Generates the static URL without any path information.
  """
  @callback static_url() :: String.t()

  @doc """
  Generates a route to a static file in `priv/static`.
  """
  @callback static_path(path :: String.t()) :: String.t()

  @doc """
  Generates an integrity hash to a static file in `priv/static`.
  """
  @callback static_integrity(path :: String.t()) :: String.t() | nil

  @doc """
  Generates a two item tuple containing the `static_path` and `static_integrity`.
  """
  @callback static_lookup(path :: String.t()) :: {String.t(), String.t()} | {String.t(), nil}

  @doc """
  Returns the script name from the :url configuration.
  """
  @callback script_name() :: [String.t()]

  @doc """
  Returns the host from the :url configuration.
  """
  @callback host() :: String.t()

  # Server information

  @doc """
  Returns the address and port that the server is running on
  """
  @callback server_info(Plug.Conn.scheme()) ::
              {:ok, {:inet.ip_address(), :inet.port_number()} | :inet.returned_non_ip_address()}
              | {:error, term()}

  # Channels

  @doc """
  Subscribes the caller to the given topic.

  See `Phoenix.PubSub.subscribe/3` for options.
  """
  @callback subscribe(topic, opts :: Keyword.t()) :: :ok | {:error, term}

  @doc """
  Unsubscribes the caller from the given topic.
  """
  @callback unsubscribe(topic) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` to all nodes.
  """
  @callback broadcast(topic, event, msg) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` to all nodes.

  Raises in case of failures.
  """
  @callback broadcast!(topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` to all nodes.
  """
  @callback broadcast_from(from :: pid, topic, event, msg) :: :ok | {:error, term}

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` to all nodes.

  Raises in case of failures.
  """
  @callback broadcast_from!(from :: pid, topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` as `event` in the given `topic` within the current node.
  """
  @callback local_broadcast(topic, event, msg) :: :ok

  @doc """
  Broadcasts a `msg` from the given `from` as `event` in the given `topic` within the current node.
  """
  @callback local_broadcast_from(from :: pid, topic, event, msg) :: :ok

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
      @otp_app unquote(opts)[:otp_app] || raise("endpoint expects :otp_app to be given")
      var!(config) = Phoenix.Endpoint.Supervisor.config(@otp_app, __MODULE__)
      var!(code_reloading?) = var!(config)[:code_reloader]

      # Avoid unused variable warnings
      _ = var!(code_reloading?)
    end
  end

  defp pubsub() do
    quote do
      def subscribe(topic, opts \\ []) when is_binary(topic) do
        Phoenix.PubSub.subscribe(pubsub_server!(), topic, opts)
      end

      def unsubscribe(topic) do
        Phoenix.PubSub.unsubscribe(pubsub_server!(), topic)
      end

      def broadcast_from(from, topic, event, msg) do
        Phoenix.Channel.Server.broadcast_from(pubsub_server!(), from, topic, event, msg)
      end

      def broadcast_from!(from, topic, event, msg) do
        Phoenix.Channel.Server.broadcast_from!(pubsub_server!(), from, topic, event, msg)
      end

      def broadcast(topic, event, msg) do
        Phoenix.Channel.Server.broadcast(pubsub_server!(), topic, event, msg)
      end

      def broadcast!(topic, event, msg) do
        Phoenix.Channel.Server.broadcast!(pubsub_server!(), topic, event, msg)
      end

      def local_broadcast(topic, event, msg) do
        Phoenix.Channel.Server.local_broadcast(pubsub_server!(), topic, event, msg)
      end

      def local_broadcast_from(from, topic, event, msg) do
        Phoenix.Channel.Server.local_broadcast_from(pubsub_server!(), from, topic, event, msg)
      end

      defp pubsub_server! do
        config(:pubsub_server) ||
          raise ArgumentError, "no :pubsub_server configured for #{inspect(__MODULE__)}"
      end
    end
  end

  defp plug() do
    quote location: :keep do
      use Plug.Builder, init_mode: Phoenix.plug_init_mode()
      import Phoenix.Endpoint

      Module.register_attribute(__MODULE__, :phoenix_sockets, accumulate: true)

      if force_ssl = Phoenix.Endpoint.__force_ssl__(__MODULE__, var!(config)) do
        plug Plug.SSL, force_ssl
      end

      if var!(config)[:debug_errors] do
        use Plug.Debugger,
          otp_app: @otp_app,
          banner: {Phoenix.Endpoint.RenderErrors, :__debugger_banner__, []},
          style: [
            primary: "#EB532D",
            logo:
              "data:image/svg+xml;base64,PHN2ZyB2aWV3Qm94PSIwIDAgNzEgNDgiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiPgoJPHBhdGggZD0ibTI2LjM3MSAzMy40NzctLjU1Mi0uMWMtMy45Mi0uNzI5LTYuMzk3LTMuMS03LjU3LTYuODI5LS43MzMtMi4zMjQuNTk3LTQuMDM1IDMuMDM1LTQuMTQ4IDEuOTk1LS4wOTIgMy4zNjIgMS4wNTUgNC41NyAyLjM5IDEuNTU3IDEuNzIgMi45ODQgMy41NTggNC41MTQgNS4zMDUgMi4yMDIgMi41MTUgNC43OTcgNC4xMzQgOC4zNDcgMy42MzQgMy4xODMtLjQ0OCA1Ljk1OC0xLjcyNSA4LjM3MS0zLjgyOC4zNjMtLjMxNi43NjEtLjU5MiAxLjE0NC0uODg2bC0uMjQxLS4yODRjLTIuMDI3LjYzLTQuMDkzLjg0MS02LjIwNS43MzUtMy4xOTUtLjE2LTYuMjQtLjgyOC04Ljk2NC0yLjU4Mi0yLjQ4Ni0xLjYwMS00LjMxOS0zLjc0Ni01LjE5LTYuNjExLS43MDQtMi4zMTUuNzM2LTMuOTM0IDMuMTM1LTMuNi45NDguMTMzIDEuNzQ2LjU2IDIuNDYzIDEuMTY1LjU4My40OTMgMS4xNDMgMS4wMTUgMS43MzggMS40OTMgMi44IDIuMjUgNi43MTIgMi4zNzUgMTAuMjY1LS4wNjgtNS44NDItLjAyNi05LjgxNy0zLjI0LTEzLjMwOC03LjMxMy0xLjM2Ni0xLjU5NC0yLjctMy4yMTYtNC4wOTUtNC43ODUtMi42OTgtMy4wMzYtNS42OTItNS43MS05Ljc5LTYuNjIzQzEyLjgtLjYyMyA3Ljc0NS4xNCAyLjg5MyAyLjM2MSAxLjkyNiAyLjgwNC45OTcgMy4zMTkgMCA0LjE0OWMuNDk0IDAgLjc2My4wMDYgMS4wMzIgMCAyLjQ0Ni0uMDY0IDQuMjggMS4wMjMgNS42MDIgMy4wMjQuOTYyIDEuNDU3IDEuNDE1IDMuMTA0IDEuNzYxIDQuNzk4LjUxMyAyLjUxNS4yNDcgNS4wNzguNTQ0IDcuNjA1Ljc2MSA2LjQ5NCA0LjA4IDExLjAyNiAxMC4yNiAxMy4zNDYgMi4yNjcuODUyIDQuNTkxIDEuMTM1IDcuMTcyLjU1NVpNMTAuNzUxIDMuODUyYy0uOTc2LjI0Ni0xLjc1Ni0uMTQ4LTIuNTYtLjk2MiAxLjM3Ny0uMzQzIDIuNTkyLS40NzYgMy44OTctLjUyOC0uMTA3Ljg0OC0uNjA3IDEuMzA2LTEuMzM2IDEuNDlabTMyLjAwMiAzNy45MjRjLS4wODUtLjYyNi0uNjItLjkwMS0xLjA0LTEuMjI4LTEuODU3LTEuNDQ2LTQuMDMtMS45NTgtNi4zMzMtMi0xLjM3NS0uMDI2LTIuNzM1LS4xMjgtNC4wMzEtLjYxLS41OTUtLjIyLTEuMjYtLjUwNS0xLjI0NC0xLjI3Mi4wMTUtLjc4LjY5My0xIDEuMzEtMS4xODQuNTA1LS4xNSAxLjAyNi0uMjQ3IDEuNi0uMzgyLTEuNDYtLjkzNi0yLjg4Ni0xLjA2NS00Ljc4Ny0uMy0yLjk5MyAxLjIwMi01Ljk0MyAxLjA2LTguOTI2LS4wMTctMS42ODQtLjYwOC0zLjE3OS0xLjU2My00LjczNS0yLjQwOGwtLjA0My4wM2EyLjk2IDIuOTYgMCAwIDAgLjA0LS4wMjljLS4wMzgtLjExNy0uMTA3LS4xMi0uMTk3LS4wNTRsLjEyMi4xMDdjMS4yOSAyLjExNSAzLjAzNCAzLjgxNyA1LjAwNCA1LjI3MSAzLjc5MyAyLjggNy45MzYgNC40NzEgMTIuNzg0IDMuNzNBNjYuNzE0IDY2LjcxNCAwIDAgMSAzNyA0MC44NzdjMS45OC0uMTYgMy44NjYuMzk4IDUuNzUzLjg5OVptLTkuMTQtMzAuMzQ1Yy0uMTA1LS4wNzYtLjIwNi0uMjY2LS40Mi0uMDY5IDEuNzQ1IDIuMzYgMy45ODUgNC4wOTggNi42ODMgNS4xOTMgNC4zNTQgMS43NjcgOC43NzMgMi4wNyAxMy4yOTMuNTEgMy41MS0xLjIxIDYuMDMzLS4wMjggNy4zNDMgMy4zOC4xOS0zLjk1NS0yLjEzNy02LjgzNy01Ljg0My03LjQwMS0yLjA4NC0uMzE4LTQuMDEuMzczLTUuOTYyLjk0LTUuNDM0IDEuNTc1LTEwLjQ4NS43OTgtMTUuMDk0LTIuNTUzWm0yNy4wODUgMTUuNDI1Yy43MDguMDU5IDEuNDE2LjEyMyAyLjEyNC4xODUtMS42LTEuNDA1LTMuNTUtMS41MTctNS41MjMtMS40MDQtMy4wMDMuMTctNS4xNjcgMS45MDMtNy4xNCAzLjk3Mi0xLjczOSAxLjgyNC0zLjMxIDMuODctNS45MDMgNC42MDQuMDQzLjA3OC4wNTQuMTE3LjA2Ni4xMTcuMzUuMDA1LjY5OS4wMjEgMS4wNDcuMDA1IDMuNzY4LS4xNyA3LjMxNy0uOTY1IDEwLjE0LTMuNy44OS0uODYgMS42ODUtMS44MTcgMi41NDQtMi43MS43MTYtLjc0NiAxLjU4NC0xLjE1OSAyLjY0NS0xLjA3Wm0tOC43NTMtNC42N2MtMi44MTIuMjQ2LTUuMjU0IDEuNDA5LTcuNTQ4IDIuOTQzLTEuNzY2IDEuMTgtMy42NTQgMS43MzgtNS43NzYgMS4zNy0uMzc0LS4wNjYtLjc1LS4xMTQtMS4xMjQtLjE3bC0uMDEzLjE1NmMuMTM1LjA3LjI2NS4xNTEuNDA1LjIwNy4zNTQuMTQuNzAyLjMwOCAxLjA3LjM5NSA0LjA4My45NzEgNy45OTIuNDc0IDExLjUxNi0xLjgwMyAyLjIyMS0xLjQzNSA0LjUyMS0xLjcwNyA3LjAxMy0xLjMzNi4yNTIuMDM4LjUwMy4wODMuNzU2LjEwNy4yMzQuMDIyLjQ3OS4yNTUuNzk1LjAwMy0yLjE3OS0xLjU3NC00LjUyNi0yLjA5Ni03LjA5NC0xLjg3MlptLTEwLjA0OS05LjU0NGMxLjQ3NS4wNTEgMi45NDMtLjE0MiA0LjQ4Ni0xLjA1OS0uNDUyLjA0LS42NDMuMDQtLjgyNy4wNzYtMi4xMjYuNDI0LTQuMDMzLS4wNC01LjczMy0xLjM4My0uNjIzLS40OTMtMS4yNTctLjk3NC0xLjg4OS0xLjQ1Ny0yLjUwMy0xLjkxNC01LjM3NC0yLjU1NS04LjUxNC0yLjUuMDUuMTU0LjA1NC4yNi4xMDguMzE1IDMuNDE3IDMuNDU1IDcuMzcxIDUuODM2IDEyLjM2OSA2LjAwOFptMjQuNzI3IDE3LjczMWMtMi4xMTQtMi4wOTctNC45NTItMi4zNjctNy41NzgtLjUzNyAxLjczOC4wNzggMy4wNDMuNjMyIDQuMTAxIDEuNzI4LjM3NC4zODguNzYzLjc2OCAxLjE4MiAxLjEwNiAxLjYgMS4yOSA0LjMxMSAxLjM1MiA1Ljg5Ni4xNTUtMS44NjEtLjcyNi0xLjg2MS0uNzI2LTMuNjAxLTIuNDUyWm0tMjEuMDU4IDE2LjA2Yy0xLjg1OC0zLjQ2LTQuOTgxLTQuMjQtOC41OS00LjAwOGE5LjY2NyA5LjY2NyAwIDAgMSAyLjk3NyAxLjM5Yy44NC41ODYgMS41NDcgMS4zMTEgMi4yNDMgMi4wNTUgMS4zOCAxLjQ3MyAzLjUzNCAyLjM3NiA0Ljk2MiAyLjA3LS42NTYtLjQxMi0xLjIzOC0uODQ4LTEuNTkyLTEuNTA3Wm0xNy4yOS0xOS4zMmMwLS4wMjMuMDAxLS4wNDUuMDAzLS4wNjhsLS4wMDYuMDA2LjAwNi0uMDA2LS4wMzYtLjAwNC4wMjEuMDE4LjAxMi4wNTNabS0yMCAxNC43NDRhNy42MSA3LjYxIDAgMCAwLS4wNzItLjA0MS4xMjcuMTI3IDAgMCAwIC4wMTUuMDQzYy4wMDUuMDA4LjAzOCAwIC4wNTgtLjAwMlptLS4wNzItLjA0MS0uMDA4LS4wMzQtLjAwOC4wMS4wMDgtLjAxLS4wMjItLjAwNi4wMDUuMDI2LjAyNC4wMTRaIgogICAgICAgICAgICBmaWxsPSIjRkQ0RjAwIiAvPgo8L3N2Zz4K"
          ]
      end

      plug :socket_dispatch

      # Compile after the debugger so we properly wrap it.
      @before_compile Phoenix.Endpoint
    end
  end

  defp server() do
    quote location: :keep, unquote: false do
      @doc """
      Returns the child specification to start the endpoint
      under a supervision tree.
      """
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      @doc """
      Starts the endpoint supervision tree.

      All other options are merged into the endpoint configuration.
      """
      def start_link(opts \\ []) do
        Phoenix.Endpoint.Supervisor.start_link(@otp_app, __MODULE__, opts)
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

      defp persistent!() do
        :persistent_term.get({Phoenix.Endpoint, __MODULE__}, nil) ||
          raise "could not find persistent term for endpoint #{inspect(__MODULE__)}. Make sure your endpoint is started and note you cannot access endpoint functions at compile-time"
      end

      @doc """
      Generates the endpoint base URL without any path information.

      It uses the configuration under `:url` to generate such.
      """
      def url, do: persistent!().url

      @doc """
      Generates the static URL without any path information.

      It uses the configuration under `:static_url` to generate
      such. It falls back to `:url` if `:static_url` is not set.
      """
      def static_url, do: persistent!().static_url

      @doc """
      Generates the endpoint base URL but as a `URI` struct.

      It uses the configuration under `:url` to generate such.
      Useful for manipulating the URL data and passing it to
      URL helpers.
      """
      def struct_url, do: persistent!().struct_url

      @doc """
      Returns the host for the given endpoint.
      """
      def host, do: persistent!().host

      @doc """
      Generates the path information when routing to this endpoint.
      """
      def path(path), do: persistent!().path <> path

      @doc """
      Generates the script name.
      """
      def script_name, do: persistent!().script_name

      @doc """
      Generates a route to a static file in `priv/static`.
      """
      def static_path(path) do
        prefix = persistent!().static_path

        case :binary.split(path, "#") do
          [path, fragment] -> prefix <> elem(static_lookup(path), 0) <> "#" <> fragment
          [path] -> prefix <> elem(static_lookup(path), 0)
        end
      end

      @doc """
      Generates a base64-encoded cryptographic hash (sha512) to a static file
      in `priv/static`. Meant to be used for Subresource Integrity with CDNs.
      """
      def static_integrity(path), do: elem(static_lookup(path), 1)

      @doc """
      Returns a two item tuple with the first item being the `static_path`
      and the second item being the `static_integrity`.
      """
      def static_lookup(path) do
        Phoenix.Config.cache(
          __MODULE__,
          {:__phoenix_static__, path},
          &Phoenix.Endpoint.Supervisor.static_lookup(&1, path)
        )
      end

      @doc """
      Returns the address and port that the server is running on
      """
      def server_info(scheme), do: config(:adapter).server_info(__MODULE__, scheme)
    end
  end

  @doc false
  def __force_ssl__(module, config) do
    if force_ssl = config[:force_ssl] do
      Keyword.put_new(force_ssl, :host, {module, :host, []})
    end
  end

  @doc false
  defmacro __before_compile__(%{module: module}) do
    sockets = Module.get_attribute(module, :phoenix_sockets)

    dispatches =
      for {path, socket, socket_opts} <- sockets,
          {path, plug, conn_ast, plug_opts} <- socket_paths(module, path, socket, socket_opts) do
        quote do
          defp do_socket_dispatch(unquote(path), conn) do
            halt(unquote(plug).call(unquote(conn_ast), unquote(Macro.escape(plug_opts))))
          end
        end
      end

    quote do
      defoverridable call: 2

      # Inline render errors so we set the endpoint before calling it.
      def call(conn, opts) do
        conn = %{conn | script_name: script_name(), secret_key_base: config(:secret_key_base)}
        conn = Plug.Conn.put_private(conn, :phoenix_endpoint, __MODULE__)

        try do
          super(conn, opts)
        rescue
          e in Plug.Conn.WrapperError ->
            %{conn: conn, kind: kind, reason: reason, stack: stack} = e

            Phoenix.Endpoint.RenderErrors.__catch__(
              conn,
              kind,
              reason,
              stack,
              config(:render_errors)
            )
        catch
          kind, reason ->
            stack = __STACKTRACE__

            Phoenix.Endpoint.RenderErrors.__catch__(
              conn,
              kind,
              reason,
              stack,
              config(:render_errors)
            )
        end
      end

      @doc false
      def __sockets__, do: unquote(Macro.escape(sockets))

      @doc false
      def socket_dispatch(%{path_info: path} = conn, _opts), do: do_socket_dispatch(path, conn)
      unquote(dispatches)
      defp do_socket_dispatch(_path, conn), do: conn
    end
  end

  defp socket_paths(endpoint, path, socket, opts) do
    paths = []
    websocket = Keyword.get(opts, :websocket, true)
    longpoll = Keyword.get(opts, :longpoll, false)

    paths =
      if websocket do
        config = Phoenix.Socket.Transport.load_config(websocket, Phoenix.Transports.WebSocket)
        plug_init = {endpoint, socket, config}
        {conn_ast, match_path} = socket_path(path, config)
        [{match_path, Phoenix.Transports.WebSocket, conn_ast, plug_init} | paths]
      else
        paths
      end

    paths =
      if longpoll do
        config = Phoenix.Socket.Transport.load_config(longpoll, Phoenix.Transports.LongPoll)
        plug_init = {endpoint, socket, config}
        {conn_ast, match_path} = socket_path(path, config)
        [{match_path, Phoenix.Transports.LongPoll, conn_ast, plug_init} | paths]
      else
        paths
      end

    paths
  end

  defp socket_path(path, config) do
    end_path_fragment = Keyword.fetch!(config, :path)

    {vars, path} =
      String.split(path <> "/" <> end_path_fragment, "/", trim: true)
      |> Enum.join("/")
      |> Plug.Router.Utils.build_path_match()

    conn_ast =
      if vars == [] do
        quote do
          conn
        end
      else
        params =
          for var <- vars,
              param = Atom.to_string(var),
              not match?("_" <> _, param),
              do: {param, Macro.var(var, nil)}

        quote do
          params = %{unquote_splicing(params)}
          %Plug.Conn{conn | path_params: params, params: params}
        end
      end

    {conn_ast, path}
  end

  ## API

  @doc """
  Defines a websocket/longpoll mount-point for a `socket`.

  It expects a `path`, a `socket` module, and a set of options.
  The socket module is typically defined with `Phoenix.Socket`.

  Both websocket and longpolling connections are supported out
  of the box.

  ## Options

    * `:websocket` - controls the websocket configuration.
      Defaults to `true`. May be false or a keyword list
      of options. See ["Common configuration"](#socket/3-common-configuration)
      and ["WebSocket configuration"](#socket/3-websocket-configuration)
      for the whole list

    * `:longpoll` - controls the longpoll configuration.
      Defaults to `false`. May be true or a keyword list
      of options. See ["Common configuration"](#socket/3-common-configuration)
      and ["Longpoll configuration"](#socket/3-longpoll-configuration)
      for the whole list

    * `:drainer` - a keyword list or a custom MFA function returning a keyword list, for example:

          {MyAppWeb.Socket, :drainer_configuration, []}

      configuring how to drain sockets on application shutdown.
      The goal is to notify all channels (and
      LiveViews) clients to reconnect. The supported options are:

      * `:batch_size` - How many clients to notify at once in a given batch.
        Defaults to 10000.
      * `:batch_interval` - The amount of time in milliseconds given for a
        batch to terminate. Defaults to 2000ms.
      * `:shutdown` - The maximum amount of time in milliseconds allowed
        to drain all batches. Defaults to 30000ms.

      For example, if you have 150k connections, the default values will
      split them into 15 batches of 10k connections. Each batch takes
      2000ms before the next batch starts. In this case, we will do everything
      right under the maximum shutdown time of 30000ms. Therefore, as
      you increase the number of connections, remember to adjust the shutdown
      accordingly. Finally, after the socket drainer runs, the lower level
      HTTP/HTTPS connection drainer will still run, and apply to all connections.
      Set it to `false` to disable draining.

  You can also pass the options below on `use Phoenix.Socket`.
  The values specified here override the value in `use Phoenix.Socket`.

  ## Examples

      socket "/ws", MyApp.UserSocket

      socket "/ws/admin", MyApp.AdminUserSocket,
        longpoll: true,
        websocket: [compress: true]

  ## Path params

  It is possible to include variables in the path, these will be
  available in the `params` that are passed to the socket.

      socket "/ws/:user_id", MyApp.UserSocket,
        websocket: [path: "/project/:project_id"]

  ## Common configuration

  The configuration below can be given to both `:websocket` and
  `:longpoll` keys:

    * `:path` - the path to use for the transport. Will default
       to the transport name ("/websocket" or "/longpoll")

    * `:serializer` - a list of serializers for messages. See
      `Phoenix.Socket` for more information

    * `:transport_log` - if the transport layer itself should log and,
      if so, the level

    * `:check_origin` - if the transport should check the origin of requests when
      the `origin` header is present. May be `true`, `false`, a list of hosts that
      are allowed, or a function provided as MFA tuple. Defaults to `:check_origin`
      setting at endpoint configuration.

      If `true`, the header is checked against `:host` in `YourAppWeb.Endpoint.config(:url)[:host]`.

      If `false` and you do not validate the session in your socket, your app
      is vulnerable to Cross-Site WebSocket Hijacking (CSWSH) attacks.
      Only use in development, when the host is truly unknown or when
      serving clients that do not send the `origin` header, such as mobile apps.

      You can also specify a list of explicitly allowed origins. Wildcards are
      supported.

          check_origin: [
            "https://example.com",
            "//another.com:888",
            "//*.other.com"
          ]

      Or to accept any origin matching the request connection's host, port, and scheme:

          check_origin: :conn

      Or a custom MFA function:

          check_origin: {MyAppWeb.Auth, :my_check_origin?, []}

      The MFA is invoked with the request `%URI{}` as the first argument,
      followed by arguments in the MFA list, and must return a boolean.

    * `:code_reloader` - enable or disable the code reloader. Defaults to your
      endpoint configuration

    * `:connect_info` - a list of keys that represent data to be copied from
      the transport to be made available in the user socket `connect/3` callback.
      See the "Connect info" subsection for valid keys

  ### Connect info

  The valid keys are:

    * `:peer_data` - the result of `Plug.Conn.get_peer_data/1`

    * `:trace_context_headers` - a list of all trace context headers. Supported
      headers are defined by the [W3C Trace Context Specification](https://www.w3.org/TR/trace-context-1/).
      These headers are necessary for libraries such as [OpenTelemetry](https://opentelemetry.io/)
      to extract trace propagation information to know this request is part of a
      larger trace in progress.

    * `:x_headers` - all request headers that have an "x-" prefix

    * `:uri` - a `%URI{}` with information from the conn

    * `:user_agent` - the value of the "user-agent" request header

    * `{:session, session_config}` - the session information from `Plug.Conn`.
      The `session_config` is typically an exact copy of the arguments given
      to `Plug.Session`. In order to validate the session, the "_csrf_token"
      must be given as request parameter when connecting the socket with the
      value of `URI.encode_www_form(Plug.CSRFProtection.get_csrf_token())`.
      The CSRF token request parameter can be modified via the `:csrf_token_key`
      option.

      Additionally, `session_config` may be a MFA, such as
      `{MyAppWeb.Auth, :get_session_config, []}`, to allow loading config in
      runtime.

  Arbitrary keywords may also appear following the above valid keys, which
  is useful for passing custom connection information to the socket.

  For example:

  ```
    socket "/socket", AppWeb.UserSocket,
        websocket: [
          connect_info: [:peer_data, :trace_context_headers, :x_headers, :uri, session: [store: :cookie]]
        ]
  ```

  With arbitrary keywords:

  ```
    socket "/socket", AppWeb.UserSocket,
        websocket: [
          connect_info: [:uri, custom_value: "abcdef"]
        ]
  ```

  > #### Where are my headers? {: .tip}
  >
  > Phoenix only gives you limited access to the connection headers for security
  > reasons. WebSockets are cross-domain, which means that, when a user "John Doe"
  > visits a malicious website, the malicious website can open up a WebSocket
  > connection to your application, and the browser will gladly submit John Doe's
  > authentication/cookie information. If you were to accept this information as is,
  > the malicious website would have full control of a WebSocket connection to your
  > application, authenticated on John Doe's behalf.
  >
  > To safe-guard your application, Phoenix limits and validates the connection
  > information your socket can access. This means your application is safe from
  > these attacks, but you can't access cookies and other headers in your socket.
  > You may access the session stored in the connection via the `:connect_info`
  > option, provided you also pass a csrf token when connecting over WebSocket.

  ## Websocket configuration

  The following configuration applies only to `:websocket`.

    * `:timeout` - the timeout for keeping websocket connections
      open after it last received data, defaults to 60_000ms

    * `:max_frame_size` - the maximum allowed frame size in bytes,
      defaults to "infinity"

    * `:fullsweep_after` - the maximum number of garbage collections
      before forcing a fullsweep for the socket process. You can set
      it to `0` to force more frequent cleanups of your websocket
      transport processes. Setting this option requires Erlang/OTP 24

    * `:compress` - whether to enable per message compression on
      all data frames, defaults to false

    * `:subprotocols` - a list of supported websocket subprotocols.
      Used for handshake `Sec-WebSocket-Protocol` response header, defaults to nil.

      For example:

          subprotocols: ["sip", "mqtt"]

    * `:error_handler` - custom error handler for connection errors.
      If `c:Phoenix.Socket.connect/3` returns an `{:error, reason}` tuple,
      the error handler will be called with the error reason. For WebSockets,
      the error handler must be a MFA tuple that receives a `Plug.Conn`, the
      error reason, and returns a `Plug.Conn` with a response. For example:

          socket "/socket", MySocket,
              websocket: [
                error_handler: {MySocket, :handle_error, []}
              ]

      and a `{:error, :rate_limit}` return may be handled on `MySocket` as:

          def handle_error(conn, :rate_limit), do: Plug.Conn.send_resp(conn, 429, "Too many requests")

  ## Longpoll configuration

  The following configuration applies only to `:longpoll`:

    * `:window_ms` - how long the client can wait for new messages
      in its poll request in milliseconds (ms). Defaults to `10_000`.

    * `:pubsub_timeout_ms` - how long a request can wait for the
      pubsub layer to respond in milliseconds (ms). Defaults to `2000`.

    * `:crypto` - options for verifying and signing the token, accepted
      by `Phoenix.Token`. By default tokens are valid for 2 weeks

  """
  defmacro socket(path, module, opts \\ []) do
    module = Macro.expand(module, %{__CALLER__ | function: {:socket_dispatch, 2}})

    quote do
      @phoenix_sockets {unquote(path), unquote(module), unquote(opts)}
    end
  end

  @doc false
  @deprecated "Phoenix.Endpoint.instrument/4 is deprecated and has no effect. Use :telemetry instead"
  defmacro instrument(_endpoint_or_conn_or_socket, _event, _runtime, _fun) do
    :ok
  end

  @doc """
  Checks if Endpoint's web server has been configured to start.

    * `otp_app` - The OTP app running the endpoint, for example `:my_app`
    * `endpoint` - The endpoint module, for example `MyAppWeb.Endpoint`

  ## Examples

      iex> Phoenix.Endpoint.server?(:my_app, MyAppWeb.Endpoint)
      true

  """
  def server?(otp_app, endpoint) when is_atom(otp_app) and is_atom(endpoint) do
    Phoenix.Endpoint.Supervisor.server?(otp_app, endpoint)
  end
end
