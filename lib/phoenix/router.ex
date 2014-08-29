defmodule Phoenix.Router do
  import Plug.Conn, only: [assign_private: 3]
  import Phoenix.Controller.Connection, only: [assign_status: 2, assign_error: 3]
  alias Phoenix.Plugs
  alias Phoenix.Router.Options
  alias Phoenix.Adapters.Cowboy
  alias Phoenix.Plugs.Parsers
  alias Phoenix.Config
  alias Phoenix.Controller.Action
  alias Phoenix.Project
  alias Plug.Conn

  @unsent [:unset, :set]

  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      use Phoenix.Router.Mapper
      use Phoenix.Adapters.Cowboy

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      use Plug.Builder


      if Config.router(__MODULE__, [:static_assets]) do
        mount = Config.router(__MODULE__, [:static_assets_mount])
        plug Plug.Static, at: mount, from: Project.app
      end
      plug Plug.Logger
      if Config.router(__MODULE__, [:parsers]) do
        plug Plug.Parsers, parsers: [:urlencoded, :multipart, Parsers.JSON], accept: ["*/*"]
      end

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      if Config.get([:code_reloader, :enabled]) do
        plug Plugs.CodeReloader
      end
      if Config.router(__MODULE__, [:cookies]) do
        key    = Config.router!(__MODULE__, [:session_key])
        secret = Config.router!(__MODULE__, [:session_secret])

        plug Plug.Session, store: :cookie, key: key, secret: secret
        plug Plugs.SessionFetcher
      end

      plug Plug.MethodOverride

      unless Plugs.plugged?(@plugs, :dispatch) do
        plug :dispatch
      end

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

  @doc """
  Starts the Router module with provided List of options
  """
  def start_adapter(module, opts) do
    protocol = if opts[:ssl], do: :https, else: :http
    case apply(Plug.Adapters.Cowboy, protocol, [module, [], opts]) do
      {:ok, pid} ->
        [:green, "Running #{Phoenix.Naming.module_name(module)} with Cowboy on port #{inspect opts[:port]}"]
        |> IO.ANSI.format
        |> IO.puts
        {:ok, pid}

      {:error, :eaddrinuse} ->
        raise "Port #{inspect opts[:port]} is already in use"
    end
  end

  @doc """
  Stops the Router module with provided List of options
  """
  def stop_adapter(module, opts) do
    protocol = if opts[:ssl], do: HTTPS, else: HTTP
    apply(Plug.Adapters.Cowboy, :shutdown, [Module.concat(module, protocol)])
    IO.puts "#{module} has been stopped"
  end

  @doc """
  Carries out Controller dispatch for router match
  """
  def perform_dispatch(conn, router) do
    conn = assign_private(conn, :phoenix_router, router)
    try do
      router.match(conn, conn.method, conn.path_info)
    catch
      kind, err -> handle_err(conn, kind, err, Config.router(router, [:catch_errors]))
    end
    |> after_dispatch
  end

  defp handle_err(conn, kind, error, _catch_errors = true) do
    conn
    |> assign_error(kind, error)
    |> assign_status(500)
  end
  defp handle_err(_, :throw, err, _nocatch), do: throw(err)
  defp handle_err(_, :error, err, _nocatch), do: reraise(err, System.stacktrace)

  defp after_dispatch(conn = %Conn{state: state, status: status})
    when state in @unsent
    and status == 404 do

    Action.handle_not_found(conn)
  end
  defp after_dispatch(conn = %Conn{state: state, status: status})
    when state in @unsent
    and status == 500 do

    Action.handle_error(conn)
  end
  defp after_dispatch(conn), do: conn
end

