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

    assert tag(:audio, autoplay: false) ==
           {:safe, ~s(<audio>)}

    assert tag(:audio, autoplay: nil) ==
           {:safe, ~s(<audio autoplay="">)}
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
           {:safe, ~s(<form action="/users" data-remote="true">) <>
                   ~s(<input name="user[name]"></form>)}
  end

  test "form_tag for get" do
    assert form_tag() ==
           {:safe, ~s(<form accept-charset="UTF-8">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}

    assert form_tag(method: :get) ==
           {:safe, ~s(<form accept-charset="UTF-8" method="get">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}

    assert form_tag(method: :get, action: "/") ==
           {:safe, ~s(<form accept-charset="UTF-8" action="/" method="get">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}

    assert form_tag(method: :get, action: "/", enforce_utf8: false) ==
           {:safe, ~s(<form action="/" method="get">)}
  end

  test "form_tag for post" do
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert form_tag(method: :post) ==
           {:safe, ~s(<form accept-charset="UTF-8" method="post">) <>
                   ~s(<input name="_csrf_token" type="hidden" value="#{csrf_token}">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}

    assert form_tag(method: :post, csrf_token: false, multipart: true) ==
           {:safe, ~s(<form accept-charset="UTF-8" enctype="multipart/form-data" method="post">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}
  end

  test "form_tag for other method" do
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert form_tag(method: :put) ==
           {:safe, ~s(<form accept-charset="UTF-8" method="post">) <>
                   ~s(<input name="_method" type="hidden" value="put">) <>
                   ~s(<input name="_csrf_token" type="hidden" value="#{csrf_token}">) <>
                   ~s(<input name="_utf8" type="hidden" value="✓">)}
  end
end
