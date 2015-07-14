defmodule Phoenix.Controller.ControllerTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller
  alias Plug.Conn

  setup do
    Logger.disable(self)
    :ok
  end

  defp get_resp_content_type(conn) do
    [header]  = get_resp_header(conn, "content-type")
    header |> String.split(";") |> Enum.fetch!(0)
  end

  test "action_name/1" do
    conn = put_private(%Conn{}, :phoenix_action, :show)
    assert action_name(conn) == :show
  end

  test "controller_module/1" do
    conn = put_private(%Conn{}, :phoenix_controller, Hello)
    assert controller_module(conn) == Hello
  end

  test "router_module/1" do
    conn = put_private(%Conn{}, :phoenix_router, Hello)
    assert router_module(conn) == Hello
  end

  test "endpoint_module/1" do
    conn = put_private(%Conn{}, :phoenix_endpoint, Hello)
    assert endpoint_module(conn) == Hello
  end

  test "socket_handler_module/1" do
    conn = put_private(%Conn{}, :phoenix_socket_handler, Handler)
    assert socket_handler_module(conn) == Handler
  end

  test "controller_template/1" do
    conn = put_private(%Conn{}, :phoenix_template, "hello.html")
    assert controller_template(conn) == "hello.html"
    assert controller_template(%Conn{}) == nil
  end

  test "put_layout_formats/2 and layout_formats/1" do
    conn = conn(:get, "/")
    assert layout_formats(conn) == ~w(html)

    conn = put_layout_formats conn, ~w(json xml)
    assert layout_formats(conn) == ~w(json xml)

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_layout_formats sent_conn, ~w(json)
    end
  end

  test "put_layout/2 and layout/1" do
    conn = conn(:get, "/")
    assert layout(conn) == false

    conn = put_layout conn, {AppView, "app.html"}
    assert layout(conn) == {AppView, "app.html"}

    conn = put_layout conn, "print.html"
    assert layout(conn) == {AppView, "print.html"}

    conn = put_layout conn, :print
    assert layout(conn) == {AppView, :print}

    conn = put_layout conn, false
    assert layout(conn) == false

    assert_raise RuntimeError, fn ->
      put_layout conn, "print"
    end

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_layout sent_conn, {AppView, :print}
    end
  end

  test "put_new_layout/2" do
    conn = put_new_layout(conn(:get, "/"), false)
    assert layout(conn) == false
    conn = put_new_layout(conn, {AppView, "app.html"})
    assert layout(conn) == false

    conn = put_new_layout(conn(:get, "/"), {AppView, "app.html"})
    assert layout(conn) == {AppView, "app.html"}
    conn = put_new_layout(conn, false)
    assert layout(conn) == {AppView, "app.html"}

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_new_layout sent_conn, {AppView, "app.html"}
    end
  end

  test "put_view/2 and put_new_view/2" do
    conn = put_new_view(conn(:get, "/"), Hello)
    assert view_module(conn) == Hello
    conn = put_new_view(conn, World)
    assert view_module(conn) == Hello
    conn = put_view(conn, World)
    assert view_module(conn) == World

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_new_view sent_conn, Hello
    end
    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_view sent_conn, Hello
    end
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

  test "json/2 allows content-type injection on connection" do
    conn = conn(:get, "/") |> put_resp_content_type("application/vnd.api+json")
    conn = json(conn, %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert Conn.get_resp_header(conn, "content-type") ==
             ["application/vnd.api+json; charset=utf-8"]
  end

  test "jsonp/3 returns json when no callback param is present" do
    conn = jsonp(conn(:get, "/") |> fetch_query_params, %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert get_resp_content_type(conn) == "application/json"
    refute conn.halted
  end

  test "jsonp/3 returns json when callback name is left empty" do
    conn = jsonp(conn(:get, "/?callback=") |> fetch_query_params, %{foo: :bar})
    assert conn.resp_body == "{\"foo\":\"bar\"}"
    assert get_resp_content_type(conn) == "application/json"
    refute conn.halted
  end

  test "jsonp/3 returns javascript when callback param is present" do
    conn = conn(:get, "/?callback=cb") |> fetch_query_params()
    conn = jsonp(conn, %{foo: :bar})
    assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
    assert get_resp_content_type(conn) == "text/javascript"
    refute conn.halted
  end

  test "jsonp/3 allows to override the callback param" do
    conn = conn(:get, "/?cb=cb") |> fetch_query_params()
    conn = jsonp(conn, %{foo: :bar}, callback: "cb")
    assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
    assert get_resp_content_type(conn) == "text/javascript"
    refute conn.halted
  end

  test "jsonp/3 raises ArgumentError when callback contains invalid characters" do
    conn = conn(:get, "/?cb=_c*b!()[0]") |> fetch_query_params()
    assert_raise(ArgumentError, "the callback name contains invalid characters", fn ->
    jsonp(conn, %{foo: :bar}, callback: "cb") end)
    refute conn.halted
  end

  test "jsonp/3 escapes invalid javascript characters" do
    conn = conn(:get, "/?cb=cb") |> fetch_query_params()
    conn = jsonp(conn, %{foo: <<0x2028::utf8>> <> <<0x2029::utf8>>}, callback: "cb")
    assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"\\u2028\\u2029\"});"
    assert get_resp_content_type(conn) == "text/javascript"
    refute conn.halted
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
    assert get_resp_header(conn, "location") == ["/foobar"]
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
    assert get_resp_header(conn, "location") == ["http://example.com"]
    refute conn.halted
  end

  test "redirect/2 with put_status/2 uses previously set status or defaults to 302" do
    conn = conn(:get, "/") |> redirect(to: "/")
    assert conn.status == 302
    conn = conn(:get, "/") |> put_status(301) |> redirect(to: "/")
    assert conn.status == 301
  end

  defp with_accept(header) do
    conn(:get, "/", [])
    |> put_req_header("accept", header)
  end

  test "accepts/2 uses params[:format] when available" do
    conn = accepts conn(:get, "/", format: "json"), ~w(json)
    assert conn.params["format"] == "json"

    conn = accepts conn(:get, "/", format: "json"), ~w(html)
    assert conn.status == 406
    assert conn.halted
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

    conn = accepts with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(xml)
    assert conn.halted
    assert conn.status == 406
  end

  test "scrub_params/2 raises Phoenix.MissingParamError for missing key" do
    assert_raise(Phoenix.MissingParamError, "expected key for \"foo\" to be present", fn ->
      conn(:get, "/") |> fetch_query_params |> scrub_params("foo")
    end)

    assert_raise(Phoenix.MissingParamError, "expected key for \"foo\" to be present", fn ->
      conn(:get, "/?foo=") |> fetch_query_params |> scrub_params("foo")
    end)
  end

  test "scrub_params/2 keeps populated keys intact" do
    conn = conn(:get, "/?foo=bar")
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["foo"] == "bar"
  end

  test "scrub_params/2 nils out all empty values for the passed in key if it is a list" do
    conn = conn(:get, "/?foo[]=&foo[]=++&foo[]=bar")
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["foo"] == [nil, nil, "bar"]
  end

  test "scrub_params/2 nils out all empty keys in value for the passed in key if it is a map" do
    conn = conn(:get, "/?foo[bar]=++&foo[baz]=&foo[bat]=ok")
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => nil, "baz" => nil, "bat" => "ok"}
  end

  test "scrub_params/2 nils out all empty keys in value for the passed in key if it is a nested map" do
    conn = conn(:get, "/?foo[bar][baz]=")
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["foo"] == %{"bar" => %{"baz" => nil}}
  end

  test "scrub_params/2 ignores the keys that don't match the passed in key" do
    conn = conn(:get, "/?foo=bar&baz=")
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["baz"] == ""
  end

  test "scrub_params/2 keeps structs intact" do
    conn = conn(:get, "/", %{"foo" => %{"bar" => %Plug.Upload{}}})
    |> fetch_query_params
    |> scrub_params("foo")

    assert conn.params["foo"]["bar"] == %Plug.Upload{}
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
    assert Phoenix.Controller.__layout__(UserController, []) ==
           LayoutView
    assert Phoenix.Controller.__layout__(MyApp.UserController, []) ==
           MyApp.LayoutView
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, []) ==
           MyApp.LayoutView
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, namespace: MyApp.Admin) ==
           MyApp.Admin.LayoutView
  end

  defp sent_conn do
    conn(:get, "/") |> send_resp(:ok, "")
  end
end
