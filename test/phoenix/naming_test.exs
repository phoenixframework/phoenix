defmodule Phoenix.NamingTest do
  use ExUnit.Case, async: true
  alias Phoenix.Naming

  doctest Naming

  test "underscore/1 converts Strings to underscore" do
    assert Naming.underscore("FooBar") == "foo_bar"
    assert Naming.underscore("Foobar") == "foobar"
    assert Naming.underscore("APIWorld") == "api_world"
    assert Naming.underscore("ErlangVM") == "erlang_vm"
    assert Naming.underscore("API.V1.User") == "api/v1/user"
  end

  test "camelize/1 converts Strings to camel case" do
    assert Naming.camelize("foo_bar") == "FooBar"
    assert Naming.camelize("foo__bar") == "FooBar"
    assert Naming.camelize("foobar") == "Foobar"
    assert Naming.camelize("_foobar") == "Foobar"
    assert Naming.camelize("__foobar") == "Foobar"
    assert Naming.camelize("_FooBar") == "FooBar"
    assert Naming.camelize("foobar_") == "Foobar"
  end

  test "camelize/2 converts Strings to lower camel case" do
    assert Naming.camelize("foo_bar", :lower) == "fooBar"
    assert Naming.camelize("foo__bar", :lower) == "fooBar"
    assert Naming.camelize("foobar", :lower) == "foobar"
    assert Naming.camelize("_foobar", :lower) == "foobar"
    assert Naming.camelize("__foobar", :lower) == "foobar"
    assert Naming.camelize("_FooBar", :lower) == "fooBar"
    assert Naming.camelize("foobar_", :lower) == "foobar"
  end
end
