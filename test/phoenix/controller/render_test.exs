Code.require_file "../../fixtures/views.exs", __DIR__

defmodule Phoenix.Controller.RenderTest do
  use ExUnit.Case, async: true

  use RouterHelper
  import Phoenix.Controller

  defp conn() do
    conn(:get, "/") |> put_view(MyApp.UserView) |> fetch_params
  end

  defp layout_conn() do
    conn() |> put_layout({MyApp.LayoutView, :application})
  end

  defp html_response?(conn) do
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
  end

  test "renders string template" do
    conn = render(conn, "index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
    refute conn.halted
  end

  test "renders atom template" do
    conn = put_in conn.params["format"], "html"
    conn = render(conn, :index, title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
    refute conn.halted
  end

  test "renders template from specified view" do
    conn = conn(:get, "/") |> fetch_params
    conn = render(conn, MyApp.UserView, "index.html")
    assert html_response?(conn)
  end

  test "renders template from specified view with assigns" do
    conn = conn(:get, "/") |> fetch_params
    conn = render(conn, MyApp.UserView, "index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
  end

  test "renders string template with put layout" do
    conn = render(layout_conn, "index.html", title: "Hello")
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders atom template with put layout" do
    conn = put_in layout_conn.params["format"], "html"
    conn = render(conn, :index, title: "Hello")
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders template with overriding layout option" do
    conn = render(layout_conn, "index.html", title: "Hello", layout: false)
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
  end

  test "renders template with atom layout option" do
    conn = render(conn, "index.html", title: "Hello", layout: {MyApp.LayoutView, :application})
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders template with string layout option" do
    conn = render(conn, "index.html", title: "Hello", layout: {MyApp.LayoutView, "application.html"})
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders with conn status code" do
    conn = %Plug.Conn{conn | status: 404}
    conn = render(conn, "index.html", title: "Hello", layout: {MyApp.LayoutView, "application.html"})
    assert conn.status == 404
  end

  test "skips layout depending on layout_formats with string template" do
    conn = layout_conn |> put_layout_formats([]) |> render("index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)

    conn = render(conn(), "show.json", layout: {MyApp.LayoutView, :application})
    assert conn.resp_body == ~s({"foo":"bar"})
  end

  test "skips layout depending on layout_formats with atom template" do
    conn = put_in layout_conn.params["format"], "html"
    conn = conn |> put_layout_formats([]) |> render(:index, title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)

    conn = put_in layout_conn.params["format"], "json"
    conn = render(conn, :show, layout: {MyApp.LayoutView, :application})
    assert conn.resp_body == ~s({"foo":"bar"})
  end

  test "merges render assigns" do
    conn = render(conn, "index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert conn.assigns.title == "Hello"
  end

  test "uses connection assigns" do
    conn = conn |> assign(:title, "Hello") |> render("index.html")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
  end

  test "uses custom status" do
    conn = render(conn(), "index.html", title: "Hello")
    assert conn.status == 200

    conn = render(put_status(conn(), :created), "index.html", title: "Hello")
    assert conn.status == 201
  end

  test "uses action name" do
    conn = put_in conn.params["format"], "html"
    conn = put_in conn.private[:phoenix_action], :index
    conn = render(conn, title: "Hello")
    assert conn.resp_body == "Hello\n"
  end

  test "errors when rendering without format" do
    assert_raise RuntimeError, ~r/cannot render template :index because conn.params/, fn ->
      render(conn(), :index)
    end

    assert_raise RuntimeError, ~r/cannot render template "index" without format/, fn ->
      render(conn(), "index")
    end
  end

  test "errors when rendering without view" do
    assert_raise RuntimeError, ~r/a view module was not specified/, fn ->
      render(conn() |> put_view(nil), "index.html")
    end
  end
end
