defmodule Phoenix.HTML.TagTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML
  import Phoenix.HTML.Tag
  doctest Phoenix.HTML.Tag

  test "tag" do
    assert tag(:br) ==
           {:safe, "<br>"}

    assert tag(:input, name: ~s("<3")) ==
           {:safe, ~s(<input name="&quot;&lt;3&quot;">)}

    assert tag(:input, name: safe "<3") ==
           {:safe, ~s(<input name="<3">)}

    assert tag(:input, name: :hello) ==
           {:safe, ~s(<input name="hello">)}

    assert tag(:input, type: "text", name: "user_id") ==
           {:safe, ~s(<input name="user_id" type="text">)}

    assert tag(:input, data: [toggle: "dropdown"]) ==
           {:safe, ~s(<input data-toggle="dropdown">)}

    assert tag(:input, my_attr: "blah") ==
           {:safe, ~s(<input my-attr="blah">)}

    assert tag(:input, data: [my_attr: "blah"]) ==
           {:safe, ~s(<input data-my-attr="blah">)}

    assert tag(:input, data: [toggle: [target: "#parent", attr: "blah"]]) ==
           {:safe, ~s(<input data-toggle-attr="blah" data-toggle-target="#parent">)}

    assert tag(:audio, autoplay: true) ==
           {:safe, ~s(<audio autoplay="autoplay">)}
  end

  test "content_tag" do
    assert content_tag(:p, "Hello", class: "dark") ==
           {:safe, ~s(<p class="dark">Hello</p>)}

    assert content_tag(:p, "Hello") ==
           {:safe, "<p>Hello</p>"}

    assert content_tag(:p, [class: "dark"], do: "Hello") ==
           {:safe, ~s(<p class="dark">Hello</p>)}

    assert content_tag(:p, "<Hello>") ==
           {:safe, "<p>&lt;Hello&gt;</p>"}

    assert content_tag(:p, [class: "dark"], do: "<Hello>") ==
           {:safe, ~s(<p class="dark">&lt;Hello&gt;</p>)}

    assert content_tag(:p, safe "<Hello>") ==
           {:safe, "<p><Hello></p>"}

    assert content_tag(:p, [class: "dark"], do: safe "<Hello>") ==
           {:safe, ~s(<p class="dark"><Hello></p>)}

    content = content_tag(:form, [action: "/users", data: [remote: true]]) do
      tag(:input, name: "user[name]")
    end

    assert content ==
           {:safe, ~s(<form action="/users" data-remote="true"><input name="user[name]"></form>)}
  end
end
