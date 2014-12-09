defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  test "builds a route based on verb, path, controller, action and helper" do
    route = build("GET", "/foo/:bar", nil, Hello, :world, "hello_world", [:foo, :bar])
    assert route.verb == "GET"
    assert route.path == "/foo/:bar"
    assert route.host == nil
    assert route.binding == [{"bar", {:bar, [], nil}}]
    assert route.controller == Hello
    assert route.action == :world
    assert route.helper == "hello_world"
    assert route.pipe_through == [:foo, :bar]
    assert route.path_segments == ["foo", {:bar, [], nil}]
    assert Macro.to_string(route.host_segments) == "_"
    assert Macro.to_string(route.pipe_segments) == "bar(foo(var!(conn), []), [])"
  end

  test "builds a route based on the host" do
    route = build("GET", "/foo/:bar", "foo.", Hello, :world, "hello_world", [])
    assert Macro.to_string(route.host_segments) == "\"foo.\" <> _"

    route = build("GET", "/foo/:bar", "foo.com", Hello, :world, "hello_world", [])
    assert Macro.to_string(route.host_segments) == "\"foo.com\""
  end
end
