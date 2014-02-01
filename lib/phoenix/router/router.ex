defmodule Phoenix.Router do
  use GenServer.Behaviour
  alias Phoenix.Dispatcher
  alias Phoenix.Controller
  alias Phoenix.Plugs

  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      use Phoenix.Router.Mapper
      use Phoenix.Router.WebsocketMapper

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      use Plug.Builder

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      plug Plugs.CodeReloader
      plug Plugs.Logger
      plug :dispatch

      def dispatch(conn, []) do
        Phoenix.Router.perform_dispatch(conn, __MODULE__)
      end

      def start do
        options = Phoenix.Adapters.Cowboy.setup_options(__MODULE__, @options, @dispatch_options)

        IO.puts "Running #{__MODULE__} with Cowboy on port #{inspect options}"
        Plug.Adapters.Cowboy.http __MODULE__, [], options
      end
    end
  end

  def perform_dispatch(conn, router) do
    alias Phoenix.Router.Path
    conn        = Plug.Connection.fetch_params(conn)
    http_method = conn.method |> String.downcase |> binary_to_atom
    split_path  = Path.split_from_conn(conn)

    request = Dispatcher.Request.new(conn: conn,
                                     router: router,
                                     http_method: http_method,
                                     path: split_path)

    {:ok, pid} = Dispatcher.Client.start(request)
    case Dispatcher.Client.dispatch(pid) do
      {:ok, conn}      -> conn
      {:error, reason} -> Controller.error(conn, reason)
    end
  end

  def dispatch(conn, router, http_method, path) do
    request = Dispatcher.Request.new(conn: conn,
                                     router: router,
                                     http_method: http_method,
                                     path: path)

    {:ok, pid} = Dispatcher.Client.start(request)
    case Dispatcher.Client.dispatch(pid) do
      {:ok, conn}      -> {:ok, conn}
      {:error, reason} -> Controller.error(conn, reason)
    end
  end
end
