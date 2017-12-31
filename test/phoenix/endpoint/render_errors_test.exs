defmodule Phoenix.Endpoint.RenderErrorsTest do
  use ExUnit.Case, async: true
  use RouterHelper
  import ExUnit.CaptureLog

  view = __MODULE__

  def render("app.html", %{view_template: view_template} = assigns) do
    "Layout: " <> render(view_template, assigns)
  end

  def render("404.html", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    "Got 404 from #{kind} with #{conn.method}"
  end

  def render("404.json", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    %{error: "Got 404 from #{kind} with #{conn.method}"}
  end

  def render("415.html", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    "Got 415 from #{kind} with #{conn.method}"
  end

  def render("500.html", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    "Got 500 from #{kind} with #{conn.method}"
  end

  def render("500.text", _) do
    "500 in TEXT"
  end

  defmodule Router do
    use Plug.Router
    use Phoenix.Endpoint.RenderErrors, view: view, accepts: ~w(html json)

    plug :match
    plug :dispatch

    get "/boom" do
      resp conn, 200, "oops"
      raise "oops"
    end

    get "/send_and_boom" do
      send_resp conn, 200, "oops"
      raise "oops"
    end

    get "/send_and_wrapped" do
      raise Plug.Conn.WrapperError, conn: conn,
        kind: :error, stack: System.stacktrace,
        reason: ArgumentError.exception("oops")
    end

    match _ do
      raise Phoenix.Router.NoRouteError, conn: conn, router: __MODULE__
    end
  end

  test "call/2 is overridden" do
    assert_raise RuntimeError, "oops", fn ->
      call(Router, :get, "/boom")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden but is a no-op when response is already sent" do
    assert_raise RuntimeError, "oops", fn ->
      call(Router, :get, "/send_and_boom")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden with no route match as HTML" do
    assert_raise Phoenix.Router.NoRouteError,
      "no route found for GET /unknown (Phoenix.Endpoint.RenderErrorsTest.Router)", fn ->
      call(Router, :get, "/unknown")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden with no route match as JSON" do
    assert_raise Phoenix.Router.NoRouteError,
      "no route found for GET /unknown (Phoenix.Endpoint.RenderErrorsTest.Router)", fn ->
      call(Router, :get, "/unknown?_format=json")
    end

    assert_received {:plug_conn, :sent}
  end

  @tag :capture_log
  test "call/2 is overridden with no route match while malformed format" do
    assert_raise Phoenix.Router.NoRouteError,
      "no route found for GET /unknown (Phoenix.Endpoint.RenderErrorsTest.Router)", fn ->
      call(Router, :get, "/unknown?_format=unknown")
    end

    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden and unwraps wrapped errors" do
    assert_raise ArgumentError, "oops", fn ->
      conn(:get, "/send_and_wrapped") |> Router.call([])
    end

    assert_received {:plug_conn, :sent}
  end

  defp render(conn, opts, fun) do
    opts =
      opts
      |> Keyword.put_new(:view, __MODULE__)
      |> Keyword.put_new(:accepts, ~w(html))

    try do
      fun.()
    catch
      kind, error ->
        Phoenix.Endpoint.RenderErrors.render(conn, kind, error, System.stacktrace, opts)
    else
      _ -> flunk "function should have failed"
    end
  end

  test "exception page for throws" do
    conn = render(conn(:get, "/"), [], fn ->
      throw :hello
    end)

    assert conn.status == 500
    assert conn.resp_body == "Got 500 from throw with GET"
  end

  test "exception page for errors" do
    conn = render(conn(:get, "/"), [], fn ->
      :erlang.error :badarg
    end)

    assert conn.status == 500
    assert conn.resp_body == "Got 500 from error with GET"
  end

  test "exception page for exceptions" do
    conn = render(conn(:get, "/"), [], fn ->
      raise Plug.Parsers.UnsupportedMediaTypeError, media_type: "foo/bar"
    end)

    assert conn.status == 415
    assert conn.resp_body == "Got 415 from error with GET"
  end

  test "exception page for exits" do
    conn = render(conn(:get, "/"), [], fn ->
      exit {:timedout, {GenServer, :call, [:foo, :bar]}}
    end)

    assert conn.status == 500
    assert conn.resp_body == "Got 500 from exit with GET"
  end

  test "exception page ignores params _format" do
    conn = render(conn(:get, "/", _format: "text"), [accepts: ["html", "text"]], fn ->
      throw :hello
    end)

    assert conn.status == 500
    assert conn.resp_body == "500 in TEXT"
  end

  test "exception page uses stored _format" do
    conn = conn(:get, "/") |> put_private(:phoenix_format, "text")
    conn = render(conn, [accepts: ["html", "text"]], fn -> throw :hello end)
    assert conn.status == 500
    assert conn.resp_body == "500 in TEXT"
  end

  test "exception page with custom format" do
    conn = render(conn(:get, "/"), [accepts: ~w(text)], fn ->
      throw :hello
    end)

    assert conn.status == 500
    assert conn.resp_body == "500 in TEXT"
  end

  test "exception page with layout" do
    conn =
      conn(:get, "/")
      |> render([layout: {__MODULE__, :app}], fn -> throw :hello end)

    assert conn.status == 500
    assert conn.resp_body == "Layout: Got 500 from throw with GET"
  end

  @tag :capture_log
  test "exception page is shown even with invalid format" do
    conn =
      conn(:get, "/")
      |> put_req_header("accept", "unknown/unknown")
      |> render([], fn -> throw :hello end)

    assert conn.status == 500
    assert conn.resp_body == "Got 500 from throw with GET"
  end

  test "exception page is shown even with invalid query parameters" do
    conn =
      conn(:get, "/?q=%{")
      |> render([], fn -> throw :hello end)

    assert conn.status == 500
    assert conn.resp_body == "Got 500 from throw with GET"
  end

  test "captures warning when format is not supported" do
    assert capture_log(fn ->
      conn(:get, "/")
      |> put_req_header("accept", "unknown/unknown")
      |> render([], fn -> throw :hello end)
    end) =~ "Could not render errors due to no supported media type in accept header"
  end

  test "captures warning when format does not match error view" do
    assert capture_log(fn ->
      conn(:get, "/?_format=unknown")
      |> render([], fn -> throw :hello end)
    end) =~ "Could not render errors due to unknown format \"unknown\""
  end

  test "does not capture warning when format does match ErrorView" do
    assert capture_log(fn ->
      conn(:get, "/")
      |> put_req_header("accept", "text/html")
      |> render([], fn -> throw :hello end)
    end) == ""
  end

  test "exception page for NoRouteError with plug_status 404" do
    conn = render(conn(:get, "/"), [], fn ->
      raise Phoenix.Router.NoRouteError, conn: conn(:get, "/"), router: nil, plug_status: 404
    end)

    assert conn.status == 404
    assert conn.resp_body == "Got 404 from error with GET"
  end
end
