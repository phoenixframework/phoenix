defmodule Phoenix.Test.HealthController do
  use Phoenix.Controller
  def health(conn, _params), do: text(conn, "health")
end

defmodule Phoenix.Router.ForwardTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Controller do
    use Phoenix.Controller

    plug :assign_fwd_script

    def index(conn, _params), do: text(conn, "admin index")
    def stats(conn, _params), do: text(conn, "stats")
    def api_users(conn, _params), do: text(conn, "api users")
    def api_root(conn, _params), do: text(conn, "api root")
    defp assign_fwd_script(conn, _), do: assign(conn, :fwd_script, conn.script_name)
  end

  defmodule ApiRouter do
    use Phoenix.Router

    get "/", Controller, :api_root
    get "/users", Controller, :api_users

    scope "/health", Phoenix.Test do
      forward "/", HealthController, :health
    end
  end

  defmodule AdminDashboard do
    use Phoenix.Router

    get "/", Controller, :index, as: :page
    get "/stats", Controller, :stats, as: :page
    forward "/api-admin", ApiRouter
  end

  defmodule InitPlug do
    def init(_), do: %{non: :literal}
    def call(conn, %{non: :literal} = opts), do: assign(conn, :opts, opts)
  end

  defmodule AssignOptsPlug do
    def init(opts), do: opts
    def call(conn, opts), do: assign(conn, :opts, opts)
  end

  defmodule Router do
    use Phoenix.Router

    scope "/" do
      get "/stats", Controller, :stats
      forward "/admin", AdminDashboard
      forward "/init", InitPlug
      forward "/assign/opts", AssignOptsPlug, %{foo: "bar"}
      scope "/internal" do
        forward "/api/v1", ApiRouter
      end
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "forwards path to plug" do
    conn = call(Router, :get, "admin")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script] == ["admin"]
    assert conn.status == 200
    assert conn.resp_body == "admin index"
  end

  test "forwards any request starting with forward path" do
    conn = call(Router, :get, "admin/stats")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script] == ["admin"]
    assert conn.status == 200
    assert conn.resp_body == "stats"
  end

  test "forward with dynamic segments raises" do
    router = quote do
      defmodule BadRouter do
        use Phoenix.Router
        forward "/api/:version", ApiRouter
      end
    end

    assert_raise ArgumentError, ~r{dynamic segment "/api/:version" not allowed}, fn ->
      Code.eval_quoted(router)
    end
  end

  test "forward with non-unique plugs raises" do
    router = quote do
      defmodule BadRouter do
        use Phoenix.Router
        forward "/api/v1", ApiRouter
        forward "/api/v2", ApiRouter
      end
    end

    assert_raise ArgumentError, ~r{Phoenix.Router.ForwardTest.ApiRouter has already been forwarded}, fn ->
      Code.eval_quoted(router)
    end
  end

  test "accumulates phoenix_forwards" do
    conn = call(Router, :get, "admin")
    assert conn.private[Router] == {[], %{
      Phoenix.Router.ForwardTest.AdminDashboard => ["admin"],
      Phoenix.Router.ForwardTest.ApiRouter => ["api", "v1"],
      Phoenix.Router.ForwardTest.InitPlug => ["init"],
      Phoenix.Router.ForwardTest.AssignOptsPlug => ["assign", "opts"]
    }}
    assert conn.private[AdminDashboard] ==
      {["admin"], %{Phoenix.Router.ForwardTest.ApiRouter => ["api-admin"]}}

  end

  test "helpers cascade script name across forwards based on main router" do
    import AdminDashboard.Helpers
    assert page_path(%Plug.Conn{}, :stats) == "/stats"

    conn = call(Router, :get, "stats")
    assert page_path(conn, :stats) == "/admin/stats"

    conn = call(Router, :get, "stats", _params = nil, ["phx"])
    assert page_path(conn, :stats) == "/phx/admin/stats"

    conn = call(Router, :get, "admin/stats")
    assert page_path(conn, :stats) == "/admin/stats"

    conn = call(Router, :get, "admin/stats", _params = nil, ["phx"])
    assert page_path(conn, :stats) == "/phx/admin/stats"
  end

  test "forward can handle plugs with non-literal init returns" do
    assert call(Router, :get, "init").assigns.opts == %{non: :literal}
  end

  test "forward can handle plugs with custom options" do
    assert call(Router, :get, "assign/opts").assigns.opts == %{foo: "bar"}
  end

  test "forward with scoped alias" do
    conn = call(ApiRouter, :get, "health")
    assert conn.resp_body == "health"
    assert conn.private[ApiRouter] == {[], %{Phoenix.Test.HealthController => []}}
  end

  test "forwards raises if using the plug to arguments" do
    error_message = ~r/expects a module/
    assert_raise(ArgumentError, error_message, fn ->
      defmodule BrokenRouter do
        use Phoenix.Router
        scope "/" do
          forward "/health", to: HealthController
        end
      end
    end)
  end
end
