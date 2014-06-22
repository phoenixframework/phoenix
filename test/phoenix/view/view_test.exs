Code.require_file "views.exs", __DIR__
Code.require_file "views/users.exs", __DIR__
Code.require_file "views/layouts.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case
  alias Phoenix.UserTest.Views

  test "Subviews render templates with imported functions from base view" do
    assert Views.Users.render("base.html", name: "chris") == "<div>\n  Base CHRIS\n</div>\n\n"
  end

  test "Subviews render templates with imported functions from subview" do
    assert Views.Users.render("sub.html", desc: "truncated") == "Subview truncat...\n"
  end

  test "views can be render within another view, such as layouts" do
    html = Views.Users.render("sub.html",
      desc: "truncated",
      title: "Test",
      within: {Views.Layouts, "application.html"}
    )

    assert html == "<html>\n  <title>Test</title>\n  Subview truncat...\n\n</html>\n"
  end

  test "Subview modules are implicity defined when missing and directory named via camel case" do
    # assert Code.ensure_compiled?(Views.Profiles)
    # refute Code.ensure_compiled?(Views.Users.Nav)
    # assert Views.Profiles.render("show.html", name: "chris") == "showing profile CHRIS\n"
  end
end

