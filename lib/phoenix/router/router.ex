defmodule Phoenix.Router do
  use GenServer.Behaviour

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
    # apply(router, :match, [conn, http_method, path])
    {:ok, pid} = start([conn, router, http_method, path])
    :gen_server.call pid, :dispatch
  end

  def start(state) do
    :gen_server.start(__MODULE__, state, [])
  end

  def init(state) do
    {:ok, state}
  end

  def handle_call(:dispatch, _from, state = [conn, router, http_method, path]) do
    plug = apply(router, :match, [conn, http_method, path])
    {:reply, plug, state}
  end

  def terminate(reason, [conn, router, http_method, path]) do
    Phoenix.Controller.error(conn, reason)
  end
end

