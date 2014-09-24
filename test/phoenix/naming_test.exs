defmodule Phoenix.NamingTest do
  use ExUnit.Case, async: true
  alias Phoenix.Naming

  doctest Naming

  test "underscore/1 converts Strings to underscore" do
    assert Naming.underscore("FooBar") == "foo_bar"
    assert Naming.underscore("Foobar") == "foobar"
    assert Naming.underscore("Foo-bar") == "foo_bar"
    assert Naming.underscore("APIWorld") == "api_world"
  end

  test "camelize/1 converts Strings to camel case" do
    assert Naming.camelize("foo_bar") == "FooBar"
    assert Naming.camelize("foobar") == "Foobar"
  end
end
