defmodule Phoenix.ControllerTest do
  use ExUnit.Case, async: true
  alias Phoenix.Controller

  doctest Controller

  test "view_module returns the view modoule based on controller module" do
    assert Controller.view_module(MyApp.UserController) == MyApp.UserView
    assert Controller.view_module(MyApp.Admin.UserController) == MyApp.Admin.UserView
  end

  test "layout_module returns the view modoule based on controller module" do
    assert Controller.layout_module(MyApp.UserController) == MyApp.LayoutView
    assert Controller.layout_module(MyApp.Admin.UserController) == MyApp.LayoutView
  end
end

