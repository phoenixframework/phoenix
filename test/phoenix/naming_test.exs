defmodule Phoenix.NamingTest do
  use ExUnit.Case, async: true
  alias Phoenix.Naming

  doctest Naming

  test "underscore/1 converts Strings to underscore" do
    assert Naming.underscore("FooBar") == "foo_bar"
    assert Naming.underscore("Foobar") == "foobar"
    assert Naming.underscore("Foo-bar") == "foo_bar"
    assert Naming.underscore("APIWorld") == "api_world"
    assert Naming.underscore("ErlangVM") == "erlang_vm"
    assert Naming.underscore("Tmp/../usr") == "tmp/../usr"
    assert Naming.underscore("Tmp/./usr") == "tmp///usr"
    assert Naming.underscore("Foo.") == "foo."
  end

  test "camelize/1 converts Strings to camel case" do
    assert Naming.camelize("foo_bar") == "FooBar"
    assert Naming.camelize("foo__bar") == "FooBar"
    assert Naming.camelize("foobar") == "Foobar"
    assert Naming.camelize("_foobar") == "Foobar"
    assert Naming.camelize("foobar_") == "Foobar"
  end
end
