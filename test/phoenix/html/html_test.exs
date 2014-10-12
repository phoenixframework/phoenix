defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML

  test "escape/1 escapes HTML entities" do
    assert HTML.escape("foo") == "foo"
    assert HTML.escape("<foo>") == "&lt;foo&gt;"
    assert HTML.escape("\" & \'") == "&quot; &amp; &#39;"
  end

  test "Phoenix.HTML.Safe for binaries" do
    assert HTML.Safe.to_string("<foo>") == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for io data" do
    assert HTML.Safe.to_string('<foo>') == "&lt;foo&gt;"
    assert HTML.Safe.to_string(['<foo>']) == "&lt;foo&gt;"
    assert HTML.Safe.to_string([?<, "foo" | ?>]) == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for atoms" do
    assert HTML.Safe.to_string(:'<foo>') == "&lt;foo&gt;"
  end

  test "Phoenix.HTML.Safe for safe data" do
    assert HTML.Safe.to_string(1) == "1"
    assert HTML.Safe.to_string(1.0) == "1.0"
    assert HTML.Safe.to_string({:safe, "<foo>"}) == "<foo>"
  end
end
