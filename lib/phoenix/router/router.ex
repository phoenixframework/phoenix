defmodule Phoenix.Router do
  use GenServer.Behaviour
  alias Phoenix.Controller
  alias Phoenix.Plugs

  defmacro __using__(plug_adapter_options \\ []) do
    quote do
      use Phoenix.Router.Mapper
      use Phoenix.Adapters.Cowboy

      import unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      use Plug.Builder

      plug Plugs.ErrorHandler, from: __MODULE__

      @options unquote(plug_adapter_options)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      plug Plugs.CodeReloader, from: __MODULE__
      plug Plugs.Logger, from: __MODULE__
      plug :dispatch

      def dispatch(conn, []) do
        Phoenix.Router.perform_dispatch(conn, __MODULE__)
      end

      def start do
        options = Phoenix.Router.Options.merge(@options, __MODULE__)
        # TODO: Refactor into Router.Options
        options = Phoenix.Adapters.Cowboy.setup_options(__MODULE__, options, @dispatch_options)

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

    apply(router, :match, [conn, http_method, split_path])
  end
end
