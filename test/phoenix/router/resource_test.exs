defmodule Phoenix.Router.ResourceTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule AccountController do
    use Phoenix.Controller
    plug :action
    def show(conn, _params), do: text(conn, "show account")
    def new(conn, _params), do: text(conn, "new account")
    def edit(conn, _params), do: text(conn, "edit account")
    def create(conn, _params), do: text(conn, "create account")
    def update(conn, _params), do: text(conn, "update account")
    def delete(conn, _params), do: text(conn, "delete account")
  end

  defmodule Api.SessionController do
    use Phoenix.Controller
    plug :action
    def show(conn, _params), do: text(conn, "show session")
    def new(conn, _params), do: text(conn, "new session")
  end

  defmodule Api.CommentController do
    use Phoenix.Controller
    plug :action
    def show(conn, _params), do: text(conn, "show comments")
  end

  defmodule Router do
    use Phoenix.Router

    resource "/account", AccountController, alias: Api do
      resources "/comments", CommentController
      resource "/session", SessionController, except: [:delete]
    end

    resource "/session", Api.SessionController, only: [:show]
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "toplevel route matches new action" do
    conn = call(Router, :get, "account/new")
    assert conn.status == 200
    assert conn.resp_body == "new account"
  end

  test "toplevel route matches show action" do
    conn = call(Router, :get, "account")
    assert conn.status == 200
    assert conn.resp_body == "show account"
  end

  test "toplevel route matches edit action" do
    conn = call(Router, :get, "account/edit")
    assert conn.status == 200
    assert conn.resp_body == "edit account"
  end

  test "toplevel route matches create action" do
    conn = call(Router, :post, "account")
    assert conn.status == 200
    assert conn.resp_body == "create account"
  end

  test "toplevel route matches update action with both PUT and PATCH" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "account")
      assert conn.status == 200
      assert conn.resp_body == "update account"

      conn = call(Router, method, "account")
      assert conn.status == 200
      assert conn.resp_body == "update account"
    end
  end

  test "toplevel route matches delete action" do
    conn = call(Router, :delete, "account")
    assert conn.status == 200
    assert conn.resp_body == "delete account"
  end

  test "1-Level nested route matches" do
    conn = call(Router, :get, "account/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show comments"
    assert conn.params["id"] == "2"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = call(Router, :get, "account/session")
    assert conn.status == 200
    assert conn.resp_body == "show session"

    conn = call(Router, :get, "session")
    assert conn.status == 200
    assert conn.resp_body == "show session"
  end

  test "limit resource by passing :except option" do
    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :delete, "account/session")
    end

    conn = call(Router, :get, "account/session/new")
    assert conn.status == 200
  end

  test "limit resource by passing :only option" do
    assert_raise Phoenix.Router.NoRouteError, fn ->
      call(Router, :patch, "session/new")
    end

    conn = call(Router, :get, "session")
    assert conn.status == 200
  end
end
