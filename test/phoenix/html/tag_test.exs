defmodule Phoenix.HTML.TagTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Tag

  test "tag" do
    assert tag(:br) == "<br>"
    assert tag(:br, false) == "<br />"
    assert tag(:input, type: "text", name: "user_id") == ~s(<input name="user_id" type="text">)
    assert tag(:input, name: ~s("<3")) == ~s(<input name="&quot;&lt;3&quot;">)
    assert tag(:input, data: [toggle: "dropdown"]) == ~s(<input data-toggle="dropdown">)
    assert tag(:input, data: [toggle: [target: "#parent", attr: "blah"]]) ==
      ~s(<input data-toggle-attr="blah" data-toggle-target="#parent">)
    assert tag(:audio, autoplay: true) == ~s(<audio autoplay="autoplay">)
  end

  test "content_tag" do
    assert content_tag(:form, [action: "/users", remote: true], do: tag(:input, name: "user[name]")) ==
      ~s(<form action="/users" data-remote="true"><input name="user[name]"></form>)
    assert content_tag(:p, "Hello", class: "dark") == ~s(<p class="dark">Hello</p>)
    assert content_tag(:p, "Hello") == "<p>Hello</p>"
    assert content_tag(:p, [class: "dark"], do: "Hello") == ~s(<p class="dark">Hello</p>)
  end
end
