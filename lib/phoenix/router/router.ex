defmodule Phoenix.Router do
  alias Phoenix.Plugs
  alias Phoenix.Router.Options
  alias Phoenix.Adapters.Cowboy

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
        options = Options.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Phoenix.Router.start_adapter(options)
      end

      def stop do
        options = Options.merge(@options, @dispatch_options, __MODULE__, Cowboy)
        Phoenix.Router.stop_adapter(options)
      end
    end
  end

  def start_adapter(options) do
    case options[:ssl] do
      true  -> Plug.Adapters.Cowboy.https __MODULE__, [], options
      false -> Plug.Adapters.Cowboy.http __MODULE__, [], options
    end
    IO.puts "Running #{__MODULE__} with Cowboy on port #{inspect options[:port]}"
  end

  def stop_adapter(options) do
    case options[:ssl] do
      true  -> Plug.Adapters.Cowboy.shutdown __MODULE__.HTTPS
      false -> Plug.Adapters.Cowboy.shutdown __MODULE__.HTTP
    end
    IO.puts "#{__MODULE__} has been stopped"
  end

  def perform_dispatch(conn, router) do
    alias Phoenix.Router.Path
    conn        = Plug.Conn.fetch_params(conn)
    http_method = conn.method |> String.downcase
    split_path  = Path.split_from_conn(conn)

    apply(router, :match, [conn, http_method, split_path])
  end
end
