defmodule Phoenix.Router do
  alias Phoenix.Plugs
  alias Phoenix.Router.Options
  alias Phoenix.Router.Path
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Plugs.Parsers
  alias Phoenix.Config

  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      use Phoenix.Router.Mapper
      use Phoenix.Adapters.Cowboy

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      use Plug.Builder

      if Config.router(__MODULE__, [:plugs, :parsers]) do
        plug Plug.Parsers, parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"]
      end
      if Config.router(__MODULE__, [:plugs, :error_handler]) do
        plug Plugs.ErrorHandler, from: __MODULE__
      end

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      plug Plugs.Logger, Config.router(__MODULE__, [:logger, :level])
      if Config.router(__MODULE__, [:plugs, :code_reload]) do
        plug Plugs.CodeReloader
      end
      if Config.router(__MODULE__, [:plugs, :cookies]) do
        key    = Config.router!(__MODULE__, [:cookies, :key])
        secret = Config.router!(__MODULE__, [:cookies, :secret])

        plug Plug.Session, store: :cookie, key: key, secret: secret
      end

      plug :dispatch

      def dispatch(conn, []) do
        Phoenix.Router.perform_dispatch(conn, __MODULE__)
      end

      def start do
        options = Options.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Phoenix.Router.start_adapter(__MODULE__, options)
      end

      def stop do
        options = Options.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Phoenix.Router.stop_adapter(__MODULE__, options)
      end
    end
  end

  def start_adapter(module, options) do
    scheme = case options[:ssl] do
      true  -> Plug.Adapters.Cowboy.https(module, [], options); "https"
      false -> Plug.Adapters.Cowboy.http( module, [], options); "http"
    end
    url = Path.build_url("", options[:host], [scheme: scheme, port: options[:port]])
    IO.puts "Running #{module} with Cowboy at #{url}"
  end

  def stop_adapter(module, options) do
    case options[:ssl] do
      true  -> Plug.Adapters.Cowboy.shutdown module.HTTPS
      false -> Plug.Adapters.Cowboy.shutdown module.HTTP
    end
    IO.puts "#{module} has been stopped"
  end

  def perform_dispatch(conn, router) do
    conn = Plug.Conn.fetch_params(conn)

    router.match(conn, conn.method, conn.path_info)
  end
end
