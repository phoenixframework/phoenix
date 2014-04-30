defmodule Phoenix.Router.NestedTest do
  use ExUnit.Case
  use PlugHelper

  defmodule Controllers.Users do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show users")
    def index(conn), do: text(conn, "index users")
    def new(conn), do: text(conn, "new users")
    def create(conn), do: text(conn, "create users")
    def update(conn), do: text(conn, "update users")
    def destroy(conn), do: text(conn, "destroy users")
  end

  defmodule Controllers.Files do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show files")
    def index(conn), do: text(conn, "index files")
    def new(conn), do: text(conn, "new files")
    def create(conn), do: text(conn, "create files")
    def update(conn), do: text(conn, "update files")
    def destroy(conn), do: text(conn, "destroy files")
  end

  defmodule Controllers.Comments do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show comments")
    def index(conn), do: text(conn, "index comments")
    def new(conn), do: text(conn, "new comments")
    def create(conn), do: text(conn, "create comments")
    def update(conn), do: text(conn, "update comments")
    def destroy(conn), do: text(conn, "destroy comments")
    def special(conn), do: text(conn, "special comments")
  end

  defmodule SessionsController do
    use Phoenix.Controller

    def new(conn), do: text(conn, "session login")
    def create(conn), do: text(conn, "session created")
    def destroy(conn), do: text(conn, "session destroyed")
  end

  defmodule PostsController do
    use Phoenix.Controller
    def show(conn), do: text(conn, "show posts")
    def new(conn), do: text(conn, "new posts")
    def index(conn), do: text(conn, "index posts")
    def create(conn), do: text(conn, "create posts")
    def update(conn), do: text(conn, "update posts")
  end


  defmodule Router do
    use Phoenix.Router
    resources "users", Controllers.Users do
      resources "comments", Controllers.Comments do
        get "/special", Controllers.Comments, :special
      end
      resources "files", Controllers.Files
      resources "posts", PostsController, except: [ :destroy ]
      resources "sessions", SessionsController, only: [ :new, :create, :destroy ]
    end

    resources "files", Controllers.Files do
      resources "comments", Controllers.Comments do
        get "/avatar", Controllers.Users, :avatar
      end
    end

    resources "scoped_files", Controllers.Files, only: [:index] do
      resources "comments", Controllers.Comments, except: [:destroy]
    end
  end


  test "toplevel route matches without nesting" do
    conn = simulate_request(Router, :get, "users/1")
    assert conn.status == 200
    assert conn.resp_body == "show users"
    assert conn.params["id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on show" do
    conn = simulate_request(Router, :get, "users/1/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show comments"
    assert conn.params["id"] == "2"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on index" do
    conn = simulate_request(Router, :get, "users/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on create" do
    conn = simulate_request(Router, :post, "users/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "create comments"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on update" do
    conn = simulate_request(Router, :put, "users/1/comments/123")
    assert conn.status == 200
    assert conn.resp_body == "update comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "123"
  end

  test "1-Level nested route matches with named param prefix on destroy" do
    conn = simulate_request(Router, :delete, "users/1/comments/123")
    assert conn.status == 200
    assert conn.resp_body == "destroy comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "123"
  end

  test "2-Level nested route with get matches" do
    conn = simulate_request(Router, :get, "users/1/comments/123/special")
    assert conn.status == 200
    assert conn.resp_body == "special comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["comment_id"] == "123"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = simulate_request(Router, :get, "users/8/files/10")
    assert conn.status == 200
    assert conn.resp_body == "show files"
    assert conn.params["user_id"] == "8"
    assert conn.params["id"] == "10"

    conn = simulate_request(Router, :get, "files")
    assert conn.status == 200
    assert conn.resp_body == "index files"
  end

  test "nested options limit resource by passing :except option" do
    conn = simulate_request(Router, :delete, "users/1/posts/2")
     assert conn.status == 404
    conn = simulate_request(Router, :get, "users/1/posts/new")
    assert conn.status == 200
  end

  test "nested options limit resource by passing :only option" do
    conn = simulate_request(Router, :put, "users/1/sessions/2")
     assert conn.status == 404
    conn = simulate_request(Router, :get, "users/1/sessions/")
     assert conn.status == 404
    conn = simulate_request(Router, :get, "users/1/sessions/1")
     assert conn.status == 404
    conn = simulate_request(Router, :get, "users/1/sessions/new")
    assert conn.status == 200
    conn = simulate_request(Router, :post, "users/1/sessions")
    assert conn.status == 200
    conn = simulate_request(Router, :delete, "users/1/sessions/1")
    assert conn.status == 200
  end

  test "resource limiting options should work for nested resources" do
    conn = simulate_request(Router, :get, "scoped_files")
    assert conn.status == 200
    assert conn.resp_body == "index files"

    conn = simulate_request(Router, :get, "scoped_files/1")
    assert conn.status == 404
    conn = simulate_request(Router, :put, "scoped_files/1")
    assert conn.status == 404
    conn = simulate_request(Router, :post, "scoped_files")
    assert conn.status == 404
    conn = simulate_request(Router, :delete, "scoped_files/1")
    assert conn.status == 404

    conn = simulate_request(Router, :get, "scoped_files/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"

    conn = simulate_request(Router, :get, "scoped_files/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "show comments"

    conn = simulate_request(Router, :put, "scoped_files/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "update comments"

    conn = simulate_request(Router, :post, "scoped_files/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "create comments"

    conn = simulate_request(Router, :delete, "scoped_files/1")
    assert conn.status == 404
  end
end
