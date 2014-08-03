Code.require_file "views.exs", __DIR__
Code.require_file "views/user_view.exs", __DIR__

defmodule Phoenix.View.HelpersTest do
  use ExUnit.Case
  alias Phoenix.UserTest.UserView
  alias Phoenix.View.Helpers


  test "render/3 safes html views" do
    assert Helpers.render(UserView, "base.html", name: "chris")
      == {:safe, "<div>\n  Base CHRIS\n</div>\n\n"}
  end

  test "render/3 returns non-html views as string" do
    assert Helpers.render(UserView, "file.txt", [])
      == "Just a text file\n"
  end
end

