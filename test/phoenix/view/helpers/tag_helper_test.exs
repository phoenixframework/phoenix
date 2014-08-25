defmodule Phoenix.View.Helpers.TagHelperTest do
  use ExUnit.Case, async: true

  import Phoenix.View.Helpers.TagHelper

  test "tag" do
    assert tag(:br) == "<br>"
    assert tag(:br, false) == "<br />"
    assert tag(:input, type: "text", name: "user_id") == "<input name=\"user_id\" type=\"text\">"
    assert tag(:input, name: "\"<3\"") == "<input name=\"&quot;&lt;3&quot;\">"
    assert tag(:input, data: [toggle: "dropdown"]) == "<input data-toggle=\"dropdown\">"
    assert tag(:input, data: [toggle: [target: "#parent"]]) == "<input data-toggle-target=\"#parent\">"
    assert tag(:audio, autoplay: true) == "<audio autoplay=\"autoplay\">"
  end

  test "content_tag" do
    assert content_tag(:form, [action: "/users", remote: true], do: tag(:input, name: "user[name]")) ==
      "<form action=\"/users\" data-remote=\"true\"><input name=\"user[name]\"></form>"
    assert content_tag(:p, "Hello", class: "dark") == "<p class=\"dark\">Hello</p>"
    assert content_tag(:p, do: "Hello") == "<p>Hello</p>"
    assert content_tag(:p, [class: "dark"], do: "Hello") == "<p class=\"dark\">Hello</p>"
  end
end
