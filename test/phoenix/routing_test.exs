defmodule RoutingTest do
  use ExUnit.Case
  use PlugHelper

  defmodule UsersController do
    use Phoenix.Controller
    def show(conn), do: text(conn, "users show")
    def top(conn), do: text(conn, "users top")
    def crash(conn), do: raise 'crash!'
  end

  defmodule FilesController do
    use Phoenix.Controller
    def show(conn), do: text(conn, "#{conn.params["path"]}")
  end

  defmodule CommentsController do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show comments")
    def index(conn), do: text(conn, "index comments")
    def new(conn), do: text(conn, "new comments")
    def create(conn), do: text(conn, "create comments")
    def update(conn), do: text(conn, "update comments")
    def destroy(conn), do: text(conn, "destroy comments")
  end

  defmodule Router do
    use Phoenix.Router
    get "users/:id", UsersController, :show, as: :user
    get "profiles/profile-:id", UsersController, :show
    get "users/top", UsersController, :top, as: :top
    get "route_that_crashes", UsersController, :crash
    get "files/:user_name/*path", FilesController, :show
    get "backups/*path", FilesController, :show
    get "static/images/icons/*image", FilesController, :show

    resources "comments", CommentsController
    get "users/:user_id/comments/:id", CommentsController, :show
  end


  test "get with named param" do
   {:ok, conn} = simulate_request(Router, :get, "users/1")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "1"
  end

  test "get with multiple named params" do
   {:ok, conn} = simulate_request(Router, :get, "users/1/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "2"
  end

  test "get to custom action" do
   {:ok, conn} = simulate_request(Router, :get, "users/top")
    assert conn.status == 200
    assert conn.resp_body == "users top"
  end

  test "named param without forward slash is properly bound" do
    {:ok, conn} = simulate_request(Router, :get, "profiles/profile-123")
    assert conn.status == 200
    assert conn.resp_body == "users show"
    assert conn.params["id"] == "123"
  end

  test "get with resources to 'comments/new' maps to new action" do
   {:ok, conn} = simulate_request(Router, :get, "comments/new")
    assert conn.status == 200
    assert conn.resp_body == "new comments"
  end

  test "get with resources to 'comments' maps to index action" do
   {:ok, conn} = simulate_request(Router, :get, "comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"
  end

  test "get with resources to 'comments/123' maps to show action with named param" do
   {:ok, conn} = simulate_request(Router, :get, "comments/123")
    assert conn.status == 200
    assert conn.resp_body == "show comments"
    assert conn.params["id"] == "123"
  end

  test "post with resources to 'comments' maps to create action" do
   {:ok, conn} = simulate_request(Router, :post, "comments")
    assert conn.status == 200
    assert conn.resp_body == "create comments"
  end

  test "put with resources to 'comments/1' maps to update action" do
   {:ok, conn} = simulate_request(Router, :put, "comments/1")
    assert conn.status == 200
    assert conn.resp_body == "update comments"
    assert conn.params["id"] == "1"
  end

  test "patch with resources to 'comments/2' maps to update action" do
   {:ok, conn} = simulate_request(Router, :patch, "comments/2")
    assert conn.status == 200
    assert conn.resp_body == "update comments"
    assert conn.params["id"] == "2"
  end

  test "delete with resources to 'comments/2' maps to destroy action" do
   {:ok, conn} = simulate_request(Router, :delete, "comments/2")
    assert conn.status == 200
    assert conn.resp_body == "destroy comments"
    assert conn.params["id"] == "2"
  end

  test "unmatched route returns 404" do
   {:ok, conn} = simulate_request(Router, :get, "route_does_not_exist")
    assert conn.status == 404
  end

  test "dispatch crash returns 500" do
    {:ok, conn} = simulate_request(Router, :get, "route_that_crashes")
    assert conn.status == 500
    assert conn.resp_body =~ %r/Internal Server Error/
  end

  test "splat arg with preceeding named parameter to files/:user_name/*path" do
    {:ok, conn} = simulate_request(Router, :get, "files/elixir/Users/home/file.txt")
    assert conn.status == 200
    assert conn.params["user_name"] == "elixir"
    assert conn.params["path"] == "Users/home/file.txt"
  end

  test "splat arg with preceeding string to backups/*path" do
    {:ok, conn} = simulate_request(Router, :get, "backups/name")
    assert conn.status == 200
    assert conn.params["path"] == "name"
  end

  test "splat arg with multiple preceeding strings to static/images/icons/*path" do
    {:ok, conn} = simulate_request(Router, :get, "static/images/icons/elixir/logos/main.png")
    assert conn.status == 200
    assert conn.params["image"] == "elixir/logos/main.png"
  end

  test "named route builds _path url helper" do
    assert Router.user_path(id: 88) == "/users/88"
  end
end

