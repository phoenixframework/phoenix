defmodule Phoenix.HTML.LinkTest do
  use ExUnit.Case, async: true

  import Phoenix.HTML.Link
  doctest Phoenix.HTML.Link

  test "link with post" do
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert link("hello", to: "/world", method: :post) ==
           {:safe, ~s[<form action="/world" class="linkmethod" method="post">] <>
                   ~s[<input name="_csrf_token" type="hidden" value="#{csrf_token}">] <>
                   ~s[<a href="#" onclick="this.parentNode.submit(); return false;">hello</a>] <>
                   ~s[</form>]}
  end

  test "link with put/delete" do
    csrf_token = Phoenix.Controller.get_csrf_token()

    assert link("hello", to: "/world", method: :put) ==
           {:safe, ~s[<form action="/world" class="linkmethod" method="post">] <>
                   ~s[<input name="_method" type="hidden" value="put">] <>
                   ~s[<input name="_csrf_token" type="hidden" value="#{csrf_token}">] <>
                   ~s[<a href="#" onclick="this.parentNode.submit(); return false;">hello</a>] <>
                   ~s[</form>]}
  end
end
