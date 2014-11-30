defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  test "builds a route based on verb, path, controller, action and helper" do
    route = build("GET", "/foo/:bar", Hello, :world, "hello_world", [:foo, :bar], "example.com")
    assert route.verb == "GET"
    assert route.segments == ["foo", {:bar, [], nil}]
    assert route.binding == [{"bar", {:bar, [], nil}}]
    assert route.controller == Hello
    assert route.action == :world
    assert route.helper == "hello_world"
    assert Macro.to_string(route.pipe_through) == "bar(foo(var!(conn), []), [])"
  end
end
