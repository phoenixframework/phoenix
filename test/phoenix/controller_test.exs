defmodule Phoenix.ControllerTest do
  use ExUnit.Case, async: true
  use ConnHelper

  import Phoenix.Controller

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

  test "__view__ returns the view modoule based on controller module" do
    assert Phoenix.Controller.__view__(MyApp.UserController) == MyApp.UserView
    assert Phoenix.Controller.__view__(MyApp.Admin.UserController) == MyApp.Admin.UserView
  end

  test "__layout__ returns the layout modoule based on controller module" do
    assert Phoenix.Controller.__layout__(MyApp.UserController) == MyApp.LayoutView
    assert Phoenix.Controller.__layout__(MyApp.Admin.UserController) == MyApp.LayoutView
  end
end
