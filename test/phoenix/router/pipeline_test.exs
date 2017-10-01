# Define it at the top to guarantee there is no scope
# leakage from the test case.

defmodule Phoenix.Router.PipelineTest.SampleController do
  use Phoenix.Controller
  def index(conn, _params), do: text(conn, "index")
  def crash(_conn, _params), do: raise "crash!"

  # Let's also define a custom plug that we will
  # use in our router as part of a pipeline
  def noop_plug(conn, _opts), do: conn
end

alias Phoenix.Router.PipelineTest.SampleController

defmodule Phoenix.Router.PipelineTest.Router do
  use Phoenix.Router

  # This should work even if the import comes
  # after the Phoenix.Router definition
  import SampleController, only: [noop_plug: 2]

  pipeline :browser do
    plug :put_assign, "browser"
  end

  pipeline :api do
    plug :put_assign, "api"
  end

  pipeline :params do
    plug :put_params
  end

  pipeline :halt do
    plug :stop
  end

  pipeline :halt_again do
    plug :stop
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

    scope "/:id" do
      pipe_through :params
      get "/", SampleController, :index
    end
  end

  scope "/browser-api" do
    pipe_through [:browser, :api]
    get "/root", SampleController, :index
  end

  scope "/stop" do
    pipe_through [:noop_plug, :halt, :halt_again]
    get "/", SampleController, :index
  end

  defp stop(conn, _) do
    conn |> send_resp(200, "stop") |> halt
  end

  defp put_assign(conn, value) do
    assign conn, :stack, value
  end

  defp put_params(conn, _) do
    assign conn, :params, conn.params
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

  test "halts on pipeline multiple pipelines" do
    conn = call(Router, :get, "/stop")
    assert conn.halted
    assert conn.status == 200
    assert conn.resp_body == "stop"
  end

  test "wraps failures on call" do
    assert_raise Plug.Conn.WrapperError, fn ->
      call(Router, :get, "/route_that_crashes")
    end
  end

  test "merge parameters before invoking pipelines" do
    conn = call(Router, :get, "/browser/hello")
    assert conn.assigns[:params] == %{"id" => "hello"}
  end

  test "duplicate pipe_through's raises" do
    assert_raise ArgumentError, ~r{duplicate pipe_through for :browser}, fn ->
      defmodule DupPipeThroughRouter do
        use Phoenix.Router, otp_app: :phoenix
        pipeline :browser do
        end
        scope "/" do
          pipe_through [:browser, :auth, :browser]
        end
      end
    end

    assert_raise ArgumentError, ~r{duplicate pipe_through for :browser}, fn ->
      defmodule DupScopedPipeThroughRouter do
        use Phoenix.Router, otp_app: :phoenix
        pipeline :browser do
        end
        scope "/" do
          pipe_through [:browser]
          scope "/nested" do
            pipe_through [:browser]
          end
        end
      end
    end
  end
end
