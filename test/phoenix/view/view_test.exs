Code.require_file "views/views.exs", __DIR__
Code.require_file "views/users/users.exs", __DIR__
Code.require_file "views/layouts/layouts.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case
  use Plug.Test
  alias Phoenix.UserTest.Views

  test "Subviews render templates with imported functions from base view" do
    assert Views.Users.render("base.html", name: "chris") == "<div>\n  Base CHRIS\n</div>\n\n\n"
  end

  test "Subviews render templates with imported functions from subview" do
    assert Views.Users.render("sub.html", desc: "truncated") == "Subview truncat...\n\n"
  end

  test "views can be render within another view, such as layouts" do
    html = Views.Users.render("sub.html",
      desc: "truncated",
      title: "Test",
      within: {Views.Layouts, "application.html"}
    )

    assert html == "<html>\n  <title>Test</title>\n  Subview truncat...\n\n</html>\n\n"
  end

end

