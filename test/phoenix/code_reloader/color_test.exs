defmodule Phoenix.CodeReloader.ColorsTest do
  use ExUnit.Case, async: true
  alias Phoenix.CodeReloader.Colors

  test "no markup" do
    assert convert(["foo"]) == ~s(foo)
  end

  test "simple color" do
    assert convert([:red, "foo", :reset]) == ~s(<span style="color: red">foo</span>)
  end

  test "color with trailing text" do
    assert convert([:red, "foo", :reset, "bar"]) == ~s(<span style="color: red">foo</span>bar)
  end

  test "overwriting formats" do
    assert convert([:red, "red", :blue, "blue", :reset]) ==
      ~s(<span style="color: red">red</span><span style="color: blue">blue</span>)
  end

  test "multiple format codes" do
    assert convert(["start", :red, :bright, "middle", :blue, "blue", :reset, "end"]) ==
      ~s(start<span style="color: red; font-weight: bold">middle</span><span style="color: blue; font-weight: bold">blue</span>end)
  end

  test "unknown formats are safely ignored" do
    assert convert([:red, "red", :inverse, "red", :reset]) ==
      ~s(<span style="color: red">red</span><span style="color: red">red</span>)
  end

  defp convert(string) do
    string |> IO.ANSI.format_fragment() |> to_string() |> Colors.to_html()
  end
end
