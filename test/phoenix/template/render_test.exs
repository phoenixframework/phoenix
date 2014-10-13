defmodule Phoenix.Template.RenderTest do
  use ExUnit.Case, async: true

  defmodule View do
    use Phoenix.Template, root: Path.join([__DIR__], "../../fixtures/templates")

    import Phoenix.HTML

    def render("user.json", [name: name]) do
      Poison.encode! %{id: 123, name: name}
    end
  end

  test "render regular function definitions" do
    assert IO.iodata_to_binary(View.render("user.json", name: "eric")) ==
      "{\"name\":\"eric\",\"id\":123}"
  end

  test "render eex templates sanitizes against xss by default" do
    assert View.render("show.html") ==
           {:safe, "<div>Show! </div>\n"}

    assert View.render("show.html", message: "<script>alert('xss');</script>") ==
           {:safe, "<div>Show! &lt;script&gt;alert(&#39;xss&#39;);&lt;/script&gt;</div>\n"}
  end

  test "render eex templates allows raw data to be injected" do
    html = View.render("safe.html", message: "<script>alert('xss');</script>")
    assert html == {:safe, "Raw <script>alert('xss');</script>\n"}
  end

  test "compiles templates from path" do
    assert View.render("show.html", message: "hello!") ==
           {:safe, "<div>Show! hello!</div>\n"}
  end

  test "compiler adds catch-all render/2 that raises UndefinedError" do
    assert_raise Phoenix.Template.UndefinedError, ~r/Could not render "not-exists.html".*/, fn ->
      View.render("not-exists.html")
    end
  end

  test "compiler ignores missing template path" do
    defmodule OtherViews do
      use Phoenix.Template, root: Path.join(__DIR__, "not-exists")
    end
  end
end
