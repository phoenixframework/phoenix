Code.require_file "views.exs", __DIR__
Code.require_file "views/assign_view.exs", __DIR__
Code.require_file "views/implicit_render_view.exs", __DIR__
Code.require_file "views/render_view.exs", __DIR__

defmodule MyApp.AssignController do
  use Phoenix.Controller

  before_action :assign_value

  def assign_value(conn, _) do
    assign(conn, :my_assign, "assign_plug")
  end

  def index(conn, _params) do
    conn
    |> assign(:my_assign, "assign_index")
    |> assign_layout(:none)
    |> render "index"
  end

  def plugged(conn, _params) do
    conn
    |> assign_layout(:none)
    |> render "index"
  end

  def overwrite(conn, _params) do
    conn
    |> assign_layout(:none)
    |> render "index", my_assign: "assign_overwrite"
  end
end

defmodule MyApp.ImplicitRenderController do
  use Phoenix.Controller

  after_action :render

  def index(conn, _params) do
    conn
    |> assign_layout(:none)
    |> assign(:my_assign, "implicit render")
  end
end

defmodule MyApp.RenderController do
  use Phoenix.Controller

  def show(conn, _params) do
    render conn, "show", []
  end
end


defmodule MyApp.Router do
  use Phoenix.Router
  get "/assign/manual", MyApp.AssignController, :index
  get "/assign/plug", MyApp.AssignController, :plugged
  get "/assign/overwrite", MyApp.AssignController, :overwrite
  get "/renders/implicit", MyApp.ImplicitRenderController, :index
  get "/renders/json",     MyApp.RenderController, :show
end

defmodule Phoenix.Controller.RenderTest do
  use ExUnit.Case
  use RouterHelper

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

  test "render can be plugged for implicit rendering of action" do
    conn = simulate_request(MyApp.Router, :get, "renders/implicit")
    assert conn.status == 200
    assert conn.resp_body == "implicit render\n"
  end

  test "rendering non-html templates does not render layout" do
    conn = simulate_request(MyApp.Router, :get, "renders/json?format=json")
    assert conn.status == 200
    assert conn.resp_body == "{\"foo\":\"bar\"}"
  end
end
