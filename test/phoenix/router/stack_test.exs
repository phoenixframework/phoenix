defmodule Phoenix.Router.StackTest.UserController do
  use Phoenix.Controller
  def show(conn, _params), do: text(conn, "users index")
  def crash(_conn, _params), do: raise "crash!"
end

alias Phoenix.Router.StackTest.UserController

# Define it at the top to guarantee there is no scope
# leakage from the test case.
defmodule Phoenix.Router.StackTest.Router do
  use Phoenix.Router

  get "/users/:id", UserController, :show, as: :users
  get "/route_that_crashes", UserController, :crash
end

alias Phoenix.Router.StackTest.Router

defmodule Phoenix.Router.StackTest do
  use ExUnit.Case, async: true
  use ConnHelper

  setup do
    Logger.disable(self())
    :ok
  end

  ## Plug stack

  test "dispatch crash returns 500 and renders friendly error page" do
    conn = call(Router, :get, "/route_that_crashes")
    assert conn.status == 500
    assert conn.resp_body =~ ~r/Something went wrong/i
    refute conn.resp_body =~ ~r/Stacktrace/i
  end

  test "parsers accepts all media types" do
    conn = call(Router, :get, "/users/1", %{}, [headers: [{"content-type", "application/widget"}]])
    assert conn.status == 200
    assert conn.params["id"] == "1"
  end
end
