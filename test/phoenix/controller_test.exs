defmodule Phoenix.ControllerTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller
  alias Plug.Conn

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

  test "endpoint_module/1" do
    conn = Conn.put_private(%Conn{}, :phoenix_endpoint, Hello)
    assert endpoint_module(conn) == Hello
  end

  test "put_layout_formats/2 and layout_formats/1" do
    conn = conn(:get, "/")
    assert layout_formats(conn) == ~w(html)

    conn = put_layout_formats conn, ~w(json xml)
    assert layout_formats(conn) == ~w(json xml)
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

  test "put_new_layout/2" do
    conn = put_new_layout(conn(:get, "/"), false)
    assert layout(conn) == false
    conn = put_new_layout(conn, {AppView, "application.html"})
    assert layout(conn) == false

    conn = put_new_layout(conn(:get, "/"), {AppView, "application.html"})
    assert layout(conn) == {AppView, "application.html"}
    conn = put_new_layout(conn, false)
    assert layout(conn) == {AppView, "application.html"}
  end

  test "put_view/2 and put_new_view/2" do
    conn = put_new_view(conn(:get, "/"), Hello)
    assert view_module(conn) == Hello
    conn = put_new_view(conn, World)
    assert view_module(conn) == Hello
    conn = put_view(conn, World)
    assert view_module(conn) == World
  end

  test "json/2" do
    conn = json(conn(:get, "/"), %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert get_resp_content_type(conn) == "application/json"
    refute conn.halted
  end

  test "json/2 allows status injection on connection" do
    conn = conn(:get, "/") |> put_status(400)
    conn = json(conn, %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert conn.status == 400
  end

  test "text/2" do
    conn = text(conn(:get, "/"), "foobar")
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/plain"
    refute conn.halted

    conn = text(conn(:get, "/"), :foobar)
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/plain"
    refute conn.halted
  end

  test "text/2 allows status injection on connection" do
    conn = conn(:get, "/") |> put_status(400)
    conn = text(conn, :foobar)
    assert conn.resp_body == "foobar"
    assert conn.status == 400
  end

  test "html/2" do
    conn = html(conn(:get, "/"), "foobar")
    assert conn.resp_body == "foobar"
    assert get_resp_content_type(conn) == "text/html"
    refute conn.halted
  end

  test "html/2 allows status injection on connection" do
    conn = conn(:get, "/") |> put_status(400)
    conn = html(conn, "foobar")
    assert conn.resp_body == "foobar"
    assert conn.status == 400
  end

  test "redirect/2 with :to" do
    conn = redirect(conn(:get, "/"), to: "/foobar")
    assert conn.resp_body =~ "/foobar"
    assert get_resp_content_type(conn) == "text/html"
    assert get_resp_header(conn, "Location") == ["/foobar"]
    refute conn.halted

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
    refute conn.halted
  end

  test "redirect/2 with put_status/2 uses previously set status or defaults to 302" do
    conn = conn(:get, "/") |> redirect(to: "/")
    assert conn.status == 302
    conn = conn(:get, "/") |> put_status(301) |> redirect(to: "/")
    assert conn.status == 301
  end

  defp with_accept(header) do
    conn(:get, "/", [], headers: [{"accept", header}])
  end

  test "accepts/2 uses params[:format] when available" do
    conn = accepts conn(:get, "/", format: "json"), ~w(json)
    assert conn.params["format"] == "json"

    exception = assert_raise Phoenix.NotAcceptableError,
                             ~r/unknown format "json"/, fn ->
      accepts conn(:get, "/", format: "json"), ~w(html)
    end
    assert Plug.Exception.status(exception) == 406
  end

  test "accepts/2 uses first accepts on empty or catch-all header" do
    conn = accepts conn(:get, "/", []), ~w(json)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("*/*"), ~w(json)
    assert conn.params["format"] == "json"
  end

  test "accepts/2 on non-empty */*" do
    # Fallbacks to HTML due to browsers behavior
    conn = accepts with_accept("application/json, */*"), ~w(html json)
    assert conn.params["format"] == "html"

    conn = accepts with_accept("*/*, application/json"), ~w(html json)
    assert conn.params["format"] == "html"

    # No HTML is treated normally
    conn = accepts with_accept("*/*, text/plain, application/json"), ~w(json text)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("text/plain, application/json, */*"), ~w(json text)
    assert conn.params["format"] == "text"
  end

  test "accepts/2 ignores invalid media types" do
    conn = accepts with_accept("foo/bar, bar baz, application/json"), ~w(html json)
    assert conn.params["format"] == "json"
  end

  test "accepts/2 considers q params" do
    conn = accepts with_accept("text/html; q=0.7, application/json"), ~w(html json)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("application/json, text/html; q=0.7"), ~w(html json)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("application/json; q=1.0, text/html; q=0.7"), ~w(html json)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("application/json; q=0.8, text/html; q=0.7"), ~w(html json)
    assert conn.params["format"] == "json"

    conn = accepts with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(html json)
    assert conn.params["format"] == "json"

    assert_raise Phoenix.NotAcceptableError, ~r/no supported media type in accept/, fn ->
      accepts with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(xml)
    end
  end

  test "scrub_params/2 raises Phoenix.MissingParamError with key as the required_key when it's missing from the params" do
    conn = conn(:get, "/?foo=bar")
    |> Plug.Conn.fetch_params

    assert_raise(Phoenix.MissingParamError, "Expected key for \"present\" to be present.", fn ->
      scrub_params(conn, "present")
    end)
  end

  test "scrub_params/2 keeps populated keys intact" do
    conn = conn(:get, "/?foo=bar")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == "bar"
  end

  test "scrub_params/2 keeps populated keys intact if the value for the required key is a map" do
    conn = conn(:get, "/?foo[bar]=baz&foo[qux]=quux")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => "baz", "qux" => "quux"}
  end

  test "scrub_params/2 keeps populated keys intact if the value for the required key is a list" do
    conn = conn(:get, "/?foo[]=bar&foo[]=baz")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == ["bar", "baz"]
  end

  test "scrub_params/2 keeps populated keys intact if the value for the required key is a nested map" do
    conn = conn(:get, "/?foo[bar][baz]=qux")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => %{"baz" => "qux"}}
  end

  test "scrub_params/2 nils out the passed in key if it's empty" do
    conn = conn(:get, "/?foo=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == nil
  end

  test "scrub_params/2 nils out all empty values for the passed in key if it is a list" do
    conn = conn(:get, "/?foo[]=&foo[]=&foo[]=bar")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == [nil, nil, "bar"]
  end

  test "scrub_params/2 nils out all empty keys in value for the passed in key if it is a map" do
    conn = conn(:get, "/?foo[bar]=&foo[baz]=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => nil, "baz" => nil}
  end

  test "scrub_params/2 nils out all empty keys in value for the passed in key if it is a nested map" do
    conn = conn(:get, "/?foo[bar][baz]=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => %{"baz" => nil}}
  end

  test "scrub_params/2 ignores the keys that don't match the passed in key" do
    conn = conn(:get, "/?foo=bar&baz=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["baz"] == ""
  end

  test "scrub_params/2 ignores the keys that don't match the passed in key for a map" do
    conn = conn(:get, "/?foo=&bar[baz]=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["bar"] == %{"baz" => ""}
  end

  test "scrub_params/2 ignores the keys that don't match the passed in key for a nested map" do
    conn = conn(:get, "/?foo=&bar[baz][qux]=")
    |> Plug.Conn.fetch_params
    |> scrub_params("foo")

    assert conn.params["bar"] == %{"baz" => %{"qux" => ""}}
  end

  test "protect_from_forgery/2 doesn't blow up" do
    conn(:get, "/")
    |> with_session
    |> protect_from_forgery([])

    assert is_binary get_csrf_token
    assert is_binary delete_csrf_token
  end

  test "__view__ returns the view module based on controller module" do
    assert Phoenix.Controller.__view__(MyApp.UserController) == MyApp.UserView
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController) == MyApp.Admin.UserView
  end

  test "__layout__ returns the layout modoule based on controller module" do
    assert Phoenix.Controller.__layout__(MyApp.UserController) == MyApp.LayoutView
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController) == MyApp.LayoutView
  end
end
