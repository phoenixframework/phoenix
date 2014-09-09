defmodule Phoenix.Router.RouteTest do
  use ExUnit.Case, async: true

  import Phoenix.Router.Route

  test "builds a route based on verb, path, controller, action and helper" do
    route = build("GET", "/foo/:bar", Hello, :world, "hello_world")
    assert route.verb == "GET"
    assert route.segments == ["foo", {:bar, [], nil}]
    assert route.params == [:bar]
    assert route.controller == Hello
    assert route.action == :world
    assert route.helper == "hello_world"
  end

  test "builds helper definitions with :identifiers" do
    route = build("GET", "/foo/:bar", Hello, :world, "hello_world")

    assert extract_helper_definition(route, 0) == String.strip """
    def(hello_world_path(:world, bar)) do
      hello_world_path(:world, bar, [])
    end
    """

    assert extract_helper_definition(route, 1) == String.strip """
    def(hello_world_path(:world, bar, params)) do
      Route.segments_to_path(("" <> "/foo") <> "/" <> to_string(bar), params, ["bar"])
    end
    """
  end

  test "builds helper definitions with *identifiers" do
    route = build("GET", "/foo/*bar", Hello, :world, "hello_world")

    assert extract_helper_definition(route, 0) == String.strip """
    def(hello_world_path(:world, bar)) do
      hello_world_path(:world, bar, [])
    end
    """

    assert extract_helper_definition(route, 1) == String.strip """
    def(hello_world_path(:world, bar, params)) do
      Route.segments_to_path(("" <> "/foo") <> "/" <> Enum.join(bar, "/"), params, ["bar"])
    end
    """
  end

  defp extract_helper_definition(route, pos) do
    {:__block__, _, block} = helper_definition(route)
    Enum.at(block, pos) |> Macro.to_string()
  end
end
