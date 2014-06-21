Code.require_file "views/views.exs", __DIR__

defmodule Phoenix.View.BaseTest do
  use ExUnit.Case
  alias Phoenix.View.Base
  alias Phoenix.UserTest.Views

  test "subview?/1 returns true when path is a directory and camelcased" do
    assert Base.subview?(Path.join([__DIR__, "views/Layouts"]))
  end

  test "subview?/1 returns false when path is not a directory" do
    refute Base.subview?(Path.join([__DIR__, "views/Layouts/application.html.eex"]))
  end

  test "subview?/1 returns false when directory is not camelcased" do
    refute Base.subview?(Path.join([__DIR__, "views/Users/nav"]))
  end

  test "subview_defined?/1 returns true when subview source file exists" do
    assert Base.subview_defined?(Path.join([__DIR__, "views/Layouts"]))
  end

  test "subview_defined?/1 returns false when subview source file does not exist" do
    refute Base.subview_defined?(Path.join([__DIR__, "views/Profiles"]))
  end

  test "implicit_subview_modules/2 returns implicit modules to be created" do
    modules = Base.implicit_subview_modules(Views, Path.join([__DIR__, "views"]))
    assert modules == [
      {Views.Profiles, Path.join([__DIR__, "views/Profiles"])}
    ]
  end
end


