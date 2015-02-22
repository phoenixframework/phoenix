defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML.Element

  test "element without do and attributes" do
    assert Element.element("span") == {:safe, [["<span>" | ""] | "</span>"]}
    assert Element.element(:span) == {:safe, [["<span>" | ""] | "</span>"]}
  end

  test "element with do but without attributes" do
    out = Element.element :span do
      "&"
    end
    assert out == {:safe, [["<span>" | "&amp;"] | "</span>"]}
  end

  test "element without do, but with attributes" do
    assert Element.element(:span, [class: "special"]) == {:safe, [["<span class=\"special\">" | ""] | "</span>"]}
    assert Element.element(:span, [foo: "&bar"]) == {:safe, [["<span foo=\"&amp;bar\">" | ""] | "</span>"]}
    assert Element.element(:span, [class: "special", "data-attr": "value"]) == {:safe, [["<span data-attr=\"value\" class=\"special\">" | ""] | "</span>"]}
  end
end

