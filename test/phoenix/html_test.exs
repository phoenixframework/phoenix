defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true
  use RouterHelper

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

  test "get_flash/2 returns the flash message" do
    conn = conn_with_session
      |> Phoenix.Controller.fetch_flash([])
      |> Phoenix.Controller.put_flash(:error, "oh noes!")
      |> Phoenix.Controller.put_flash(:notice, "false alarm!")

    assert HTML.get_flash(conn, :error) == "oh noes!"
    assert HTML.get_flash(conn, :notice) == "false alarm!"
  end

  test "get_flash/2 raises ArugmentError when session not previously fetched" do
    assert_raise ArgumentError, fn ->
      HTML.get_flash(%Plug.Conn{}, :boom)
    end
  end
end
