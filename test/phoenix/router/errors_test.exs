defmodule Phoenix.Router.ErrorsTest do
  use ExUnit.Case
  alias Phoenix.Router.Errors

  test "path without leading slash" do
    path = "users/:id"

    assert_raise ArgumentError, fn ->
      Errors.ensure_valid_path!(path)
    end
  end

  test "path with leading slash" do
    path = "/users/:id"

    assert Errors.ensure_valid_path!(path) == nil
  end
end
