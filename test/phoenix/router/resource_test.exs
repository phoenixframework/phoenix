defmodule Phoenix.Router.ResourceTest do
  use ExUnit.Case, async: true
  use RouterHelper

  defmodule Api.GenericController do
    use Phoenix.Controller
    plug :action
    def show(conn, _params), do: text(conn, "show")
    def new(conn, _params), do: text(conn, "new")
    def edit(conn, _params), do: text(conn, "edit")
    def create(conn, _params), do: text(conn, "create")
    def update(conn, _params), do: text(conn, "update")
    def delete(conn, _params), do: text(conn, "delete")
  end

  defmodule Router do
    use Phoenix.Router

    resource "/account", Api.GenericController, alias: Api do
      resources "/comments", GenericController
      resource "/session", GenericController, except: [:delete]
    end

    resource "/session", Api.GenericController, only: [:show]
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "toplevel route matches new action" do
    conn = call(Router, :get, "account/new")
    assert conn.status == 200
    assert conn.resp_body == "new"
  end

  test "toplevel route matches show action" do
    conn = call(Router, :get, "account")
    assert conn.status == 200
    assert conn.resp_body == "show"
  end

  test "toplevel route matches edit action" do
    conn = call(Router, :get, "account/edit")
    assert conn.status == 200
    assert conn.resp_body == "edit"
  end

  test "toplevel route matches create action" do
    conn = call(Router, :post, "account")
    assert conn.status == 200
    assert conn.resp_body == "create"
  end

  test "toplevel route matches update action with both PUT and PATCH" do
    for method <- [:put, :patch] do
      conn = call(Router, method, "account")
      assert conn.status == 200
      assert conn.resp_body == "update"

      conn = call(Router, method, "account")
      assert conn.status == 200
      assert conn.resp_body == "update"
    end
  end

  test "toplevel route matches delete action" do
    conn = call(Router, :delete, "account")
    assert conn.status == 200
    assert conn.resp_body == "delete"
  end

  test "1-Level nested route matches" do
    conn = call(Router, :get, "account/comments/2")
    assert conn.status == 200
    assert conn.resp_body == "show"
    assert conn.params["id"] == "2"
  end

  test "nested prefix context reverts back to previous scope after expansion" do
    conn = call(Router, :get, "account/session")
    assert conn.status == 200
    assert conn.resp_body == "show"

    conn = call(Router, :get, "session")
    assert conn.status == 200
    assert conn.resp_body == "show"
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
