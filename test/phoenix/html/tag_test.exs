defmodule Phoenix.HTML.TagTest do
  use ExUnit.Case, async: true
  import Phoenix.HTML.Tag
  doctest Phoenix.HTML.Tag

  test "tag" do
    assert tag(:br) == "<br>"
    assert tag(:br, false) == "<br />"
    assert tag(:input, type: "text", name: "user_id") == ~s(<input name="user_id" type="text">)
    assert tag(:input, name: ~s("<3")) == ~s(<input name="&quot;&lt;3&quot;">)
    assert tag(:input, data: [toggle: "dropdown"]) == ~s(<input data-toggle="dropdown">)
    assert tag(:input, data: [my_attr: "blah"]) == ~s(<input data-my-attr="blah">)
    assert tag(:input, data: [toggle: [target: "#parent", attr: "blah"]]) ==
      ~s(<input data-toggle-attr="blah" data-toggle-target="#parent">)
    assert tag(:audio, autoplay: true) == ~s(<audio autoplay="autoplay">)
  end

  test "content_tag" do
    assert content_tag(:form, [action: "/users", data: [remote: true]], do: tag(:input, name: "user[name]")) ==
      ~s(<form action="/users" data-remote="true"><input name="user[name]"></form>)
    assert content_tag(:p, "Hello", class: "dark") == ~s(<p class="dark">Hello</p>)
    assert content_tag(:p, "Hello") == "<p>Hello</p>"
    assert content_tag(:p, [class: "dark"], do: "Hello") == ~s(<p class="dark">Hello</p>)
  end

  test "input_tag" do
    assert input_tag(:text, name: "name") ==
      ~s(<input name="name" type="text" />)
    assert input_tag(:password, name: "password") ==
      ~s(<input name="password" type="password" />)
    assert input_tag(:text, name: "username", required: true) ==
      ~s(<input name="username" required="required" type="text" />)
  end
end
