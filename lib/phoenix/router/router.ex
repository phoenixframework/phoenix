defmodule Phoenix.Router do
  use GenServer.Behaviour
  alias Phoenix.Request
  alias Phoenix.Dispatcher
  alias Phoenix.Controller

  defmacro __using__(plug_adapter_options // []) do
    quote do
      use Phoenix.Router.Mapper
      import unquote(__MODULE__)

      @options unquote(plug_adapter_options)

      def start do
        IO.puts "Running #{__MODULE__} with Cowboy with #{inspect @options}"
        Plug.Adapters.Cowboy.http __MODULE__, [], @options
      end

      def call(conn, []) do
        conn        = Plug.Connection.fetch_params(conn)
        http_method = conn.method |> String.downcase |> binary_to_atom
        split_path  = conn.path_info
        params      = conn.params

        IO.puts "#{__MODULE__}: #{http_method}: #{inspect split_path}"
        dispatch(conn, __MODULE__, http_method, split_path)
      end
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


