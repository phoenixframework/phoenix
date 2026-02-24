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
    assert Naming.underscore("") == ""
    assert Naming.underscore("FooBar1") == "foo_bar1"
    assert Naming.underscore("fooBar1") == "foo_bar1"
  end

  test "camelize/1 converts Strings to camel case" do
    assert Naming.camelize("foo_bar") == "FooBar"
    assert Naming.camelize("foo__bar") == "FooBar"
    assert Naming.camelize("foobar") == "Foobar"
    assert Naming.camelize("_foobar") == "Foobar"
    assert Naming.camelize("__foobar") == "Foobar"
    assert Naming.camelize("_FooBar") == "FooBar"
    assert Naming.camelize("foobar_") == "Foobar"
    assert Naming.camelize("foobar_1") == "Foobar1"
    assert Naming.camelize("") == ""
    assert Naming.camelize("_foo_bar") == "FooBar"
    assert Naming.camelize("foo_bar_1") == "FooBar1"
  end

  test "camelize/2 converts Strings to lower camel case" do
    assert Naming.camelize("foo_bar", :lower) == "fooBar"
    assert Naming.camelize("foo__bar", :lower) == "fooBar"
    assert Naming.camelize("foobar", :lower) == "foobar"
    assert Naming.camelize("_foobar", :lower) == "foobar"
    assert Naming.camelize("__foobar", :lower) == "foobar"
    assert Naming.camelize("_FooBar", :lower) == "fooBar"
    assert Naming.camelize("foobar_", :lower) == "foobar"
    assert Naming.camelize("foobar_1", :lower) == "foobar1"
    assert Naming.camelize("", :lower) == ""
    assert Naming.camelize("_foo_bar", :lower) == "fooBar"
    assert Naming.camelize("foo_bar_1", :lower) == "fooBar1"
  end

  test "humanize/1 converts atoms and strings to humanized form" do
    assert Naming.humanize(:username) == "Username"
    assert Naming.humanize(:created_at) == "Created at"
    assert Naming.humanize("user_id") == "User"
    assert Naming.humanize("foo_bar") == "Foo bar"
    assert Naming.humanize(:email_id) == "Email"
  end

  test "titleize/1 converts atoms and strings to titleized form" do
    assert Naming.titleize(:username) == "Username"
    assert Naming.titleize(:created_at) == "Created At"
    assert Naming.titleize("user_id") == "User"
    assert Naming.titleize("foo_bar") == "Foo Bar"
    assert Naming.titleize(:email_id) == "Email"
  end
end
