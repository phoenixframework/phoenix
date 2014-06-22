Code.require_file "views.exs", __DIR__
Code.require_file "views/users.exs", __DIR__
Code.require_file "views/profiles.exs", __DIR__
Code.require_file "views/layouts.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case
  alias Phoenix.UserTest.Views

  test "Subviews render templates with imported functions from base view" do
    assert Views.Users.render("base.html", name: "chris") == {:safe, "<div>\n  Base CHRIS\n</div>\n\n"}
  end

  test "Subviews render templates with imported functions from subview" do
    assert Views.Users.render("sub.html", desc: "truncated") == {:safe, "Subview truncat...\n"}
  end

  test "views can be render within another view, such as layouts" do
    html = Views.Users.render("sub.html",
      desc: "truncated",
      title: "Test",
      within: {Views.Layouts, "application.html"}
    )

    assert html == {:safe, "<html>\n  <title>Test</title>\n  Subview truncat...\n\n</html>\n"}
  end

  test "views can render other views within template without safing" do
    html = Views.Users.render("show.html", name: "<em>chris</em>")
    assert html == {:safe, "Showing User <b>name:</b> &lt;em&gt;chris&lt;/em&gt;\n\n"}
  end
end

