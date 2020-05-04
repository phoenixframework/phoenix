defmodule Phoenix.Router.ResourcesTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule UserController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "show users")
    def index(conn, _params), do: text(conn, "index users")
    def new(conn, _params), do: text(conn, "new users")
    def edit(conn, _params), do: text(conn, "edit users")
    def create(conn, _params), do: text(conn, "create users")
    def update(conn, _params), do: text(conn, "update users")
    def delete(conn, _params), do: text(conn, "delete users")
  end

  defmodule Api.FileController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "show files")
    def index(conn, _params), do: text(conn, "index files")
    def new(conn, _params), do: text(conn, "new files")
  end

  defmodule Api.CommentController do
    use Phoenix.Controller
    def show(conn, _params), do: text(conn, "show comments")
    def index(conn, _params), do: text(conn, "index comments")
    def new(conn, _params), do: text(conn, "new comments")
    def create(conn, _params), do: text(conn, "create comments")
    def update(conn, _params), do: text(conn, "update comments")
    def delete(conn, _params), do: text(conn, "delete comments")
    def special(conn, _params), do: text(conn, "special comments")
  end

  defmodule Router do
    use Phoenix.Router

    resources "/users", UserController, alias: Api do
      resources "/comments", CommentController do
        get "/special", CommentController, :special
      end
      resources "/files", FileController, except: [:delete]
    end

    resources "/members", UserController, only: [:show, :new, :delete]

    resources "/files", Api.FileController, only: [:index]

    resources "/admin", UserController, param: "slug", name: "admin", only: [:show], alias: Api do
      resources "/comments", CommentController, param: "key", name: "post", except: [:delete]
      resources "/files", FileController, only: [:show, :index, :new]
    end
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "toplevel route matches new action" do
    conn = call(Router, :get, "users/new")
    assert conn.status == 200
    assert conn.resp_body == "new users"
  end

  test "toplevel route matches index action" do
    conn = call(Router, :get, "users")
    assert conn.status == 200
    assert conn.resp_body == "index users"
  end

  test "toplevel route matches show action with named param" do
    conn = call(Router, :get, "users/123")
    assert conn.status == 200
    assert conn.resp_body == "show users"
    assert conn.params["id"] == "123"
  end

  test "toplevel route matches edit action with named param" do
    conn = call(Router, :get, "users/123/edit")
    assert conn.status == 200
    assert conn.resp_body == "edit users"
    assert conn.params["id"] == "123"
  end

  test "toplevel route matches create action" do
    conn = call(Router, :post, "users")
    assert conn.status == 200
    assert conn.resp_body == "create users"
  end

  test "toplevel route matches update action with both PUT and PATCH" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "users/1")
      assert conn.status == 200
      assert conn.resp_body == "update users"
      assert conn.params["id"] == "1"

      conn = call(Router, method, "users/2")
      assert conn.status == 200
      assert conn.resp_body == "update users"
      assert conn.params["id"] == "2"
    end
  end

  test "toplevel route matches delete action" do
    conn = call(Router, :delete, "users/2")
    assert conn.status == 200
    assert conn.resp_body == "delete users"
    assert conn.params["id"] == "2"
  end

  test "1-Level nested route matches with named param prefix on show" do
    conn = call(Router, :get, "users/1/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show comments"
    assert conn.params["id"] == "2"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on index" do
    conn = call(Router, :get, "users/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on create" do
    conn = call(Router, :post, "users/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "create comments"
    assert conn.params["user_id"] == "1"
  end

  test "1-Level nested route matches with named param prefix on update" do
    conn = call(Router, :patch, "users/1/comments/123")
    assert conn.status == 200
    assert conn.resp_body == "update comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "123"
  end

  test "1-Level nested route matches with named param prefix on delete" do
    conn = call(Router, :delete, "users/1/comments/123")
    assert conn.status == 200
    assert conn.resp_body == "delete comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["id"] == "123"
  end

  test "2-Level nested route with get matches" do
    conn = call(Router, :get, "users/1/comments/123/special")
    assert conn.status == 200
    assert conn.resp_body == "special comments"
    assert conn.params["user_id"] == "1"
    assert conn.params["comment_id"] == "123"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = call(Router, :get, "users/8/files/10")
    assert conn.status == 200
    assert conn.resp_body == "show files"
    assert conn.params["user_id"] == "8"
    assert conn.params["id"] == "10"

    conn = call(Router, :get, "files")
    assert conn.status == 200
    assert conn.resp_body == "index files"
  end

  test "nested options limit resource by passing :except option" do
    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :delete, "users/1/files/2")
    end

    conn = call(Router, :get, "users/1/files/new")
    assert conn.status == 200
  end

  test "nested options limit resource by passing :only option" do
    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :patch, "admin/1/files/2")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :post, "admin/1/files")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :delete, "admin/1/files/1")
    end

    conn = call(Router, :get, "admin/1/files/")
    assert conn.status == 200
    conn = call(Router, :get, "admin/1/files/1")
    assert conn.status == 200
    conn = call(Router, :get, "admin/1/files/new")
    assert conn.status == 200
  end

  test "resource limiting options should work for nested resources" do
    conn = call(Router, :get, "admin/1")
    assert conn.status == 200
    assert conn.resp_body == "show users"

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :get, "admin/")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :patch, "admin/1")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :post, "admin")
    end

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :delete, "admin/1")
    end

    conn = call(Router, :get, "admin/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "index comments"

    conn = call(Router, :get, "admin/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "show comments"

    conn = call(Router, :patch, "admin/1/comments/1")
    assert conn.status == 200
    assert conn.resp_body == "update comments"

    conn = call(Router, :post, "admin/1/comments")
    assert conn.status == 200
    assert conn.resp_body == "create comments"

    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :delete, "scoped_files/1")
    end
  end

  test "param option allows default singularlized _id param to be overridden" do
    conn = call(Router, :get, "admin/foo")
    assert conn.status == 200
    assert conn.params["slug"] == "foo"
    assert conn.resp_body == "show users"
    assert Router.Helpers.admin_path(conn, :show, "foo") ==
           "/admin/foo"

    conn = call(Router, :get, "admin/bar/comments/the_key")
    assert conn.status == 200
    assert conn.params["admin_slug"] == "bar"
    assert conn.params["key"] == "the_key"
    assert conn.resp_body == "show comments"
    assert Router.Helpers.admin_post_path(conn, :show, "bar", "the_key") ==
           "/admin/bar/comments/the_key"
  end

  test "resources with :only sets proper match order for :show and :new" do
    conn = call(Router, :get, "members/new")
    assert conn.status == 200
    assert conn.resp_body == "new users"

    conn = call(Router, :get, "members/2")
    assert conn.status == 200
    assert conn.resp_body == "show users"
    assert conn.params["id"] == "2"
  end

  test "singleton resources declaring an :index route throws an ArgumentError" do
    assert_raise ArgumentError, ~r/supported singleton actions: \[:edit, :new, :show, :create, :update, :delete\]/, fn ->
      defmodule SingletonRouter.Router do
        use Phoenix.Router
        resources "/", UserController, singleton: true, only: [:index]
      end
    end
  end

  test "resources validates :only actions" do
    assert_raise ArgumentError, ~r/supported actions: \[:index, :edit, :new, :show, :create, :update, :delete\]/, fn ->
      defmodule SingletonRouter.Router do
        use Phoenix.Router
        resources "/", UserController, only: [:bad_index]
      end
    end
  end

  test "resources validates :except actions" do
    assert_raise ArgumentError, ~r/supported actions: \[:index, :edit, :new, :show, :create, :update, :delete\]/, fn ->
      defmodule SingletonRouter.Router do
        use Phoenix.Router
        resources "/", UserController, except: [:bad_index]
      end
    end
  end
end
