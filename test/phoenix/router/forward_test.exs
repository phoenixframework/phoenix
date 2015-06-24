defmodule Phoenix.Router.ForwardTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Controller do
    use Phoenix.Controller

    plug :put_script_name

    def index(conn, _params), do: text(conn, "admin index")
    def stats(conn, _params), do: text(conn, "admin stats")
    def api_users(conn, _params), do: text(conn, "api users")
    def api_root(conn, _params), do: text(conn, "api root")

    defp put_script_name(conn, _) do
      assign(conn, :fwd_script_name, conn.script_name)
    end
  end


  defmodule AdminDashboard do
    use Phoenix.Router

    get "/", Controller, :index
    get "/stats", Controller, :stats
  end

  defmodule ApiRouter do
    use Phoenix.Router

    get "/", Controller, :api_root
    get "/users", Controller, :api_users
  end


  defmodule Router do
    use Phoenix.Router

    forward "/admin", AdminDashboard
    forward "/api/:version", ApiRouter
    scope "/internal" do
      forward "/api/:version", ApiRouter
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
    assert conn.resp_body == "admin stats"
  end

  test "can forward with dynamic segments" do
    conn = call(Router, :get, "api/v1/users")
    assert conn.status == 200
    assert conn.script_name == []
    assert conn.assigns[:fwd_script_name] == ["api", "v1"]
    assert conn.resp_body == "api users"
    assert conn.params["version"] == "v1"

    conn = call(Router, :get, "api/v1")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script_name] == ["api", "v1"]
    assert conn.status == 200
    assert conn.resp_body == "api root"
  end

  test "forwarded routes can be scoped" do
    conn = call(Router, :get, "internal/api/v1/users")
    assert conn.script_name == []
    assert conn.assigns[:fwd_script_name] == ["internal", "api", "v1"]
    assert conn.status == 200
    assert conn.resp_body == "api users"
  end
end
