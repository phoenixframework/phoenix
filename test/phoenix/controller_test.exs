defmodule Phoenix.ControllerTest do
  use ExUnit.Case, async: true
  use ConnHelper

  import Phoenix.Controller

  defp get_resp_content_type(conn) do
    [header]  = get_resp_header(conn, "content-type")
    header |> String.split(";") |> Enum.fetch!(0)
  end

  test "action_name/1" do
    conn = Conn.put_private(%Conn{}, :phoenix_action, :show)
    assert action_name(conn) == :show
  end

  test "controller_module/1" do
    conn = Conn.put_private(%Conn{}, :phoenix_controller, Hello)
    assert controller_module(conn) == Hello
  end

  test "router_module/1" do
    conn = Conn.put_private(%Conn{}, :phoenix_router, Hello)
    assert router_module(conn) == Hello
  end

  test "put_layout/2 and layout/1" do
    conn = conn(:get, "/")
    assert layout(conn) == false

    conn = put_layout conn, {AppView, "application.html"}
    assert layout(conn) == {AppView, "application.html"}

    conn = put_layout conn, "print.html"
    assert layout(conn) == {AppView, "print.html"}

    conn = put_layout conn, :print
    assert layout(conn) == {AppView, :print}

    conn = put_layout conn, false
    assert layout(conn) == false

    assert_raise RuntimeError, fn ->
      put_layout conn, "print"
    end
  end

  test "json/2" do
    conn = json(conn(:get, "/"), %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert get_resp_content_type(conn) == "application/json"
    assert conn.halted
  end

  test "text/2" do
    conn = text(conn(:get, "/"), "foobar")
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/plain"
    assert conn.halted

    conn = text(conn(:get, "/"), :foobar)
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/plain"
    assert conn.halted
  end

  test "html/2" do
    conn = html(conn(:get, "/"), "foobar")
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/html"
    assert conn.halted
  end

  test "redirect/2 with :to" do
    conn = redirect(conn(:get, "/"), to: "/foobar")
    assert conn.resp_body =~ "/foobar"
    assert get_resp_content_type(conn) == "text/html"
    assert get_resp_header(conn, "Location") == ["/foobar"]
    assert conn.halted

    conn = redirect(conn(:get, "/"), to: "/<foobar>")
    assert conn.resp_body =~ "/&lt;foobar&gt;"

    assert_raise ArgumentError, ~r/the :to option in redirect expects a path/, fn ->
      redirect(conn(:get, "/"), to: "http://example.com")
    end
  end

  test "redirect/2 with :external" do
    conn = redirect(conn(:get, "/"), external: "http://example.com")
    assert conn.resp_body =~ "http://example.com"
    assert get_resp_header(conn, "Location") == ["http://example.com"]
    assert conn.halted
  end

  test "__view__ returns the view modoule based on controller module" do
    assert Phoenix.Controller.__view__(MyApp.UserController) == MyApp.UserView
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController) == MyApp.Admin.UserView
  end

  test "__layout__ returns the layout modoule based on controller module" do
    assert Phoenix.Controller.__layout__(MyApp.UserController) == MyApp.LayoutView
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController) == MyApp.LayoutView
  end
end
