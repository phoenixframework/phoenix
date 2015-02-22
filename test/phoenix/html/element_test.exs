defmodule Phoenix.HTMLTest do
  use ExUnit.Case, async: true

  alias Phoenix.HTML.Element

  test "element without do" do
    assert Element.element("span") == {:safe, [["<span>" | ""] | "</span>"]}
    assert Element.element(:span) == {:safe, [["<span>" | ""] | "</span>"]}
    assert Element.element(:span, [foo: :bar, baz: "value"]) == {:safe, [["<span baz=\"value\" foo=\"bar\">" | ""] | "</span>"]}
  end

  test "element with do" do
    out = Element.element :span do
      "fun"
    end
    assert out == {:safe, [["<span>" | "fun"] | "</span>"]}

    out = Element.element :span, [foo: :bar] do
      {:safe, "safe"}
    end
    assert out == {:safe, [["<span foo=\"bar\">" | "safe"] | "</span>"]}
  end

  test "html safety" do
    assert Element.element(:span, [foo: "&bar"]) == {:safe, [["<span foo=\"&amp;bar\">" | ""] | "</span>"]}

    out = Element.element :span do
      "&"
    end
    assert out == {:safe, [["<span>" | "&amp;"] | "</span>"]}
  end
end

