defmodule NamingTest do
  use ExUnit.Case
  alias Phoenix.Naming

  test "snake_to_camel_case with string" do
    assert Naming.snake_to_camel_case("users") == "Users"
    assert Naming.snake_to_camel_case("users_controller") == "UsersController"
  end

  test "snake_to_camel_case with atom" do
    assert Naming.snake_to_camel_case(:users) == "Users"
    assert Naming.snake_to_camel_case(:users_controller) == "UsersController"
  end
end

