defmodule Phoenix.Controller.ErrorHandlingTest do
  use ExUnit.Case, async: false
  use PlugHelper
  alias Phoenix.Controller.ErrorHandlingTest
  alias ErrorHandlingTest.RouterCatchAllHandler
  alias ErrorHandlingTest.RouterNoHandler
  alias ErrorHandlingTest.RouterCustomHandler
  alias ErrorHandlingTest.ErrorController
  alias ErrorHandlingTest.CustomerErrorController

  setup_all do
    Mix.Config.persist(phoenix: [
      {RouterCatchAllHandler,
        error_controller: ErrorController
      }
    ])

    defmodule MyController do
      use Phoenix.Controller

      plug :action

      def not_found(conn, _params) do
        throw {:not_found, conn}
      end

      def error(_conn, _params) do
        raise "boom"
      end
    end

    defmodule CustomerErrorController do
      use Phoenix.Controller

      plug :action

      def call(conn, options) do
        try do
          super(conn, options)
        catch
          :throw, {:not_found, conn} -> text(conn, "couldn't find it")
        end
      end

      def not_found(conn, _params) do
        throw {:not_found, conn}
      end

      def error(_conn, _params) do
        raise "boom"
      end
    end

    defmodule ErrorController do
      use Phoenix.Controller

      def handle_error(conn, :throw, {:not_found, conn}) do
        assign(conn, :error, :handled_404)
      end

      def handle_error(conn, _kind, _error) do
        assign(conn, :error, :handled_500)
      end
    end

    defmodule RouterCatchAllHandler do
      use Phoenix.Router
      get "/404", MyController, :not_found
      get "/500", MyController, :error
    end

    defmodule RouterNoHandler do
      use Phoenix.Router
      get "/404", MyController, :not_found
      get "/500", MyController, :error
    end

    defmodule RouterCustomHandler do
      use Phoenix.Router
      get "/404", CustomerErrorController, :not_found
      get "/500", CustomerErrorController, :error
    end

    :ok
  end

  test "error_controller can be configured for custom 404 handling" do
    conn = simulate_request(RouterCatchAllHandler, :get, "/404")
    assert conn.assigns[:error] == :handled_404
  end

  test "error_controller can be configured for custom error handling" do
    conn = simulate_request(RouterCatchAllHandler, :get, "/500")
    assert conn.assigns[:error] == :handled_500
  end

  test "default 404 handling returns 404 status" do
    conn = simulate_request(RouterNoHandler, :get, "/404")
    assert conn.status == 404
    assert conn.assigns[:error] == nil
  end

  test "default 500 handling returns 500 status" do
    conn = simulate_request(RouterNoHandler, :get, "/500")
    assert conn.status == 500
    assert conn.assigns[:error] == nil
  end

  test "controllers can override call/2 for custom error handling per controller" do
    conn = simulate_request(RouterCustomHandler, :get, "/404")
    assert conn.status == 200
    assert conn.resp_body == "couldn't find it"
  end

end
