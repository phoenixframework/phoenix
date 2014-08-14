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

  test "build with named params uses extras to construct the query string" do
    assert Path.build("users/:user_id/comments/:id", user_id: 123, id: 1, highlights: %{red: "abc", yellow: "def"}) ==
      "/users/123/comments/1?highlights[red]=abc&highlights[yellow]=def"
  end

  test "build ensures leading forward slash" do
    assert Path.build("users/:id", id: 55) == "/users/55"
    assert Path.build("/users/:id", id: 55) == "/users/55"
  end

  test "build/4 replaces named params in pathand build query_string params" do
    assert Path.build("users/:id", [id: 55], []) == "/users/55"
    assert Path.build("/users/:id", [id: 55], foo: "bar") == "/users/55?foo=bar"
  end

  test "ensure_leading_slash adds forward slash to route if missing" do
    assert Path.ensure_leading_slash("users/1") == "/users/1"
    assert Path.ensure_leading_slash("/users/1") == "/users/1"
  end

  test "build_url includes the host and scheme" do
    path = Path.build("users/:id", id: 1)
    assert Path.build_url(path, host: "example.com", ssl: true) ==
      "https://example.com/users/1"
  end

  test "build_url includes the host and default scheme" do
    path = Path.build("users/:id", id: 1)
    assert Path.build_url(path, host: "example.com") ==
      "http://example.com/users/1"
  end

  test "build_url includes the port" do
    path = Path.build("users/:id", id: 1)
    assert Path.build_url(path, host: "example.com", port: 1200) ==
      "http://example.com:1200/users/1"
  end

  test "build_url does not include the port for 80 and 443" do
    path = Path.build("users/:id", id: 1)
    assert Path.build_url(path, host: "example.com", port: 80) ==
      "http://example.com/users/1"

    assert Path.build_url(path, host: "example.com", port: 443) ==
      "http://example.com/users/1"
  end

end
