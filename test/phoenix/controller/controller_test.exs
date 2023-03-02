defmodule Phoenix.Controller.ControllerTest do
  use ExUnit.Case, async: true
  use RouterHelper

  import Phoenix.Controller
  alias Plug.Conn

  setup do
    Logger.disable(self())
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

  test "view_template/1" do
    conn = put_private(%Conn{}, :phoenix_template, "hello.html")
    assert view_template(conn) == "hello.html"
    assert view_template(%Conn{}) == nil
  end

  test "status_message_from_template/1" do
    assert status_message_from_template("404.html") == "Not Found"
    assert status_message_from_template("whatever.html") == "Internal Server Error"
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
      put_layout sent_conn(), {AppView, :print}
    end
  end

  test "put_layout/2 and layout/1 with formats" do
    conn = conn(:get, "/") |> put_format("html")
    assert layout(conn) == false

    conn = put_layout(conn, html: {AppView, :app})
    assert layout(conn) == {AppView, :app}

    conn = put_layout(conn, html: :print)
    assert layout(conn) == {AppView, :print}

    conn = put_layout(conn, html: {AppView, :app}, print: {AppView, :print})

    conn = put_format(conn, "html")
    assert layout(conn) == {AppView, :app}

    conn = put_format(conn, "print")
    assert layout(conn) == {AppView, :print}

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_layout(sent_conn(), {AppView, :print})
    end
  end

  test "put_root_layout/2 and root_layout/1" do
    conn = conn(:get, "/")
    assert root_layout(conn) == false

    conn = put_root_layout(conn, {AppView, "root.html"})
    assert root_layout(conn) == {AppView, "root.html"}

    conn = put_root_layout(conn, "bare.html")
    assert root_layout(conn) == {AppView, "bare.html"}

    conn = put_root_layout(conn, :print)
    assert root_layout(conn) == {AppView, :print}

    conn = put_root_layout(conn, false)
    assert root_layout(conn) == false

    assert_raise RuntimeError, fn ->
      put_root_layout(conn, "print")
    end

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_layout sent_conn(), {AppView, :print}
    end
  end

  test "put_root_layout/2 and root_layout/1 with formats" do
    conn = conn(:get, "/") |> put_format("html")
    assert root_layout(conn) == false

    conn = put_root_layout(conn, html: {AppView, :app})
    assert root_layout(conn) == {AppView, :app}

    conn = put_root_layout(conn, html: :print)
    assert root_layout(conn) == {AppView, :print}

    conn = put_root_layout(conn, html: {AppView, :app}, print: {AppView, :print})

    conn = put_format(conn, "html")
    assert root_layout(conn) == {AppView, :app}

    conn = put_format(conn, "print")
    assert root_layout(conn) == {AppView, :print}

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_root_layout(sent_conn(), {AppView, :print})
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
      put_new_layout sent_conn(), {AppView, "app.html"}
    end
  end

  test "put_new_layout/2 with formats" do
    conn = put_new_layout(conn(:get, "/"), html: false, json: false)
    conn = put_format(conn, "html")
    assert layout(conn) == false
    conn = put_new_layout(conn, html: {AppView, :app})
    assert layout(conn) == false

    conn = put_new_layout(conn(:get, "/"), html: {AppView, :app}, json: false)
    conn = put_format(conn, "html")
    assert layout(conn) == {AppView, :app}
    conn = put_new_layout(conn, false)
    assert layout(conn) == false

    conn = put_format(conn, "json")
    assert layout(conn) == false

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_new_layout(sent_conn(), {AppView, :app})
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
      put_new_view sent_conn(), Hello
    end
    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_view sent_conn(), Hello
    end
  end

  test "put_view/2 and put_new_view/2 with formats" do
    conn =
      conn(:get, "/")
      |> put_format("print")
      |> put_new_view(html: Hello, json: HelloJSON)

    assert view_module(conn, "html") == Hello

    assert_raise RuntimeError, ~r/no view was found for the format: print/, fn ->
      view_module(conn)
    end

    conn =
      conn(:get, "/")
      |> put_format("html")
      |> put_new_view(html: Hello, json: HelloJSON)

    conn = put_format(conn, "html")
    assert view_module(conn) == Hello

    conn = put_new_view(conn, html: World)
    assert view_module(conn) == Hello
    conn = put_view(conn, html: World)
    assert view_module(conn) == World

    conn = put_format(conn, "json")
    assert view_module(conn) == HelloJSON
    assert view_module(conn, "json") == HelloJSON

    conn = put_format(conn, "json")
    conn = put_new_view(conn, Hello)
    assert view_module(conn) == Hello
    assert view_module(conn, "json") == Hello

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_new_view sent_conn(), html: Hello
    end

    assert_raise Plug.Conn.AlreadySentError, fn ->
      put_view sent_conn(), html: Hello
    end
  end

  describe "json/2" do
    test "encodes content to json" do
      conn = json(conn(:get, "/"), %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = json(conn, %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert conn.status == 400
    end

    test "allows content-type injection on connection" do
      conn = conn(:get, "/") |> put_resp_content_type("application/vnd.api+json")
      conn = json(conn, %{foo: :bar})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert Conn.get_resp_header(conn, "content-type") ==
               ["application/vnd.api+json; charset=utf-8"]
    end

    test "with allow_jsonp/2 returns json when no callback param is present" do
      conn = conn(:get, "/")
             |> fetch_query_params()
             |> allow_jsonp()
             |> json(%{foo: "bar"})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "with allow_jsonp/2 returns json when callback name is left empty" do
      conn = conn(:get, "/?callback=")
             |> fetch_query_params()
             |> allow_jsonp()
             |> json(%{foo: "bar"})
      assert conn.resp_body == "{\"foo\":\"bar\"}"
      assert get_resp_content_type(conn) == "application/json"
      refute conn.halted
    end

    test "with allow_jsonp/2 returns javascript when callback param is present" do
      conn = conn(:get, "/?callback=cb")
             |> fetch_query_params
             |> allow_jsonp
             |> json(%{foo: "bar"})
      assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end

    test "with allow_jsonp/2 allows to override the callback param" do
      conn = conn(:get, "/?cb=cb")
             |> fetch_query_params
             |> allow_jsonp(callback: "cb")
             |> json(%{foo: "bar"})
      assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"bar\"});"
      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end

    test "with allow_jsonp/2 raises ArgumentError when callback contains invalid characters" do
      conn = conn(:get, "/?cb=_c*b!()[0]") |> fetch_query_params()
      assert_raise ArgumentError, "the JSONP callback name contains invalid characters", fn ->
        allow_jsonp(conn, callback: "cb")
      end
    end

    test "with allow_jsonp/2 escapes invalid javascript characters" do
      conn = conn(:get, "/?cb=cb")
             |> fetch_query_params
             |> allow_jsonp(callback: "cb")
             |> json(%{foo: <<0x2028::utf8, 0x2029::utf8>>})
      assert conn.resp_body == "/**/ typeof cb === 'function' && cb({\"foo\":\"\\u2028\\u2029\"});"
      assert get_resp_content_type(conn) == "application/javascript"
      refute conn.halted
    end
  end

  describe "text/2" do
    test "sends the content as text" do
      conn = text(conn(:get, "/"), "foobar")
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted

      conn = text(conn(:get, "/"), :foobar)
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/plain"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = text(conn, :foobar)
      assert conn.resp_body == "foobar"
      assert conn.status == 400
    end
  end

  describe "html/2" do
    test "sends the content as html" do
      conn = html(conn(:get, "/"), "foobar")
      assert conn.resp_body == "foobar"
      assert get_resp_content_type(conn) == "text/html"
      refute conn.halted
    end

    test "allows status injection on connection" do
      conn = conn(:get, "/") |> put_status(400)
      conn = html(conn, "foobar")
      assert conn.resp_body == "foobar"
      assert conn.status == 400
    end
  end

  describe "redirect/2" do
    test "with :to" do
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

      assert_raise ArgumentError, ~r/the :to option in redirect expects a path/, fn ->
        redirect(conn(:get, "/"), to: "//example.com")
      end

      assert_raise ArgumentError, ~r/unsafe/, fn ->
        redirect(conn(:get, "/"), to: "/\\example.com")
      end
    end

    test "with :external" do
      conn = redirect(conn(:get, "/"), external: "http://example.com")
      assert conn.resp_body =~ "http://example.com"
      assert get_resp_header(conn, "location") == ["http://example.com"]
      refute conn.halted
    end

    test "with put_status/2 uses previously set status or defaults to 302" do
      conn = conn(:get, "/") |> redirect(to: "/")
      assert conn.status == 302
      conn = conn(:get, "/") |> put_status(301) |> redirect(to: "/")
      assert conn.status == 301
    end
  end

  defp with_accept(header) do
    conn(:get, "/", [])
    |> put_req_header("accept", header)
  end

  describe "accepts/2" do
    test "uses params[\"_format\"] when available" do
      conn = accepts conn(:get, "/", _format: "json"), ~w(json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == "json"

      exception = assert_raise Phoenix.NotAcceptableError, ~r/unknown format "json"/, fn ->
        accepts conn(:get, "/", _format: "json"), ~w(html)
      end
      assert Plug.Exception.status(exception) == 406
      assert exception.accepts == ["html"]
    end

    test "uses first accepts on empty or catch-all header" do
      conn = accepts conn(:get, "/", []), ~w(json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("*/*"), ~w(json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil
    end

    test "uses first matching accepts on empty subtype" do
      conn = accepts with_accept("text/*"), ~w(json text css)
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil
    end

    test "on non-empty */*" do
      # Fallbacks to HTML due to browsers behavior
      conn = accepts with_accept("application/json, */*"), ~w(html json)
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("*/*, application/json"), ~w(html json)
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      # No HTML is treated normally
      conn = accepts with_accept("*/*, text/plain, application/json"), ~w(json text)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("text/plain, application/json, */*"), ~w(json text)
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("text/*, application/*, */*"), ~w(json text)
      assert get_format(conn) == "text"
      assert conn.params["_format"] == nil
    end

    test "ignores invalid media types" do
      conn = accepts with_accept("foo/bar, bar baz, application/json"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("foo/*, */bar, text/*"), ~w(json html)
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil
    end

    test "considers q params" do
      conn = accepts with_accept("text/html; q=0.7, application/json"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("application/json, text/html; q=0.7"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("application/json; q=1.0, text/html; q=0.7"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("application/json; q=0.8, text/html; q=0.7"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("text/*; q=0.7, application/json"), ~w(html json)
      assert get_format(conn) == "json"
      assert conn.params["_format"] == nil

      conn = accepts with_accept("application/json; q=0.7, text/*; q=0.8"), ~w(json html)
      assert get_format(conn) == "html"
      assert conn.params["_format"] == nil

      exception = assert_raise Phoenix.NotAcceptableError, ~r/no supported media type in accept/, fn ->
        accepts with_accept("text/html; q=0.7, application/json; q=0.8"), ~w(xml)
      end
      assert Plug.Exception.status(exception) == 406
      assert exception.accepts == ["xml"]
    end
  end

  describe "send_download/3" do
    @hello_txt Path.expand("../../fixtures/hello.txt", __DIR__)

    test "sends file for download" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt})
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"hello.txt\""]
      assert get_resp_header(conn, "content-type") ==
             ["text/plain"]
      assert conn.resp_body ==
             "world"
    end

    test "sends file for download with custom :filename" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, filename: "hello world.json")
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"hello+world.json\""]
      assert get_resp_header(conn, "content-type") ==
             ["application/json"]
      assert conn.resp_body ==
             "world"
    end

    test "sends file for download with custom :filename and :encode false" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, filename: "dev's hello world.json", encode: false)
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"dev's hello world.json\""]
      assert get_resp_header(conn, "content-type") ==
             ["application/json"]
      assert conn.resp_body ==
             "world"
    end

    test "sends file for download with custom :content_type and :charset" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, content_type: "application/json", charset: "utf8")
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"hello.txt\""]
      assert get_resp_header(conn, "content-type") ==
             ["application/json; charset=utf8"]
      assert conn.resp_body ==
             "world"
    end

    test "sends file for download with custom :disposition" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, disposition: :inline)
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["inline; filename=\"hello.txt\""]
      assert conn.resp_body ==
             "world"
    end

    test "sends file for download with custom :offset" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, offset: 2)
      assert conn.status == 200
      assert conn.resp_body ==
             "rld"
    end

    test "sends file for download with custom :length" do
      conn = send_download(conn(:get, "/"), {:file, @hello_txt}, length: 2)
      assert conn.status == 200
      assert conn.resp_body ==
             "wo"
    end

    test "sends binary for download with :filename" do
      conn = send_download(conn(:get, "/"), {:binary, "world"}, filename: "hello world.json")
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"hello+world.json\""]
      assert get_resp_header(conn, "content-type") ==
             ["application/json"]
      assert conn.resp_body ==
             "world"
    end

    test "sends binary as download with custom :content_type and :charset" do
      conn = send_download(conn(:get, "/"), {:binary, "world"},
                           filename: "hello.txt", content_type: "application/json", charset: "utf8")
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["attachment; filename=\"hello.txt\""]
      assert get_resp_header(conn, "content-type") ==
             ["application/json; charset=utf8"]
      assert conn.resp_body ==
             "world"
    end

    test "sends binary for download with custom :disposition" do
      conn = send_download(conn(:get, "/"), {:binary, "world"},
                           filename: "hello.txt", disposition: :inline)
      assert conn.status == 200
      assert get_resp_header(conn, "content-disposition") ==
             ["inline; filename=\"hello.txt\""]
      assert conn.resp_body ==
             "world"
    end

    test "raises ArgumentError for :disposition other than :attachment or :inline" do
      assert_raise(ArgumentError, ~r"expected :disposition to be :attachment or :inline, got: :foo", fn ->
        send_download(conn(:get, "/"), {:file, @hello_txt}, disposition: :foo)
      end)

      assert_raise(ArgumentError, ~r"expected :disposition to be :attachment or :inline, got: :foo", fn ->
        send_download(conn(:get, "/"), {:binary, "world"},
                           filename: "hello.txt", disposition: :foo)
      end)
    end
  end

  describe "scrub_params/2" do
    test "raises Phoenix.MissingParamError for missing key" do
      assert_raise(Phoenix.MissingParamError, ~r"expected key \"foo\" to be present in params", fn ->
        conn(:get, "/") |> fetch_query_params |> scrub_params("foo")
      end)

      assert_raise(Phoenix.MissingParamError, ~r"expected key \"foo\" to be present in params", fn ->
        conn(:get, "/?foo=") |> fetch_query_params |> scrub_params("foo")
      end)
    end

    test "keeps populated keys intact" do
      conn = conn(:get, "/?foo=bar")
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["foo"] == "bar"
    end

    test "nils out all empty values for the passed in key if it is a list" do
      conn = conn(:get, "/?foo[]=&foo[]=++&foo[]=bar")
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["foo"] == [nil, nil, "bar"]
    end

    test "nils out all empty keys in value for the passed in key if it is a map" do
      conn = conn(:get, "/?foo[bar]=++&foo[baz]=&foo[bat]=ok")
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["foo"] == %{"bar" => nil, "baz" => nil, "bat" => "ok"}
    end

    test "nils out all empty keys in value for the passed in key if it is a nested map" do
      conn = conn(:get, "/?foo[bar][baz]=")
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["foo"] == %{"bar" => %{"baz" => nil}}
    end

    test "ignores the keys that don't match the passed in key" do
      conn = conn(:get, "/?foo=bar&baz=")
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["baz"] == ""
    end

    test "keeps structs intact" do
      conn = conn(:post, "/", %{"foo" => %{"bar" => %Plug.Upload{}}})
      |> fetch_query_params
      |> scrub_params("foo")

      assert conn.params["foo"]["bar"] == %Plug.Upload{}
    end
  end

  test "protect_from_forgery/2 sets token" do
    conn(:get, "/")
    |> init_test_session(%{})
    |> protect_from_forgery([])

    assert is_binary get_csrf_token()
    assert is_binary delete_csrf_token()
  end

  test "put_secure_browser_headers/2" do
    conn = conn(:get, "/") |> put_secure_browser_headers()
    assert get_resp_header(conn, "x-frame-options") == ["SAMEORIGIN"]
    assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
    assert get_resp_header(conn, "x-download-options") == ["noopen"]
    assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]

    custom_headers = %{"x-frame-options" => "custom", "foo" => "bar"}
    conn = conn(:get, "/") |> put_secure_browser_headers(custom_headers)
    assert get_resp_header(conn, "x-frame-options") == ["custom"]
    assert get_resp_header(conn, "x-download-options") == ["noopen"]
    assert get_resp_header(conn, "x-permitted-cross-domain-policies") == ["none"]
    assert get_resp_header(conn, "foo") == ["bar"]
  end

  test "__view__ returns the view module based on controller module" do
    assert Phoenix.Controller.__view__(MyApp.UserController, []) == MyApp.UserView
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController, []) == MyApp.Admin.UserView
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController, formats: [:html, :json]) ==
      [html: MyApp.Admin.UserHTML, json: MyApp.Admin.UserJSON]
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController, formats: [:html, json: "View"]) ==
      [html: MyApp.Admin.UserHTML, json: MyApp.Admin.UserView]
  end

  test "__layout__ returns the layout module based on controller module" do
    assert Phoenix.Controller.__layout__(UserController, []) ==
           {LayoutView, :app}
    assert Phoenix.Controller.__layout__(MyApp.UserController, []) ==
           {MyApp.LayoutView, :app}
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, []) ==
           {MyApp.LayoutView, :app}
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, namespace: MyApp.Admin) ==
           {MyApp.Admin.LayoutView, :app}

    opts = [layouts: [html: MyApp.LayoutHTML]]
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, opts) ==
           [html: {MyApp.LayoutHTML, :app}]

    opts = [layouts: [html: {MyApp.LayoutHTML, :application}]]
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController, opts) ==
           [html: {MyApp.LayoutHTML, :application}]
  end

  defp sent_conn do
    conn(:get, "/") |> send_resp(:ok, "")
  end

  describe "path and url generation" do
    def url(), do: "https://www.example.com"

    def build_conn_for_path(path) do
      conn(:get, path)
      |> fetch_query_params()
      |> put_private(:phoenix_endpoint, __MODULE__)
      |> put_private(:phoenix_router, __MODULE__)
    end

    test "current_path/1 uses the conn's query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn) == "/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn) == "/foo?one=1&two=2"

      conn = build_conn_for_path("/foo//bar/")
      assert current_path(conn) == "/foo/bar"
    end

    test "current_path/2 allows custom query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn, %{}) == "/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn, %{}) == "/foo"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_path(conn, %{three: 3}) == "/foo?three=3"
    end

    test "current_path/2 allows custom nested query params" do
      conn = build_conn_for_path("/")
      assert current_path(conn, %{foo: %{bar: [:baz], baz: :qux}}) == "/?foo[bar][]=baz&foo[baz]=qux"
    end

    test "current_url/1 with root path includes trailing slash" do
      conn = build_conn_for_path("/")
      assert current_url(conn) == "https://www.example.com/"
    end

    test "current_url/1 users conn's endpoint and query params" do
      conn = build_conn_for_path("/?foo=bar")
      assert current_url(conn) == "https://www.example.com/?foo=bar"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn) == "https://www.example.com/foo?one=1&two=2"
    end

    test "current_url/2 allows custom query params" do
      conn = build_conn_for_path("/")
      assert current_url(conn, %{}) == "https://www.example.com/"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn, %{}) == "https://www.example.com/foo"

      conn = build_conn_for_path("/foo?one=1&two=2")
      assert current_url(conn, %{three: 3}) == "https://www.example.com/foo?three=3"
    end
  end
end
