defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true

  doctest Phoenix.HTML
  alias Phoenix.HTML

  test "html_escape/1 entities" do
    assert HTML.html_escape("foo") == {:safe, "foo"}
    assert HTML.html_escape("<foo>") == {:safe, "&lt;foo&gt;"}
    assert HTML.html_escape("\" & \'") == {:safe, "&quot; &amp; &#39;"}
  end

  test "Phoenix.HTML.Safe for binaries" do
    assert HTML.Safe.to_iodata("<foo>") == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for io data" do
    assert HTML.Safe.to_iodata('<foo>') == ["&lt;", 102, 111, 111, "&gt;"]
    assert HTML.Safe.to_iodata(['<foo>']) == [["&lt;", 102, 111, 111, "&gt;"]]
    assert HTML.Safe.to_iodata([?<, "foo" | ?>]) == ["&lt;", "foo" | "&gt;"]
  end

  test "Phoenix.HTML.Safe for atoms" do
    assert HTML.Safe.to_iodata(:'<foo>') == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for safe data" do
    assert HTML.Safe.to_iodata(1) == "1"
    assert HTML.Safe.to_iodata(1.0) == "1.0"
    assert HTML.Safe.to_iodata({:safe, "<foo>"}) == "<foo>"
  end
end
