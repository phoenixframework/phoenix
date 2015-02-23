defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true
  use RouterHelper

  doctest Phoenix.HTML

  use Phoenix.HTML
  alias Phoenix.HTML.Safe

  test "html_escape/1 entities" do
    assert html_escape("foo") == "foo"
    assert html_escape("<foo>") == "&lt;foo&gt;"
    assert html_escape("\" & \'") == "&quot; &amp; &#39;"
  end

  test "imports controller functions" do
    conn = conn(:get, "/") |> put_private(:phoenix_action, :hello)
    assert action_name(conn) == :hello
  end

  test "Phoenix.HTML.Safe for binaries" do
    assert Safe.to_iodata("<foo>") == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for io data" do
    assert Safe.to_iodata('<foo>') == ["&lt;", 102, 111, 111, "&gt;"]
    assert Safe.to_iodata(['<foo>']) == [["&lt;", 102, 111, 111, "&gt;"]]
    assert Safe.to_iodata([?<, "foo" | ?>]) == ["&lt;", "foo" | "&gt;"]
  end

  test "Phoenix.HTML.Safe for atoms" do
    assert Safe.to_iodata(:'<foo>') == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for safe data" do
    assert Safe.to_iodata(1) == "1"
    assert Safe.to_iodata(1.0) == "1.0"
    assert Safe.to_iodata({:safe, "<foo>"}) == "<foo>"
  end
end
