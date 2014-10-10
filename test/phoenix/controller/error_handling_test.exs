defmodule Phoenix.Controller.ErrorHandlingTest do
  use ExUnit.Case, async: true
  use ConnHelper

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

    def assign_404(conn, _params), do: put_status(conn, 404)
    def assign_500(conn, _params), do: put_status(conn, 500)
    def raise_500(_conn, _params), do: raise "boom!"
    def throw_error(_conn, _params), do: throw "boom"
  end

  defmodule PageController do
    use Phoenix.Controller

    plug :action

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

  defmodule Router do
    use Phoenix.Router

    get "/404", MyController, :assign_404
    get "/500", MyController, :assign_500
    get "/500-raise", MyController, :raise_500
    get "/500-throw", MyController, :throw_error
  end

  @defaults [catch_errors: true,
             debug_errors: false,
             error_controller: Phoenix.Controller.ErrorController]

  defp config!(opts) do
    Phoenix.Config.store(Router, Keyword.merge(@defaults, opts))
  end

  setup_all do
    Application.put_env(:phoenix, Router, http: false, https: false)
    Router.start()
    on_exit &Router.stop/0
  end

  setup do
    Logger.disable(self())
    :ok
  end

  test "default error controller renders 404 for returned 404 status" do
    config! catch_errors: true
    conn = call(Router, :get, "/404")
    assert conn.resp_body =~ ~r/not found/
  end

  test "default error controller renders 500 for returned 500 status" do
    config! catch_errors: true
    conn = call(Router, :get, "/500")
    assert conn.resp_body =~ ~r/Something went wrong/
  end

  test "default error controller renders 500 for errors" do
    config! catch_errors: true
    conn = call(Router, :get, "/500-raise")
    assert conn.resp_body =~ ~r/Something went wrong/
  end

  test "error controller can be configured for custom 404 handling" do
    config! error_controller: PageController, catch_errors: true
    conn = call(Router, :get, "/404")
    assert conn.assigns[:error] == :handled_404
  end

  test "error controller can be configured for custom 500 handling" do
    config! error_controller: PageController, catch_errors: true
    conn = call(Router, :get, "/500-raise")
    assert conn.assigns[:error] == :handled_500
  end

  test "error controller can override call/2 to catch errors" do
    config! error_controller: PageController, catch_errors: true
    conn = call(Router, :get, "/500-throw")
    assert conn.status == 500
    assert conn.resp_body == "boom"
  end

  test "errors are not caught when catch_errors: false" do
    config! catch_errors: false

    assert_raise RuntimeError, fn ->
      call(Router, :get, "/500-raise")
    end
  end

  test "renders Phoenix's debug 404 page" do
    config! debug_errors: true
    conn = call(Router, :get, "/400")
    assert conn.resp_body =~ ~r/No route matches/
  end

  test "renders Phoenix's debug 500 page for assigned 500 status when debug_errors: true" do
    config! debug_errors: true
    conn = call(Router, :get, "/500")
    assert conn.resp_body =~ ~r/Something went wrong/
  end

  test "renders Phoenix's debug 500 page for uncaught error  when debug_errors: true" do
    config! debug_errors: true
    conn = call(Router, :get, "/500-raise")
    assert conn.resp_body =~ ~r/Stacktrace/
  end
end

