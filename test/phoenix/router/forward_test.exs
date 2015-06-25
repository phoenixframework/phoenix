defmodule Phoenix.Router.ForwardTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Controller do
    use Phoenix.Controller
    alias Phoenix.Router.ForwardTest.AdminDashboard

    plug :put_assigns

    def index(conn, _params), do: text(conn, "admin index")
    def stats(conn, _params), do: text(conn, "stats")
    def api_users(conn, _params), do: text(conn, "api users")
    def api_root(conn, _params), do: text(conn, "api root")

    defp put_assigns(conn, _) do
      page_path = AdminDashboard.Helpers.page_path(conn, :stats)

      conn
      |> assign(:internal_admin_page_path, page_path)
      |> assign(:fwd_script_name, conn.script_name)
    end
  end

  defmodule ApiRouter do
    use Phoenix.Router

    get "/", Controller, :api_root
    get "/users", Controller, :api_users
  end

  defmodule AdminDashboard do
    use Phoenix.Router

    get "/", Controller, :index, as: :page
    get "/stats", Controller, :stats, as: :page
    forward "/api-admin", ApiRouter
  end


  defmodule Router do
    use Phoenix.Router

    pipeline :browser do
      plug :assigns
    end

    scope "/" do
      pipe_through :browser
      get "/stats", Controller, :stats
      forward "/admin", AdminDashboard
      scope "/internal" do
        forward "/api/v1", ApiRouter
      end
    end

    defp assigns(conn, _) do
      Plug.Conn.assign(conn, :external_admin_page_path,
                       AdminDashboard.Helpers.page_path(conn, :stats))
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "forwards path to plug" do
    conn = call(Router, :get, "admin")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script_name] == ["admin"]
    assert conn.status == 200
    assert conn.resp_body == "admin index"
  end

  test "forwards any request starting with forward path" do
    conn = call(Router, :get, "admin/stats")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script_name] == ["admin"]
    assert conn.status == 200
    assert conn.resp_body == "stats"
  end

  test "phoenix_main_router is set for the first router" do
    # conn = call(Router, :get, "internal/api/v1/users")
    # assert conn.private.phoenix_main_router == Router
  end

  test "forward with dynamic segments raises" do
    router = quote do
      defmodule BadRouter do
        use Phoenix.Router
        forward "/api/:version", ApiRouter
      end
    end

    assert_raise RuntimeError, ~r{Dynamic segment `"/api/:version"` not allowed}, fn ->
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

    assert_raise RuntimeError, ~r{`Phoenix.Router.ForwardTest.ApiRouter` has already been forwarded}, fn ->
      Code.eval_quoted(router)
    end
  end

  test "accumulates phoenix_forwards" do
    conn = call(Router, :get, "admin")
    assert conn.private[Router] == {[], %{
      Phoenix.Router.ForwardTest.AdminDashboard => ["admin"],
      Phoenix.Router.ForwardTest.ApiRouter => ["api", "v1"]
    }}
    assert conn.private[AdminDashboard] ==
      {["admin"], %{Phoenix.Router.ForwardTest.ApiRouter => ["api-admin"]}}

  end

  test "helpers cascade script name across forwards based on main router" do
    assert AdminDashboard.Helpers.page_path(%Plug.Conn{}, :stats) == "/stats"

    conn = call(Router, :get, "stats")
    assert conn.assigns[:internal_admin_page_path] == "/admin/stats"
    assert conn.assigns[:external_admin_page_path] == "/admin/stats"
    conn = call(Router, :get, "stats", _params = nil, _headers = [], ["phx"])
    assert conn.assigns[:internal_admin_page_path] == "/phx/admin/stats"
    assert conn.assigns[:external_admin_page_path] == "/phx/admin/stats"

    conn = call(Router, :get, "admin/stats")
    assert conn.assigns[:internal_admin_page_path] == "/admin/stats"
    assert conn.assigns[:external_admin_page_path] == "/admin/stats"
    conn = call(Router, :get, "admin/stats", _params = nil, _headers = [], ["phx"])
    assert conn.assigns[:internal_admin_page_path] == "/phx/admin/stats"
    assert conn.assigns[:external_admin_page_path] == "/phx/admin/stats"
  end
end
