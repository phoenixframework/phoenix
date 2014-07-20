Code.require_file "views.exs", __DIR__
Code.require_file "views/assign_view.exs", __DIR__

defmodule MyApp.AssignController do
  use Phoenix.Controller

  plug :assign_value

  def assign_value(conn, _) do
    assign(conn, :my_assign, "assign_plug")
  end

  def index(conn, _params) do
    conn
    |> assign(:my_assign, "assign_index")
    |> layout(nil)
    |> render "index"
  end

  def plugged(conn, _params) do
    conn
    |> layout(nil)
    |> render "index"
  end

  def overwrite(conn, _params) do
    conn
    |> layout(nil)
    |> render "index", my_assign: "assign_overwrite"
  end
end

defmodule MyApp.Router do
  use Phoenix.Router
  get "/assign/manual", MyApp.AssignController, :index
  get "/assign/plug", MyApp.AssignController, :plugged
  get "/assign/overwrite", MyApp.AssignController, :overwrite
end

defmodule Phoenix.Controller.RenderTest do
  use ExUnit.Case
  use PlugHelper

  test "render contain values from conn.assigns" do
    conn = simulate_request(MyApp.Router, :get, "assign/manual")
    assert conn.status == 200
    assert conn.resp_body == "assign_index\n"
  end

  test "render contain values from conn.assigns assigned in a plug" do
    conn = simulate_request(MyApp.Router, :get, "assign/plug")
    assert conn.status == 200
    assert conn.resp_body == "assign_plug\n"
  end

  test "render can overvrite values in conn.assigns" do
    conn = simulate_request(MyApp.Router, :get, "assign/overwrite")
    assert conn.status == 200
    assert conn.resp_body == "assign_overwrite\n"
  end
end
