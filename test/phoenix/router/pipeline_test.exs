# Define it at the top to guarantee there is no scope
# leakage from the test case.

defmodule Phoenix.Router.PipelineTest.SampleController do
  use Phoenix.Controller
  plug :action
  def index(conn, _params), do: text(conn, "index")
  def crash(_conn, _params), do: raise "crash!"
end

alias Phoenix.Router.PipelineTest.SampleController

defmodule Phoenix.Router.PipelineTest.Router do
  use Phoenix.Router

  pipeline :browser do
    plug :put_assign, "browser"
  end

  pipeline :api do
    plug :put_assign, "api"
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
end

alias Phoenix.Router.PipelineTest.Router

defmodule Phoenix.Router.PipelineTest do
  use ExUnit.Case, async: true
  use RouterHelper

  setup do
    Logger.disable(self())
    :ok
  end

  test "does not invoke pipelines at root" do
    conn = call(Router, :get, "/root")
    assert conn.private[:phoenix_pipelines] == []
    assert conn.assigns[:stack] == nil
  end

  test "invokes pipelines per scope" do
    conn = call(Router, :get, "/browser/root")
    assert conn.private[:phoenix_pipelines] == [:browser]
    assert conn.assigns[:stack] == "browser"
  end

  test "invokes pipelines in a nested scope" do
    conn = call(Router, :get, "/browser/api/root")
    assert conn.private[:phoenix_pipelines] == [:browser, :api]
    assert conn.assigns[:stack] == "api"
  end

  test "invokes multiple pipelines" do
    conn = call(Router, :get, "/browser-api/root")
    assert conn.private[:phoenix_pipelines] == [:browser, :api]
    assert conn.assigns[:stack] == "api"
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
