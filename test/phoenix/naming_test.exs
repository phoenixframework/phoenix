defmodule Phoenix.NamingTest do
  use ExUnit.Case
  alias Phoenix.Naming

  doctest Naming

  test "underscore/1 converts Strings to underscore" do
    assert Naming.underscore("FooBar") == "foo_bar"
    assert Naming.underscore("Foobar") == "foobar"
    assert Naming.underscore("Foo-bar") == "foo_bar"
  end

  test "camelize/1 converts Strings to camel case" do
    assert Naming.camelize("foo_bar") == "FooBar"
    assert Naming.camelize("foobar") == "Foobar"
  end

  test "module_name/1 returns the name of the module without Elixir prefix" do
    assert Naming.module_name(Phoenix.Naming) == "Phoenix.Naming"
    assert Naming.module_name(:math) == "math"
  end
end
