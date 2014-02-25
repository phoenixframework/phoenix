defmodule Phoenix.Router.FilterTest do
  use ExUnit.Case
  use PlugHelper

  defmodule Plugs do
    defmodule ModulePlug do
      @behaviour Plug
      def init(opts), do: opts
      def call(conn, opts), do: Plug.Connection.assign_private(conn, :module_plug_test, opts)
    end

    defmodule WrapPlug do
      @behaviour Plug
      def init(opts), do: opts
      def wrap(conn, opts, fun) do
        conn = Plug.Connection.assign_private(conn, :wrap_plug_test, opts)
        fun.(conn)
      end
    end
  end

  defmodule NoFilterController do
    use Phoenix.Controller
    def index(conn), do: text(conn, "NoFilterController")
  end

  defmodule ModulePlugController do
    use Phoenix.Controller
    use Plug.Builder
    plug Plugs.ModulePlug, metallica: "black album"
    def index(conn), do: text(conn, "ModulePlugController")
  end

  defmodule FunctionPlugController do
    use Phoenix.Controller
    use Plug.Builder
    plug :testing, the_cult: "sonic temple"
    def index(conn), do: text(conn, "FunctionPlugController")
    def testing(conn, opts), do: Plug.Connection.assign_private(conn, :function_plug_test, opts)
  end

  defmodule WrapPlugController do
    use Phoenix.Controller
    use Plug.Builder
    plug Plugs.WrapPlug, beck: "odelay"
    def index(conn), do: text(conn, "WrapPlugController")
  end

  defmodule ConditionalController do
    use Phoenix.Controller
    use Plug.Builder
    plug :info, only: :show
    def index(conn), do: text(conn, "index: #{conn.private[:from_plug]}")
    def show(conn), do: text(conn, "show: #{conn.private[:from_plug]}")
    def info(conn, options) do
      action = conn.private[:phoenix_context][:action]
      if action in List.wrap(options[:only]) do
        Plug.Connection.assign_private(conn, :from_plug, "code executed")
      else
        conn
      end
    end
  end

  defmodule Router do
    use Phoenix.Router
    get "/no-filter", NoFilterController, :index
    get "/module-plug", ModulePlugController, :index
    get "/function-plug", FunctionPlugController, :index
    get "/wrap-plug", WrapPlugController, :index
    get "/conditional/index", ConditionalController, :index
    get "/conditional/show", ConditionalController, :show
  end

  test "run successfully without filters" do
    conn = simulate_request(Router, :get, "/no-filter")
    assert conn.status == 200
    assert Enum.empty?(conn.private)
  end

  test "executes module plug successfully" do
    conn = simulate_request(Router, :get, "/module-plug")
    assert conn.status == 200
    assert conn.private[:module_plug_test] == [ metallica: "black album" ]
  end

  test "executes function plug successfully" do
    conn = simulate_request(Router, :get, "/function-plug")
    assert conn.status == 200
    assert conn.private[:function_plug_test] == [ the_cult: "sonic temple" ]
  end

  test "executes wrap plug successfully" do
    conn = simulate_request(Router, :get, "/wrap-plug")
    assert conn.status == 200
    assert conn.private[:wrap_plug_test] == [ beck: "odelay" ]
  end

  test "use plug option to conditionaly do something" do
    conn = simulate_request(Router, :get, "/conditional/index")
    assert conn.resp_body == "index: "
    conn = simulate_request(Router, :get, "/conditional/show")
    assert conn.resp_body == "show: code executed"
  end
end
