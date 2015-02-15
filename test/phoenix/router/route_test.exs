defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  test "builds a route based on verb, path, controller, action and helper" do
    route = build("GET", "/foo/:bar", nil, Hello, :world, "hello_world", [:foo, :bar], %{foo: "bar"})
    assert route.verb == "GET"
    assert route.path == "/foo/:bar"
    assert route.host == nil
    assert route.binding == [{"bar", {:bar, [], nil}}]
    assert route.controller == Hello
    assert route.action == :world
    assert route.helper == "hello_world"
    assert route.pipe_through == [:foo, :bar]
    assert route.segments == ["foo", {:bar, [], nil}]
    assert route.private == %{foo: "bar"}
  end

  test "builds expressions based on the route" do
    exprs = build("GET", "/foo/:bar", nil, Hello, :world, "hello_world", [], %{}) |> exprs
    assert Macro.to_string(exprs.host) == "_"
    assert Macro.to_string(exprs.pipes) == "var!(conn)"
    assert Macro.to_string(exprs.private) == "nil"

    exprs = build("GET", "/foo/:bar", "foo.", Hello, :world, "hello_world", [:foo, :bar], %{foo: "bar"}) |> exprs
    assert Macro.to_string(exprs.host) == "\"foo.\" <> _"
    assert Macro.to_string(exprs.pipes) == "bar(foo(var!(conn), []), [])"
    assert Macro.to_string(exprs.private) == "var!(conn) = update_in(var!(conn).private(), &Map.merge(&1, %{foo: \"bar\"}))"

    exprs = build("GET", "/foo/:bar", "foo.com", Hello, :world, "hello_world", [], %{foo: "bar"}) |> exprs
    assert Macro.to_string(exprs.host_segments) == "\"foo.com\""
  end
end
