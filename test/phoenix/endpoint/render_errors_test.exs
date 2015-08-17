defmodule Phoenix.Endpoint.RenderErrorsTest do
  use ExUnit.Case, async: true
  use RouterHelper

  view = __MODULE__

  def render("404.html", %{kind: kind, reason: _reason, stack: _stack, conn: conn}) do
    "Got 404 from #{kind} with #{conn.method}"
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
    use Phoenix.Endpoint.RenderErrors, view: view, accepts: ~w(html)

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

  test "call/2 is overridden with no route match" do
    conn = call(Router, :get, "/unknown")
    assert conn.state == :sent
    assert conn.status == 404
    assert conn.resp_body == "Got 404 from error with GET"
    assert_received {:plug_conn, :sent}
  end

  test "call/2 is overridden and unwrapps wrapped errors" do
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

  test "exception page with params _format" do
    conn = render(conn(:get, "/", [_format: "text"]), [], fn ->
      throw :hello
    end)

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

  test "exception page with invalid format" do
    conn =
      conn(:get, "/")
      |> put_req_header("accept", "unknown/unknown")
      |> render([], fn -> throw :hello end)

    assert conn.status == 406
    assert conn.resp_body == ""
  end
end
