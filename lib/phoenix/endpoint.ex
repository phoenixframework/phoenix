defmodule Phoenix.Endpoint do
  @moduledoc """
  Defines a Phoenix endpoint.

  The endpoint is the boundary where all requests to your
  web application start. It is also the interface your
  application provides to the underlying web servers.

  Overall, an endpoint has three responsibilities:

    * It provides a wrapper for starting and stopping the
      endpoint as part of a supervision tree.

    * To define an initial plug pipeline where requests
      are sent to.

    * To host web specific configuration for your
      application.

  ## Endpoints

  An endpoint is simply a module defined with the help
  of Phoenix.Endpoint. If you have used the phoenix.new
  generator, an endpoint was automatically generated as
  part of your application:

      defmodule YourApp.Endpoint do
        use Phoenix.Endpoint, otp_app: :your_app

        # plug ...
        # plug ...

        plug :router, YourApp.Router
      end

  Before being used, an endpoint must be splicitly started as part
  of your application supervision tree too (which is again done by
  default in generated applications):

      supervisor(YourApp.Endpoint, [])

  ## Endpoint configuration

  All endpoints are configured in your application environment.
  For example:

      config :your_app, YourApp.Endpoint,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Endpoint configuration is split in two categories. Compile-time
  configuration means the configuration is read during compilation
  and changing it at runtime has no effect. The compile-time
  configuration is mostly related to error handling.

  On the other hand, runtime configuration is accessed during or
  after your application is started and can be read through the
  `config/2` function:

      YourApp.Endpoint.config(:port)
      YourApp.Endpoint.config(:some_config, :default_value)

  ### Compile-time

    * `:debug_errors` - when true, uses `Plug.Debugger` functionality for
      debugging failures in the application. Recomended to be set to true
      only in development as it allows listing of the application source
      code during debugging. Defaults to false.

    * `:render_errors` - a module representing a view to render templates
      whenever there is a failure in the application. For example, if the
      application crashes with a 500 error during a HTML request,
      `render("500.html", assigns)` will be called in the view given to
      `:render_errors`. The default view is `MyApp.ErrorView`.

  ### Runtime

    * `:cache_static_lookup` - when true, static assets lookup in the
      filesystem via the `static_path` function are cached. Defaults to true.

    * `:http` - the configuration for the http server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:https` - the configuration for the https server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:secret_key_base` - a secret key used as base to generate secrets
      to encode cookies, session and friends. Defaults to nil as it must
      be set per application.

    * `:server` - when true, starts the web server when the endpoint
      supervision tree starts. Defaults to false. The `mix phoenix.server`
      task automatically sets this to true.

    * `:url` - configuration for generating URLs throughout the app.
      Accepts the host, scheme and port. Defaults to:

          [host: "localhost"]

    * `:pubsub` - configuration for this Endpoint's pubsub adapter.
      Configuration either requires a `:name` of the registered pubsub server
      or a `:name`, `:adapter`, and `:options` which starts the adapter in
      the endpoint's supervision tree. If no name is provided, the name is
      inflected from the endpoint module. Defaults to:

          [adapter: Phoenix.PubSub.PG2]

      with advanced adapter configuration:

          [name: :my_pubsub, adapter: Phoenix.PubSub.Redis,
                             options: [host: "192.168.100.1"]]

  ## Endpoint API

  In the previous section, we have used the `config/2` function which is
  automatically generated in your Endpoint. Here is a summary of all functions
  defined in your endpoint:

    * `start_link()` - starts the Endpoint supervision tree, including its
      configuration cache and possibly the servers for handling requests
    * `config(key, default)` - access the endpoint configuration given by key
    * `config_change(changed, removed)` - reload the endpoint configuration on application upgrades
    * `url(path)` - returns the URL for this endpoint with the given path
    * `static_path(path)` - returns the static path for a given asset
    * `broadcast_from(from, topic, event, msg)` - proxy to `Phoenix.Channel.broadcast_from/4`
      using this endpoint's configured pubsub server
    * `broadcast_from!(from, topic, event, msg)` - proxy to `Phoenix.Channel.broadcast_from!/4`
      using this endpoint's configured pubsub server
    * `broadcast(topic, event, msg)` - proxy to `Phoenix.Channel.broadcast/3`
      using this endpoint's configured pubsub server
    * `broadcast!(topic, event, msg)` - proxy to `Phoenix.Channel.broadcast!/3`
      using this endpoint's configured pubsub server


  Besides the functions above, it defines also the API expected by Plug
  for serving requests:

    * `init(opts)` - invoked when starting the endpoint server
    * `call(conn, opts)` - invoked on every request and it simply dispatches to
      the defined Plug pipeline

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
      otp_app = unquote(opts)[:otp_app] || raise "endpoint expects :otp_app to be given"
      config  = Adapter.config(otp_app, __MODULE__)
      @config config
    end
  end

  defp pubsub() do
    quote do
      @pubsub_server get_in(@config, [:pubsub, :name]) ||
        Phoenix.Naming.base_concat(__MODULE__, "PubSub")

      def __pubsub_server__, do: @pubsub_server

      def broadcast_from(from, topic, event, msg) do
        Phoenix.Channel.broadcast_from(@pubsub_server, from, topic, event, msg)
      end
      def broadcast_from!(from, topic, event, msg) do
        Phoenix.Channel.broadcast_from!(@pubsub_server, from, topic, event, msg)
      end

      def broadcast(topic, event, msg) do
        Phoenix.Channel.broadcast(@pubsub_server, topic, event, msg)
      end

      def broadcast!(topic, event, msg) do
        Phoenix.Channel.broadcast!(@pubsub_server, topic, event, msg)
      end
    end
  end

  defp plug() do
    quote location: :keep do
      @behaviour Plug
      import Phoenix.Endpoint

      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Phoenix.Endpoint

      def init(opts) do
        opts
      end

      def call(conn, opts) do
        conn = put_in conn.secret_key_base, config(:secret_key_base)
        conn = update_in conn.private, &Map.put(&1, :phoenix_endpoint, __MODULE__)
        phoenix_endpoint_pipeline(conn, opts)
      end

      defoverridable [init: 1, call: 2]

      if config[:debug_errors] do
        use Plug.Debugger, otp_app: otp_app
      end

      use Phoenix.Endpoint.ErrorHandler, view: config[:render_errors]
    end
  end

  defp server() do
    quote location: :keep, unquote: false do
      @doc """
      Starts the endpoint supervision tree.
      """
      def start_link do
        Adapter.start_link(unquote(otp_app), __MODULE__)
      end

      @doc """
      Returns the endpoint configuration for `key`

      Returns `default` if the router does not exist.
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
        Phoenix.Config.config_change(__MODULE__, changed, removed)
      end

      @doc """
      Generates a URL for the given path based on the
      `:url` configuration for the endpoint.
      """
      def url(path) do
        Phoenix.Config.cache(__MODULE__,
          :__phoenix_url__,
          &Phoenix.Endpoint.Adapter.url/1) <> path
      end

      @doc """
      Generates a route to a static file based on the contents inside
      `priv/static` for the endpoint otp application.
      """
      def static_path(path) do
        Phoenix.Config.cache(__MODULE__,
          {:__phoenix_static__, path},
          &Phoenix.Endpoint.Adapter.static_path(&1, path))
      end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    plugs = Module.get_attribute(env.module, :plugs)
    plugs = for plug <- plugs, allow_plug?(plug), do: plug
    {conn, body} = Plug.Builder.compile(plugs)

    quote do
      defp phoenix_endpoint_pipeline(unquote(conn), _), do: unquote(body)
    end
  end

  defp allow_plug?({Phoenix.CodeReloader, _, _}), do:
    Application.get_env(:phoenix, :code_reloader, false)
  defp allow_plug?(_), do:
    true

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
  A macro that can be plugged in order to handle routing errors.

  By default, a Phoenix router will raise a `Phoenix.Router.NoRouteError`
  struct in case no route is found. This macro wraps the router call so
  the route error does not pass through.

  It also wraps the router call to provide better debugger and error
  rendering behaviour.

  ## Examples

      plug :router, MyApp.Router

  """
  defmacro router(conn, plug) do
    conf = Module.get_attribute(__CALLER__.module, :config)

    code =
      if conf[:debug_errors] do
        quote do
          Plug.Debugger.wrap(conn, @plug_debugger, fn ->
            plug.call(conn, plug.init([]))
          end)
        end
      else
        quote do
          plug.call(conn, plug.init([]))
        end
      end

    quote do
      conn = unquote(conn)
      plug = unquote(plug)
      Phoenix.Endpoint.ErrorHandler.wrap(conn, @phoenix_handle_errors, fn ->
        unquote(code)
      end)
    end
  end
end
