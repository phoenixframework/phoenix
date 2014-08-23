defmodule Phoenix.Controller.ErrorHandlingTest do
  use ExUnit.Case, async: false
  use PlugHelper
  alias Phoenix.Controller.ErrorHandlingTest
  alias ErrorHandlingTest.RouterCustomPageController
  alias ErrorHandlingTest.RouterDefaultPageController
  alias ErrorHandlingTest.RouterDefaultPageControllerDebugErrors
  alias ErrorHandlingTest.RouterDefaultPageControllerNoCatch
  alias ErrorHandlingTest.PageController

  setup_all do
    Mix.Config.persist(phoenix: [
      {RouterCustomPageController,
        page_controller: PageController,
        catch_errors: true
      },
      {RouterDefaultPageController,
        catch_errors: true
      },
      {RouterDefaultPageControllerNoCatch,
        catch_errors: false
      },
      {RouterDefaultPageControllerDebugErrors,
        catch_errors: true,
        debug_errors: true
      }
    ])

    defmodule MyController do
      use Phoenix.Controller

      plug :action

      def call(conn, options) do
        try do
          super(conn, options)
        catch
          :throw, "boom" -> text(conn, 500, "boom")
        end
      end

      def assign_404(conn, _params), do: assign_status(conn, 404)
      def assign_500(conn, _params), do: assign_status(conn, 500)
      def raise_500(_conn, _params), do: raise "boom!"
      def throw_error(_conn, _params), do: throw "boom"
    end

    defmodule PageController do
      use Phoenix.Controller

      def error(conn, _) do
        case error(conn) do
          _ -> assign(conn, :error, :handled_500)
        end
      end

      def not_found(conn, _) do
        conn
        |> assign(:error, :handled_404)
        |> text 404, "not found"
      end
    end

    defmodule RouterCustomPageController do
      use Phoenix.Router
      get "/404", MyController, :assign_404
      get "/500", MyController, :assign_500
      get "/500-raise", MyController, :raise_500
      get "/500-throw", MyController, :throw_error
    end

    defmodule RouterDefaultPageController do
      use Phoenix.Router
      get "/404", MyController, :assign_404
      get "/500", MyController, :assign_500
      get "/500-raise", MyController, :raise_500
      get "/500-throw", MyController, :throw_error
    end

    defmodule RouterDefaultPageControllerNoCatch do
      use Phoenix.Router
      get "/500-raise", MyController, :raise_500
    end

    defmodule RouterDefaultPageControllerDebugErrors do
      use Phoenix.Router
      get "/404", MyController, :assign_404
      get "/500", MyController, :assign_500
      get "/500-raise", MyController, :raise_500
      get "/500-throw", MyController, :throw_error
    end

    :ok
  end


  test "default PageController renders 404 for returned 404 status" do
    conn = simulate_request(RouterDefaultPageController, :get, "/404")
    assert String.match?(conn.resp_body, ~r/not found/)
  end

  test "default PageController renders 500 for returned 500 status" do
    conn = simulate_request(RouterDefaultPageController, :get, "/500")
    assert String.match?(conn.resp_body, ~r/Something went wrong/)
  end

  test "default PageController renders 500 for errors when catch_errors: true" do
    conn = simulate_request(RouterDefaultPageController, :get, "/500-raise")
    assert String.match?(conn.resp_body, ~r/Something went wrong/)
  end

  test "errors are not caught when catch_errors: false" do
    assert_raise RuntimeError, fn ->
      simulate_request(RouterDefaultPageControllerNoCatch, :get, "/500-raise")
    end
  end

  test "page_controller can be configured for custom 404 handling" do
    conn = simulate_request(RouterCustomPageController, :get, "/404")
    assert conn.assigns[:error] == :handled_404
  end

  test "page_controller can be configured for custom 500 handling" do
    conn = simulate_request(RouterCustomPageController, :get, "/500-raise")
    assert conn.assigns[:error] == :handled_500
  end

  test "controller can override call/2 to cache errors" do
    conn = simulate_request(RouterCustomPageController, :get, "/500-throw")
    assert conn.status == 500
    assert conn.resp_body == "boom"
  end

  test "debug_errors: true renders Phoenix's debug 404 page" do
    conn = simulate_request(RouterDefaultPageControllerDebugErrors, :get, "/400")
    assert String.match?(conn.resp_body, ~r/No route matches/)
  end

  test "debug_errors: true renders Phoenix's debug 500 page for assigned 500 status" do
    conn = simulate_request(RouterDefaultPageControllerDebugErrors, :get, "/500")
    assert String.match?(conn.resp_body, ~r/Something went wrong/)
  end

  test "debug_errors: true renders Phoenix's debug 500 page for uncaught error" do
    conn = simulate_request(RouterDefaultPageControllerDebugErrors, :get, "/500-raise")
    assert String.match?(conn.resp_body, ~r/Stacktrace/)
  end
end

