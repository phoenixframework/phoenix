Code.require_file "views.exs", __DIR__
Code.require_file "views/render_test_view.exs", __DIR__

defmodule MyApp.RenderTestController do
  use Phoenix.Controller

  plug :assign_value when action in [:index, :plugged, :overwrite]
  plug :action
  plug :render when action in [:implicit]

  def assign_value(conn, _) do
    assign(conn, :my_assign, "assign_plug")
  end

  def index(conn, _params) do
    conn
    |> assign(:my_assign, "assign_index")
    |> put_layout(:none)
    |> render "index"
  end

  def plugged(conn, _params) do
    conn
    |> put_layout(:none)
    |> render "index"
  end

  def overwrite(conn, _params) do
    conn
    |> put_layout(:none)
    |> render "index", my_assign: "assign_overwrite"
  end

  def implicit(conn, _params) do
    conn
    |> put_layout(:none)
    |> assign(:my_assign, "implicit render")
  end

  def show(conn, _params) do
    render conn, "show", []
  end
end

defmodule Phoenix.Controller.RenderTest do
  use ExUnit.Case, async: true
  use ConnHelper

  setup do
    Logger.disable(self())
    :ok
  end

  test "render contain values from conn.assigns" do
    conn = action(MyApp.RenderTestController, :get, :index)
    assert conn.status == 200
    assert conn.resp_body == "assign_index\n"
  end

  test "render contain values from conn.assigns assigned in a plug" do
    conn = action(MyApp.RenderTestController, :get, :plugged)
    assert conn.status == 200
    assert conn.resp_body == "assign_plug\n"
  end

  test "render can overvrite values in conn.assigns" do
    conn = action(MyApp.RenderTestController, :get, :overwrite)
    assert conn.status == 200
    assert conn.resp_body == "assign_overwrite\n"
  end

  test "render can be plugged for implicit rendering of action" do
    conn = action(MyApp.RenderTestController, :get, :implicit)
    assert conn.status == 200
    assert conn.resp_body == "implicit render\n"
  end

  test "rendering non-html templates does not render layout" do
    conn = action(MyApp.RenderTestController, :get, :show, %{"format" => "json"})
    assert conn.status == 200
    assert conn.resp_body =~ "{\"foo\":\"bar\"}"
  end
end
