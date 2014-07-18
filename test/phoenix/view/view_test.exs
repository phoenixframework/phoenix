Code.require_file "views.exs", __DIR__
Code.require_file "views/user_view.exs", __DIR__
Code.require_file "views/profile_view.exs", __DIR__
Code.require_file "views/layout_view.exs", __DIR__

defmodule Phoenix.ViewTest do
  use ExUnit.Case
  alias Phoenix.UserTest.UserView
  alias Phoenix.UserTest.LayoutView

  test "Subviews render templates with imported functions from base view" do
    assert UserView.render("base.html", name: "chris") == {:safe, "<div>\n  Base CHRIS\n</div>\n\n"}
  end

  test "Subviews render templates with imported functions from subview" do
    assert UserView.render("sub.html", desc: "truncated") == {:safe, "Subview truncat...\n"}
  end

  test "views can be render within another view, such as layouts" do
    html = UserView.render("sub.html",
      desc: "truncated",
      title: "Test",
      within: {LayoutView, "application.html"}
    )

    assert html == {:safe, "<html>\n  <title>Test</title>\n  Subview truncat...\n\n</html>\n"}
  end

  test "views can render other views within template without safing" do
    html = UserView.render("show.html", name: "<em>chris</em>")
    assert html == {:safe, "Showing User <b>name:</b> &lt;em&gt;chris&lt;/em&gt;\n\n"}
  end

  test "template_path_from_view_module finds the template path given view module" do
    assert Phoenix.View.template_path_from_view_module(MyApp.UserView, "web/templates") ==
      "web/templates/user"

    assert Phoenix.View.template_path_from_view_module(MyApp.Admin.UserView, "web/templates") ==
      "web/templates/admin/user"
  end
end

