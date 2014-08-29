defmodule Phoenix.Router.ControllerTest do
  use ExUnit.Case
  use PlugHelper
  alias Plug.Conn
  alias Phoenix.Controller

  doctest Controller

  defmodule RedirController do
    use Phoenix.Controller
    def redir_301(conn, _params) do
      redirect conn, 301, "/users"
    end
    def redir_302(conn, _params) do
      redirect conn, "/users"
    end
  end

  defmodule AtomStatusController do
    use Phoenix.Controller

    def atom(conn, %{"status" => status}) do
      status_atom = String.to_atom(status)
      text conn, status_atom, ""
    end
  end

  defmodule PlugController do
    use Phoenix.Controller

    plug :first_plug
    plug :second_plug
    plug :authenticate

    def authenticate(conn = %Conn{private: %{phoenix_action: :restricted}}, _) do
      if conn.params["username"] == "superadmin" do
        conn
      else
        conn |> assign_status(401) |> halt
      end
    end
    def authenticate(conn, _), do: conn

    def first_plug(conn, _) do
      stack = conn.assigns[:stack] || []
      Conn.assign(conn, :stack, stack ++ [:first_plug])
    end

    def second_plug(conn, _) do
      stack = conn.assigns[:stack] || []
      Conn.assign(conn, :stack, stack ++ [:second_plug])
    end

    def index(conn, _params) do
      stack = conn.assigns[:stack] || []
      conn
      |> Conn.assign(:stack, stack ++ [:action])
      |> text("")
    end

    def restricted(conn, _params) do
      conn |> assign(:restricted, true) |> text ""
    end
  end

  defmodule ManuallyPluggedActionController do
    use Phoenix.Controller

    plug :first_plug
    plug :action
    plug :second_plug

    def first_plug(conn, _) do
      stack = conn.assigns[:stack] || []
      Conn.assign(conn, :stack, stack ++ [:first_plug])
    end

    def second_plug(conn, _) do
      stack = conn.assigns[:stack] || []
      Conn.assign(conn, :stack, stack ++ [:second_plug])
    end

    def index(conn, _params) do
      stack = conn.assigns[:stack] || []
      conn
      |> Conn.assign(:stack, stack ++ [:action])
      |> text("")
    end
  end


  defmodule Router do
    use Phoenix.Router
    get "/users/not_found_301", RedirController, :redir_301
    get "/users/not_found_302", RedirController, :redir_302
    get "/atom/:status", AtomStatusController, :atom
    get "/plugs/standard", PlugController, :index
    get "/plugs/standard/restricted", PlugController, :restricted
    get "/plugs/manual", ManuallyPluggedActionController, :index
  end

  test "redirect without status performs 302 redirect do url" do
    conn = simulate_request(Router, :get, "users/not_found_302")
    assert conn.status == 302
  end

  test "redirect without status performs 301 redirect do url" do
    conn = simulate_request(Router, :get, "users/not_found_301")
    assert conn.status == 301
  end

  test "accepts atoms as http statuses" do
    conn = simulate_request(Router, :get, "atom/ok")
    assert conn.status == 200

    conn = simulate_request(Router, :get, "atom/not_found")
    assert conn.status == 404
  end

  test "plug chain invokes :action plug last by default" do
    conn = simulate_request(Router, :get, "plugs/standard")
    assert conn.status == 200
    assert conn.assigns[:stack] == [:first_plug, :second_plug, :action]
  end

  test "plug chain invokes :action in order of explicity plugging" do
    conn = simulate_request(Router, :get, "plugs/manual")
    assert conn.status == 200
    assert conn.assigns[:stack] == [:first_plug, :action, :second_plug]
  end

  test "halt stops plug chain" do
    conn = simulate_request(Router, :get, "plugs/standard/restricted?username=superadmin")
    assert conn.status == 200
    assert conn.assigns[:restricted]

    conn = simulate_request(Router, :get, "plugs/standard/restricted?username=bob")
    assert conn.status == 401
    refute conn.assigns[:restricted]
    assert conn.resp_body == nil
  end

  test "view_module returns the view modoule based on controller module" do
    assert Controller.view_module(MyApp.UserController) == MyApp.UserView
    assert Controller.view_module(MyApp.Admin.UserController) == MyApp.Admin.UserView
  end

  test "layout_module returns the view modoule based on controller module" do
    assert Controller.layout_module(MyApp.UserController) == MyApp.LayoutView
    assert Controller.layout_module(MyApp.Admin.UserController) == MyApp.LayoutView
  end
end

