defmodule Phoenix.Router.RoutingTest do
  use ExUnit.Case, async: true
  use ConnHelper

  setup do
    Logger.disable(self())
    :ok
  end

  defmodule UserController do
    use Phoenix.Controller
    def index(conn, _params), do: text(conn, "users index")
    def show(conn, _params), do: text(conn, "users show")
    def top(conn, _params), do: text(conn, "users top")
    def options(conn, _params), do: text(conn, "users options")
    def connect(conn, _params), do: text(conn, "users connect")
    def head(conn, _params), do: conn |> send_resp(200, "")
    def trace(conn, _params), do: text(conn, "users trace")
    def not_found(conn, _params), do: text(conn, :not_found, "not found")
    def image(conn, _params), do: text(conn, conn.params["path"] || "show files")
  end

  defmodule Router do
    use Phoenix.Router

    get "/", UserController, :index, as: :users
    get "/users/top", UserController, :top, as: :top
    get "/users/:id", UserController, :show, as: :users
    get "/profiles/profile-:id", UserController, :show
    get "/route_that_crashes", UserController, :crash
    get "/files/:user_name/*path", UserController, :image
    get "/backups/*path", UserController, :image
    get "/static/images/icons/*image", UserController, :image

    trace "/trace", UserController, :trace
    options "/options", UserController, :options
    connect "/connect", UserController, :connect
    head "/head", UserController, :head

    get "/users/:user_id/files/:id", UserController, :image
  end

  defmodule CatchAllRouter do
    use Phoenix.Router
    get "/users/top", UserController, :top, as: :top
    get "/users/:id", UserController, :show, as: :user
    get "/*path", UserController, :not_found
  end

  test "get root path" do
    conn = call(Router, :get, "/")
    assert conn.status == 200
    assert conn.resp_body == "users index"
  end

  test "get to named param with dashes" do
    conn = call(Router, :get, "users/75f6306d-a090-46f9-8b80-80fd57ec9a41")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "75f6306d-a090-46f9-8b80-80fd57ec9a41"

    conn = call(Router, :get, "users/75f6306d-a0/files/34-95")
    assert conn.status == 200
    assert conn.resp_body == "show files"
    assert conn.params["user_id"] == "75f6306d-a0"
    assert conn.params["id"] == "34-95"
  end

  test "get with named param" do
    conn = call(Router, :get, "users/1")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
  end

  test "get to custom action" do
    conn = call(Router, :get, "users/top")
    assert conn.status == 200
    assert conn.resp_body == "users top"
  end

  test "options to custom action" do
    conn = call(Router, :options, "/options")
    assert conn.status == 200
    assert conn.resp_body == "users options"
  end

  test "connect to custom action" do
    conn = call(Router, :connect, "/connect")
    assert conn.status == 200
    assert conn.resp_body == "users connect"
  end

  test "trace to custom action" do
    conn = call(Router, :trace, "/trace")
    assert conn.status == 200
    assert conn.resp_body == "users trace"
  end

  test "head to custom action" do
    conn = call(Router, :head, "/head")
    assert conn.status == 200
    assert conn.method == "HEAD"
    assert conn.resp_body == ""
  end

  test "unmatched route returns 404" do
    conn = call(Router, :get, "route_does_not_exist")
    assert conn.status == 404
  end

  test "splat arg with preceding named parameter to files/:user_name/*path" do
    conn = call(Router, :get, "files/elixir/Users/home/file.txt")
    assert conn.status == 200
    assert conn.params["user_name"] == "elixir"
    assert conn.params["path"] == ["Users", "home", "file.txt"]
  end

  test "splat arg with preceding string to backups/*path" do
    conn = call(Router, :get, "backups/name")
    assert conn.status == 200
    assert conn.params["path"] == ["name"]
  end

  test "splat arg with multiple preceding strings to static/images/icons/*path" do
    conn = call(Router, :get, "static/images/icons/elixir/logos/main.png")
    assert conn.status == 200
    assert conn.params["image"] == ["elixir", "logos", "main.png"]
  end

  test "catch-all splat route matches" do
    conn = call(CatchAllRouter, :get, "foo/bar/baz")
    assert conn.status == 404
    assert conn.params == %{"path" => ~w"foo bar baz"}
    assert conn.resp_body == "not found"
  end
end
