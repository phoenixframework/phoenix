defmodule Phoenix.Router.RoutingTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule UserController do
    use Phoenix.Controller
    def index(conn, _params), do: text(conn, "users index")
    def show(conn, _params), do: text(conn, "users show")
    def top(conn, _params), do: text(conn, "users top")
    def options(conn, _params), do: text(conn, "users options")
    def connect(conn, _params), do: text(conn, "users connect")
    def trace(conn, _params), do: text(conn, "users trace")
    def not_found(conn, _params), do: text(put_status(conn, :not_found), "not found")
    def image(conn, _params), do: text(conn, conn.params["path"] || "show files")
    def move(conn, _params), do: text(conn, "users move")
    def any(conn, _params), do: text(conn, "users any")
  end

  defmodule Router do
    use Phoenix.Router

    get "/", UserController, :index, as: :users
    get "/users/top", UserController, :top, as: :top
    get "/users/:id", UserController, :show, as: :users
    get "/spaced users/:id", UserController, :show
    get "/profiles/profile-:id", UserController, :show
    get "/route_that_crashes", UserController, :crash
    get "/files/:user_name/*path", UserController, :image
    get "/backups/*path", UserController, :image
    get "/static/images/icons/*image", UserController, :image

    trace "/trace", UserController, :trace
    options "/options", UserController, :options
    connect "/connect", UserController, :connect
    match :move, "/move", UserController, :move
    match :*, "/any", UserController, :any

    get "/users/:user_id/files/:id", UserController, :image
    get "/*path", UserController, :not_found
  end

  setup do
    Logger.disable(self())
    :ok
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
    assert conn.path_params["id"] == "75f6306d-a090-46f9-8b80-80fd57ec9a41"

    conn = call(Router, :get, "users/75f6306d-a0/files/34-95")
    assert conn.status == 200
    assert conn.resp_body == "show files"
    assert conn.params["user_id"] == "75f6306d-a0"
    assert conn.path_params["user_id"] == "75f6306d-a0"
    assert conn.params["id"] == "34-95"
    assert conn.path_params["id"] == "34-95"
  end

  test "get with named param" do
    conn = call(Router, :get, "users/1")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
    assert conn.path_params["id"] == "1"
  end

  test "parameters are url decoded" do
    conn = call(Router, :get, "/users/hello%20matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/spaced%20users/hello%20matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/spaced users/hello matey")
    assert conn.params == %{"id" => "hello matey"}

    conn = call(Router, :get, "/users/a%20b")
    assert conn.params == %{"id" => "a b"}

    conn = call(Router, :get, "/backups/a%20b/c%20d")
    assert conn.params == %{"path" => ["a b", "c d"]}
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

  test "splat args are %encodings in path" do
    conn = call(Router, :get, "backups/silly%20name")
    assert conn.status == 200
    assert conn.params["path"] == ["silly name"]
  end

  test "catch-all splat route matches" do
    conn = call(Router, :get, "foo/bar/baz")
    assert conn.status == 404
    assert conn.params == %{"path" => ~w"foo bar baz"}
    assert conn.resp_body == "not found"
  end

  test "match on arbitrary http methods" do
    conn = call(Router, :move, "/move")
    assert conn.method == "MOVE"
    assert conn.status == 200
    assert conn.resp_body == "users move"
  end

  test "any verb matches" do
    conn = call(Router, :get, "/any")
    assert conn.method == "GET"
    assert conn.status == 200
    assert conn.resp_body == "users any"

    conn = call(Router, :put, "/any")
    assert conn.method == "PUT"
    assert conn.status == 200
    assert conn.resp_body == "users any"
  end
end
