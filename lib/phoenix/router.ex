defmodule Phoenix.Router do
  alias Phoenix.Plugs
  alias Phoenix.Router.Options
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

      if Config.router(__MODULE__, [:parsers]) do
        plug Plug.Parsers, parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"]
      end
      if Config.router(__MODULE__, [:error_handler]) do
        plug Plugs.ErrorHandler, from: __MODULE__
      end

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      plug Plugs.Logger, Config.router(__MODULE__, [:logger, :level])
      if Config.router(__MODULE__, [:code_reload]) do
        plug Plugs.CodeReloader
      end
      if Config.router(__MODULE__, [:cookies]) do
        key    = Config.router!(__MODULE__, [:session_key])
        secret = Config.router!(__MODULE__, [:session_secret])

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

  def start_adapter(module, opts) do
    protocol = if opts[:ssl], do: :https, else: :http
    case apply(Plug.Adapters.Cowboy, protocol, [module, [], opts]) do
      {:ok, _pid} ->
        "%{green}Running #{module} with Cowboy on port #{inspect opts[:port]}%{reset}"
        |> IO.ANSI.escape
        |> IO.puts
      {:error, _} ->
        raise "Port #{inspect opts[:port]} is already in use"
    end
  end

  def stop_adapter(module, opts) do
    protocol = if opts[:ssl], do: HTTPS, else: HTTP
    apply(Plug.Adapters.Cowboy, :shutdown, [Module.concat(module, protocol)])
    IO.puts "#{module} has been stopped"
  end

  def perform_dispatch(conn, router) do
    conn = Plug.Conn.fetch_params(conn)

    router.match(conn, conn.method, conn.path_info)
  end
end
