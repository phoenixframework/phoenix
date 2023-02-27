Code.require_file "../../fixtures/views.exs", __DIR__

defmodule Phoenix.Controller.RenderTest do
  use ExUnit.Case, async: true

  use RouterHelper
  import Phoenix.Controller

  defp conn() do
    conn(:get, "/") |> fetch_query_params() |> put_view(MyApp.UserView)
  end

  defp layout_conn() do
    conn() |> put_layout({MyApp.LayoutView, :app})
  end

  defp html_response?(conn) do
    assert get_resp_header(conn, "content-type") == ["text/html; charset=utf-8"]
  end

  test "renders string template" do
    conn = render(conn(), "index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
    refute conn.halted
    assert view_template(conn) == "index.html"
  end

  test "renders atom template" do
    conn = put_format(conn(), "html")
    conn = render(conn, :index, title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
    refute conn.halted
    assert view_template(conn) == "index.html"
  end

  test "renders string template with put layout" do
    conn = render(layout_conn(), "index.html", title: "Hello")
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders string template with put_root_layout" do
    conn =
      conn()
      |> put_layout({MyApp.LayoutView, "app.html"})
      |> put_root_layout({MyApp.LayoutView, "root.html"})
      |> render("index.html", title: "Hello")

    assert conn.resp_body == "ROOTSTART[Hello]<html>\n  <title>Hello</title>\n  Hello\n\n</html>\nROOTEND\n"
    assert html_response?(conn)
  end

  test "renders atom template with put layout" do
    conn = put_format(layout_conn(), "html")
    conn = render(conn, :index, title: "Hello")
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders atom template with put_root_layout" do
    conn =
      conn()
      |> put_layout({MyApp.LayoutView, "app.html"})
      |> put_root_layout({MyApp.LayoutView, :root})
      |> render("index.html", title: "Hello")

    assert conn.resp_body == "ROOTSTART[Hello]<html>\n  <title>Hello</title>\n  Hello\n\n</html>\nROOTEND\n"
    assert html_response?(conn)
  end

  test "renders template with overriding layout option" do
    conn = render(layout_conn(), "index.html", title: "Hello", layout: false)
    assert conn.resp_body == "Hello\n"
    assert html_response?(conn)
  end

  test "renders template with atom layout option" do
    conn = render(conn(), "index.html", title: "Hello", layout: {MyApp.LayoutView, :app})
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "renders template with string layout option" do
    conn = render(conn(), "index.html", title: "Hello", layout: {MyApp.LayoutView, "app.html"})
    assert conn.resp_body =~ ~r"<title>Hello</title>"
    assert html_response?(conn)
  end

  test "render with layout sets view_module/template for layout and inner view" do
    conn = render(conn(), "inner.html", title: "Hello", layout: {MyApp.LayoutView, :app})
    assert conn.resp_body == "<html>\n  <title>Hello</title>\n  View module is Elixir.MyApp.UserView and view template is inner.html\n\n</html>\n"
  end

  test "render without layout sets inner view_module/template assigns" do
    conn = render(conn(), "inner.html", [])
    assert conn.resp_body == "View module is Elixir.MyApp.UserView and view template is inner.html\n"
  end

  test "renders with conn status code" do
    conn = %Plug.Conn{conn() | status: 404}
    conn = render(conn, "index.html", title: "Hello", layout: {MyApp.LayoutView, "app.html"})
    assert conn.status == 404
  end

  test "merges render assigns" do
    conn = render(conn(), "index.html", title: "Hello")
    assert conn.resp_body == "Hello\n"
    assert conn.assigns.title == "Hello"
  end

  test "uses connection assigns" do
    conn = conn() |> assign(:title, "Hello") |> render("index.html")
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
    conn = put_format(conn(), "html")
    conn = put_in conn.private[:phoenix_action], :index
    conn = render(conn, title: "Hello")
    assert conn.resp_body == "Hello\n"
  end

  test "render/2 renders with View and Template with atom for template" do
    conn = put_format(conn(), "json")
    conn = put_in conn.private[:phoenix_action], :show
    conn = put_view(conn, MyApp.UserView)
    conn = render(conn, :show)
    assert conn.resp_body == ~s({"foo":"bar"})
  end

  test "render/2 renders with View and Template" do
    conn = put_format(conn(), "json")
    conn = put_in conn.private[:phoenix_action], :show
    conn = put_view(conn, MyApp.UserView)
    conn = render(conn, "show.json")
    assert conn.resp_body == ~s({"foo":"bar"})
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
    assert_raise RuntimeError, ~r/no view was found for the format: html/, fn ->
      render(conn() |> put_view(nil), "index.html")
    end
  end

  describe "telemetry" do
    @render_start_event [:phoenix, :controller, :render, :start]
    @render_stop_event [:phoenix, :controller, :render, :stop]
    @render_exception_event [:phoenix, :controller, :render, :exception]

    @render_events [
      @render_start_event,
      @render_stop_event,
      @render_exception_event
    ]

    setup context do
      :telemetry.attach_many(context.test, @render_events, &__MODULE__.message_pid/4, self())
    end

    def message_pid(event, measures, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, {measures, metadata}})
    end

    test "phoenix.controller.render.start and .stop are emitted on success" do
      render(conn(), "index.html", title: "Hello")

      assert_received {:telemetry_event, [:phoenix, :controller, :render, :start],
                       {_, %{format: "html", template: "index", view: MyApp.UserView}}}

      assert_received {:telemetry_event, [:phoenix, :controller, :render, :stop],
                       {_, %{format: "html", template: "index", view: MyApp.UserView}}}

      refute_received {:telemetry_event, [:phoenix, :controller, :render, :exception], _}
    end

    test "phoenix.controller.render.exception is emitted on failure" do
      :ok =
        try do
          render(conn(), "index.html")
        rescue
          ArgumentError ->
            :ok
        end

      assert_received {:telemetry_event, [:phoenix, :controller, :render, :start],
                       {_, %{format: "html", template: "index", view: MyApp.UserView}}}

      refute_received {:telemetry_event, [:phoenix, :controller, :render, :stop], _}

      assert_received {:telemetry_event, [:phoenix, :controller, :render, :exception],
                       {_,
                        %{
                          format: "html",
                          template: "index",
                          view: MyApp.UserView,
                          kind: :error,
                          reason: %ArgumentError{}
                        }}}
    end
  end
end
