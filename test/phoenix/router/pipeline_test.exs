defmodule Phoenix.Router.PipelineTest.SampleController do
  use Phoenix.Controller
  plug :action
  def index(conn, _params), do: text(conn, "index")
  def crash(_conn, _params), do: raise "crash!"
end

alias Phoenix.Router.PipelineTest.SampleController

## Empty router

Application.put_env(:phoenix, Phoenix.Router.PipelineTest.EmptyRouter,
  static: false, parsers: false, http: false, https: false)

defmodule Phoenix.Router.PipelineTest.EmptyRouter do
  use Phoenix.Router

  get "/root", SampleController, :index
  put "/root/:id", SampleController, :index
end

alias Phoenix.Router.PipelineTest.EmptyRouter

## Router

Application.put_env(:phoenix, Phoenix.Router.PipelineTest.Router,
  session: [store: :cookie, key: "_app"],
  secret_key_base: String.duplicate("abcdefgh", 8),
  http: false, https: false)

# Define it at the top to guarantee there is no scope
# leakage from the test case.
defmodule Phoenix.Router.PipelineTest.Router do
  use Phoenix.Router

  pipeline :before do
    plug :put_assign, "from before"
    plug :super
  end

  pipeline :browser do
    plug :fetch_session
  end

  pipeline :browser do
    plug :super
    plug :put_session, "from browser" # session must be fetched
    plug :put_assign, "from browser"
  end

  pipeline :api do
    plug :put_assign, "from api"
  end

  get "/root", SampleController, :index
  put "/root/:id", SampleController, :index
  get "/route_that_crashes", SampleController, :crash

  scope "/browser" do
    pipe_through :browser
    get "/root", SampleController, :index

    scope "/api" do
      pipe_through :api
      get "/root", SampleController, :index
    end
  end

  scope "/browser-api" do
    pipe_through [:browser, :api]
    get "/root", SampleController, :index
  end

  defp put_assign(conn, value) do
    assign conn, :stack, value
  end

  defp put_session(conn, value) do
    put_session conn, :stack, value
  end
end

alias Phoenix.Router.PipelineTest.Router

defmodule Phoenix.Router.PipelineTest do
  use ExUnit.Case, async: true
  use ConnHelper

  setup_all do
    EmptyRouter.start()
    Router.start()
    on_exit &EmptyRouter.stop/0
    on_exit &Router.stop/0
    :ok
  end

  setup do
    Logger.disable(self())
    :ok
  end

  ## No configuration

  test "does not setup the session" do
    conn = call(EmptyRouter, :get, "/root")
    assert_raise ArgumentError, "cannot fetch session without a configured session plug", fn ->
      fetch_session(conn)
    end
  end

  test "does not setup parsers" do
    conn = call(EmptyRouter, :put, "/root/1", "{\"foo\": [1, 2, 3]}",
                [headers: [{"content-type", "application/json"}]])
    assert conn.params.__struct__ == Plug.Conn.Unfetched
  end

  test "does not setup static" do
    conn = call(EmptyRouter, :get, "/js/phoenix.js")
    assert conn.status == 404
  end

  test "does not override method" do
    conn = call(EmptyRouter, :post, "/root/1", %{"_method" => "PUT"})
    assert conn.status == 404
  end

  ## Plug configuration

  test "dispatch crash returns 500 and renders friendly error page" do
    conn = call(Router, :get, "/route_that_crashes")
    assert conn.status == 500
    assert conn.resp_body =~ ~r/Something went wrong/i
    refute conn.resp_body =~ ~r/Stacktrace/i
  end

  test "converts HEAD requests to GET" do
    conn = call(Router, :head, "/root")
    assert conn.status == 200
    assert conn.resp_body == ""
  end

  test "parsers parses json body" do
    conn = call(Router, :put, "/root/1", "{\"foo\": [1, 2, 3]}",
                [headers: [{"content-type", "application/json"}]])
    assert conn.status == 200
    assert conn.params["id"] == "1"
    assert conn.params["foo"] == [1, 2, 3]
  end

  test "parsers accepts all media types" do
    conn = call(Router, :put, "/root/1", "WIDGET",
                [headers: [{"content-type", "application/widget"}]])
    assert conn.status == 200
    assert conn.params["id"] == "1"
  end

  test "parsers servers static assets" do
    conn = call(Router, :get, "/js/phoenix.js")
    assert conn.status == 200
  end

  test "overrides method" do
    conn = call(Router, :post, "/root/1", %{"_method" => "PUT"})
    assert conn.status == 200
    assert conn.params["id"] == "1"
  end

  ## Pipelines

  test "does not invoke pipelines at root" do
    conn = call(Router, :get, "/root")
    assert conn.assigns.stack == "from before"
  end

  test "invokes pipelines per scope" do
    conn = call(Router, :get, "/browser/root")
    assert conn.assigns.stack == "from browser"
    assert get_session(conn, :stack) == "from browser"
  end

  test "invokes pipelines in a nested scope" do
    conn = call(Router, :get, "/browser/api/root")
    assert conn.assigns.stack == "from api"
    assert get_session(conn, :stack) == "from browser"
  end

  test "invokes multiple pipelines" do
    conn = call(Router, :get, "/browser-api/root")
    assert conn.assigns.stack == "from api"
    assert get_session(conn, :stack) == "from browser"
  end

  test "invalid pipelines" do
    assert_raise ArgumentError, ~r"unknown pipeline :unknown", fn ->
      defmodule ErrorRouter do
        use Phoenix.Router
        pipe_through :unknown
      end
    end

    assert_raise ArgumentError, ~r"the :before pipeline is always piped through", fn ->
      defmodule ErrorRouter do
        use Phoenix.Router
        pipe_through :before
      end
    end
  end
end
