defmodule Phoenix.Router.PathTest do
  use ExUnit.Case
  alias Phoenix.Router.Path

  doctest Path

  test "build with no params returns given path" do
    assert Path.build("pages/about", []) == "/pages/about"
  end

  test "build with named params replaces matching keys with values" do
    assert Path.build("users/:id", id: 123) == "/users/123"
    assert Path.build("users/:user_id/comments/:id", user_id: 123, id: 1) ==
      "/users/123/comments/1"
  end

  test "build ensures leading forward slash" do
    assert Path.build("users/:id", id: 55) == "/users/55"
    assert Path.build("/users/:id", id: 55) == "/users/55"
  end

  test "ensure_leading_slash adds forward slash to route if missing" do
    assert Path.ensure_leading_slash("users/1") == "/users/1"
    assert Path.ensure_leading_slash("/users/1") == "/users/1"
  end
end
