defmodule Phoenix.Endpoint do
  @moduledoc """
  Defines a Phoenix endpoint.

  The endpoint is the boundary where all requests to your
  web application start. It is also the interface your
  application provides to the underlying web servers.

  Overall, an endpoint has three responsibilities:

    * To define an initial plug pipeline where requests
      are sent to.

    * To host web specific configuration for your
      application.

    * It provides a wrapper for starting and stopping the
      endpoint in a specific web server.

  ## Endpoint configuration

  All endpoints are configured directly in the Phoenix application
  environment. For example:

      config :phoenix, YourApp.Endpoint,
        secret_key_base: "kjoy3o1zeidquwy1398juxzldjlksahdk3"

  Phoenix configuration is split in two categories. Compile-time
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

    * `:http` - the configuration for the http server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:https` - the configuration for the https server. Currently uses
      cowboy and accepts all options as defined by `Plug.Adapters.Cowboy`.
      Defaults to false.

    * `:secret_key_base` - a secret key used as base to generate secrets
      to encode cookies, session and friends. Defaults to nil as it must
      be set per application.

    * `:url` - configuration for generating URLs throughout the app.
      Accepts the host, scheme and port. Defaults to:

          [host: "localhost"]

  ## Web server

  Starting an endpoint as part of a web server can be done by invoking
  `YourApp.Endpoint.start/0`. Stopping the endpoint is done with
  `YourApp.Endpoint.stop/0`. The web server is configured with the
  `:http` and `:https` options defined above.
  """

  alias Phoenix.Endpoint.Adapter

  # How to upgrade to Phoenix 0.7.0
  #
  # 1. Define a Phoenix.Endpoint
  #
  # 2. Migrate your config/*.exs files to configure the
  #    endpoint in your application instead of the router
  #
  # 3. Add a config_change callback to your application
  #

  # TODO: Add error handling and other configs (What about the router)
  # TODO: Migrate to own app OTP config

  @doc false
  defmacro __using__(opts) do
    quote do
      unquote(config(opts))
      unquote(plug())
      unquote(server())
    end
  end

  defp config(opts) do
    quote do
      otp_app = unquote(opts)[:otp_app] || raise "endpoint expects :otp_app to be given"
      config  = Adapter.config(otp_app, __MODULE__)
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
      Starts the current endpoint for serving requests.
      """
      def start() do
        Adapter.start(unquote(otp_app), __MODULE__)
      end

      @doc """
      Stops the current endpoint from serving requests.
      """
      def stop() do
        Adapter.stop(unquote(otp_app), __MODULE__)
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

  defp allow_plug?({Phoenix.CodeReloder, _, _}), do:
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
end
